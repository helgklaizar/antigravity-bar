import Foundation
import AppKit

@MainActor
struct TerminalHelper {
    static var antigravityCLI: String {
        let isVersion2 = AntigravityAPI.shared.baseDir.lastPathComponent == "antigravity-ide"
        let ideCLI = "/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide"
        let classicCLI = "/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity"

        if isVersion2 {
            if FileManager.default.fileExists(atPath: ideCLI) {
                return ideCLI
            }
            if FileManager.default.fileExists(atPath: classicCLI) {
                return classicCLI
            }
        } else {
            if FileManager.default.fileExists(atPath: classicCLI) {
                return classicCLI
            }
            if FileManager.default.fileExists(atPath: ideCLI) {
                return ideCLI
            }
        }
        return classicCLI
    }

    static func runAppleScript(_ script: String) {
        let appleScript = """
            tell application "Terminal"
                activate
                do script "\(script)"
            end tell
        """
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", appleScript]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    static func sendAntigravityCommand(_ command: String) {
        let cliPaths = [
            antigravityCLI,
            "/usr/local/bin/antigravity",
            NSHomeDirectory() + "/.local/bin/antigravity"
        ]
        for cli in cliPaths {
            if FileManager.default.fileExists(atPath: cli) {
                let task = Process()
                task.launchPath = cli
                task.arguments = ["--command", command]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                try? task.run()
                return
            }
        }
    }

    static func openNewChat() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose folder for new chat"
        panel.prompt = "Open"
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())

        if panel.runModal() == .OK, let folderURL = panel.url {
            let fm = FileManager.default
            if fm.fileExists(atPath: antigravityCLI) {
                let task = Process()
                task.launchPath = antigravityCLI
                task.arguments = ["chat"]
                task.currentDirectoryURL = folderURL
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                try? task.run()
            } else {
                let bundleID = AntigravityAPI.shared.baseDir.lastPathComponent == "antigravity-ide" ? "com.google.antigravity-ide" : "com.google.antigravity"
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.antigravity") {
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                }
            }
        }
    }

    static func openGitReposDatabase() {
        DispatchQueue.global(qos: .userInitiated).async {
            let projectsDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Projects")
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(at: projectsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }

            var repos: [URL] = []
            for case let fileURL as URL in enumerator {
                let name = fileURL.lastPathComponent
                if name == "node_modules" || name == ".git" || name == "build" || name == ".build" || name == "dist" || name == "Pods" || name == "venv" || name == ".venv" {
                    enumerator.skipDescendants()
                    continue
                }

                var isDir: ObjCBool = false
                let gitPath = fileURL.appendingPathComponent(".git").path
                if fm.fileExists(atPath: gitPath, isDirectory: &isDir), isDir.boolValue {
                    repos.append(fileURL)
                    enumerator.skipDescendants() // Skip searching inside the git repo
                }
            }

            let sortedRepos = repos.sorted(by: { $0.path < $1.path })

            var html = """
            <!DOCTYPE html>
            <html lang="ru">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Гитхаб БД</title>
                <style>
                    :root {
                        --bg-color: #f5f5f7;
                        --text-color: #1d1d1f;
                        --card-bg: #ffffff;
                        --card-shadow: rgba(0,0,0,0.1);
                        --link-color: #0066cc;
                        --path-color: #86868b;
                    }
                    @media (prefers-color-scheme: dark) {
                        :root {
                            --bg-color: #000000;
                            --text-color: #f5f5f7;
                            --card-bg: #1c1c1e;
                            --card-shadow: rgba(255,255,255,0.1);
                            --link-color: #2997ff;
                            --path-color: #86868b;
                        }
                    }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                        padding: 40px 20px;
                        background-color: var(--bg-color);
                        color: var(--text-color);
                        max-width: 800px;
                        margin: 0 auto;
                    }
                    h1 {
                        font-weight: 600;
                        margin-bottom: 30px;
                    }
                    .repo-list {
                        list-style: none;
                        padding: 0;
                        display: grid;
                        grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
                        gap: 15px;
                    }
                    .repo-item {
                        background: var(--card-bg);
                        padding: 20px;
                        border-radius: 12px;
                        box-shadow: 0 2px 10px var(--card-shadow);
                        transition: transform 0.2s ease, box-shadow 0.2s ease;
                    }
                    .repo-item:hover {
                        transform: translateY(-2px);
                        box-shadow: 0 4px 15px var(--card-shadow);
                    }
                    .repo-link {
                        text-decoration: none;
                        color: var(--link-color);
                        font-size: 18px;
                        font-weight: 600;
                        display: block;
                        margin-bottom: 8px;
                    }
                    .repo-link:hover {
                        text-decoration: underline;
                    }
                    .repo-path {
                        color: var(--path-color);
                        font-size: 13px;
                        word-break: break-all;
                    }
                </style>
            </head>
            <body>
                <h1>Гитхаб БД (Список репозиториев)</h1>
                <ul class="repo-list">
            """

            for repo in sortedRepos {
                let relativePath = repo.path.replacingOccurrences(of: projectsDir.path + "/", with: "")
                let name = repo.lastPathComponent

                html += """
                    <li class="repo-item">
                        <a class="repo-link" href="vscode://file\(repo.path)">\(name)</a>
                        <div class="repo-path">\(relativePath)</div>
                    </li>
                """
            }

            html += """
                </ul>
            </body>
            </html>
            """

            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("github_db.html")
            do {
                try html.write(to: tempURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(tempURL)
                }
            } catch {
                print("Error writing HTML: \(error)")
            }
        }
    }

    static func autoConfigureEcosystem() {
        let baseDir = AntigravityAPI.shared.baseDir.path
        let prompt = "Please analyze my project folders in ~/Documents/PROJECTS. Based on the languages and frameworks you find, determine my Tech Stack. Before pulling new files, move existing skills and workflows in \(baseDir)/ to \(baseDir)/legacy_backup/$(date +%Y%m%d_%H%M%S)/. Then read ~/Documents/PROJECTS/WORK/AI-Ecosystem/ECOSYSTEM_GUIDE.md, copy the necessary skills into \(baseDir)/, generate my \(baseDir)/knowledge/user_ecosystem_profile/artifacts/PROFILE.md, and create a base environment config at ~/.gemini/GEMINI.md."
        let script = "'\(antigravityCLI)' chat \\\"\(prompt)\\\""
        runAppleScript(script)
    }

    static func syncEcosystem(ecosystemDir: String) {
        let script = "cd '\(ecosystemDir)' && git pull"
        runAppleScript(script)
    }

    static func analyzeChatsAndSyncSkills() {
        let baseDir = AntigravityAPI.shared.baseDir.path
        let prompt = "Please analyze recent conversations in \(baseDir)/brain. Identify recurring topics and check if we have all necessary skills/workflows downloaded locally. If any are missing, fetch them from the registry."
        let script = "'\(antigravityCLI)' chat \\\"\(prompt)\\\""
        runAppleScript(script)
    }

    static func launchSyncChat(projectPath: String) {
        let script = "cd '\(projectPath)' && '\(antigravityCLI)' chat \\\"/sync\\\""
        runAppleScript(script)
    }
}
