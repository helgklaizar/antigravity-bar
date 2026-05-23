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

    static func openNewChatAgent() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose folder for agent"
        panel.prompt = "Open"
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())

        if panel.runModal() == .OK, let folderURL = panel.url {
            let script = "cd '\(folderURL.path)' && '\(antigravityCLI)' chat"
            runAppleScript(script)
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
}
