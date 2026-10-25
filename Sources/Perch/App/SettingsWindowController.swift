import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(settings: SettingsStore, taskStore: TaskStore) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, taskStore: taskStore))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Perch Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 360, height: 480))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
