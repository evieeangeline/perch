import Foundation
import Testing
@testable import Perch

/// Pinned to a fixed "now", time zone and locale so the labels don't depend
/// on when or where the tests run.
@Suite struct ReminderLabelTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()
    let locale = Locale(identifier: "en_GB")

    /// Tue 14 Oct 2025, 10:30.
    var now: Date { date(day: 14, hour: 10, minute: 30) }

    private func date(month: Int = 10, day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: month, day: day, hour: hour, minute: minute))!
    }

    private func label(_ date: Date) -> String {
        date.reminderLabel(now: now, calendar: calendar, locale: locale)
    }

    @Test func todayShowsJustTheTime() {
        #expect(label(date(day: 14, hour: 15)) == "3:00 pm")
    }

    @Test func earlierTodayStillCountsAsToday() {
        #expect(label(date(day: 14, hour: 8, minute: 5)) == "8:05 am")
    }

    @Test func tomorrowIsPrefixed() {
        #expect(label(date(day: 15, hour: 9)) == "Tomorrow 9:00 am")
    }

    @Test func laterDatesShowDayAndDate() {
        #expect(label(date(day: 21, hour: 9)) == "Tue 21 Oct 9:00 am")
    }

    @Test func pastDatesShowDayAndDate() {
        #expect(label(date(day: 13, hour: 18)) == "Mon 13 Oct 6:00 pm")
    }

    @Test func tomorrowAcrossAMonthBoundary() {
        let lastOfMonth = date(day: 31, hour: 22)
        let firstOfNext = date(month: 11, day: 1, hour: 7)
        #expect(firstOfNext.reminderLabel(now: lastOfMonth, calendar: calendar, locale: locale) == "Tomorrow 7:00 am")
    }
}
