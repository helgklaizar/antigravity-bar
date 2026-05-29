# 📋 Project Tasks & Audit Findings: Antigravity Status Bar

## 📊 Summary of Findings

The **Antigravity Status Bar** is a native macOS menu bar utility built in Swift using AppKit/SwiftUI, with supporting Python scripting (`archive_unused.py`). The project tracks local AI daemons (Connect/Protobuf JSON API endpoints), displays active LLM model quotas, shows real-time macOS system statistics (CPU, GPU, RAM, Cache size), and facilitates quick ecosystem actions. 

While the core functionality is lightweight and has zero bloated external dependencies, the audit revealed several critical architecture and UI issues:
1. **Thread Blocking (Main Actor Freeze):** A synchronous `DispatchSemaphore.wait()` call in `isHTTPReachable` is executed inside a `@MainActor` context during polling, which blocks the main thread and can freeze the macOS UI for several seconds per checked port.
2. **Technical Debt (AppDelegate Monolith):** `AppDelegate.swift` has expanded to 1,501 lines, violating the Single Responsibility Principle by combining app life cycle, timer polling, custom view layout construction, and action triggers in one file.
3. **Accessibility (a11y) Violations:** Custom AppKit view hierarchies embedded in `NSMenuItem`s (Quick Actions and Top RAM grids) lack proper accessibility labels and keyboard traversal capability, blocking VoiceOver users.
4. **Subprocess Risks:** Heavy reliance on executing raw shell/AppleScript subprocesses (`osascript`, `/usr/sbin/lsof`, CLI binaries) that violate App Sandbox guidelines.

---

## 🛠️ Actionable Tasks

### 🔒 Security, Compliance & Dependencies
- [ ] **Address App Sandbox Compliance & Entitlements (P1):** Since `ProcessManager.swift` accesses `/System/`, `/usr/`, and `/sbin/` processes and calls `kill(pid, SIGTERM)` natively, this will violate macOS sandboxing. Define appropriate temporary exception entitlements (`com.apple.security.temporary-exception.shared-preference`) or prepare the app for non-Sandbox distribution.
- [ ] **Sanitize and Decouple Subprocess Invocations in TerminalHelper.swift (P1):** Replace raw command launching via `Process()` for `osascript` in `TerminalHelper.runAppleScript` (line 36) with the native `NSAppleScript` class or clean up arguments to avoid command injection vulnerabilities.
- [ ] **Mask Private User Emails (P2):** The status bar app displays full user email addresses (e.g. from `quota.email` in `AppDelegate.swift` line 205 and `AntigravityAPI.swift` line 341) in the menu bar. Introduce an email masking option (e.g. `u***@d***.com`) in `SourcesSettingsView` for privacy.

### ♿ Accessibility & SEO (WCAG 2.2 / a11y / Crawl4ai)
- [ ] **Add Accessibility Labels to Custom Menu Items (P1):** In `AppDelegate.swift`, the custom items `makeHorizontalToolbarItem()` (line 388) and `makeAppsHorizontalItem()` (line 522) embed custom AppKit view hierarchies. The embedded buttons (like the close button for killing processes, and toolbar action buttons) have no accessibility labels. Add `setAccessibilityLabel` to all interactive elements.
- [ ] **Fix VoiceOver Support for Hidden Section Labels (P2):** In `InstallerView.swift` -> `SourcesSettingsView` (line 342), the repository toggle switches inside the List section header `Toggle("", isOn: ...)` have hidden labels (`.labelsHidden()`). Replace with explicit accessibility labels: `.accessibilityLabel(viewModel.registrySections[index].title)`.
- [ ] **Configure Keyboard Navigation Loop in Custom NSMenuItems (P2):** The custom embedded `NSView` panels in the context menu are skipped during keyboard Arrow Up/Down navigation. Implement Custom key event handling or subclass `NSView` to properly intercept key loop cycles.
- [ ] **Clean and Localize Generated HTML in openGitReposDatabase (P2):** In `TerminalHelper.swift` (line 119), the generated HTML file has hardcoded language `<html lang="ru">` and lacks responsive viewport guidelines. Localize the markup and add standard WCAG-compliant CSS text scaling.

### ⚙️ Technical Debt & Assumptions
- [ ] **Eliminate Synchronous Blocking of Main Thread in AntigravityAPI (P0):** In `AntigravityAPI.swift` (line 291), `isHTTPReachable` uses `DispatchSemaphore.wait()` to synchronously block until a response is received or timed out. Since `findActiveDaemons()` (which runs `isHTTPReachable`) is called inside `fetchAndUpdate()` on the `@MainActor`, this blocks the main UI thread during polling. Rewrite `isHTTPReachable` to be fully asynchronous (`async/await`) and run it in a background task queue.
- [ ] **Deconstruct AppDelegate Monolith (P1):** `AppDelegate.swift` is a 1,501-line monolith that handles UI layout code, context menus, polling, notification registration, and quick actions. Split menu building into a separate class (e.g., `StatusMenuBuilder.swift`) and quick actions into a coordinator class (e.g., `QuickActionCoordinator.swift`).
- [ ] **Reduce Nesting in InstallerView.swift and AntigravityAPI.swift (P1):** In `InstallerView.swift` (11 levels of nesting) and `AntigravityAPI.swift` (9 levels of nesting), break down nested switch statements, if-lets, and closures into clean helper methods as indicated in the TODO list.
- [ ] **Improve Error Handling from Silently failing (P2):** Replace `try?` in `TerminalHelper.runAppleScript`, `sendAntigravityCommand`, and JSON decoding in `AntigravityAPI.swift` with structured `do-catch` blocks and unified logging to avoid silent failures.

### 🧪 QA & Testing Strategy (Unit, Integration, E2E, Load, A/B)
- [ ] **Implement Integration Tests for Daemon Discovery (P1):** In `AntigravityBarTests.swift`, create test cases that mock the process list (by injecting test process arrays into `findLanguageServerProcesses()`) and mock local HTTP responses on ports `58622`, `58621` to verify correct daemon status resolution.
- [ ] **Add E2E UI Tests for Installer Flow (P1):** Write UI automation tests in `AntigravityBarTests` using `XCUIApplication` (or ViewInspector) to verify step transitions in `InstallerView` (`.initial` -> `.analyzing` -> `.results` -> `.installing`).
- [ ] **Verify Disk I/O & Memory Profile in Load Tests (P2):** Create a performance benchmark test using `XCTestCase.measure` to verify that `updateCacheSize()` (which enumerates folders in `.gemini`) runs efficiently and does not cause I/O starvation when there are >10,000 files in the brain directory.
- [ ] **Implement A/B Test for Quick Actions UI Layout (P2):** Add a feature flag or config setting in `Environment` to alternate between the grid toolbar (`makeHorizontalToolbarItem()`) and a classic list-based context menu to measure click-through interaction rates.
