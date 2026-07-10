import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { print("FAIL: \(message)"); exit(1) }
}

@main
struct TimerProgressStateTestRunner {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000)
        let resting = TimerProgressState.make(
            lastFireEpoch: 900,
            intervalSeconds: 600,
            restSeconds: 120,
            restEndsAt: Date(timeIntervalSince1970: 1_060),
            now: now
        )
        expect(resting.isResting, "future rest deadline should be resting")
        expect(resting.progress == 0.5, "rest progress should count down from the right")
        expect(resting.remainingSeconds == 60, "rest remaining seconds should be exposed")

        let interval = TimerProgressState.make(
            lastFireEpoch: 900,
            intervalSeconds: 600,
            restSeconds: 120,
            restEndsAt: Date(timeIntervalSince1970: 990),
            now: now
        )
        expect(!interval.isResting, "expired rest deadline should return to interval")
        expect(interval.progress == 1.0 / 6.0, "interval progress should remain elapsed fraction")
        print("PASS")
    }
}
