import Foundation

struct SystemReport {
    var hasBrew: Bool
    var hasGit: Bool
    var hasNode: Bool
    var hasRust: Bool
    var hasAntigravity: Bool

    var foundProjects: [String]
    var warnings: [String]
}

class SystemAnalyzer {
    static func analyze() -> SystemReport {
        var report = SystemReport(hasBrew: false, hasGit: false, hasNode: false, hasRust: false, hasAntigravity: false, foundProjects: [], warnings: [])

        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser

        // 1. Check Binaries
        report.hasBrew = fileManager.fileExists(atPath: "/opt/homebrew/bin/brew") || fileManager.fileExists(atPath: "/usr/local/bin/brew")
        report.hasGit = fileManager.fileExists(atPath: "/usr/bin/git")
        report.hasNode = fileManager.fileExists(atPath: "/opt/homebrew/bin/node") || fileManager.fileExists(atPath: "/usr/local/bin/node") || fileManager.fileExists(atPath: homeDir.appendingPathComponent(".nvm").path)
        report.hasRust = fileManager.fileExists(atPath: homeDir.appendingPathComponent(".cargo/bin/cargo").path)

        // 2. Check Ecosystem
        report.hasAntigravity = fileManager.fileExists(atPath: homeDir.appendingPathComponent(".gemini/antigravity").path) ||
                                fileManager.fileExists(atPath: homeDir.appendingPathComponent(".gemini/antigravity-ide").path)

        // 3. Deep Scan Projects
        let projectsDir = homeDir.appendingPathComponent("Projects")
        if fileManager.fileExists(atPath: projectsDir.path) {
            do {
                let categories = try fileManager.contentsOfDirectory(atPath: projectsDir.path)
                for category in categories where category != ".DS_Store" {
                    let categoryPath = projectsDir.appendingPathComponent(category)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: categoryPath.path, isDirectory: &isDir), isDir.boolValue {
                        let projects = try? fileManager.contentsOfDirectory(atPath: categoryPath.path)
                        for project in projects ?? [] {
                            let projectPath = categoryPath.appendingPathComponent(project)

                            // JS/TS
                            if fileManager.fileExists(atPath: projectPath.appendingPathComponent("package.json").path) {
                                if !report.foundProjects.contains("Node/React") { report.foundProjects.append("Node/React") }
                            }

                            // Rust
                            if fileManager.fileExists(atPath: projectPath.appendingPathComponent("Cargo.toml").path) {
                                if !report.foundProjects.contains("Rust/Tauri") { report.foundProjects.append("Rust/Tauri") }
                            }
                        }
                    }
                }
            } catch {
                print("Error scanning projects: \(error)")
            }
        }

        // 4. Generate Diagnostics
        if !report.hasBrew { report.warnings.append("Homebrew is missing. You will need it to install basic CLI tools.") }
        if !report.hasGit { report.warnings.append("Git is missing. Required for cloning repositories.") }
        if !report.hasAntigravity { report.warnings.append("Antigravity is not initialized. We will install the Core Ecosystem.") }

        if report.foundProjects.isEmpty {
            report.warnings.append("No active projects found. Showing default general-purpose AI skills.")
        }

        return report
    }
}
