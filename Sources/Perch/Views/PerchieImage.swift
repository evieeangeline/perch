import SwiftUI
import AppKit

/// Perchie, the bird from the app icon, hanging upside down with a
/// checkmark in its beak. The legs and checkmark are recoloured light so they
/// read against the black panel.
struct PerchieImage: View {
    private static let image: NSImage? = Bundle.module
        .url(forResource: "Perchie", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))

    var body: some View {
        if let image = Self.image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        }
    }
}
