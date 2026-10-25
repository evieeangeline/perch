import SwiftUI

/// Draws the single shape that grows out of the notch. The window never
/// resizes; SwiftUI animates the shape's size, corners and opacity inside it,
/// which is what keeps the expand/collapse smooth.
struct RootView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var settings: SettingsStore
    @ObservedObject var hoverModel: HoverModel
    let layout: NotchLayout
    let openSettings: () -> Void

    private var expanded: Bool { hoverModel.isExpanded }
    private var restingOpacity: Double { settings.glanceTranslucent ? settings.glanceOpacity : 1 }

    /// Perchie's hang position when a drag began, in the same fraction units
    /// as `settings.perchieHangPosition`.
    @State private var dragStartPosition: Double?

    var body: some View {
        let size = layout.shapeSize(
            expanded: expanded,
            pendingCount: taskStore.pendingTasks.count,
            contentHeight: hoverModel.expandedContentHeight,
            perchieAtTop: settings.perchieStyle == .top,
            listHidden: hoverModel.isListHidden
        )
        let expandedSize = layout.expandedSize(contentHeight: hoverModel.expandedContentHeight)
        let shape = NotchShape(
            earRadius: expanded ? NotchLayout.expandedEarRadius : NotchLayout.glanceEarRadius,
            bottomRadius: expanded ? NotchLayout.expandedBottomRadius : NotchLayout.glanceBottomRadius
        )

        ZStack(alignment: .top) {
            // Each state's content is laid out at its own final size and
            // revealed by the clip as the shape grows, so text never reflows
            // mid-animation. Both stay in the hierarchy and cross-fade: the
            // expanded list must stay laid out so its height can be measured
            // before it's shown (it also keeps a half-typed task).
            GlanceView(tasks: hoverModel.isListHidden ? [] : taskStore.pendingTasks, layout: layout)
                .frame(width: size.width, alignment: .top)
                .opacity(expanded ? 0 : 1)

            expandedContent
                .frame(width: expandedSize.width, height: expandedSize.height, alignment: .top)
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded)
        }
        .onPreferenceChange(ExpandedContentHeightKey.self) { height in
            hoverModel.expandedContentHeight = height
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(background)
        .clipShape(shape)
        .overlay(alignment: .bottom) {
            if settings.perchieStyle == .hanging {
                hangingPerchie(shapeWidth: size.width)
            }
        }
        .overlay(alignment: .top) {
            // Hangs from the top edge of the screen beside the camera.
            if settings.perchieStyle == .top {
                PerchieImage()
                    .frame(height: NotchLayout.topPerchieHeight)
                    .offset(x: layout.topPerchieOffset)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: expanded)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: hoverModel.isListHidden)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: taskStore.pendingTasks.count)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: hoverModel.expandedContentHeight)
        .animation(.easeInOut(duration: 0.2), value: settings.perchieStyle)
        // The panel is always black, so render controls (text cursor,
        // selection, date field) in their dark-mode colours.
        .environment(\.colorScheme, .dark)
    }

    /// Hangs by its feet from the shape's bottom edge, like the icon's bird
    /// from its bar. While expanded it can be dragged along the edge; at rest
    /// it ignores the mouse so clicks pass through to whatever is beneath.
    private func hangingPerchie(shapeWidth: CGFloat) -> some View {
        let offset = NotchLayout.hangingPerchieOffset(
            fraction: settings.perchieHangPosition,
            shapeWidth: shapeWidth,
            expanded: expanded
        )
        let expandedWidth = layout.expandedWidth
        return PerchieImage()
            .frame(height: NotchLayout.hangingPerchieHeight)
            .contentShape(Rectangle())
            .offset(x: offset, y: NotchLayout.hangingPerchieHeight - NotchLayout.hangingPerchieTuck)
            .allowsHitTesting(expanded)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartPosition ?? settings.perchieHangPosition
                        dragStartPosition = start
                        hoverModel.isDragging = true
                        // Store the clamped position so it can't drift past
                        // the corners and feel "stuck" on the way back.
                        let proposed = start + Double(value.translation.width / expandedWidth)
                        let clamped = NotchLayout.hangingPerchieOffset(
                            fraction: proposed,
                            shapeWidth: expandedWidth,
                            expanded: true
                        )
                        settings.perchieHangPosition = Double(clamped / expandedWidth)
                    }
                    .onEnded { _ in
                        dragStartPosition = nil
                        hoverModel.isDragging = false
                    }
            )
            .transition(.opacity)
    }

    /// Solid black across the notch band so the shape reads as part of the
    /// camera housing, fading softly to translucent below it at rest; a solid
    /// layer fades in over the top when expanded.
    private var background: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Color.black.frame(height: layout.notchHeight)
                LinearGradient(
                    colors: [.black, .black.opacity(restingOpacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)
                Color.black.opacity(restingOpacity)
            }
            Color.black.opacity(expanded ? 1 : 0)
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // The header shares the notch band, either side of the camera.
            HStack(spacing: 6) {
                // Clicking the title hides/shows the list (title bar only).
                Button {
                    hoverModel.isListHidden.toggle()
                } label: {
                    HStack(spacing: 6) {
                        PerchieImage()
                            .frame(height: 20)
                        Text("Perch")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(hoverModel.isListHidden ? "Show list" : "Hide list")
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .frame(height: layout.notchHeight)
            .padding(.horizontal, NotchLayout.expandedEarRadius + 16)

            ExpandedView(
                taskStore: taskStore,
                settings: settings,
                hoverModel: hoverModel,
                needsScrolling: layout.notchHeight + hoverModel.expandedContentHeight > NotchLayout.maxExpandedHeight
            )
            .opacity(hoverModel.isListHidden ? 0 : 1)
            .allowsHitTesting(!hoverModel.isListHidden)
        }
    }
}
