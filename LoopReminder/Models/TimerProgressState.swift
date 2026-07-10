import Foundation

struct TimerProgressState {
    let isResting: Bool
    let progress: Double
    let remainingSeconds: Int

    static func make(
        lastFireEpoch: Double,
        intervalSeconds: Double,
        restSeconds: Double,
        restEndsAt: Date?,
        now: Date = Date()
    ) -> TimerProgressState {
        if let restEndsAt, restEndsAt > now {
            let remaining = restEndsAt.timeIntervalSince(now)
            return TimerProgressState(
                isResting: true,
                progress: max(0, min(1, remaining / max(restSeconds, 1))),
                remainingSeconds: max(0, Int(remaining.rounded(.up)))
            )
        }

        let elapsed = now.timeIntervalSince1970 - lastFireEpoch
        let remaining = max(0, intervalSeconds - elapsed)
        return TimerProgressState(
            isResting: false,
            progress: max(0, min(1, elapsed / max(intervalSeconds, 1))),
            remainingSeconds: Int(remaining.rounded(.up))
        )
    }
}
