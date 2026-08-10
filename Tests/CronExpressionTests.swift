import Foundation

func expectCron(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func makeDate(_ value: String, timeZone: TimeZone) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = timeZone
    guard let date = formatter.date(from: value) else {
        fatalError("invalid test date \(value)")
    }
    return date
}

func testWeekdaySchedule() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let cron = try CronExpression("0 9 * * 1-5")
    let fridayMorning = makeDate("2026-08-14T08:30:00Z", timeZone: calendar.timeZone)
    let fridayNine = makeDate("2026-08-14T09:00:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: fridayMorning, calendar: calendar) == fridayNine, "weekday cron should fire later the same day")

    let fridayAfter = makeDate("2026-08-14T09:01:00Z", timeZone: calendar.timeZone)
    let mondayNine = makeDate("2026-08-17T09:00:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: fridayAfter, calendar: calendar) == mondayNine, "weekday cron should skip the weekend")
}

func testListsRangesAndSteps() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let cron = try CronExpression("*/15 8-9 * * *")
    let start = makeDate("2026-08-11T08:07:00Z", timeZone: calendar.timeZone)
    let expected = makeDate("2026-08-11T08:15:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: start, calendar: calendar) == expected, "step and range syntax should find the next quarter hour")
}

func testSundayCanBeSeven() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let cron = try CronExpression("30 10 * * 7")
    let saturday = makeDate("2026-08-15T12:00:00Z", timeZone: calendar.timeZone)
    let sunday = makeDate("2026-08-16T10:30:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: saturday, calendar: calendar) == sunday, "weekday 7 should map to Sunday")
}

func testDayOfMonthAndWeekdayUseCronOrSemantics() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let cron = try CronExpression("0 9 15 * 1")
    let sunday = makeDate("2026-08-16T12:00:00Z", timeZone: calendar.timeZone)
    let monday = makeDate("2026-08-17T09:00:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: sunday, calendar: calendar) == monday, "restricted date and weekday should use traditional cron OR semantics")
}

func testLeapDaySchedule() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let cron = try CronExpression("0 12 29 2 *")
    let start = makeDate("2027-03-01T00:00:00Z", timeZone: calendar.timeZone)
    let leapDay = makeDate("2028-02-29T12:00:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: start, calendar: calendar) == leapDay, "cron should find the next leap day")
}

func testInvalidExpressionsAreRejected() {
    expectCron((try? CronExpression("0 9 * *")) == nil, "four fields should be rejected")
    expectCron((try? CronExpression("60 9 * * *")) == nil, "out-of-range minute should be rejected")
    expectCron((try? CronExpression("*/0 9 * * *")) == nil, "zero step should be rejected")
    expectCron((try? CronExpression("0 9 20-10 * *")) == nil, "descending range should be rejected")
}

func testUnsatisfiableExpressionsParseButNeverMatch() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let februaryThirtieth = try CronExpression("0 0 30 2 *")
    expectCron(februaryThirtieth.nextDate(after: Date(), calendar: calendar) == nil, "February 30 should never match")

    let aprilThirtyFirst = try CronExpression("0 0 31 4 *")
    expectCron(aprilThirtyFirst.nextDate(after: Date(), calendar: calendar) == nil, "April 31 should never match")
}

func testStepPrefixedFieldsCountAsUnrestricted() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    // Vixie cron treats a field starting with `*` as unrestricted, so `*/1` must not trigger OR semantics.
    let cron = try CronExpression("0 9 15 * */1")
    let start = makeDate("2026-08-11T00:00:00Z", timeZone: calendar.timeZone)
    let fifteenth = makeDate("2026-08-15T09:00:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: start, calendar: calendar) == fifteenth, "*/1 weekday should not widen a restricted day-of-month")

    // A restricted weekday with a step still participates in OR semantics.
    let stepped = try CronExpression("0 9 15 * 1-5/2")
    let sunday = makeDate("2026-08-16T12:00:00Z", timeZone: calendar.timeZone)
    let monday = makeDate("2026-08-17T09:00:00Z", timeZone: calendar.timeZone)
    expectCron(stepped.nextDate(after: sunday, calendar: calendar) == monday, "restricted stepped weekday should keep OR semantics")
}

func testBothFieldsWildcardMatchesEveryDay() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let cron = try CronExpression("0 9 * * *")
    let start = makeDate("2026-08-11T10:00:00Z", timeZone: calendar.timeZone)
    let tomorrow = makeDate("2026-08-12T09:00:00Z", timeZone: calendar.timeZone)
    expectCron(cron.nextDate(after: start, calendar: calendar) == tomorrow, "fully wildcard day fields should match the next day")
}

func testSkipsNonexistentLocalTimeAcrossDSTGap() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let cron = try CronExpression("30 2 * * *")

    var components = DateComponents()
    components.year = 2027
    components.month = 3
    components.day = 13
    components.hour = 12
    let start = calendar.date(from: components)!

    // 2027-03-14 02:30 ET does not exist, so the next fire must land on 03-15.
    guard let next = cron.nextDate(after: start, calendar: calendar) else {
        print("FAIL: DST-aware cron should still find a fire date")
        exit(1)
    }
    let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: next)
    expectCron(parts.month == 3 && parts.day == 15 && parts.hour == 2 && parts.minute == 30,
               "cron should skip the nonexistent 02:30 during the DST gap")
}

@main
struct CronExpressionTestRunner {
    static func main() throws {
        try testWeekdaySchedule()
        try testListsRangesAndSteps()
        try testSundayCanBeSeven()
        try testDayOfMonthAndWeekdayUseCronOrSemantics()
        try testLeapDaySchedule()
        testInvalidExpressionsAreRejected()
        try testUnsatisfiableExpressionsParseButNeverMatch()
        try testStepPrefixedFieldsCountAsUnrestricted()
        try testBothFieldsWildcardMatchesEveryDay()
        try testSkipsNonexistentLocalTimeAcrossDSTGap()
        print("PASS")
    }
}
