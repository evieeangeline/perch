import SwiftUI

/// Quick reminder choices shown inline under a task (inline rather than a
/// popover: a popover is a separate window, and moving into it would count
/// as leaving the panel and collapse it).
struct ReminderPicker: View {
    let current: Date?
    let onPick: (Date?) -> Void

    @State private var showCustom = false
    @State private var customDate: Date

    init(current: Date?, onPick: @escaping (Date?) -> Void) {
        self.current = current
        self.onPick = onPick
        _customDate = State(initialValue: current ?? Self.nextWholeHour())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                chip("30m") { onPick(Date().addingTimeInterval(30 * 60)) }
                chip("1hr") { onPick(Date().addingTimeInterval(60 * 60)) }
                chip("2hr") { onPick(Date().addingTimeInterval(2 * 60 * 60)) }
                chip("Tomorrow") { onPick(Self.tomorrowMorning()) }
                    .help("Tomorrow at 9 am")
                chip(showCustom ? "Custom ▴" : "Custom ▾") {
                    withAnimation(.easeInOut(duration: 0.3)) { showCustom.toggle() }
                }
            }

            if showCustom {
                HStack(spacing: 6) {
                    ReminderDateField(date: $customDate, minimumDate: Date())
                        .fixedSize()
                    chip("Set") { onPick(customDate) }
                }
            }

            if current != nil {
                chip("Remove reminder", tint: .orange) { onPick(nil) }
            }
        }
        .colorScheme(.dark)
    }

    private func chip(_ title: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tint.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private static func nextWholeHour() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return calendar.date(byAdding: .hour, value: 1, to: hour) ?? now
    }

    private static func tomorrowMorning() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}

extension Date {
    /// "3:00 pm" today, "Tomorrow 9:00 am", otherwise "Tue 14 Oct 9:00 am".
    var reminderLabel: String {
        reminderLabel(now: Date())
    }

    func reminderLabel(now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        if calendar.isDate(self, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: self)
        } else if calendar.isDate(self, inSameDayAs: tomorrow) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow " + formatter.string(from: self)
        } else {
            formatter.dateFormat = "EEE d MMM h:mm a"
            return formatter.string(from: self)
        }
    }
}
