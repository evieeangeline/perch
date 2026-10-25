import Foundation
import UserNotifications

/// What `TaskStore` needs from the scheduler, so tests can swap in a fake.
protocol ReminderScheduling: AnyObject {
    func schedule(_ task: PerchTask)
    func cancel(_ taskID: UUID)
    func resync(_ tasks: [PerchTask])
}

/// Turns task reminders into macOS notifications. Each task has at most one
/// pending notification, identified by the task's id, so scheduling again
/// simply replaces it.
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate, ReminderScheduling {
    static let shared = ReminderScheduler()

    /// `UNUserNotificationCenter` crashes without a bundle identifier (e.g.
    /// `swift run`, which runs the bare executable); reminders are simply
    /// inert there.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func start() {
        center?.delegate = self
    }

    /// Schedules (or replaces) the task's notification, or cancels it if the
    /// task is done or has no future reminder.
    func schedule(_ task: PerchTask) {
        guard let center else { return }
        guard let date = task.remindAt, date > Date(), !task.isDone else {
            cancel(task.id)
            return
        }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Perch"
            content.body = task.title
            content.sound = .default
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            let request = UNNotificationRequest(
                identifier: task.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            center.add(request)
        }
    }

    func cancel(_ taskID: UUID) {
        center?.removePendingNotificationRequests(withIdentifiers: [taskID.uuidString])
    }

    /// Rebuilds every pending notification from the saved tasks, so what's
    /// scheduled always matches what's on disk.
    func resync(_ tasks: [PerchTask]) {
        center?.removeAllPendingNotificationRequests()
        tasks.forEach(schedule)
    }

    /// Show reminders even when Perch itself is the active app (e.g. while
    /// typing in the add-task field).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
