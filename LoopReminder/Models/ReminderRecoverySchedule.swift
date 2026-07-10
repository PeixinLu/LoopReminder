import Foundation

enum ReminderRecoverySchedule {
    static func nextScheduledDate(
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> Date {
        let day = calendar.startOfDay(for: now)
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? now
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? now
    }

    static func missedScheduledTimes(
        times: [ScheduledTime],
        from: Date,
        through: Date,
        calendar: Calendar = .current
    ) -> [ScheduledTime] {
        guard through > from else { return [] }

        var result: [ScheduledTime] = []
        var day = calendar.startOfDay(for: from)
        let endDay = calendar.startOfDay(for: through)

        while day <= endDay {
            for time in times {
                guard let candidate = calendar.date(
                    bySettingHour: time.hour,
                    minute: time.minute,
                    second: 0,
                    of: day
                ) else {
                    continue
                }

                if candidate >= from && candidate < through {
                    result.append(time)
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return result
    }

    static func nextIntervalDate(lastFireEpoch: Double, interval: TimeInterval, now: Date) -> Date {
        max(now, Date(timeIntervalSince1970: lastFireEpoch + interval))
    }

    static func shouldResetInterval(isEnabled: Bool, elapsed: TimeInterval) -> Bool {
        isEnabled && elapsed >= 300
    }
}
