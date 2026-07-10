import Foundation

struct ScheduledTime: Equatable {
    let hour: Int
    let minute: Int

    func formattedTime() -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

func makeDate(day: Int, hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.calendar = utcCalendar
    components.year = 2026
    components.month = 7
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

func testNextScheduledDateMovesPastTimeToTomorrow() {
    let next = ReminderRecoverySchedule.nextScheduledDate(
        hour: 9,
        minute: 30,
        now: makeDate(day: 2, hour: 10, minute: 0),
        calendar: utcCalendar
    )
    expect(next == makeDate(day: 3, hour: 9, minute: 30), "past time should move to tomorrow")
}

func testNextScheduledDateKeepsFutureTimeToday() {
    let next = ReminderRecoverySchedule.nextScheduledDate(
        hour: 9,
        minute: 30,
        now: makeDate(day: 2, hour: 9, minute: 0),
        calendar: utcCalendar
    )
    expect(next == makeDate(day: 2, hour: 9, minute: 30), "future time should stay today")
}

func testMissedTimesOnlyIncludesSleepWindow() {
    let missed = ReminderRecoverySchedule.missedScheduledTimes(
        times: [ScheduledTime(hour: 9, minute: 30), ScheduledTime(hour: 12, minute: 0)],
        from: makeDate(day: 1, hour: 23, minute: 0),
        through: makeDate(day: 2, hour: 10, minute: 0),
        calendar: utcCalendar
    )
    expect(missed.map { $0.formattedTime() } == ["09:30"], "only 09:30 should be recorded as missed")
}

func testOverdueIntervalSchedulesImmediately() {
    let now = makeDate(day: 2, hour: 10, minute: 0)
    let next = ReminderRecoverySchedule.nextIntervalDate(
        lastFireEpoch: makeDate(day: 2, hour: 9, minute: 0).timeIntervalSince1970,
        interval: 1_800,
        now: now
    )
    expect(next == now, "overdue interval should run immediately")
}

func testIntervalResetRequiresOptionAndFiveMinutes() {
    expect(!ReminderRecoverySchedule.shouldResetInterval(isEnabled: false, elapsed: 600), "disabled option should not reset")
    expect(!ReminderRecoverySchedule.shouldResetInterval(isEnabled: true, elapsed: 299), "short sleep should not reset")
    expect(ReminderRecoverySchedule.shouldResetInterval(isEnabled: true, elapsed: 300), "five minutes should reset")
}

@main
struct ReminderRecoveryScheduleTestRunner {
    static func main() {
        testNextScheduledDateMovesPastTimeToTomorrow()
        testNextScheduledDateKeepsFutureTimeToday()
        testMissedTimesOnlyIncludesSleepWindow()
        testOverdueIntervalSchedulesImmediately()
        testIntervalResetRequiresOptionAndFiveMinutes()
        print("PASS")
    }
}
