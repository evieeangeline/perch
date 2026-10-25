import AppKit
import SwiftUI

/// Owns the panel that hangs from the notch. The window itself is a fixed,
/// transparent rectangle big enough for the expanded state; SwiftUI animates
/// the visible shape inside it. Clicks fall through everywhere outside that
/// shape, so the unused part of the window never blocks the menu bar.
final class NotchWindowController: NSWindowController {

    private let taskStore: TaskStore
    private let settings: SettingsStore
    private let openSettings: () -> Void
    private let hoverModel = HoverModel()
    private var layout: NotchLayout

    private var mouseMonitors: [Any] = []
    private var mouseInside = false
    private var collapseWorkItem: DispatchWorkItem?

    init(taskStore: TaskStore, settings: SettingsStore, openSettings: @escaping () -> Void) {
        self.taskStore = taskStore
        self.settings = settings
        self.openSettings = openSettings

        let layout = NotchLayout(geometry: NotchGeometry.detect(for: NotchGeometry.builtInScreen))
        self.layout = layout

        let panel = PerchPanel(contentRect: NotchWindowController.windowFrame(for: layout))
        panel.ignoresMouseEvents = true
        super.init(window: panel)

        let hostingView = FirstClickHostingView(rootView: makeRootView())
        // The window's size is fixed; never let SwiftUI content resize it.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        // When the panel becomes key, AppKit would otherwise focus the first
        // text field in its key-view loop, leaving a task title in edit mode
        // that the user never clicked.
        panel.initialFirstResponder = hostingView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Hover is tracked here rather than with SwiftUI's `.onHover`, by
        // comparing the cursor to the visible shape. The global monitor covers
        // other apps being frontmost; the local one covers Perch itself (e.g.
        // while typing in the add-task field). Neither needs Accessibility.
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.mouseMoved() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in
            handler(event)
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        mouseMonitors.forEach(NSEvent.removeMonitor)
    }

    func forceExpand() {
        hoverModel.isExpanded = true
    }

    private func makeRootView() -> RootView {
        RootView(
            taskStore: taskStore,
            settings: settings,
            hoverModel: hoverModel,
            layout: layout,
            openSettings: openSettings
        )
    }

    private static func windowFrame(for layout: NotchLayout) -> NSRect {
        let screenFrame = layout.geometry.screenFrame
        let size = layout.windowSize
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// The visible shape's rect in screen coordinates (top-centred in the
    /// window), for the state the panel is currently in.
    private func visibleShapeRect() -> NSRect {
        guard let window else { return .zero }
        let size = layout.shapeSize(
            expanded: hoverModel.isExpanded,
            pendingCount: taskStore.pendingTasks.count,
            contentHeight: hoverModel.expandedContentHeight,
            perchieAtTop: settings.perchieStyle == .top,
            listHidden: hoverModel.isListHidden
        )
        return NSRect(
            x: window.frame.midX - size.width / 2,
            y: window.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// The hanging Perchie's rect in screen coordinates. It only takes
    /// clicks (to be dragged) while expanded.
    private func hangingPerchieRect(below shape: NSRect) -> NSRect {
        let offset = NotchLayout.hangingPerchieOffset(
            fraction: settings.perchieHangPosition,
            shapeWidth: shape.width,
            expanded: hoverModel.isExpanded
        )
        let height = NotchLayout.hangingPerchieHeight
        let width = NotchLayout.hangingPerchieWidth
        return NSRect(
            x: shape.midX + offset - width / 2,
            y: shape.minY + NotchLayout.hangingPerchieTuck - height,
            width: width,
            height: height
        )
    }

    private func cursorIsInsideShape() -> Bool {
        if hoverModel.isDragging { return true }
        let mouse = NSEvent.mouseLocation
        let shape = visibleShapeRect()
        if NSMouseInRect(mouse, shape, false) { return true }
        return hoverModel.isExpanded
            && settings.perchieStyle == .hanging
            && NSMouseInRect(mouse, hangingPerchieRect(below: shape), false)
    }

    /// Expands as soon as the cursor enters the shape and collapses shortly
    /// after it genuinely leaves. Only inside<->outside transitions count, so
    /// "Start expanded" stays open until the user hovers in and out once.
    private func mouseMoved() {
        let inside = cursorIsInsideShape()
        window?.ignoresMouseEvents = !inside
        guard inside != mouseInside else { return }
        mouseInside = inside
        collapseWorkItem?.cancel()

        if inside {
            hoverModel.isExpanded = true
        } else {
            let workItem = DispatchWorkItem { [weak self] in
                // With the list hidden, the title bar stays out so it can be
                // clicked to bring the list back.
                guard let self, !self.cursorIsInsideShape(), !self.hoverModel.isListHidden else { return }
                self.hoverModel.isExpanded = false
            }
            collapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
        }
    }

    @objc private func screenParametersChanged() {
        layout = NotchLayout(geometry: NotchGeometry.detect(for: NotchGeometry.builtInScreen))
        window?.setFrame(NotchWindowController.windowFrame(for: layout), display: true)
        (window?.contentView as? NSHostingView<RootView>)?.rootView = makeRootView()
    }
}

/// Lets the very first click on the panel act on what's under it. Without
/// this, while the panel isn't the key window the first click only makes it
/// key, so editing a task (or anything else) needed a second click.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
