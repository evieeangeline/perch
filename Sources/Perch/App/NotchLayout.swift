import CoreGraphics
import Foundation

/// Single source of truth for the size of the notch-attached shape in each
/// state. Shared by the SwiftUI view (to draw it) and the window controller
/// (to hit-test the cursor against what's actually visible).
struct NotchLayout {
    let geometry: NotchGeometry

    /// The concave "ears" where the shape meets the top edge of the screen,
    /// so it flows out of the notch like the camera housing itself.
    static let glanceEarRadius: CGFloat = 8
    static let expandedEarRadius: CGFloat = 12
    static let glanceBottomRadius: CGFloat = 12
    static let expandedBottomRadius: CGFloat = 24

    static let glanceRowHeight: CGFloat = 20
    static let glanceTopPadding: CGFloat = 4
    static let glanceBottomPadding: CGFloat = 10
    static let maxGlanceTasks = 3

    var notchHeight: CGFloat { geometry.notchHeight }

    /// The expanded shape grows to fit its content (the notch band plus the
    /// task list), up to this height; beyond it the list scrolls.
    static let maxExpandedHeight: CGFloat = 480

    var expandedWidth: CGFloat {
        max(360, geometry.notchWidth + 2 * Self.expandedEarRadius + 150)
    }

    func expandedSize(contentHeight: CGFloat) -> CGSize {
        CGSize(
            width: expandedWidth,
            height: min(Self.maxExpandedHeight, notchHeight + contentHeight)
        )
    }

    /// Perchie's image is 165x216.
    static let perchieAspect: CGFloat = 165.0 / 216.0

    /// Perchie hanging below the shape's bottom edge. Its feet tuck 2pt up
    /// into the edge so it looks attached.
    static let hangingPerchieHeight: CGFloat = 30
    static var hangingPerchieWidth: CGFloat { hangingPerchieHeight * perchieAspect }
    static let hangingPerchieTuck: CGFloat = 2

    /// Perchie hanging from the top of the screen in the notch band, just
    /// right of the camera.
    static let topPerchieHeight: CGFloat = 26
    static var topPerchieWidth: CGFloat { topPerchieHeight * perchieAspect }
    static let topPerchieGap: CGFloat = 6

    /// Horizontal offset of Perchie (top style) from the shape's centre.
    var topPerchieOffset: CGFloat {
        geometry.notchWidth / 2 + Self.topPerchieGap + Self.topPerchieWidth / 2
    }

    /// Horizontal offset of the hanging Perchie from the shape's centre,
    /// keeping it on the flat part of the bottom edge (clear of the corners).
    static func hangingPerchieOffset(fraction: Double, shapeWidth: CGFloat, expanded: Bool) -> CGFloat {
        let ear = expanded ? expandedEarRadius : glanceEarRadius
        let corner = expanded ? expandedBottomRadius : glanceBottomRadius
        let limit = max(0, shapeWidth / 2 - ear - corner - hangingPerchieWidth / 2)
        return min(limit, max(-limit, CGFloat(fraction) * shapeWidth))
    }

    /// The panel window never resizes (resizing a real window can't be
    /// animated smoothly); it's always big enough for the tallest expanded
    /// shape (plus Perchie hanging under it) and SwiftUI animates the shape
    /// inside it.
    var windowSize: CGSize {
        CGSize(width: expandedWidth, height: Self.maxExpandedHeight + Self.hangingPerchieHeight)
    }

    /// Rows shown while not hovered: up to `maxGlanceTasks` tasks, plus a
    /// "+N more" row when there are extras.
    static func glanceRowCount(pendingCount: Int) -> Int {
        min(pendingCount, maxGlanceTasks) + (pendingCount > maxGlanceTasks ? 1 : 0)
    }

    func glanceSize(pendingCount: Int, perchieAtTop: Bool) -> CGSize {
        let rows = Self.glanceRowCount(pendingCount: pendingCount)
        // With nothing to show, stay a thin lip barely wider than the notch,
        // but always leave room beside the camera for Perchie at the top
        // (on both sides, so the shape stays centred on the notch).
        var extraWidth: CGFloat = rows == 0 ? 16 : 70
        if perchieAtTop {
            extraWidth = max(extraWidth, 2 * (Self.topPerchieGap + Self.topPerchieWidth + 6))
        }
        let listHeight = rows == 0
            ? 0
            : CGFloat(rows) * Self.glanceRowHeight + Self.glanceTopPadding + Self.glanceBottomPadding
        return CGSize(
            width: geometry.notchWidth + 2 * Self.glanceEarRadius + extraWidth,
            height: notchHeight + listHeight
        )
    }

    /// With the list hidden, the expanded shape is just the title bar and the
    /// glance is the empty lip.
    func shapeSize(expanded: Bool, pendingCount: Int, contentHeight: CGFloat, perchieAtTop: Bool, listHidden: Bool = false) -> CGSize {
        if listHidden {
            return expanded
                ? CGSize(width: expandedWidth, height: notchHeight)
                : glanceSize(pendingCount: 0, perchieAtTop: perchieAtTop)
        }
        return expanded
            ? expandedSize(contentHeight: contentHeight)
            : glanceSize(pendingCount: pendingCount, perchieAtTop: perchieAtTop)
    }
}
