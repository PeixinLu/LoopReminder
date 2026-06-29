import Foundation

struct TimeSegmentInputState {
    enum Segment {
        case hour
        case minute
    }

    enum Action {
        case none
        case commit
    }

    var focusedSegment: Segment = .hour

    private var hourDigits = ""
    private var minuteDigits = ""

    @discardableResult
    mutating func handle(character: Character, hour: inout Int, minute: inout Int, disabledKeys: Set<Int>) -> Action {
        if Self.isCommit(character) {
            commitPendingInput(hour: &hour, minute: &minute, disabledKeys: disabledKeys)
            clearBuffers()
            return .commit
        }

        if Self.isSeparator(character) {
            toggleFocusedSegment()
            return .none
        }

        guard character.isNumber else { return .none }

        switch focusedSegment {
        case .hour:
            Self.appendDigit(character, to: &hourDigits)
            commitHour(hour: &hour)
        case .minute:
            Self.appendDigit(character, to: &minuteDigits)
            commitMinute(hour: &hour, minute: &minute, disabledKeys: disabledKeys)
        }

        return .none
    }

    mutating func focus(_ segment: Segment) {
        focusedSegment = segment
        clearBuffers()
    }

    mutating func clearBuffers() {
        hourDigits = ""
        minuteDigits = ""
    }

    func displayText(hour: Int, minute: Int) -> String {
        "\(String(format: "%02d", hour)):\(String(format: "%02d", minute))"
    }

    func segmentText(_ segment: Segment, hour: Int, minute: Int) -> String {
        switch segment {
        case .hour:
            return String(format: "%02d", hour)
        case .minute:
            return String(format: "%02d", minute)
        }
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character == "\t" || character == " " || character == ":" || character == "："
    }

    private static func isCommit(_ character: Character) -> Bool {
        character == "\n" || character == "\r"
    }

    private mutating func toggleFocusedSegment() {
        focusedSegment = focusedSegment == .hour ? .minute : .hour
        clearBuffers()
    }

    private static func appendDigit(_ digit: Character, to buffer: inout String) {
        if buffer.count >= 2 {
            buffer = ""
        }
        buffer.append(digit)
    }

    private mutating func commitHour(hour: inout Int) {
        guard let candidate = Int(hourDigits), (0...23).contains(candidate) else {
            hourDigits = ""
            return
        }

        hour = candidate
        if hourDigits.count == 2 {
            hourDigits = ""
            focusedSegment = .minute
        }
    }

    private mutating func commitMinute(hour: inout Int, minute: inout Int, disabledKeys: Set<Int>) {
        guard let candidate = Int(minuteDigits), (0...59).contains(candidate) else {
            minuteDigits = ""
            return
        }

        minute = candidate
        if minuteDigits.count == 2 {
            let corrected = Self.nearestEnabledTime(hour: hour, minute: minute, disabledKeys: disabledKeys)
            hour = corrected.hour
            minute = corrected.minute
            minuteDigits = ""
        }
    }

    private mutating func commitPendingInput(hour: inout Int, minute: inout Int, disabledKeys: Set<Int>) {
        clearBuffers()
    }

    private static func nearestEnabledTime(hour: Int, minute: Int, disabledKeys: Set<Int>) -> (hour: Int, minute: Int) {
        let target = hour * 60 + minute
        guard disabledKeys.contains(target) else {
            return (hour, minute)
        }

        for distance in 1..<1440 {
            let forward = target + distance
            if forward <= 1439, !disabledKeys.contains(forward) {
                return (forward / 60, forward % 60)
            }

            let backward = target - distance
            if backward >= 0, !disabledKeys.contains(backward) {
                return (backward / 60, backward % 60)
            }
        }

        return (hour, minute)
    }
}
