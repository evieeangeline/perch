import CoreGraphics
import Foundation
import Testing
@testable import Perch

@Suite struct NotchLayoutTests {
    /// Roughly a 14" MacBook Pro's notch.
    let notched = NotchLayout(geometry: NotchGeometry(
        screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
        hasNotch: true,
        notchWidth: 200,
        notchHeight: 32
    ))

    // MARK: Glance

    @Test(arguments: [(0, 0), (1, 1), (3, 3), (4, 4), (10, 4)])
    func glanceRowCountCapsAtThreePlusMoreRow(pending: Int, rows: Int) {
        #expect(NotchLayout.glanceRowCount(pendingCount: pending) == rows)
    }

    @Test func emptyGlanceIsAThinLip() {
        let size = notched.glanceSize(pendingCount: 0, perchieAtTop: false)
        #expect(size.height == 32)
        #expect(size.width == 200 + 2 * NotchLayout.glanceEarRadius + 16)
    }

    @Test func glanceGrowsWithRows() {
        let one = notched.glanceSize(pendingCount: 1, perchieAtTop: false)
        let three = notched.glanceSize(pendingCount: 3, perchieAtTop: false)
        let padding = NotchLayout.glanceTopPadding + NotchLayout.glanceBottomPadding
        #expect(one.height == 32 + NotchLayout.glanceRowHeight + padding)
        #expect(three.height == 32 + 3 * NotchLayout.glanceRowHeight + padding)
        #expect(one.width == three.width)
    }

    @Test func perchieAtTopLeavesRoomBesideTheCamera() {
        let without = notched.glanceSize(pendingCount: 0, perchieAtTop: false)
        let with = notched.glanceSize(pendingCount: 0, perchieAtTop: true)
        let neededEachSide = NotchLayout.topPerchieGap + NotchLayout.topPerchieWidth
        #expect(with.width > without.width)
        #expect((with.width - 200) / 2 >= neededEachSide)
    }

    // MARK: Expanded

    @Test func expandedWidthHasAMinimum() {
        let tiny = NotchLayout(geometry: NotchGeometry(
            screenFrame: .zero, hasNotch: false, notchWidth: 50, notchHeight: 24
        ))
        #expect(tiny.expandedWidth == 360)
        #expect(notched.expandedWidth == max(360, 200 + 2 * NotchLayout.expandedEarRadius + 150))
    }

    @Test func expandedHeightFitsContentUpToTheMax() {
        #expect(notched.expandedSize(contentHeight: 100).height == 132)
        #expect(notched.expandedSize(contentHeight: 10_000).height == NotchLayout.maxExpandedHeight)
    }

    @Test func windowFitsTallestShapeAndHangingPerchie() {
        let tallest = notched.expandedSize(contentHeight: 10_000)
        #expect(notched.windowSize.width == tallest.width)
        #expect(notched.windowSize.height == tallest.height + NotchLayout.hangingPerchieHeight)
    }

    // MARK: Hidden list

    @Test func hiddenListShrinksToTitleBarOrLip() {
        let expanded = notched.shapeSize(
            expanded: true, pendingCount: 5, contentHeight: 300, perchieAtTop: false, listHidden: true
        )
        #expect(expanded == CGSize(width: notched.expandedWidth, height: 32))

        let glance = notched.shapeSize(
            expanded: false, pendingCount: 5, contentHeight: 300, perchieAtTop: false, listHidden: true
        )
        #expect(glance == notched.glanceSize(pendingCount: 0, perchieAtTop: false))
    }

    @Test func shapeSizeMatchesStateWhenListShown() {
        #expect(notched.shapeSize(expanded: true, pendingCount: 2, contentHeight: 120, perchieAtTop: false)
            == notched.expandedSize(contentHeight: 120))
        #expect(notched.shapeSize(expanded: false, pendingCount: 2, contentHeight: 120, perchieAtTop: true)
            == notched.glanceSize(pendingCount: 2, perchieAtTop: true))
    }

    // MARK: Hanging Perchie

    @Test func hangingPerchieFollowsFractionWithinLimits() {
        let width: CGFloat = 400
        #expect(NotchLayout.hangingPerchieOffset(fraction: 0, shapeWidth: width, expanded: true) == 0)
        #expect(NotchLayout.hangingPerchieOffset(fraction: 0.1, shapeWidth: width, expanded: true) == 40)
    }

    @Test func hangingPerchieStaysClearOfTheCorners() {
        let width: CGFloat = 400
        let limit = width / 2 - NotchLayout.expandedEarRadius - NotchLayout.expandedBottomRadius
            - NotchLayout.hangingPerchieWidth / 2
        #expect(NotchLayout.hangingPerchieOffset(fraction: 5, shapeWidth: width, expanded: true) == limit)
        #expect(NotchLayout.hangingPerchieOffset(fraction: -5, shapeWidth: width, expanded: true) == -limit)
    }

    @Test func hangingPerchieCentresOnTinyShapes() {
        #expect(NotchLayout.hangingPerchieOffset(fraction: 0.4, shapeWidth: 20, expanded: false) == 0)
    }
}
