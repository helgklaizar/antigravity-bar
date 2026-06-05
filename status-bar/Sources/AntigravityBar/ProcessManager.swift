import Foundation
import Darwin

struct ProcessItem: Identifiable {
    let id = UUID()
    let pid: Int
    let rssKB: Int
    let name: String
    let appName: String
    let appPath: String
    let isSystem: Bool
}

struct AppGroup: Identifiable {
    let id: String // appName
    let appName: String
    let appPath: String
    var totalRssKB: Int
    var processes: [ProcessItem]

    var isSystemGroup: Bool {
        return processes.allSatisfy { $0.isSystem }
    }
}

class ProcessManager {
    static func getTopProcesses() -> [AppGroup] {
        let maxPids = 4096
        var pids = [pid_t](repeating: 0, count: maxPids)
        let returnedBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(maxPids * MemoryLayout<pid_t>.stride))
        let numPids = Int(returnedBytes) / MemoryLayout<pid_t>.stride

        var allProcesses: [ProcessItem] = []

        for i in 0..<numPids {
            let pid = pids[i]
            if pid <= 0 { continue }

            var pathBuffer = [CChar](repeating: 0, count: Int(4096))
            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            guard pathLen > 0 else { continue }

            let realPath = pathBuffer.withUnsafeBufferPointer { ptr in
                // [C-8] Guard against nil baseAddress for empty buffers
                guard let base = ptr.baseAddress else { return "" }
                return String(cString: base)
            }
            guard !realPath.isEmpty else { continue }
            let name = (realPath as NSString).lastPathComponent

            var info = proc_taskinfo()
            let infoSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, infoSize)
            if result == infoSize {
                let rss = Int(info.pti_resident_size / 1024)
                if rss <= 0 { continue }

                let pathLower = realPath.lowercased()
                let nameLower = name.lowercased()

                var isSystem = (realPath.hasPrefix("/System/") ||
                                realPath.hasPrefix("/usr/") ||
                                realPath.hasPrefix("/sbin/") ||
                                realPath.hasPrefix("/bin/") ||
                                realPath.hasPrefix("/Library/Apple/") ||
                                realPath.contains("/Library/Developer/") ||
                                realPath.contains("/Contents/Developer/") ||
                                name.hasPrefix("com.apple.") ||
                                realPath.hasPrefix("/Library/SystemExtensions/"))
                               && !realPath.hasPrefix("/usr/local/")

                if realPath.contains("Safari.app") || realPath.contains("com.apple.WebKit") || realPath.contains("Safari") {
                    isSystem = false
                }

                var appName = name
                var appPath = realPath

                let isAntigravity = pathLower.contains("antigravity") || pathLower.contains(".gemini") || nameLower.contains("antigravity") || nameLower.contains("gemini") || nameLower.contains("language_server")

                if isSystem {
                    appName = "macOS System"
                } else if isAntigravity {
                    let standardNames = ["antigravity", "antigravitybar", "gemini", "language_server", "language-server"]
                    let isStandard = standardNames.contains(where: { nameLower.contains($0) })
                    if isStandard {
                        appName = "Antigravity (Стандартные)"
                        if realPath.contains("Antigravity IDE.app") {
                            appPath = "/Applications/Antigravity IDE.app"
                        } else if realPath.contains("Antigravity.app") {
                            appPath = "/Applications/Antigravity.app"
                        } else if realPath.contains("AntigravityBar") {
                            appPath = "/Applications/Antigravity Bar.app"
                        }
                    } else {
                        appName = "Antigravity (Дополнительные)"
                        appPath = ""
                    }
                } else if realPath.contains("com.apple.WebKit") || name.contains("Safari") {
                    appName = "Safari"
                    appPath = "/Applications/Safari.app"
                } else if let appRange = realPath.range(of: ".app/") {
                    let prefix = realPath[..<appRange.lowerBound]
                    appName = (prefix as NSString).lastPathComponent + ".app"
                    appPath = String(prefix) + ".app"
                } else if name.contains("Helper") {
                    if let firstWord = appName.split(separator: " ").first {
                        appName = String(firstWord)
                    }
                }

                allProcesses.append(ProcessItem(pid: Int(pid), rssKB: rss, name: name, appName: appName, appPath: appPath, isSystem: isSystem))
            }
        }

        var grouped: [String: [ProcessItem]] = [:]
        for p in allProcesses {
            var groupName = p.appName
            if groupName.hasSuffix(".app") {
                groupName = String(groupName.dropLast(4))
            }
            grouped[groupName, default: []].append(p)
        }

        var groups: [AppGroup] = grouped.map { (key, value) in
            let total = value.reduce(0) { $0 + $1.rssKB }
            let sortedProcesses = value.sorted { $0.rssKB > $1.rssKB }
            let path = sortedProcesses.first?.appPath ?? ""
            return AppGroup(id: key, appName: key, appPath: path, totalRssKB: total, processes: sortedProcesses)
        }

        groups.sort { $0.totalRssKB > $1.totalRssKB }
        return Array(groups.prefix(20))
    }

    static func formatMemory(_ kb: Int) -> String {
        let mb = Double(kb) / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        }
        return String(format: "%.0f MB", mb)
    }

    static func killProcess(pid: Int) {
        print("[ProcessManager] Attempting to kill process \(pid)...")
        let result = kill(pid_t(pid), SIGTERM)
        if result != 0 {
            let err = errno
            let errStr = String(cString: strerror(err))
            print("[ProcessManager] Failed to kill process \(pid): errno \(err) (\(errStr))")
        } else {
            print("[ProcessManager] Successfully sent SIGTERM to process \(pid)")
        }
    }
}
