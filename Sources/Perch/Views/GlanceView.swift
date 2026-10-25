import SwiftUI

/// The resting state: a few upcoming tasks, dimmed, hanging just below the
/// notch. Read-only; hovering expands into the full list.
struct GlanceView: View {
    let tasks: [PerchTask]
    let layout: NotchLayout

    private var shown: ArraySlice<PerchTask> { tasks.prefix(NotchLayout.maxGlanceTasks) }
    private var extraCount: Int { tasks.count - shown.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: layout.notchHeight)

            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { task in
                        HStack(spacing: 7) {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                                .frame(width: 9, height: 9)
                            Text(task.title)
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if task.remindAt != nil {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .frame(height: NotchLayout.glanceRowHeight)
                    }

                    if extraCount > 0 {
                        Text("+\(extraCount) more")
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.leading, 16)
                            .frame(height: NotchLayout.glanceRowHeight)
                    }
                }
                .padding(.top, NotchLayout.glanceTopPadding)
                .padding(.horizontal, NotchLayout.glanceEarRadius + 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
