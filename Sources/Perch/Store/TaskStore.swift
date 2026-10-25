import Foundation
import Combine

final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [PerchTask] = []

    private let fileURL: URL
    private let reminders: ReminderScheduling

    /// `~/Library/Application Support/Perch/tasks.json`.
    static var defaultFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Perch", isDirectory: true)
            .appendingPathComponent("tasks.json")
    }

    init(fileURL: URL = TaskStore.defaultFileURL, reminders: ReminderScheduling = ReminderScheduler.shared) {
        self.fileURL = fileURL
        self.reminders = reminders
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        load()
        reminders.resync(tasks)
    }

    /// Pending tasks for now (not parked in Future) in the user's order,
    /// which is their order in `tasks` (new tasks are appended, so it starts
    /// out as creation order).
    var pendingTasks: [PerchTask] {
        tasks.filter { !$0.isDone && !$0.isFuture }
    }

    /// Pending tasks parked for later, in the user's order.
    var futureTasks: [PerchTask] {
        tasks.filter { !$0.isDone && $0.isFuture }
    }

    var completedTasks: [PerchTask] {
        tasks
            .filter { $0.isDone }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(PerchTask(title: trimmed))
        save()
    }

    func toggleDone(_ task: PerchTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isDone.toggle()
        tasks[idx].completedAt = tasks[idx].isDone ? Date() : nil
        save()
        // Ticking off cancels the reminder; un-ticking restores it if it's
        // still in the future.
        reminders.schedule(tasks[idx])
    }

    /// Moves a task between the main list and Future. It goes to the bottom
    /// of the section it lands in.
    func setFuture(_ task: PerchTask, _ isFuture: Bool) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }),
              tasks[idx].isFuture != isFuture else { return }
        var moved = tasks.remove(at: idx)
        moved.isFuture = isFuture
        tasks.append(moved)
        save()
    }

    /// Moves a pending task to the position of another pending task in the
    /// same section (after it when moving down, before it when moving up).
    /// Completed tasks and the other section keep their slots in `tasks`, so
    /// un-completing one restores it in place.
    func movePending(_ taskID: UUID, to targetID: UUID) {
        guard let section = tasks.first(where: { $0.id == taskID })?.isFuture else { return }
        let slots = tasks.indices.filter { !tasks[$0].isDone && tasks[$0].isFuture == section }
        var order = slots.map { tasks[$0] }
        guard let from = order.firstIndex(where: { $0.id == taskID }),
              let to = order.firstIndex(where: { $0.id == targetID }),
              from != to else { return }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        for (slot, task) in zip(slots, order) {
            tasks[slot] = task
        }
        save()
    }

    /// Renames a task. A blank title is ignored, keeping the old one.
    func rename(_ task: PerchTask, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = tasks.firstIndex(where: { $0.id == task.id }),
              tasks[idx].title != trimmed else { return }
        tasks[idx].title = trimmed
        save()
        // The reminder notification carries the title, so refresh it.
        reminders.schedule(tasks[idx])
    }

    /// Sets or clears (with `nil`) the task's reminder.
    func setReminder(_ task: PerchTask, at date: Date?) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].remindAt = date
        save()
        reminders.schedule(tasks[idx])
    }

    func delete(_ task: PerchTask) {
        tasks.removeAll { $0.id == task.id }
        save()
        reminders.cancel(task.id)
    }

    func clearCompletedHistory() {
        tasks.removeAll { $0.isDone }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        tasks = (try? decoder.decode([PerchTask].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
