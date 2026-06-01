import AppKit
import Foundation

// MARK: - Entry Point
setbuf(__stdoutp, nil)
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no dock
let delegate = AppDelegate()
app.delegate = delegate
app.run()
