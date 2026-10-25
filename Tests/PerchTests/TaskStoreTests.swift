import Foundation
import Testing
@testable import Perch

/// Records what `TaskStore` asks of the scheduler instead of posting real
/// notifications.
private final class FakeReminders: ReminderScheduling {
    var scheduled: [PerchTask] = []
    var cancelled: [UUID] = []
    var resynced: [[PerchTask]] = []

    func schedule(_ task: PerchTask) { scheduled.append(task) }
    func cancel(_ taskID: UUID) { cancelled.append(taskID) }
    func resync(_ tasks: [PerchTask]) { resynced.append(tasks) }
}

/// Each test gets its own store backed by a fresh temp file, so nothing
/// touches the real `tasks.json`.
@Suite struct TaskStoreTests {
    let fileURL: URL
    fileprivate let reminders = FakeReminders()
    let store: TaskStore

    init() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerchTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("tasks.json")
        store = TaskStore(fileURL: fileURL, reminders: reminders)
    }

    /// Adds tasks and returns them in the order given.
    @discardableResult
    private func add(_ titles: String...) -> [PerchTask] {
        titles.forEach(store.add(title:))
        return Array(store.tasks.suffix(titles.count))
    }

    private func reload() -> TaskStore {
        TaskStore(fileURL: fileURL, reminders: FakeReminders())
    }

    // MARK: Adding

    @Test func addTrimsWhitespace() {
        store.add(title: "  Buy milk \n")
        #expect(store.tasks.map(\.title) == ["Buy milk"])
    }

    @Test func addIgnoresBlankTitles() {
        store.add(title: "")
        store.add(title: "   \n\t")
        #expect(store.tasks.isEmpty)
    }

    @Test func newTasksArePendingInCreationOrder() {
        add("A", "B", "C")
        #expect(store.pendingTasks.map(\.title) == ["A", "B", "C"])
        #expect(store.futureTasks.isEmpty)
        #expect(store.completedTasks.isEmpty)
    }

    // MARK: Completing

    @Test func toggleDoneCompletesAndUndoes() throws {
        let task = try #require(add("A").first)

        store.toggleDone(task)
        let done = try #require(store.tasks.first)
        #expect(done.isDone)
        #expect(done.completedAt != nil)
        #expect(store.pendingTasks.isEmpty)
        #expect(store.completedTasks.map(\.id) == [task.id])

        store.toggleDone(done)
        let undone = try #require(store.tasks.first)
        #expect(!undone.isDone)
        #expect(undone.completedAt == nil)
    }

    @Test func toggleDoneReschedulesReminder() throws {
        let task = try #require(add("A").first)
        store.toggleDone(task)
        #expect(reminders.scheduled.last?.id == task.id)
        #expect(reminders.scheduled.last?.isDone == true)
    }

    @Test func completedTasksAreNewestFirst() throws {
        // Completing in quick succession can tie on completedAt, so write
        // the file with explicit times instead.
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Stored out of order; completed A, then B, then C.
        let tasks = [("A", 0.0), ("C", 2.0), ("B", 1.0)].map { title, seconds in
            var task = PerchTask(title: title)
            task.isDone = true
            task.completedAt = base.addingTimeInterval(seconds)
            return task
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(tasks).write(to: fileURL)

        #expect(reload().completedTasks.map(\.title) == ["C", "B", "A"])
    }

    @Test func clearCompletedHistoryKeepsPending() {
        let tasks = add("A", "B")
        store.toggleDone(tasks[0])
        store.clearCompletedHistory()
        #expect(store.tasks.map(\.title) == ["B"])
    }

    // MARK: Future

    @Test func setFutureMovesToBottomOfFuture() {
        let tasks = add("A", "B", "C")
        store.setFuture(tasks[2], true)
        store.setFuture(tasks[0], true)
        #expect(store.pendingTasks.map(\.title) == ["B"])
        #expect(store.futureTasks.map(\.title) == ["C", "A"])

        store.setFuture(tasks[2], false)
        #expect(store.pendingTasks.map(\.title) == ["B", "C"])
        #expect(store.futureTasks.map(\.title) == ["A"])
    }

    @Test func setFutureToSameSectionIsNoOp() {
        let tasks = add("A", "B")
        store.setFuture(tasks[0], false)
        #expect(store.tasks.map(\.title) == ["A", "B"])
    }

    // MARK: Reordering

    @Test func movePendingDownPlacesAfterTarget() {
        let tasks = add("A", "B", "C", "D")
        store.movePending(tasks[0].id, to: tasks[2].id)
        #expect(store.pendingTasks.map(\.title) == ["B", "C", "A", "D"])
    }

    @Test func movePendingUpPlacesBeforeTarget() {
        let tasks = add("A", "B", "C", "D")
        store.movePending(tasks[3].id, to: tasks[1].id)
        #expect(store.pendingTasks.map(\.title) == ["A", "D", "B", "C"])
    }

    @Test func movePendingKeepsCompletedTasksInTheirSlots() {
        let tasks = add("A", "Done", "B", "C")
        store.toggleDone(tasks[1])
        store.movePending(tasks[3].id, to: tasks[0].id)
        #expect(store.tasks.map(\.title) == ["C", "Done", "A", "B"])

        // Un-completing restores it where it was.
        store.toggleDone(store.tasks[1])
        #expect(store.pendingTasks.map(\.title) == ["C", "Done", "A", "B"])
    }

    @Test func movePendingDoesNotCrossSections() {
        let tasks = add("A", "B", "Later")
        store.setFuture(tasks[2], true)
        store.movePending(tasks[0].id, to: tasks[2].id)
        #expect(store.pendingTasks.map(\.title) == ["A", "B"])
        #expect(store.futureTasks.map(\.title) == ["Later"])
    }

    @Test func movePendingWithinFuture() {
        let tasks = add("X", "Y", "Z")
        tasks.forEach { store.setFuture($0, true) }
        store.movePending(tasks[2].id, to: tasks[0].id)
        #expect(store.futureTasks.map(\.title) == ["Z", "X", "Y"])
    }

    // MARK: Renaming, reminders, deleting

    @Test func renameTrimsAndReschedules() throws {
        let task = try #require(add("Old").first)
        store.rename(task, to: "  New  ")
        #expect(store.tasks.first?.title == "New")
        #expect(reminders.scheduled.last?.title == "New")
    }

    @Test func renameIgnoresBlankAndUnchangedTitles() throws {
        let task = try #require(add("Keep").first)
        store.rename(task, to: "   ")
        store.rename(task, to: "Keep")
        #expect(store.tasks.first?.title == "Keep")
        #expect(reminders.scheduled.isEmpty)
    }

    @Test func setReminderSavesAndSchedules() throws {
        let task = try #require(add("A").first)
        let date = Date().addingTimeInterval(3600)
        store.setReminder(task, at: date)
        #expect(store.tasks.first?.remindAt == date)
        #expect(reminders.scheduled.last?.remindAt == date)

        store.setReminder(task, at: nil)
        #expect(store.tasks.first?.remindAt == nil)
    }

    @Test func deleteRemovesAndCancelsReminder() throws {
        let tasks = add("A", "B")
        store.delete(tasks[0])
        #expect(store.tasks.map(\.title) == ["B"])
        #expect(reminders.cancelled == [tasks[0].id])
    }

    // MARK: Persistence

    @Test func tasksPersistAcrossLaunches() throws {
        let tasks = add("A", "B", "C")
        store.toggleDone(tasks[1])
        store.setFuture(tasks[2], true)
        store.setReminder(tasks[0], at: Date(timeIntervalSince1970: 2_000_000_000))

        let reloaded = reload()
        #expect(reloaded.tasks.map(\.id) == store.tasks.map(\.id))
        #expect(reloaded.pendingTasks.map(\.title) == ["A"])
        #expect(reloaded.futureTasks.map(\.title) == ["C"])
        #expect(reloaded.completedTasks.map(\.title) == ["B"])
        #expect(reloaded.tasks.first?.remindAt == Date(timeIntervalSince1970: 2_000_000_000))
    }

    @Test func launchResyncsRemindersFromDisk() {
        add("A", "B")
        let fake = FakeReminders()
        _ = TaskStore(fileURL: fileURL, reminders: fake)
        #expect(fake.resynced.map { $0.map(\.title) } == [["A", "B"]])
    }

    @Test func missingFileStartsEmpty() {
        #expect(store.tasks.isEmpty)
        #expect(reminders.resynced.count == 1)
    }

    @Test func corruptFileStartsEmpty() throws {
        try Data("not json".utf8).write(to: fileURL)
        #expect(reload().tasks.isEmpty)
    }
}
