import AppKit

/// A borderless, non-activating panel that floats above the menu bar, follows
/// the user across every Space (including full-screen apps), and never steals
/// focus from whatever app is currently frontmost — except when the user
/// actually clicks into it (e.g. the add-task field).
final class PerchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// AppKit normally pulls window frames back onto the "visible" area of
    /// the screen (below the menu bar) whenever `setFrame` is called on a
    /// frame that overlaps it — which fights our collapsed/expanded frames
    /// (both deliberately sit at the very top, overlapping the menu bar /
    /// notch strip) and was causing inconsistent size/position corrections
    /// between the two states. Disable that entirely; we set our own frames.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }
}
