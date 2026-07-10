import Foundation

enum TimerEditorRestSettings {
    static func minutes(from seconds: Double) -> Int {
        min(120, max(1, Int((seconds / 60).rounded())))
    }

    static func seconds(fromMinutes minutes: Int) -> Double {
        Double(minutes * 60)
    }

    static func validatedMinutes(_ value: String) -> Int? {
        guard let minutes = Int(value), value == String(minutes), (1...120).contains(minutes) else {
            return nil
        }
        return minutes
    }
}
