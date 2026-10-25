import AppKit
import SwiftUI

/// The system's behind-window blur (as in Control Center and HUD windows),
/// so whatever is under the panel is blurred and darkened rather than shown
/// through as flat grey.
struct FrostedBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        // The panel is rarely key; without this the blur greys out as if the
        // window were inactive.
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
