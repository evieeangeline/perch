import SwiftUI

/// The natural height of the expanded list, so the shape can fit it.
struct ExpandedContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ExpandedView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var settings: SettingsStore
    @ObservedObject var hoverModel: HoverModel
    /// Whether the list is taller than the panel can grow, i.e. genuinely
    /// needs to scroll. Otherwise the scroll bar is hidden: the panel is sized
    /// to the content exactly, so rounding can leave it scrollable by a hair,
    /// and the scroll bar then flickers in near the right edge, squeezing the
    /// rows.
    let needsScrolling: Bool

    @State private var newTaskTitle: String = ""
    /// The task whose reminder picker is open, if any.
    @State private var editingReminderID: UUID?

    // Reordering is a plain drag gesture rather than system drag-and-drop,
    // which always draws a floating copy of the row. The row itself lifts
    // and follows the cursor while the others slide around it.
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var draggingID: UUID?
    /// The dragged row's top edge when the drag began, in list coordinates.
    @State private var dragStartMinY: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    /// Set after a swap until the new row frames are reported, so a stale
    /// frame can't trigger an immediate swap back.
    @State private var awaitingLayout = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    addTaskField

                    if taskStore.pendingTasks.isEmpty {
                        allDone
                    } else {
                        taskList(taskStore.pendingTasks)
                    }

                    if !taskStore.futureTasks.isEmpty {
                        futureSection
                    }

                    if !taskStore.completedTasks.isEmpty {
                        completedSection
                    }
                }
                .coordinateSpace(name: Self.listSpace)
                // Close any open reminder picker when the panel collapses.
                .onChange(of: hoverModel.isExpanded) { expanded in
                    if !expanded { editingReminderID = nil }
                }
                .onPreferenceChange(TaskRowFramesKey.self) {
                    rowFrames = $0
                    awaitingLayout = false
                }
                .padding(.horizontal, NotchLayout.expandedEarRadius + 14)
                .padding(.top, 8)
                .padding(.bottom, 14)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ExpandedContentHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .scrollIndicators(needsScrolling ? .automatic : .never)
        }
    }

    private var futureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Future")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 6)

            taskList(taskStore.futureTasks)
        }
    }

    /// A reorderable list of pending tasks: the main list or Future.
    private func taskList(_ sectionTasks: [PerchTask]) -> some View {
        VStack(spacing: 6) {
            ForEach(sectionTasks) { task in
                let isDragging = draggingID == task.id
                TaskRow(
                    task: task,
                    isEditingReminder: editingReminderID == task.id,
                    panelExpanded: hoverModel.isExpanded,
                    onToggle: { withAnimation { taskStore.toggleDone(task) } },
                    onReminderTap: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            editingReminderID = editingReminderID == task.id ? nil : task.id
                        }
                    },
                    onSetReminder: { date in
                        taskStore.setReminder(task, at: date)
                        withAnimation(.easeInOut(duration: 0.3)) { editingReminderID = nil }
                    },
                    onRename: { taskStore.rename(task, to: $0) },
                    onDelete: {
                        if editingReminderID == task.id { editingReminderID = nil }
                        withAnimation { taskStore.delete(task) }
                    },
                    onMoveSection: {
                        if editingReminderID == task.id { editingReminderID = nil }
                        withAnimation { taskStore.setFuture(task, !task.isFuture) }
                    }
                )
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(isDragging ? 0.08 : 0))
                        .padding(.horizontal, -6)
                )
                .scaleEffect(isDragging ? 1.02 : 1)
                .offset(y: isDragging ? dragOffset(for: task.id) : 0)
                // The dragged row tracks the cursor exactly; only the rows
                // it displaces animate.
                .transaction { if isDragging { $0.animation = nil } }
                // Measured after the offset/scale (which don't change layout)
                // so this is the row's slot in the list, not where it's being
                // drawn mid-drag; measuring inside the offset feeds the drag
                // offset back into itself.
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TaskRowFramesKey.self,
                            value: [task.id: proxy.frame(in: .named(Self.listSpace))]
                        )
                    }
                )
                .zIndex(isDragging ? 1 : 0)
                // Drags that start on the title select text (it's a text
                // field); anywhere else on the row, e.g. the grip, reorders.
                .gesture(reorderGesture(for: task, in: sectionTasks.map(\.id)))
            }
        }
    }

    private static let listSpace = "taskLists"

    /// Keeps the dragged row under the cursor even after the list has been
    /// reordered beneath it (its layout slot moves, so compensate).
    private func dragOffset(for id: UUID) -> CGFloat {
        guard let frame = rowFrames[id] else { return dragTranslation }
        return dragStartMinY + dragTranslation - frame.minY
    }

    /// Reorders within `sectionIDs` only; moving between the main list and
    /// Future is done with the row's arrow button.
    private func reorderGesture(for task: PerchTask, in sectionIDs: [UUID]) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.listSpace))
            .onChanged { value in
                if draggingID == nil {
                    draggingID = task.id
                    dragStartMinY = rowFrames[task.id]?.minY ?? 0
                    hoverModel.isDragging = true
                }
                dragTranslation = value.translation.height

                // Swap with whichever row the dragged row's centre is over.
                guard !awaitingLayout, let frame = rowFrames[task.id] else { return }
                let centre = dragStartMinY + dragTranslation + frame.height / 2
                if let target = rowFrames.first(where: { $0.key != task.id && sectionIDs.contains($0.key) && $0.value.minY <= centre && centre <= $0.value.maxY })?.key {
                    awaitingLayout = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        taskStore.movePending(task.id, to: target)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    draggingID = nil
                    dragTranslation = 0
                }
                awaitingLayout = false
                hoverModel.isDragging = false
            }
    }

    private var allDone: some View {
        VStack(spacing: 6) {
            PerchieImage()
                .frame(height: 52)
            Text("All done")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Text("Nothing left on the list.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var addTaskField: some View {
        HStack {
            // A custom placeholder: the system one is too faint on black.
            TextField("", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .onSubmit(addTask)
                .background(alignment: .leading) {
                    if newTaskTitle.isEmpty {
                        Text("Add a task…")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .allowsHitTesting(false)
                    }
                }

            if !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.12)))
    }

    private func addTask() {
        taskStore.add(title: newTaskTitle)
        newTaskTitle = ""
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recently completed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 6)

            let recent = taskStore.completedTasks.prefix(settings.recentCompletedCount)
            ForEach(Array(recent)) { task in
                CompletedTaskRow(
                    task: task,
                    onToggle: { withAnimation { taskStore.toggleDone(task) } },
                    onDelete: { withAnimation { taskStore.delete(task) } }
                )
            }

            if taskStore.completedTasks.count > settings.recentCompletedCount {
                DisclosureGroup {
                    ForEach(Array(taskStore.completedTasks.dropFirst(settings.recentCompletedCount))) { task in
                        CompletedTaskRow(
                            task: task,
                            onToggle: { withAnimation { taskStore.toggleDone(task) } },
                            onDelete: { withAnimation { taskStore.delete(task) } }
                        )
                    }
                } label: {
                    Text("Show all completed (\(taskStore.completedTasks.count))")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .tint(.white.opacity(0.5))
            }
        }
    }
}


/// Each pending row's frame in the list's coordinate space, for reordering.
private struct TaskRowFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
