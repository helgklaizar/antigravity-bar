import AppKit
import Foundation
import ServiceManagement
import SwiftUI
import UserNotifications

struct EnvPaths {
    static let geminiDir = NSHomeDirectory() + "/.gemini"
    static let antigravityDir = NSHomeDirectory() + "/.gemini/antigravity"
    static let ecosystemDir = NSHomeDirectory() + "/Documents/PROJECTS/WORK/AI-Ecosystem"
}

class DaemonActionButton: NSButton {
    var email: String = ""
    var port: Int = 0
    var pid: Int = 0
    var actionType: String = "" // "select", "stop", "webui"
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var pollTimer: Timer?
    private var lastQuota: QuotaData?
    private var daemonOnline = false
    private let api = AntigravityAPI.shared
    private var isMenuOpen = false
    private var isFetching = false
    private var installerWindowController: NSWindowController?
    
    // Multi-account and daemon tracking
    private var activeQuotas: [String: QuotaData] = [:] // Key: Email
    private var discoveredDaemons: [String: DaemonInfo] = [:] // Key: Email
    private var selectedEmail: String? {
        get { UserDefaults.standard.string(forKey: "SelectedEmail") }
        set { UserDefaults.standard.set(newValue, forKey: "SelectedEmail") }
    }
    private var lastExhaustedModels: Set<String> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateBarTitle(models: [], cpu: 0, gpu: 0, ram: 0)
            button.action = #selector(statusBarClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Request authorization for local notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        startPolling()
    }

    // MARK: - Polling

    private let backgroundInterval: TimeInterval = 2
    private let activeInterval: TimeInterval = 2
    private let retryInterval: TimeInterval = 2

    private func startPolling() {
        fetchAndUpdate()
    }

    private func scheduleNextPoll() {
        pollTimer?.invalidate()
        let interval: TimeInterval
        if !daemonOnline {
            interval = retryInterval
        } else if isMenuOpen {
            interval = activeInterval
        } else {
            interval = backgroundInterval
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fetchAndUpdate()
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        fetchAndUpdate()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        scheduleNextPoll()
    }

    private func fetchQuotaAsync(daemon: DaemonInfo) async -> QuotaData? {
        await withCheckedContinuation { continuation in
            api.fetchQuota(daemon: daemon) { quota in
                continuation.resume(returning: quota)
            }
        }
    }

    private func fetchAndUpdate() {
        guard !isFetching else { return }
        isFetching = true
        
        Task {
            let cpu = SystemStats.shared.getCPUUsage()
            let gpu = SystemStats.shared.getGPUUsage()
            let ram = SystemStats.shared.getRAMUsage()
            
            let daemons = api.findActiveDaemons()
            
            guard !daemons.isEmpty else {
                self.daemonOnline = false
                self.activeQuotas = [:]
                self.discoveredDaemons = [:]
                self.lastQuota = nil
                
                let home = NSHomeDirectory()
                let ideDir = URL(fileURLWithPath: home).appendingPathComponent(".gemini/antigravity-ide")
                let baseDirName = FileManager.default.fileExists(atPath: ideDir.path) ? "antigravity-ide" : "antigravity"
                self.api.baseDir = URL(fileURLWithPath: home).appendingPathComponent(".gemini/\(baseDirName)")
                
                self.updateBarTitle(models: [], cpu: cpu, gpu: gpu, ram: ram)
                self.isFetching = false
                self.scheduleNextPoll()
                return
            }
            
            var newQuotas: [String: QuotaData] = [:]
            var newDaemons: [String: DaemonInfo] = [:]
            
            await withTaskGroup(of: (String, QuotaData, DaemonInfo)?.self) { group in
                for daemon in daemons {
                    group.addTask {
                        if let quota = await self.fetchQuotaAsync(daemon: daemon) {
                            let emailKey = quota.email ?? "Local Daemon (\(daemon.httpPort))"
                            return (emailKey, quota, daemon)
                        }
                        return nil
                    }
                }
                
                for await result in group {
                    if let (emailKey, quota, daemon) = result {
                        newQuotas[emailKey] = quota
                        newDaemons[emailKey] = daemon
                    }
                }
            }
            
            self.activeQuotas = newQuotas
            self.discoveredDaemons = newDaemons
            
            let targetEmail = self.selectedEmail
            var activeQ: QuotaData? = nil
            
            if let target = targetEmail, let q = newQuotas[target] {
                activeQ = q
            } else if let firstKey = newQuotas.keys.sorted().first {
                activeQ = newQuotas[firstKey]
                self.selectedEmail = firstKey
            }
            
            self.lastQuota = activeQ
            self.daemonOnline = activeQ != nil
            
            if let email = self.selectedEmail, let daemon = newDaemons[email] {
                let isVersion2 = daemon.path.contains("Antigravity IDE") || daemon.path.contains("language_server_macos")
                let baseDirName = isVersion2 ? "antigravity-ide" : "antigravity"
                self.api.baseDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".gemini/\(baseDirName)")
            } else {
                let home = NSHomeDirectory()
                let ideDir = URL(fileURLWithPath: home).appendingPathComponent(".gemini/antigravity-ide")
                let baseDirName = FileManager.default.fileExists(atPath: ideDir.path) ? "antigravity-ide" : "antigravity"
                self.api.baseDir = URL(fileURLWithPath: home).appendingPathComponent(".gemini/\(baseDirName)")
            }
            
            for (email, qData) in newQuotas {
                self.checkAndNotifyExhaustion(newModels: qData.models, email: email)
            }
            
            self.updateBarTitle(models: activeQ?.models ?? [], cpu: cpu, gpu: gpu, ram: ram)
            self.isFetching = false
            self.scheduleNextPoll()
        }
    }

    private func checkAndNotifyExhaustion(newModels: [ModelQuota], email: String) {
        for model in newModels {
            let key = "\(email)-\(model.label)"
            if model.isExhausted {
                if !lastExhaustedModels.contains(key) {
                    lastExhaustedModels.insert(key)
                    sendExhaustionNotification(modelLabel: model.label, email: email, resetTime: model.timeUntilReset)
                }
            } else {
                lastExhaustedModels.remove(key)
            }
        }
    }
    
    private func sendExhaustionNotification(modelLabel: String, email: String, resetTime: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Quota Exhausted"
        content.body = "\(modelLabel) quota for \(email) is exhausted. Resets in \(resetTime)."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func updateBarTitle(models: [ModelQuota], cpu: Int, gpu: Int, ram: Int) {
        let cache = api.cacheSize()
        statusItem.button?.attributedTitle = StatusBarUI.makeBarTitle(
            models: models, 
            daemonOnline: daemonOnline, 
            cacheFormatted: cache.formatted, 
            cacheMB: cache.megabytes,
            cpu: cpu,
            gpu: gpu,
            ram: ram,
            historyCPU: SystemStats.shared.cpuHistory,
            historyGPU: SystemStats.shared.gpuHistory,
            historyRAM: SystemStats.shared.ramHistory
        )
    }

    // MARK: - Click Handling
    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        showContextMenu()
    }

    // MARK: - Context Menu
    
    private func prepareModelsForMenu(quota: QuotaData) -> [ModelQuota] {
        let sortedModels = quota.models.sorted { m1, m2 in
            func priority(_ label: String) -> Int {
                let l = label.lowercased()
                if l.contains("3.1") || l.contains("pro") {
                    if l.contains("high") { return 10 }
                    if l.contains("low") { return 11 }
                    return 12
                }
                if l.contains("flash") || l.contains("gemini 3") { return 20 }
                if l.contains("sonnet") { return 30 }
                if l.contains("opus") { return 31 }
                if l.contains("claude") { return 32 }
                if l.contains("oss") || l.contains("120b") || l.contains("gemma") { return 40 }
                return 100
            }
            let p1 = priority(m1.label)
            let p2 = priority(m2.label)
            if p1 != p2 { return p1 < p2 }
            return m1.label < m2.label
        }

        var finalModels: [ModelQuota] = []
        var proModels: [ModelQuota] = []
        for m in sortedModels {
            if m.label.lowercased().contains("3.1") {
                proModels.append(m)
            } else {
                finalModels.append(m)
            }
        }
        
        if !proModels.isEmpty {
            let minPct = proModels.map { $0.remainingPercentage }.min() ?? 0
            let minSecs = proModels.map { $0.secondsUntilReset }.min() ?? 0
            let minTimeStr = proModels.first(where: { $0.secondsUntilReset == minSecs })?.timeUntilReset ?? ""
            let isExh = proModels.allSatisfy { $0.isExhausted }
            let combined = ModelQuota(
                label: "Gemini 3.1 Pro",
                remainingPercentage: minPct,
                isExhausted: isExh,
                timeUntilReset: minTimeStr,
                secondsUntilReset: minSecs
            )
            finalModels.insert(combined, at: 0)
        }
        return finalModels
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        
        // 1. Header section "ACTIVE ACCOUNTS & DAEMONS"
        let headerItem = NSMenuItem()
        headerItem.view = makeSectionHeader(iconName: "person.3.fill", title: "ACTIVE ACCOUNTS & DAEMONS")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        // 2. Beautiful cards for each discovered account
        if discoveredDaemons.isEmpty {
            let emptyItem = NSMenuItem(title: "⏳ No active accounts or daemons", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let sortedEmails = discoveredDaemons.keys.sorted()
            for email in sortedEmails {
                if let daemon = discoveredDaemons[email],
                   let quota = activeQuotas[email] {
                    let isActive = (email == selectedEmail)
                    let cardItem = makeAccountCardItem(
                        email: email,
                        name: quota.name,
                        daemon: daemon,
                        quota: quota,
                        isActive: isActive
                    )
                    menu.addItem(cardItem)
                }
            }
        }
        
        menu.addItem(.separator())
        
        // 4. Workflows Radar widget (Restored)
        menu.addItem(makeWorkflowsRadarItem())
        
        menu.addItem(.separator())
        
        // 6. Dynamic Skills Hub (Restored)
        menu.addItem(makeDynamicSkillsItem())
        
        menu.addItem(.separator())
        
        // 8. Top RAM Processes
        menu.addItem(makeAppsHorizontalItem())
        
        menu.addItem(.separator())
        
        // 10. Enhanced Quick Actions toolbar (2x4)
        menu.addItem(makeHorizontalToolbarItem())
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    private func createLabel(_ attrStr: NSAttributedString) -> NSTextField {
        let field = NSTextField()
        field.attributedStringValue = attrStr
        field.isEditable = false
        field.drawsBackground = false
        field.isBordered = false
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        return field
    }

    private func makeSectionHeader(iconName: String, title: String) -> NSView {
        let container = NSView()
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        
        var icon: NSImage?
        if #available(macOS 12.0, *) {
            icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(hierarchicalColor: .secondaryLabelColor))
        } else {
            icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        }
        let iconView = NSImageView(image: icon ?? NSImage())
        
        let titleLabel = createLabel(NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        
        header.addArrangedSubview(iconView)
        header.addArrangedSubview(titleLabel)
        
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)
        
        NSLayoutConstraint.activate([
            header.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }

    private func makeHorizontalToolbarItem() -> NSMenuItem {
        let item = NSMenuItem()
        
        let cacheSize = api.cacheSize().formatted
        let allActions: [(String, String, NSColor)] = [
            ("AI\nInstaller", "wand.and.stars", .systemPurple),
            ("Open\n.gemini", "folder", .systemBlue),
            ("New\nChat", "bubble.left.and.bubble.right", .systemGreen),
            ("Chat\nAgent", "person.and.sparkles", .systemTeal),
            ("Sync\nEcosystem", "arrow.triangle.2.circlepath", .systemOrange),
            ("Restart &\nReload", "arrow.clockwise", .systemYellow),
            ("Clean Cache\n\(cacheSize)", "trash", .systemRed),
            ("Quit\nApp", "xmark.circle", .systemGray)
        ]
        
        let wrapperStack = NSStackView()
        wrapperStack.orientation = .vertical
        wrapperStack.alignment = .centerX
        wrapperStack.spacing = 10
        
        wrapperStack.addArrangedSubview(makeSectionHeader(iconName: "square.grid.2x2", title: "QUICK ACTIONS"))
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = 8
        
        func createRow(actions: [(String, String, NSColor)], startIndex: Int) -> NSStackView {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 8
            
            for (i, action) in actions.enumerated() {
                let containerBox = NSBox()
                containerBox.boxType = .custom
                containerBox.borderWidth = 0
                containerBox.cornerRadius = 10
                containerBox.fillColor = NSColor.labelColor.withAlphaComponent(0.06)
                
                let vStack = NSStackView()
                vStack.orientation = .vertical
                vStack.alignment = .centerX
                vStack.spacing = 4
                
                let imgView = NSImageView()
                if let img = NSImage(systemSymbolName: action.1, accessibilityDescription: nil) {
                    let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
                    img.isTemplate = true
                    imgView.image = img.withSymbolConfiguration(config)
                }
                imgView.contentTintColor = action.2
                
                let lbl = NSTextField(labelWithString: action.0)
                lbl.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
                lbl.textColor = NSColor.labelColor
                lbl.alignment = .center
                lbl.lineBreakMode = .byWordWrapping
                lbl.maximumNumberOfLines = 2
                
                vStack.addArrangedSubview(imgView)
                vStack.addArrangedSubview(lbl)
                
                containerBox.contentView = vStack
                vStack.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    vStack.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor, constant: 2),
                    vStack.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor, constant: -2),
                    vStack.centerYAnchor.constraint(equalTo: containerBox.centerYAnchor)
                ])
                
                let btn = NSButton()
                btn.title = ""
                btn.isBordered = false
                btn.isTransparent = true
                btn.target = self
                btn.action = #selector(toolbarButtonClicked(_:))
                btn.tag = startIndex + i
                btn.toolTip = action.0
                
                let wrapper = NSView()
                containerBox.translatesAutoresizingMaskIntoConstraints = false
                btn.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(containerBox)
                wrapper.addSubview(btn)
                
                NSLayoutConstraint.activate([
                    containerBox.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                    containerBox.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                    containerBox.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    containerBox.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                    
                    btn.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                    btn.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                    btn.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    btn.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                    
                    wrapper.heightAnchor.constraint(equalToConstant: 72)
                ])
                
                rowStack.addArrangedSubview(wrapper)
            }
            
            return rowStack
        }
        
        let row1 = createRow(actions: Array(allActions[0..<4]), startIndex: 0)
        let row2 = createRow(actions: Array(allActions[4..<8]), startIndex: 4)
        
        mainStack.addArrangedSubview(row1)
        mainStack.addArrangedSubview(row2)
        
        row1.translatesAutoresizingMaskIntoConstraints = false
        row2.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row1.widthAnchor.constraint(equalToConstant: 526),
            row2.widthAnchor.constraint(equalToConstant: 526)
        ])
        
        wrapperStack.addArrangedSubview(mainStack)
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 185))
        wrapperStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(wrapperStack)
        
        NSLayoutConstraint.activate([
            wrapperStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            wrapperStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            wrapperStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            wrapperStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        item.view = container
        return item
    }

    private func makeAppsHorizontalItem() -> NSMenuItem {
        let item = NSMenuItem()
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .centerX
        mainStack.spacing = 10
        
        mainStack.addArrangedSubview(makeSectionHeader(iconName: "memorychip", title: "TOP RAM PROCESSES"))
        
        let topApps = Array(ProcessManager.getTopProcesses().prefix(6))
        
        let gridStack = NSStackView()
        gridStack.orientation = .horizontal
        gridStack.distribution = .fillEqually
        gridStack.spacing = 20
        
        let col1 = NSStackView()
        col1.orientation = .vertical
        col1.alignment = .leading
        col1.spacing = 8
        
        let col2 = NSStackView()
        col2.orientation = .vertical
        col2.alignment = .leading
        col2.spacing = 8
        
        for (i, app) in topApps.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            
            var appIcon: NSImage?
            if app.isSystemGroup {
                if #available(macOS 12.0, *) {
                    appIcon = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)?
                        .withSymbolConfiguration(.init(hierarchicalColor: .systemBlue))
                } else {
                    appIcon = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
                }
            } else if !app.appPath.isEmpty, FileManager.default.fileExists(atPath: app.appPath) {
                appIcon = NSWorkspace.shared.icon(forFile: app.appPath)
            }
            let imgView = NSImageView(image: appIcon ?? NSImage())
            imgView.imageScaling = .scaleProportionallyUpOrDown
            imgView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imgView.widthAnchor.constraint(equalToConstant: 16),
                imgView.heightAnchor.constraint(equalToConstant: 16)
            ])
            
            var displayName = app.appName
            if displayName.hasSuffix(".app") { displayName = String(displayName.dropLast(4)) }
            if displayName.count > 15 { displayName = String(displayName.prefix(15)) + "..." }
            
            let nameField = createLabel(NSAttributedString(string: displayName, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: app.isSystemGroup ? NSColor.systemBlue : NSColor.labelColor
            ]))
            nameField.alignment = .left
            
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            
            let memField = createLabel(NSAttributedString(string: ProcessManager.formatMemory(app.totalRssKB), attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
            memField.alignment = .right
            
            row.addArrangedSubview(imgView)
            row.addArrangedSubview(nameField)
            row.addArrangedSubview(spacer)
            row.addArrangedSubview(memField)
            
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: 240).isActive = true
            
            if i < 3 {
                col1.addArrangedSubview(row)
            } else {
                col2.addArrangedSubview(row)
            }
        }
        
        gridStack.addArrangedSubview(col1)
        gridStack.addArrangedSubview(col2)
        
        mainStack.addArrangedSubview(gridStack)
        
        let containerBox = NSBox()
        containerBox.boxType = .custom
        containerBox.borderWidth = 0
        containerBox.cornerRadius = 12
        containerBox.fillColor = NSColor.unemphasizedSelectedContentBackgroundColor.withAlphaComponent(0.2)
        
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        containerBox.contentView = mainStack
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor, constant: -16),
            mainStack.topAnchor.constraint(equalTo: containerBox.topAnchor, constant: 12),
            mainStack.bottomAnchor.constraint(equalTo: containerBox.bottomAnchor, constant: -12)
        ])
        
        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 140))
        containerBox.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(containerBox)
        NSLayoutConstraint.activate([
            containerBox.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 12),
            containerBox.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -12),
            containerBox.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            containerBox.heightAnchor.constraint(equalToConstant: 125)
        ])
        
        item.view = wrapper
        return item
    }

    private func makeWorkflowsRadarItem() -> NSMenuItem {
        let item = NSMenuItem()
        
        let stats = WorkflowTracker.shared.fetchUsageStats()
        let topStats = Array(stats.prefix(3))
        let unusedCount = stats.filter { $0.uses == 0 }.count
        
        let mainStack = NSStackView()
        mainStack.orientation = .horizontal
        mainStack.distribution = .fillEqually
        mainStack.spacing = 8
        
        // ----------------------------------------
        // LEFT BOX: HOT WORKFLOWS
        // ----------------------------------------
        let hotBox = NSBox()
        hotBox.boxType = .custom
        hotBox.borderWidth = 1
        hotBox.borderColor = NSColor.separatorColor.withAlphaComponent(0.2)
        hotBox.cornerRadius = 10
        hotBox.fillColor = NSColor.unemphasizedSelectedContentBackgroundColor.withAlphaComponent(0.2)
        
        let hotStack = NSStackView()
        hotStack.orientation = .vertical
        hotStack.alignment = .leading
        hotStack.spacing = 8
        
        let hotHeader = NSStackView()
        hotHeader.orientation = .horizontal
        hotHeader.alignment = .centerY
        hotHeader.spacing = 4
        
        var flameIcon: NSImage?
        if #available(macOS 12.0, *) {
            flameIcon = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(hierarchicalColor: .systemOrange))
        } else {
            flameIcon = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)
        }
        
        let hotIconView = NSImageView(image: flameIcon ?? NSImage())
        let hotTitle = createLabel(NSAttributedString(string: "HOT WORKFLOWS", attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.7)
        ]))
        hotHeader.addArrangedSubview(hotIconView)
        hotHeader.addArrangedSubview(hotTitle)
        
        hotStack.addArrangedSubview(hotHeader)
        
        if topStats.isEmpty {
            let emptyLabel = createLabel(NSAttributedString(string: "No data yet", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
            hotStack.addArrangedSubview(emptyLabel)
        } else {
            for stat in topStats {
                let row = NSStackView()
                row.orientation = .horizontal
                row.distribution = .gravityAreas
                
                let nameLabel = createLabel(NSAttributedString(string: "/\(stat.name)", attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]))
                
                let countBox = NSBox()
                countBox.boxType = .custom
                countBox.borderWidth = 0
                countBox.cornerRadius = 4
                countBox.fillColor = NSColor.systemOrange.withAlphaComponent(0.15)
                
                let countLabel = createLabel(NSAttributedString(string: "\(stat.uses)", attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: NSColor.systemOrange
                ]))
                
                countBox.contentView = countLabel
                countLabel.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    countLabel.leadingAnchor.constraint(equalTo: countBox.leadingAnchor, constant: 4),
                    countLabel.trailingAnchor.constraint(equalTo: countBox.trailingAnchor, constant: -4),
                    countLabel.topAnchor.constraint(equalTo: countBox.topAnchor, constant: 2),
                    countLabel.bottomAnchor.constraint(equalTo: countBox.bottomAnchor, constant: -2)
                ])
                
                row.addView(nameLabel, in: .leading)
                row.addView(countBox, in: .trailing)
                row.translatesAutoresizingMaskIntoConstraints = false
                hotStack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: hotStack.widthAnchor).isActive = true
            }
        }
        
        // Add spacer to push content up if < 3 items
        if topStats.count < 3 {
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            hotStack.addArrangedSubview(spacer)
        }
        
        hotBox.contentView = hotStack
        hotStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hotStack.leadingAnchor.constraint(equalTo: hotBox.leadingAnchor, constant: 12),
            hotStack.trailingAnchor.constraint(equalTo: hotBox.trailingAnchor, constant: -12),
            hotStack.topAnchor.constraint(equalTo: hotBox.topAnchor, constant: 10),
            hotStack.bottomAnchor.constraint(equalTo: hotBox.bottomAnchor, constant: -10)
        ])
        
        // ----------------------------------------
        // RIGHT BOX: COLD STORAGE
        // ----------------------------------------
        let coldBox = NSBox()
        coldBox.boxType = .custom
        coldBox.borderWidth = 1
        coldBox.borderColor = NSColor.separatorColor.withAlphaComponent(0.2)
        coldBox.cornerRadius = 10
        coldBox.fillColor = NSColor.unemphasizedSelectedContentBackgroundColor.withAlphaComponent(0.2)
        
        let coldStack = NSStackView()
        coldStack.orientation = .vertical
        coldStack.alignment = .centerX
        coldStack.distribution = .fill
        coldStack.spacing = 2
        
        let coldHeader = NSStackView()
        coldHeader.orientation = .horizontal
        coldHeader.alignment = .centerY
        coldHeader.spacing = 4
        
        var archiveIcon: NSImage?
        if #available(macOS 12.0, *) {
            archiveIcon = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(hierarchicalColor: .systemTeal))
        } else {
            archiveIcon = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: nil)
        }
        
        let coldIconView = NSImageView(image: archiveIcon ?? NSImage())
        let coldTitle = createLabel(NSAttributedString(string: "COLD STORAGE", attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.7)
        ]))
        coldHeader.addArrangedSubview(coldIconView)
        coldHeader.addArrangedSubview(coldTitle)
        
        let countField = createLabel(NSAttributedString(string: "\(unusedCount)", attributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .heavy),
            .foregroundColor: NSColor.labelColor
        ]))
        
        let unusedText = createLabel(NSAttributedString(string: "Unused Workflows", attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        
        let archiveBtn = NSButton()
        archiveBtn.title = "Clean Up"
        archiveBtn.target = self
        archiveBtn.action = #selector(cleanUpWorkflows)
        
        let btnBox = NSBox()
        btnBox.boxType = .custom
        btnBox.borderWidth = 0
        btnBox.cornerRadius = 6
        btnBox.fillColor = unusedCount > 0 ? NSColor.systemTeal.withAlphaComponent(0.8) : NSColor.tertiaryLabelColor.withAlphaComponent(0.2)
        
        let btnLbl = createLabel(NSAttributedString(string: "Clean Up", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: unusedCount > 0 ? NSColor.white : NSColor.secondaryLabelColor
        ]))
        btnBox.contentView = btnLbl
        btnLbl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btnLbl.centerXAnchor.constraint(equalTo: btnBox.centerXAnchor),
            btnLbl.centerYAnchor.constraint(equalTo: btnBox.centerYAnchor)
        ])
        
        let btnWrapper = NSView()
        btnBox.translatesAutoresizingMaskIntoConstraints = false
        archiveBtn.translatesAutoresizingMaskIntoConstraints = false
        archiveBtn.isTransparent = true
        archiveBtn.title = ""
        btnWrapper.addSubview(btnBox)
        btnWrapper.addSubview(archiveBtn)
        NSLayoutConstraint.activate([
            btnBox.leadingAnchor.constraint(equalTo: btnWrapper.leadingAnchor),
            btnBox.trailingAnchor.constraint(equalTo: btnWrapper.trailingAnchor),
            btnBox.topAnchor.constraint(equalTo: btnWrapper.topAnchor),
            btnBox.bottomAnchor.constraint(equalTo: btnWrapper.bottomAnchor),
            archiveBtn.leadingAnchor.constraint(equalTo: btnWrapper.leadingAnchor),
            archiveBtn.trailingAnchor.constraint(equalTo: btnWrapper.trailingAnchor),
            archiveBtn.topAnchor.constraint(equalTo: btnWrapper.topAnchor),
            archiveBtn.bottomAnchor.constraint(equalTo: btnWrapper.bottomAnchor),
            btnWrapper.heightAnchor.constraint(equalToConstant: 22)
        ])
        
        if unusedCount == 0 { archiveBtn.isEnabled = false }
        
        coldStack.addArrangedSubview(coldHeader)
        coldStack.setCustomSpacing(4, after: coldHeader)
        coldStack.addArrangedSubview(countField)
        coldStack.addArrangedSubview(unusedText)
        coldStack.setCustomSpacing(6, after: unusedText)
        coldStack.addArrangedSubview(btnWrapper)
        
        btnWrapper.widthAnchor.constraint(equalTo: coldStack.widthAnchor, multiplier: 0.7).isActive = true
        
        coldBox.contentView = coldStack
        coldStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coldStack.leadingAnchor.constraint(equalTo: coldBox.leadingAnchor, constant: 12),
            coldStack.trailingAnchor.constraint(equalTo: coldBox.trailingAnchor, constant: -12),
            coldStack.topAnchor.constraint(equalTo: coldBox.topAnchor, constant: 10),
            coldStack.bottomAnchor.constraint(equalTo: coldBox.bottomAnchor, constant: -10)
        ])
        
        mainStack.addArrangedSubview(hotBox)
        mainStack.addArrangedSubview(coldBox)
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 110))
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            mainStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        item.view = container
        return item
    }

    private func makeDynamicSkillsItem() -> NSMenuItem {
        let item = NSMenuItem()
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.distribution = .fill
        mainStack.spacing = 8
        
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        
        var icon: NSImage?
        if #available(macOS 12.0, *) {
            icon = NSImage(systemSymbolName: "network", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(hierarchicalColor: .systemPurple))
        } else {
            icon = NSImage(systemSymbolName: "network", accessibilityDescription: nil)
        }
        let iconView = NSImageView(image: icon ?? NSImage())
        let title = createLabel(NSAttributedString(string: "DYNAMIC SKILLS HUB", attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.7)
        ]))
        
        header.addArrangedSubview(iconView)
        header.addArrangedSubview(title)
        
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.distribution = .gravityAreas
        controls.spacing = 8
        
        let toggleLabel = createLabel(NSAttributedString(string: "Auto-Fetch", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]))
        let toggle = NSSwitch()
        toggle.state = UserDefaults.standard.bool(forKey: "DynamicSkillsEnabled") ? .on : .off
        toggle.target = self
        toggle.action = #selector(dynamicSkillsToggled(_:))
        
        let toggleStack = NSStackView()
        toggleStack.orientation = .horizontal
        toggleStack.spacing = 4
        toggleStack.addArrangedSubview(toggleLabel)
        toggleStack.addArrangedSubview(toggle)
        
        let syncBtn = NSButton()
        syncBtn.title = "Analyze System & Install"
        syncBtn.bezelStyle = .rounded
        syncBtn.target = self
        syncBtn.action = #selector(showInstallerWindow)
        
        controls.addView(toggleStack, in: .leading)
        controls.addView(syncBtn, in: .trailing)
        
        let statusBox = NSBox()
        statusBox.boxType = .custom
        statusBox.borderWidth = 0
        statusBox.cornerRadius = 6
        statusBox.fillColor = NSColor.systemPurple.withAlphaComponent(0.15)
        
        let statusLabel = createLabel(NSAttributedString(string: "Registry: helgklaizar/AI-Ecosystem", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.systemPurple.withAlphaComponent(0.8)
        ]))
        statusBox.contentView = statusLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusBox.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusBox.trailingAnchor, constant: -8),
            statusLabel.topAnchor.constraint(equalTo: statusBox.topAnchor, constant: 4),
            statusLabel.bottomAnchor.constraint(equalTo: statusBox.bottomAnchor, constant: -4)
        ])
        
        mainStack.addArrangedSubview(header)
        mainStack.addArrangedSubview(controls)
        mainStack.addArrangedSubview(statusBox)
        
        controls.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        statusBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 95))
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            mainStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        item.view = container
        return item
    }

    @objc private func dynamicSkillsToggled(_ sender: NSSwitch) {
        UserDefaults.standard.set(sender.state == .on, forKey: "DynamicSkillsEnabled")
    }
    
    @objc private func showInstallerWindow() {
        statusItem.menu?.cancelTracking()
        
        if installerWindowController == nil {
            let hostingController = NSHostingController(rootView: InstallerView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "AI Ecosystem Installer"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.center()
            window.setFrameAutosaveName("AIInstallerWindow")
            installerWindowController = NSWindowController(window: window)
        }
        
        installerWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func cleanUpWorkflows() {
        let alert = NSAlert()
        alert.messageText = "Archive Unused Workflows?"
        alert.informativeText = "Workflows with 0 uses will be moved to the _archive folder."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Archive")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            WorkflowTracker.shared.archiveUnusedWorkflows()
            statusItem.menu?.cancelTracking()
        }
    }

    @objc private func toolbarButtonClicked(_ sender: NSButton) {
        let segment = sender.tag
        
        // Close menu manually since custom views don't dismiss it
        statusItem.menu?.cancelTracking()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch segment {
            case 0: self.showInstallerWindow()
            case 1: self.openGeminiFolder()
            case 2: self.launchNewChat()
            case 3: self.launchChatAgent()
            case 4: self.syncEcosystem()
            case 5: self.restartAndReload()
            case 6: self.fullCleanup()
            case 7: self.quitApp()
            default: break
            }
        }
    }

    private func launchNewChat() {
        TerminalHelper.openNewChat()
    }
    
    private func launchChatAgent() {
        TerminalHelper.openNewChatAgent()
    }
    
    private func syncEcosystem() {
        TerminalHelper.syncEcosystem(ecosystemDir: EnvPaths.ecosystemDir)
    }

    private func makeModelsHorizontalStack(models: [ModelQuota], width: CGFloat) -> NSStackView {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        
        for model in models {
            let pct = Int(model.remainingPercentage)
            let icon: String
            if pct >= 80 { icon = "🟢" }
            else if pct >= 60 { icon = "🟡" }
            else if pct >= 40 { icon = "🟠" }
            else { icon = "🔴" }
            
            let cleanLabel = model.label
                .replacingOccurrences(of: " (Thinking)", with: "")
                .replacingOccurrences(of: " (Medium)", with: "")
            
            var vendor = ""
            var tier = ""
            if cleanLabel.hasPrefix("Gemini ") {
                vendor = "Gemini"
                tier = cleanLabel.replacingOccurrences(of: "Gemini ", with: "")
            } else if cleanLabel.hasPrefix("Claude ") {
                vendor = "Claude"
                tier = cleanLabel.replacingOccurrences(of: "Claude ", with: "")
            } else if cleanLabel.hasPrefix("GPT-OSS ") {
                vendor = "GPT-OSS"
                tier = cleanLabel.replacingOccurrences(of: "GPT-OSS ", with: "")
            } else {
                let parts = cleanLabel.split(separator: " ", maxSplits: 1)
                vendor = String(parts.first ?? "")
                tier = parts.count > 1 ? String(parts[1]) : ""
            }
            
            if tier == "Sonnet 4.6" { tier = "Sonnet" }
            if tier == "Opus 4.6" { tier = "Opus" }
            
            var vendorColor: NSColor = .secondaryLabelColor
            if vendor == "Gemini" { vendorColor = .systemBlue }
            else if vendor == "Claude" { vendorColor = .systemOrange }
            else if vendor == "GPT-OSS" { vendorColor = .systemGreen }
            
            let vendorField = createLabel(NSAttributedString(string: vendor.uppercased(), attributes: [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: vendorColor.withAlphaComponent(0.9)
            ]))
            
            let tierField = createLabel(NSAttributedString(string: tier, attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .heavy),
                .foregroundColor: NSColor.labelColor
            ]))
            
            let pctField = createLabel(NSAttributedString(string: "\(icon) \(pct)%", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]))
            
            let timeField = createLabel(NSAttributedString(string: model.timeUntilReset, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]))
            
            let vStack = NSStackView()
            vStack.orientation = .vertical
            vStack.alignment = .centerX
            vStack.spacing = 1
            
            vStack.addArrangedSubview(vendorField)
            vStack.addArrangedSubview(tierField)
            vStack.addArrangedSubview(pctField)
            vStack.addArrangedSubview(timeField)
            
            vStack.setCustomSpacing(3, after: tierField)
            vStack.setCustomSpacing(1, after: pctField)
            
            let box = NSBox()
            box.boxType = .custom
            box.borderWidth = 0
            box.cornerRadius = 10
            box.fillColor = NSColor.labelColor.withAlphaComponent(0.04)
            box.contentView = vStack
            
            vStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                vStack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 4),
                vStack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -4),
                vStack.topAnchor.constraint(equalTo: box.topAnchor, constant: 6),
                vStack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: 6)
            ])
            
            stackView.addArrangedSubview(box)
        }
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.widthAnchor.constraint(equalToConstant: width).isActive = true
        return stackView
    }

    private func makeModelsHorizontalItem(models: [ModelQuota]) -> NSMenuItem {
        let item = NSMenuItem()
        
        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .centerX
        outerStack.spacing = 10
        
        outerStack.addArrangedSubview(makeSectionHeader(iconName: "cpu", title: "AI MODELS QUOTA"))
        
        let stackView = makeModelsHorizontalStack(models: models, width: 526)
        outerStack.addArrangedSubview(stackView)
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 125))
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(outerStack)
        
        NSLayoutConstraint.activate([
            outerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            outerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            outerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            outerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])
        
        item.view = container
        return item
    }

    private func makeAccountCardItem(email: String, name: String?, daemon: DaemonInfo, quota: QuotaData, isActive: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        
        let containerBox = NSBox()
        containerBox.boxType = .custom
        containerBox.borderWidth = isActive ? 1.5 : 1
        containerBox.borderColor = isActive ? NSColor.systemBlue.withAlphaComponent(0.8) : NSColor.separatorColor.withAlphaComponent(0.2)
        containerBox.cornerRadius = 14
        containerBox.fillColor = isActive ? NSColor.systemBlue.withAlphaComponent(0.06) : NSColor.unemphasizedSelectedContentBackgroundColor.withAlphaComponent(0.15)
        
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.distribution = .gravityAreas
        
        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 1
        
        let nameString = name ?? "Local Developer"
        let nameLabel = createLabel(NSAttributedString(string: nameString, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]))
        
        let emailLabel = createLabel(NSAttributedString(string: email, attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        
        infoStack.addArrangedSubview(nameLabel)
        infoStack.addArrangedSubview(emailLabel)
        
        let pillBox = NSBox()
        pillBox.boxType = .custom
        pillBox.borderWidth = 0
        pillBox.cornerRadius = 6
        pillBox.fillColor = isActive ? NSColor.systemGreen.withAlphaComponent(0.15) : NSColor.tertiaryLabelColor.withAlphaComponent(0.15)
        
        let pillText = isActive ? "ACTIVE" : "STANDBY"
        let pillColor = isActive ? NSColor.systemGreen : NSColor.secondaryLabelColor
        let pillLabel = createLabel(NSAttributedString(string: pillText, attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: pillColor
        ]))
        
        pillBox.contentView = pillLabel
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillLabel.leadingAnchor.constraint(equalTo: pillBox.leadingAnchor, constant: 6),
            pillLabel.trailingAnchor.constraint(equalTo: pillBox.trailingAnchor, constant: -6),
            pillLabel.topAnchor.constraint(equalTo: pillBox.topAnchor, constant: 3),
            pillLabel.bottomAnchor.constraint(equalTo: pillBox.bottomAnchor, constant: -3)
        ])
        
        topRow.addView(infoStack, in: .leading)
        topRow.addView(pillBox, in: .trailing)
        
        let finalModels = prepareModelsForMenu(quota: quota)
        let quotaStack = makeModelsHorizontalStack(models: finalModels, width: 502)
        
        let bottomRow = NSStackView()
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .centerY
        bottomRow.distribution = .gravityAreas
        
        let metaLabel = createLabel(NSAttributedString(string: "PID: \(daemon.pid)  •  Port: \(daemon.httpPort)", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]))
        
        let actionsStack = NSStackView()
        actionsStack.orientation = .horizontal
        actionsStack.spacing = 8
        
        func createActionButton(title: String, type: String, color: NSColor) -> NSView {
            let btnBox = NSBox()
            btnBox.boxType = .custom
            btnBox.borderWidth = 0
            btnBox.cornerRadius = 6
            btnBox.fillColor = color.withAlphaComponent(0.12)
            
            let btnLbl = createLabel(NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: color
            ]))
            btnBox.contentView = btnLbl
            
            btnLbl.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                btnLbl.leadingAnchor.constraint(equalTo: btnBox.leadingAnchor, constant: 8),
                btnLbl.trailingAnchor.constraint(equalTo: btnBox.trailingAnchor, constant: -8),
                btnLbl.topAnchor.constraint(equalTo: btnBox.topAnchor, constant: 4),
                btnLbl.bottomAnchor.constraint(equalTo: btnBox.bottomAnchor, constant: -4)
            ])
            
            let button = DaemonActionButton()
            button.email = email
            button.port = daemon.httpPort
            button.pid = daemon.pid
            button.actionType = type
            button.isBordered = false
            button.isTransparent = true
            button.target = self
            button.action = #selector(daemonActionClicked(_:))
            
            let wrapper = NSView()
            btnBox.translatesAutoresizingMaskIntoConstraints = false
            button.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(btnBox)
            wrapper.addSubview(button)
            
            NSLayoutConstraint.activate([
                btnBox.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                btnBox.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                btnBox.topAnchor.constraint(equalTo: wrapper.topAnchor),
                btnBox.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                
                button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                button.topAnchor.constraint(equalTo: wrapper.topAnchor),
                button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                
                wrapper.heightAnchor.constraint(equalToConstant: 20)
            ])
            
            return wrapper
        }
        
        if !isActive {
            let activateBtn = createActionButton(title: "Activate", type: "select", color: .systemBlue)
            actionsStack.addArrangedSubview(activateBtn)
        }
        
        let webBtn = createActionButton(title: "Web UI", type: "webui", color: .systemPurple)
        let stopBtn = createActionButton(title: "Stop", type: "stop", color: .systemRed)
        actionsStack.addArrangedSubview(webBtn)
        actionsStack.addArrangedSubview(stopBtn)
        
        bottomRow.addView(metaLabel, in: .leading)
        bottomRow.addView(actionsStack, in: .trailing)
        
        contentStack.addArrangedSubview(topRow)
        contentStack.addArrangedSubview(quotaStack)
        contentStack.addArrangedSubview(bottomRow)
        
        topRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        quotaStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        bottomRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        
        containerBox.contentView = contentStack
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: containerBox.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: containerBox.bottomAnchor, constant: 12)
        ])
        
        let wrapperView = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 185))
        containerBox.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.addSubview(containerBox)
        
        NSLayoutConstraint.activate([
            containerBox.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor, constant: 12),
            containerBox.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor, constant: -12),
            containerBox.topAnchor.constraint(equalTo: wrapperView.topAnchor, constant: 4),
            containerBox.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor, constant: -4)
        ])
        
        if !isActive {
            let overlayBtn = DaemonActionButton()
            overlayBtn.email = email
            overlayBtn.port = daemon.httpPort
            overlayBtn.pid = daemon.pid
            overlayBtn.actionType = "select"
            overlayBtn.isBordered = false
            overlayBtn.isTransparent = true
            overlayBtn.target = self
            overlayBtn.action = #selector(daemonActionClicked(_:))
            
            overlayBtn.translatesAutoresizingMaskIntoConstraints = false
            wrapperView.addSubview(overlayBtn)
            
            NSLayoutConstraint.activate([
                overlayBtn.leadingAnchor.constraint(equalTo: containerBox.leadingAnchor),
                overlayBtn.trailingAnchor.constraint(equalTo: containerBox.trailingAnchor),
                overlayBtn.topAnchor.constraint(equalTo: containerBox.topAnchor),
                overlayBtn.bottomAnchor.constraint(equalTo: bottomRow.topAnchor, constant: -4)
            ])
        }
        
        item.view = wrapperView
        return item
    }

    @objc private func daemonActionClicked(_ sender: DaemonActionButton) {
        statusItem.menu?.cancelTracking()
        
        switch sender.actionType {
        case "select":
            self.selectedEmail = sender.email
            fetchAndUpdate()
        case "webui":
            if let url = URL(string: "http://127.0.0.1:\(sender.port)") {
                NSWorkspace.shared.open(url)
            }
        case "stop":
            kill(pid_t(sender.pid), SIGTERM)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fetchAndUpdate()
            }
        default:
            break
        }
    }

    // MARK: - Actions

    @objc private func openGeminiFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: EnvPaths.geminiDir)) }

    // MARK: - Unified Utilities

    @objc private func restartAndReload() {
        TerminalHelper.sendAntigravityCommand("antigravity.restartLanguageServer")
        TerminalHelper.sendAntigravityCommand("antigravity.restartUserStatusUpdater")
        TerminalHelper.sendAntigravityCommand("workbench.action.reloadWindow")
    }

    @objc private func fullCleanup() {
        let alert = NSAlert()
        alert.messageText = "Full Cleanup?"
        alert.informativeText = "Cache, Brain, and Recordings will be cleared. (Knowledge is preserved)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            api.clearCache()
            api.clearBrain()
            api.clearRecordings()
            fetchAndUpdate()
        }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    private func openInAntigravity(_ path: String) {
        let url = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        let bundleIDs = [
            "com.google.antigravity",
            "com.google.android.studio.antigravity",
            "com.todesktop.241115phmt2hfaz"
        ]
        for bid in bundleIDs {
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: config)
                return
            }
        }
        NSWorkspace.shared.open(url)
    }
}
