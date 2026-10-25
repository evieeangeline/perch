import AppKit

/// Describes the notch (or lack thereof) on a given screen, used to size and
/// position the collapsed pill so it hugs the real notch on machines that have
/// one, and falls back to a plain top-center bar on machines that don't.
struct NotchGeometry {
    let screenFrame: NSRect
    let hasNotch: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    static func detect(for screen: NSScreen) -> NotchGeometry {
        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            return NotchGeometry(
                screenFrame: screen.frame,
                hasNotch: true,
                notchWidth: max(width, 150),
                notchHeight: topInset
            )
        }
        // No physical notch (external display, older MacBook, iMac/Mac mini/Studio):
        // draw a small bar at the very top of the screen instead.
        return NotchGeometry(
            screenFrame: screen.frame,
            hasNotch: false,
            notchWidth: 180,
            notchHeight: max(NSStatusBar.system.thickness, 24)
        )
    }

    /// The built-in display if one is connected, otherwise falls back to the
    /// main screen. The notch only ever exists on the built-in panel.
    static var builtInScreen: NSScreen {
        NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
