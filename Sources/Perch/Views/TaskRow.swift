import SwiftUI
import AppKit

struct TaskRow: View {
    let task: PerchTask
    let isEditingReminder: Bool
    /// Whether the panel is expanded; collapsing it ends (and saves) an
    /// in-progress title edit, since the field otherwise stays focused while
    /// hidden.
    let panelExpanded: Bool
    let onToggle: () -> Void
    let onReminderTap: () -> Void
    let onSetReminder: (Date?) -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    /// Moves the task to Future, or back to the main list if it's there.
    let onMoveSection: () -> Void

    @State private var titleDraft = ""
    @FocusState private var titleFocused: Bool
    @State private var hoveringTitle = false
    @State private var hoveringRow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Long titles wrap, so keep the checkbox and actions on the
            // first line rather than centred on the whole block.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: "circle")
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)

                titleArea

                reminderButton

                moveSectionButton

                deleteButton

                // A hint that rows can be dragged to reorder.
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .help("Drag to reorder")
            }

            if isEditingReminder {
                ReminderPicker(current: task.remindAt, onPick: onSetReminder)
                    .padding(.leading, 24)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { hoveringRow = $0 }
        .contextMenu {
            Button(task.isFuture ? "Move to Now" : "Move to Future", action: onMoveSection)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .onChange(of: panelExpanded) { expanded in
            if !expanded { titleFocused = false }
        }
    }

    /// Shows on hover, like the trash can: down into Future, or back up.
    private var moveSectionButton: some View {
        Button(action: onMoveSection) {
            Image(systemName: task.isFuture ? "arrow.up.to.line" : "arrow.down.to.line")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .buttonStyle(.plain)
        .opacity(hoveringRow ? 1 : 0)
        .allowsHitTesting(hoveringRow)
        .help(task.isFuture ? "Move to Now" : "Move to Future")
    }

    /// A trash can that only shows while the row is hovered, so the list
    /// stays uncluttered. Right-clicking the row also offers Delete.
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .buttonStyle(.plain)
        .opacity(hoveringRow ? 1 : 0)
        .allowsHitTesting(hoveringRow)
        .help("Delete task")
    }

    /// The title is always a borderless text field styled as plain text, so
    /// a single click puts the caret where you click and clicking another
    /// task moves straight into editing it. A faint highlight on hover (and
    /// the text cursor) hints that it's editable; it's a little stronger
    /// while editing. Return or clicking away saves, Escape reverts. Long
    /// titles wrap onto as many lines as they need.
    private var titleArea: some View {
        TextField("", text: $titleDraft, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...)
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(titleFocused ? 1 : 0.9))
            .focused($titleFocused)
            .onSubmit { titleFocused = false }
            .onExitCommand {
                titleDraft = task.title
                titleFocused = false
            }
            .onAppear { titleDraft = task.title }
            .onChange(of: task.title) { title in
                if !titleFocused { titleDraft = title }
            }
            .onChange(of: titleFocused) { focused in
                guard !focused else { return }
                // A title is one line of text, even if a newline was pasted in.
                let trimmed = titleDraft
                    .components(separatedBy: .newlines)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    titleDraft = task.title
                } else if trimmed != task.title {
                    onRename(trimmed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(titleFocused ? 0.1 : (hoveringTitle ? 0.06 : 0)))
            )
            // Keep the text aligned as if the highlight's padding weren't there.
            .padding(.horizontal, -5)
            .padding(.vertical, -2)
            // Instant (no fade) so editing feels immediate. `set` rather than
            // push/pop, which can get out of balance and leave the I-beam stuck.
            .onHover { hovering in
                hoveringTitle = hovering
                (hovering ? NSCursor.iBeam : NSCursor.arrow).set()
            }
    }

    /// A faint bell (on hover) when there's no reminder; the time (orange
    /// once it has passed) when there is. Either opens the picker.
    private var reminderButton: some View {
        Button(action: onReminderTap) {
            if let date = task.remindAt {
                HStack(spacing: 3) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9))
                    Text(date.reminderLabel)
                        .font(.system(size: 10.5))
                }
                .foregroundColor(date < Date() ? .orange.opacity(0.9) : .white.opacity(0.55))
            } else {
                Image(systemName: "bell")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(isEditingReminder ? 0.7 : 0.25))
            }
        }
        .buttonStyle(.plain)
        // An empty bell only shows on hover (or while its picker is open),
        // like the other row actions; a set reminder always shows its time.
        .opacity(task.remindAt != nil || hoveringRow || isEditingReminder ? 1 : 0)
        .allowsHitTesting(task.remindAt != nil || hoveringRow || isEditingReminder)
        .help(task.remindAt == nil ? "Add a reminder" : "Change reminder")
    }
}

struct CompletedTaskRow: View {
    let task: PerchTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var timeLabel: String {
        guard let date = task.completedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green.opacity(0.8))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 12))
                .strikethrough()
                .foregroundColor(.white.opacity(0.4))

            Spacer()

            Text(timeLabel)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}
