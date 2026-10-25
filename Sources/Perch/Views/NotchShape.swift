import SwiftUI

/// The outline of the notch-attached panel: flush with the top of the screen,
/// with concave ears curving into the top edge (like the notch's own
/// silhouette) and rounded bottom corners. Both radii animate, so the shape
/// morphs smoothly between the glance and expanded states.
struct NotchShape: Shape {
    var earRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(earRadius, bottomRadius) }
        set {
            earRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let e = earRadius
        let b = max(0, min(bottomRadius, rect.height - e, (rect.width - 2 * e) / 2))

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e, y: rect.minY + e),
            control: CGPoint(x: rect.minX + e, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + e, y: rect.maxY - b))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + e + b, y: rect.maxY),
            control: CGPoint(x: rect.minX + e, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - e - b, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - e, y: rect.maxY - b),
            control: CGPoint(x: rect.maxX - e, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - e, y: rect.minY + e))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - e, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
