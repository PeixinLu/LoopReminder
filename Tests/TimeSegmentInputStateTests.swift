import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func send(_ input: String, to state: inout TimeSegmentInputState, hour: inout Int, minute: inout Int, disabledKeys: Set<Int> = []) {
    for character in input {
        state.handle(character: character, hour: &hour, minute: &minute, disabledKeys: disabledKeys)
    }
}

func testHourStartsFocusedAndAdvancesAfterTwoDigits() {
    var state = TimeSegmentInputState()
    var hour = 9
    var minute = 30

    expect(state.focusedSegment == .hour, "default focus should be hour")
    send("1", to: &state, hour: &hour, minute: &minute)
    expect(hour == 1, "single hour digit should update hour immediately")
    expect(minute == 30, "single hour digit should not change minute")
    expect(state.focusedSegment == .hour, "single hour digit should keep hour focus")

    send("2", to: &state, hour: &hour, minute: &minute)

    expect(hour == 12, "two hour digits should update hour")
    expect(minute == 30, "hour input should not change minute")
    expect(state.focusedSegment == .minute, "two hour digits should move focus to minute")
}

func testSeparatorTogglesBetweenSegments() {
    var state = TimeSegmentInputState()
    var hour = 9
    var minute = 30

    send(":", to: &state, hour: &hour, minute: &minute)
    expect(state.focusedSegment == .minute, "colon should move hour focus to minute")

    send("：", to: &state, hour: &hour, minute: &minute)
    expect(state.focusedSegment == .hour, "Chinese colon should move minute focus to hour")

    send(" ", to: &state, hour: &hour, minute: &minute)
    expect(state.focusedSegment == .minute, "space should move hour focus to minute")
}

func testMinuteRepeatedDigitsRestartMinuteInputWithoutChangingFocus() {
    var state = TimeSegmentInputState()
    var hour = 9
    var minute = 30

    send(":", to: &state, hour: &hour, minute: &minute)
    send("4", to: &state, hour: &hour, minute: &minute)
    expect(minute == 4, "single minute digit should update minute immediately")

    send("5", to: &state, hour: &hour, minute: &minute)
    expect(hour == 9, "minute input should not change hour")
    expect(minute == 45, "two minute digits should update minute")

    send("1", to: &state, hour: &hour, minute: &minute)

    expect(hour == 9, "minute overflow input should not change hour")
    expect(minute == 1, "third minute digit should restart minute input")
    expect(state.displayText(hour: hour, minute: minute) == "09:01", "restarted minute input should display padded value")
    expect(state.focusedSegment == .minute, "minute overflow input should keep minute focus")
}

func testMinuteCompletionMovesUnavailableTimeToNearestLegalValue() {
    var state = TimeSegmentInputState()
    var hour = 12
    var minute = 30

    send(":", to: &state, hour: &hour, minute: &minute)
    send("08", to: &state, hour: &hour, minute: &minute, disabledKeys: [12 * 60 + 8])

    expect(hour == 12, "nearest legal correction should keep hour when possible")
    expect(minute == 9, "nearest legal correction should prefer the next minute on ties")
}

func testHourInputDoesNotValidateUnavailableTime() {
    var state = TimeSegmentInputState()
    var hour = 9
    var minute = 8

    send("12", to: &state, hour: &hour, minute: &minute, disabledKeys: [12 * 60 + 8])

    expect(hour == 12, "hour completion should not reject unavailable hour plus existing minute")
    expect(minute == 8, "hour input should keep existing minute")
    expect(state.focusedSegment == .minute, "hour completion should still move focus to minute")
}

func testNearestLegalValueSearchesBackwardAtDayEnd() {
    var state = TimeSegmentInputState()
    var hour = 23
    var minute = 30

    send(":", to: &state, hour: &hour, minute: &minute)
    send("59", to: &state, hour: &hour, minute: &minute, disabledKeys: [23 * 60 + 59])

    expect(hour == 23, "day-end correction should stay in range")
    expect(minute == 58, "day-end correction should search backward when forward is out of range")
}

func testNearestLegalValueLeavesCurrentValueWhenAllTimesDisabled() {
    var state = TimeSegmentInputState()
    var hour = 12
    var minute = 30
    let allDisabled = Set(0..<1440)

    send(":", to: &state, hour: &hour, minute: &minute)
    send("08", to: &state, hour: &hour, minute: &minute, disabledKeys: allDisabled)

    expect(hour == 12, "all-disabled correction should keep current hour")
    expect(minute == 8, "all-disabled correction should keep typed minute")
}

func testInvalidAndDuplicateInputAreRejected() {
    var state = TimeSegmentInputState()
    var hour = 9
    var minute = 30

    send("29", to: &state, hour: &hour, minute: &minute)
    expect(hour == 2, "invalid completed hour should leave the first valid digit")
    expect(state.focusedSegment == .hour, "invalid hour should keep hour focus")

    send("12", to: &state, hour: &hour, minute: &minute, disabledKeys: [12 * 60 + 30])
    expect(hour == 12, "duplicate time should not be rejected during hour input")
    expect(state.focusedSegment == .minute, "two valid hour digits should move focus to minute")
}

func testReturnRequestsCommit() {
    var state = TimeSegmentInputState()
    var hour = 9
    var minute = 30

    send("1245", to: &state, hour: &hour, minute: &minute)
    let action = state.handle(character: "\n", hour: &hour, minute: &minute, disabledKeys: [])

    expect(action == .commit, "return should request commit")
    expect(hour == 12, "return should preserve committed hour")
    expect(minute == 45, "return should preserve committed minute")
}

@main
struct TimeSegmentInputStateTestRunner {
    static func main() {
        testHourStartsFocusedAndAdvancesAfterTwoDigits()
        testSeparatorTogglesBetweenSegments()
        testMinuteRepeatedDigitsRestartMinuteInputWithoutChangingFocus()
        testMinuteCompletionMovesUnavailableTimeToNearestLegalValue()
        testHourInputDoesNotValidateUnavailableTime()
        testNearestLegalValueSearchesBackwardAtDayEnd()
        testNearestLegalValueLeavesCurrentValueWhenAllTimesDisabled()
        testInvalidAndDuplicateInputAreRejected()
        testReturnRequestsCommit()
        print("PASS")
    }
}
