import Combine
import Foundation

/// Shared between the AppKit window controller and the SwiftUI content: the
/// controller decides when the cursor is over the shape and sets
/// `isExpanded`; `RootView` animates between the glance and expanded states
/// and reports the expanded list's natural height so both sides agree on
/// how tall the expanded shape is.
final class HoverModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var expandedContentHeight: CGFloat = 200
    /// While something on the panel is being dragged (Perchie, or a task
    /// being reordered) it must not collapse, even if the cursor strays
    /// outside the shape.
    @Published var isDragging = false
    /// Toggled by clicking the "Perch" title: hides the task list, leaving
    /// just the title bar out (hovered or not) until the title is clicked
    /// again.
    @Published var isListHidden = false
}
