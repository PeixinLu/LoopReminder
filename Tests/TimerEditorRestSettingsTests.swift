import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func testValidatesRestMinutes() {
    expect(TimerEditorRestSettings.validatedMinutes("5") == 5, "valid minutes should be accepted")
    expect(TimerEditorRestSettings.validatedMinutes("0") == nil, "zero should be rejected")
    expect(TimerEditorRestSettings.validatedMinutes("121") == nil, "over-limit minutes should be rejected")
    expect(TimerEditorRestSettings.validatedMinutes("1.5") == nil, "non-integer minutes should be rejected")
}

func testConvertsStoredSeconds() {
    expect(TimerEditorRestSettings.minutes(from: 300) == 5, "five minutes should be displayed as five")
    expect(TimerEditorRestSettings.minutes(from: 0) == 1, "invalid stored zero should clamp to one")
    expect(TimerEditorRestSettings.seconds(fromMinutes: 5) == 300, "minutes should save as seconds")
}

@main
struct TimerEditorRestSettingsTestRunner {
    static func main() {
        testValidatesRestMinutes()
        testConvertsStoredSeconds()
        print("PASS")
    }
}
