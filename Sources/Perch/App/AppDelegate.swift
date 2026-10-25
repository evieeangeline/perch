import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let taskStore = TaskStore()
    private let settings = SettingsStore()

    private var notchController: NotchWindowController!
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ReminderScheduler.shared.start()
        notchController = NotchWindowController(
            taskStore: taskStore,
            settings: settings,
            openSettings: { [weak self] in self?.openSettings() }
        )
        // Show without making the panel key: it only takes focus when the
        // user clicks into it.
        notchController.window?.orderFrontRegardless()

        if settings.startExpanded {
            notchController.forceExpand()
        }

        setupStatusItem()
        LoginItemManager.shared.sync(enabled: settings.launchAtLogin)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            if let url = Bundle.module.url(forResource: "StatusBarIcon", withExtension: "png"),
               let icon = NSImage(contentsOf: url) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = false
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Perch")
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Perch", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu

        statusItem = item
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings, taskStore: taskStore)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
