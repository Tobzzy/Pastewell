import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = AppSettings()
    lazy var store = HistoryStore(settings: settings)

    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?
    private var localKeyMonitor: Any?
    private var lastTargetApplication: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        configureMainMenu()
        configureHistoryWindow()
        configureSettingsWindow()
        if settings.showMenuBarItem {
            configureStatusItem()
        }
        observeSettings()
        store.startMonitoring()
        rememberFrontmostApplication()
        observeApplicationChanges()

        configureHotKey()
        configureLocalKeyMonitor()

        showHistoryWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if settings.clearHistoryOnQuit {
            store.clearAll()
        }
        store.stopMonitoring()
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showHistoryWindow()
        return true
    }

    private func configureHistoryWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pastewell"
        window.level = settings.floatAboveWindows ? .floating : .normal
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentMinSize = NSSize(width: 320, height: 240)
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: HistoryView(
                store: store,
                settings: settings,
                onRestore: { [weak self] in self?.pasteIntoTargetApplication() },
                onDismiss: { [weak self] in self?.hideHistoryWindow() },
                onShowSettings: { [weak self] in self?.showSettingsWindow() }
            )
        )

        if !settings.rememberWindowPosition || !window.setFrameUsingName("PastewellHistoryWindow") {
            window.center()
        }
        if settings.rememberWindowPosition {
            window.setFrameAutosaveName("PastewellHistoryWindow")
        }
        historyWindow = window
    }

    private func configureSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 570, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pastewell Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: PastewellSettingsView(settings: settings, store: store)
        )
        window.center()
        settingsWindow = window
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let aboutItem = NSMenuItem(title: "About Pastewell", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Pastewell", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func configureHotKey() {
        hotKey = nil
        hotKey = GlobalHotKey(
            keyCode: settings.hotKeyPreset.keyCode,
            modifiers: settings.hotKeyPreset.modifiers
        ) { [weak self] in
            self?.showHistoryWindow()
        }
    }

    private func configureLocalKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.keyCode == UInt16(kVK_Escape),
                  let historyWindow = self.historyWindow,
                  historyWindow.isVisible else {
                return event
            }

            self.hideHistoryWindow()
            return nil
        }
    }

    private func observeSettings() {
        settings.$floatAboveWindows
            .dropFirst()
            .sink { [weak self] shouldFloat in
                self?.historyWindow?.level = shouldFloat ? .floating : .normal
            }
            .store(in: &cancellables)

        settings.$showMenuBarItem
            .dropFirst()
            .sink { [weak self] shouldShow in
                guard let self else { return }
                if shouldShow {
                    if self.statusItem == nil { self.configureStatusItem() }
                } else {
                    if let item = self.statusItem {
                        NSStatusBar.system.removeStatusItem(item)
                    }
                    self.statusItem = nil
                }
            }
            .store(in: &cancellables)

        settings.$showDockIcon
            .dropFirst()
            .sink { [weak self] shouldShow in
                NSApp.setActivationPolicy(shouldShow ? .regular : .accessory)
                self?.historyWindow?.standardWindowButton(.miniaturizeButton)?.isEnabled = shouldShow
            }
            .store(in: &cancellables)

        settings.$hotKeyPreset
            .dropFirst()
            .sink { [weak self] _ in self?.configureHotKey() }
            .store(in: &cancellables)

        settings.$historyLimit
            .dropFirst()
            .sink { [weak self] _ in self?.store.enforceHistoryLimit() }
            .store(in: &cancellables)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "clipboard",
            accessibilityDescription: "Pastewell clipboard history"
        )
        item.button?.title = " PW"
        item.button?.toolTip = "Pastewell"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            showHistoryWindow()
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            showHistoryWindow()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let pauseTitle = store.isPaused ? "Resume Recording" : "Pause Recording"
        menu.addItem(withTitle: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(showSettingsWindow), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit Pastewell", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func togglePause() {
        store.isPaused.toggle()
    }

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showSettingsWindow() {
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func showHistoryWindow() {
        rememberFrontmostApplication()
        guard let historyWindow else { return }

        if !settings.rememberWindowPosition {
            historyWindow.center()
        }

        if historyWindow.isMiniaturized {
            historyWindow.deminiaturize(nil)
        }
        historyWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func hideHistoryWindow() {
        historyWindow?.orderOut(nil)
    }

    private func observeApplicationChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func workspaceDidActivateApplication(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        remember(application)
    }

    private func rememberFrontmostApplication() {
        guard let application = NSWorkspace.shared.frontmostApplication else { return }
        remember(application)
    }

    private func remember(_ application: NSRunningApplication) {
        guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        lastTargetApplication = application
    }

    private func pasteIntoTargetApplication() {
        guard settings.autoPaste else {
            if !settings.keepWindowOpen {
                hideHistoryWindow()
            }
            return
        }

        guard AccessibilityPermission.request() else {
            store.needsAccessibilityPermission = true
            return
        }

        store.needsAccessibilityPermission = false
        guard let target = lastTargetApplication, !target.isTerminated else { return }
        target.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
            )
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            )
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
        }

        if !settings.keepWindowOpen {
            hideHistoryWindow()
        }
    }
}
