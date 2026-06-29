import Foundation

struct ReminderChartAxisRange {
    let start: Date
    let end: Date

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    static func automatic(
        eventDates: [Date],
        runningStart: Date?,
        now: Date = Date(),
        calendar: Calendar = .current,
        padding: TimeInterval = 600,
        maxDuration: TimeInterval = 86_400
    ) -> ReminderChartAxisRange {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(maxDuration)

        var dates = eventDates
        if let runningStart {
            dates.append(max(runningStart, dayStart))
            dates.append(min(now, dayEnd))
        }

        guard let earliest = dates.min(), let latest = dates.max() else {
            return ReminderChartAxisRange(start: dayStart, end: dayEnd)
        }

        var start = max(dayStart, earliest.addingTimeInterval(-padding))
        var end = min(dayEnd, latest.addingTimeInterval(padding))

        if end <= start {
            end = min(dayEnd, start.addingTimeInterval(padding * 2))
            start = max(dayStart, end.addingTimeInterval(-padding * 2))
        }

        if end.timeIntervalSince(start) > maxDuration {
            end = start.addingTimeInterval(maxDuration)
        }

        return ReminderChartAxisRange(start: start, end: end)
    }

    func xPosition(for date: Date, width: Double) -> Double {
        guard duration > 0 else { return 0 }
        let ratio = date.timeIntervalSince(start) / duration
        return width * min(max(ratio, 0), 1)
    }

    func date(atX x: Double, width: Double) -> Date {
        let clampedWidth = max(width, 1)
        let ratio = min(max(x / clampedWidth, 0), 1)
        return start.addingTimeInterval(duration * ratio)
    }

    func labelDates(count: Int = 5) -> [Date] {
        guard count > 1 else { return [start] }
        let step = duration / Double(count - 1)
        return (0..<count).map { start.addingTimeInterval(Double($0) * step) }
    }
}
