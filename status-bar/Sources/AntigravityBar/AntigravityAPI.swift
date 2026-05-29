import Foundation
import AppKit
import Darwin

// MARK: - Daemon Discovery

struct DaemonInfo: Codable {
    let pid: Int
    let httpsPort: Int
    let httpPort: Int
    let csrfToken: String
    let path: String
    let isHttps: Bool
}

struct ModelQuota: Codable {
    let label: String
    let remainingPercentage: Double  // 0..100
    let isExhausted: Bool
    let timeUntilReset: String
    let secondsUntilReset: Double
}

struct QuotaData: Codable {
    let email: String?
    let name: String?
    let models: [ModelQuota]
    let timestamp: Date
    let credits: String?
}

struct AvailableCredit: Decodable {
    let creditType: String?
    let creditAmount: String?
}

struct UserTier: Decodable {
    let availableCredits: [AvailableCredit]?
}

struct CascadeUserStatus: Decodable {
    let userStatus: UserStatusContainer
}

struct UserStatusContainer: Decodable {
    let cascadeModelConfigData: CascadeModelConfigData
    let email: String?
    let name: String?
    let userTier: UserTier?
}

class InsecureSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
let sharedInsecureSession = URLSession(configuration: .ephemeral, delegate: InsecureSessionDelegate(), delegateQueue: nil)

struct CascadeModelConfigData: Decodable {
    let clientModelConfigs: [ClientModelConfig]
}

struct ClientModelConfig: Decodable {
    let label: String?
    let quotaInfo: QuotaInfo?
}

struct QuotaInfo: Decodable {
    let remainingFraction: Double?
    let resetTime: String?
}

// MARK: - API

@MainActor
class AntigravityAPI: @unchecked Sendable {
    static let shared = AntigravityAPI()
    
    let env: SystemEnvironment
    
    @MainActor public var baseDir: URL {
        didSet {
            updateCacheSize()
        }
    }
    
    private var cachedDaemon: DaemonInfo?
    private var cachedCacheSize: (String, Double) = ("0 B", 0.0)
    private var cacheTimer: Timer?
    
    init(env: SystemEnvironment = DefaultSystemEnvironment()) {
        self.env = env
        let home = NSHomeDirectory()
        let ideDir = URL(fileURLWithPath: home).appendingPathComponent(".gemini/antigravity-ide")
        let baseDirName = FileManager.default.fileExists(atPath: ideDir.path) ? "antigravity-ide" : "antigravity"
        self.baseDir = URL(fileURLWithPath: home).appendingPathComponent(".gemini/\(baseDirName)")
        
        startCacheSizeUpdater()
    }
    
    private func startCacheSizeUpdater() {
        updateCacheSize()
        cacheTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCacheSize()
            }
        }
    }
    
    private func updateCacheSize() {
        let brain = self.brainDir
        let conversations = self.conversationsDir
        let htmlArts = self.htmlArtsDir
        let implicit = self.implicitDir
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let total = self.dirSize(brain) + self.dirSize(conversations) + self.dirSize(htmlArts) + self.dirSize(implicit)
            let formatted = self.formatDirSize(total)
            let mb = Double(total) / (1024 * 1024)
            DispatchQueue.main.async {
                self.cachedCacheSize = (formatted, mb)
            }
        }
    }

    var brainDir: URL { baseDir.appendingPathComponent("brain") }
    var conversationsDir: URL { baseDir.appendingPathComponent("conversations") }
    var browserRecDir: URL { baseDir.appendingPathComponent("browser_recordings") }
    var htmlArtsDir: URL { baseDir.appendingPathComponent("html_artifacts") }
    var implicitDir: URL { baseDir.appendingPathComponent("implicit") }
    var knowledgeDir: URL { baseDir.appendingPathComponent("knowledge") }
    var skillsDir: URL { baseDir.appendingPathComponent("skills") }
    var workflowsDir: URL { baseDir.appendingPathComponent("global_workflows") }

    // MARK: - Daemon Discovery (process-based + JSON fallback)

    func findActiveDaemon() -> DaemonInfo? {
        if let cached = cachedDaemon, isHTTPReachable(port: cached.httpPort, csrfToken: cached.csrfToken, isHttps: cached.isHttps) {
            return cached
        }
        
        // Primary: find running language_server process and extract info
        if let info = findActiveDaemons().first {
            cachedDaemon = info
            return info
        }
        
        cachedDaemon = nil
        return nil
    }

    private struct LSProcessInfo {
        let pid: Int
        let csrfToken: String
        let extPort: Int?
        let path: String
    }

    private func getListeningPorts(for pid: Int) -> [Int] {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-a", "-p", String(pid), "-iTCP", "-sTCP:LISTEN", "-n", "-P"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var ports: [Int] = []
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("LISTEN") {
                        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if parts.count >= 2, parts.last == "(LISTEN)" {
                            let nameField = parts[parts.count - 2]
                            if let portStr = nameField.components(separatedBy: ":").last,
                               let port = Int(portStr) {
                                ports.append(port)
                            }
                        }
                    }
                }
                return ports
            }
        } catch {
            // Ignore error
        }
        return []
    }

    /// Parse running language_server process args natively to get csrf_token and extension_server_port,
    /// then validate HTTP on active ports
    func findActiveDaemons() -> [DaemonInfo] {
        let psInfo = findLanguageServerProcesses()
        guard !psInfo.isEmpty else { return [] }

        var daemons: [DaemonInfo] = []
        for info in psInfo {
            // We expect the HTTP port to be either the extension port itself, or +1, or +2.
            // For standalone daemons without an extension port, we scan standard ports.
            let basePorts: [Int]
            if let ePort = info.extPort {
                basePorts = [ePort + 2, ePort + 1, ePort]
            } else {
                basePorts = [58642, 58641, 58622, 58621, 58620]
            }

            let dynamicPorts = getListeningPorts(for: info.pid)
            let portsToTry = dynamicPorts + basePorts + [50150, 50151]

            for port in portsToTry {
                if isHTTPReachable(port: port, csrfToken: info.csrfToken, isHttps: true) {
                    daemons.append(DaemonInfo(pid: info.pid, httpsPort: port, httpPort: port, csrfToken: info.csrfToken, path: info.path, isHttps: true))
                    break
                } else if isHTTPReachable(port: port, csrfToken: info.csrfToken, isHttps: false) {
                    daemons.append(DaemonInfo(pid: info.pid, httpsPort: port, httpPort: port, csrfToken: info.csrfToken, path: info.path, isHttps: false))
                    break
                }
            }
        }
        return daemons
    }

    /// Find all language_server processes and extract PID + csrf_token natively
    private func findLanguageServerProcesses() -> [LSProcessInfo] {
        var results: [LSProcessInfo] = []
        let maxPids = 2048
        var pids = [pid_t](repeating: 0, count: maxPids)
        let returnedBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(maxPids * MemoryLayout<pid_t>.stride))
        let numPids = Int(returnedBytes) / MemoryLayout<pid_t>.stride
        
        for i in 0..<numPids {
            let pid = pids[i]
            if pid <= 0 { continue }
            
            var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            if pathLen > 0 {
                let path = pathBuffer.withUnsafeBufferPointer { ptr in
                    String(cString: ptr.baseAddress!)
                }
                let lowercasedPath = path.lowercased()
                if lowercasedPath.contains("language_server") {
                    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
                    var size: Int = 0
                    sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0)
                    if size > 0 {
                        var buffer = [CChar](repeating: 0, count: size)
                        if sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 {
                            let argc = buffer.withUnsafeBufferPointer { ptr -> Int32 in
                                ptr.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
                            }
                            var offset = MemoryLayout<Int32>.size
                            while offset < buffer.count && buffer[offset] != 0 { offset += 1 }
                            while offset < buffer.count && buffer[offset] == 0 { offset += 1 }
                            
                            var args = [String]()
                            for _ in 0..<argc {
                                let argStart = offset
                                while offset < buffer.count && buffer[offset] != 0 { offset += 1 }
                                args.append(String(cString: Array(buffer[argStart...offset])))
                                offset += 1
                            }
                            
                            var port: Int? = nil
                            if let tokenIdx = args.firstIndex(of: "--csrf_token"), tokenIdx + 1 < args.count {
                                if let extIdx = args.firstIndex(of: "--extension_server_port"), extIdx + 1 < args.count {
                                    port = Int(args[extIdx + 1])
                                }
                                results.append(LSProcessInfo(pid: Int(pid), csrfToken: args[tokenIdx + 1], extPort: port, path: path))
                            }
                        }
                    }
                }
            }
        }
        return results
    }



    /// Lightweight HTTP check — send minimal request, expect any response
    private func isHTTPReachable(port: Int, csrfToken: String, isHttps: Bool = false) -> Bool {
        let scheme = isHttps ? "https" : "http"
        let url = URL(string: "\(scheme)://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/GetUserStatus")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 2
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["metadata": ["ideName": "antigravity"]])

        let semaphore = DispatchSemaphore(value: 0)
        final class ReachableStatus: @unchecked Sendable { var ok = false }
        let status = ReachableStatus()
        
        sharedInsecureSession.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                status.ok = true
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return status.ok
    }    // Fetch quota using Connect/Protobuf JSON over HTTP
    func fetchQuota(daemon: DaemonInfo, completion: @Sendable @escaping (QuotaData?) -> Void) {
        let scheme = daemon.isHttps ? "https" : "http"
        let url = URL(string: "\(scheme)://127.0.0.1:\(daemon.httpPort)/exa.language_server_pb.LanguageServerService/GetUserStatus")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(daemon.csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        let body = ["metadata": ["ideName": "antigravity", "extensionName": "antigravity", "locale": "en"]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        sharedInsecureSession.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let parsed = try? JSONDecoder().decode(CascadeUserStatus.self, from: data)
            else {
                completion(nil)
                return
            }
            completion(self.parseQuota(parsed))
        }.resume()
    }

    nonisolated func parseQuota(_ parsed: CascadeUserStatus) -> QuotaData? {
        let configs = parsed.userStatus.cascadeModelConfigData.clientModelConfigs
        let email = parsed.userStatus.email
        let name = parsed.userStatus.name

        let models: [ModelQuota] = configs.compactMap { config in
            guard let quotaInfo = config.quotaInfo,
                  let label = config.label
            else { return nil }

            let remainingFraction = quotaInfo.remainingFraction ?? 0.0
            let resetTimeStr = quotaInfo.resetTime ?? ""
            let resetDate = ISO8601DateFormatter().date(from: resetTimeStr) ?? Date()
            let secsLeft = max(0, resetDate.timeIntervalSinceNow)
            let timeStr = formatTime(Int(secsLeft * 1000))

            return ModelQuota(
                label: label,
                remainingPercentage: remainingFraction * 100,
                isExhausted: remainingFraction == 0,
                timeUntilReset: timeStr,
                secondsUntilReset: secsLeft
            )
        }

        let credits = parsed.userStatus.userTier?.availableCredits?.first?.creditAmount
        return QuotaData(email: email, name: name, models: models, timestamp: Date(), credits: credits)
    }

    nonisolated func formatTime(_ ms: Int) -> String {
        if ms <= 0 { return "Ready" }
        let minutes = Int(ceil(Double(ms) / 60000))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours >= 24 {
            let days = hours / 24
            let rem = hours % 24
            return "\(days)d \(rem)h"
        }
        return "\(hours)h \(minutes % 60)m"
    }

    // MARK: - Actions

    func clearCache() {
        let dirsToClear = [brainDir, conversationsDir, htmlArtsDir, implicitDir]
        for dir in dirsToClear {
            guard let contents = try? env.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []) else { continue }
            for item in contents {
                let name = item.lastPathComponent
                if name == ".DS_Store" { continue }
                try? env.removeItem(at: item)
            }
        }
    }

    func clearBrain() {
        guard let contents = try? env.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: nil, options: []) else { return }
        for item in contents {
            let name = item.lastPathComponent
            if name == ".DS_Store" { continue }
            try? env.removeItem(at: item)
        }
    }

    func clearRecordings() {
        let dirsToClear = [browserRecDir]
        for dir in dirsToClear {
            guard let contents = try? env.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []) else { continue }
            for item in contents {
                let name = item.lastPathComponent
                if name == ".DS_Store" { continue }
                try? env.removeItem(at: item)
            }
        }
    }

    func openBrain() {
        NSWorkspace.shared.open(brainDir)
    }

    func openDirectory(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func openKnowledge() { openDirectory(knowledgeDir) }
    func openSkills() { openDirectory(skillsDir) }
    func openWorkflows() { openDirectory(workflowsDir) }

    // MARK: - Brain size

    func brainSize() -> String {
        return formatDirSize(dirSize(brainDir))
    }

    func cacheSize() -> (formatted: String, megabytes: Double) {
        return cachedCacheSize
    }

    func recordingsSize() -> String {
        return formatDirSize(dirSize(browserRecDir))
    }

    nonisolated private func dirSize(_ dir: URL) -> Int64 {
        guard let enumerator = env.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                total += Int64(vals.fileSize ?? 0)
            }
        }
        return total
    }

    nonisolated private func formatDirSize(_ total: Int64) -> String {
        if total < 1024 { return "\(total) B" }
        if total < 1024*1024 { return String(format: "%.1f KB", Double(total)/1024) }
        return String(format: "%.1f MB", Double(total)/(1024*1024))
    }
}
