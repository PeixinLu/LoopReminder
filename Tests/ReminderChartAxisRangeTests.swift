import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func makeDate(_ hour: Int, _ minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2026
    components.month = 6
    components.day = 25
    components.hour = hour
    components.minute = minute
    return components.date!
}

func minutesSinceStartOfDay(_ date: Date) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = calendar.startOfDay(for: date)
    return Int(date.timeIntervalSince(start) / 60)
}

func testEventsUsePaddedAutomaticRange() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let range = ReminderChartAxisRange.automatic(
        eventDates: [makeDate(9, 20), makeDate(9, 30)],
        runningStart: nil,
        now: makeDate(12, 0),
        calendar: calendar
    )

    expect(minutesSinceStartOfDay(range.start) == 9 * 60 + 10, "range should start 10 minutes before first event")
    expect(minutesSinceStartOfDay(range.end) == 9 * 60 + 40, "range should end 10 minutes after last event")
}

func testEmptyDataUsesFullDay() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let range = ReminderChartAxisRange.automatic(
        eventDates: [],
        runningStart: nil,
        now: makeDate(12, 0),
        calendar: calendar
    )

    expect(minutesSinceStartOfDay(range.start) == 0, "empty range should start at midnight")
    expect(Int(range.end.timeIntervalSince(range.start)) == 86_400, "empty range should span 24 hours")
}

func testRangeDoesNotExceedTwentyFourHours() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let range = ReminderChartAxisRange.automatic(
        eventDates: [makeDate(0, 0), makeDate(23, 59)],
        runningStart: nil,
        now: makeDate(12, 0),
        calendar: calendar
    )

    expect(range.duration <= 86_400, "range should not exceed 24 hours")
    expect(minutesSinceStartOfDay(range.start) == 0, "near-full-day range should clamp to start of day")
}

@main
struct ReminderChartAxisRangeTestRunner {
    static func main() {
        testEventsUsePaddedAutomaticRange()
        testEmptyDataUsesFullDay()
        testRangeDoesNotExceedTwentyFourHours()
        print("PASS")
    }
}
