import Foundation

public struct WorkflowStats {
    let name: String
    let uses: Int
    let path: String
}

@MainActor
public final class WorkflowTracker {
    public static let shared = WorkflowTracker()

    private var antigravityDir: URL { AntigravityAPI.shared.baseDir }
    private var workflowsDir: URL { antigravityDir.appendingPathComponent("global_workflows") }
    private var archiveDir: URL { antigravityDir.appendingPathComponent("workflows_archive") }
    private var brainDir: URL { antigravityDir.appendingPathComponent("brain") }

    private init() {}

    public func fetchUsageStats() -> [WorkflowStats] {
        guard let workflowFiles = findMarkdownFiles(in: workflowsDir) else { return [] }

        var knownWorkflows: [String: String] = [:] // name -> path
        for file in workflowFiles {
            // ignore archive dir
            if file.path.contains("/_archive/") { continue }
            let name = file.deletingPathExtension().lastPathComponent
            knownWorkflows[name] = file.path
        }

        guard let logDirs = try? FileManager.default.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return [] }

        var usageCount: [String: Int] = [:]
        for name in knownWorkflows.keys { usageCount[name] = 0 }

        for dir in logDirs {
            let logFile = dir.appendingPathComponent(".system_generated/logs/overview.txt")
            if let content = try? String(contentsOf: logFile, encoding: .utf8) {
                for name in knownWorkflows.keys {
                    let pattern = "(?:@\\[)?/\(NSRegularExpression.escapedPattern(for: name))(?:])?\\b"
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let matches = regex.numberOfMatches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))
                        usageCount[name, default: 0] += matches
                    }
                }
            }
        }

        var stats: [WorkflowStats] = []
        for (name, count) in usageCount {
            if let path = knownWorkflows[name] {
                stats.append(WorkflowStats(name: name, uses: count, path: path))
            }
        }

        return stats.sorted { $0.uses > $1.uses }
    }

    public func archiveUnusedWorkflows() {
        let stats = fetchUsageStats()
        let unused = stats.filter { $0.uses == 0 }

        if !FileManager.default.fileExists(atPath: archiveDir.path) {
            try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true, attributes: nil)
        }

        for workflow in unused {
            let sourceURL = URL(fileURLWithPath: workflow.path)
            let destURL = archiveDir.appendingPathComponent(sourceURL.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destURL)
                print("Archived unused workflow: \(workflow.name)")
            } catch {
                print("Failed to archive \(workflow.name): \(error)")
            }
        }
    }

    private func findMarkdownFiles(in directory: URL) -> [URL]? {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        var files: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "md" {
                files.append(fileURL)
            }
        }
        return files
    }
}
