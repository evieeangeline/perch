import Foundation
import Testing
@testable import Perch

@Suite struct PerchTaskTests {
    private func decode(_ json: String) throws -> PerchTask {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PerchTask.self, from: Data(json.utf8))
    }

    @Test func newTaskDefaults() {
        let task = PerchTask(title: "A")
        #expect(task.title == "A")
        #expect(!task.isDone)
        #expect(!task.isFuture)
        #expect(task.completedAt == nil)
        #expect(task.remindAt == nil)
    }

    /// Tasks saved before reminders and Future existed must still load.
    @Test func decodesTasksSavedByOlderVersions() throws {
        let task = try decode("""
            {
              "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
              "title": "Old task",
              "isDone": true,
              "createdAt": "2025-01-01T09:00:00Z",
              "completedAt": "2025-01-02T09:00:00Z"
            }
            """)
        #expect(task.title == "Old task")
        #expect(task.isDone)
        #expect(task.completedAt != nil)
        #expect(task.remindAt == nil)
        #expect(!task.isFuture)
    }

    @Test func roundTripsAllFields() throws {
        var task = PerchTask(title: "Full")
        task.isDone = true
        task.isFuture = true
        task.completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        task.remindAt = Date(timeIntervalSince1970: 1_800_000_000)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(task), as: UTF8.self)
        let decoded = try decode(json)
        #expect(decoded.id == task.id)
        #expect(decoded.title == task.title)
        #expect(decoded.isDone && decoded.isFuture)
        #expect(decoded.completedAt == task.completedAt)
        #expect(decoded.remindAt == task.remindAt)
        // ISO-8601 is saved to the whole second, so sub-second precision on
        // `createdAt` (from `Date()`) is dropped.
        #expect(abs(decoded.createdAt.timeIntervalSince(task.createdAt)) < 1)
    }

    @Test func missingRequiredFieldFails() {
        #expect(throws: DecodingError.self) {
            try decode(#"{"title": "No id", "isDone": false, "createdAt": "2025-01-01T09:00:00Z"}"#)
        }
    }
}
