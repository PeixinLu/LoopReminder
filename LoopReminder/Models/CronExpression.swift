import Foundation

/// A standard five-field cron expression: minute, hour, day of month, month, weekday.
struct CronExpression {
    enum ParseError: LocalizedError, Equatable {
        case fieldCount
        case emptyValue(field: String)
        case invalidValue(String, field: String)
        case outOfRange(Int, field: String, range: ClosedRange<Int>)
        case invalidRange(String, field: String)
        case invalidStep(String, field: String)

        var errorDescription: String? {
            switch self {
            case .fieldCount:
                return "Cron 表达式需要 5 个字段：分 时 日 月 周"
            case .emptyValue(let field):
                return "\(field)字段不能为空"
            case .invalidValue(let value, let field):
                return "\(field)字段包含无效值“\(value)”"
            case .outOfRange(let value, let field, let range):
                return "\(field)字段的 \(value) 超出范围 \(range.lowerBound)-\(range.upperBound)"
            case .invalidRange(let value, let field):
                return "\(field)字段包含无效范围“\(value)”"
            case .invalidStep(let value, let field):
                return "\(field)字段包含无效步长“\(value)”"
            }
        }
    }

    private struct Field {
        let values: Set<Int>
        /// True when the field begins with `*`, matching how Vixie cron flags an unrestricted field.
        let isStarPrefixed: Bool
    }

    private let minutes: Field
    private let hours: Field
    private let daysOfMonth: Field
    private let months: Field
    private let weekdays: Field

    init(_ expression: String) throws {
        let fields = expression.split(whereSeparator: \.isWhitespace).map(String.init)
        guard fields.count == 5 else { throw ParseError.fieldCount }

        minutes = try Self.parseField(fields[0], name: "分钟", range: 0...59)
        hours = try Self.parseField(fields[1], name: "小时", range: 0...23)
        daysOfMonth = try Self.parseField(fields[2], name: "日期", range: 1...31)
        months = try Self.parseField(fields[3], name: "月份", range: 1...12)
        weekdays = try Self.parseField(fields[4], name: "星期", range: 0...7, normalizeSunday: true)
    }

    /// Finds the next matching local date strictly after `date`.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        var calendar = calendar
        if calendar.timeZone.identifier.isEmpty {
            calendar.timeZone = .current
        }

        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let currentMinute = calendar.date(from: startComponents),
              let start = calendar.date(byAdding: .minute, value: 1, to: currentMinute) else {
            return nil
        }

        let startDay = calendar.startOfDay(for: start)
        let sortedHours = hours.values.sorted()
        let sortedMinutes = minutes.values.sorted()

        // Eight years covers the longest possible gap in a five-field expression (Feb 29).
        for dayOffset in 0..<(366 * 8) {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDay),
                  matchesDay(day, calendar: calendar) else {
                continue
            }

            let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
            for hour in sortedHours {
                for minute in sortedMinutes {
                    var candidateComponents = dayComponents
                    candidateComponents.hour = hour
                    candidateComponents.minute = minute
                    candidateComponents.second = 0

                    guard let candidate = calendar.date(from: candidateComponents), candidate >= start else {
                        continue
                    }

                    // Reject nonexistent local times that Calendar normalizes across a DST gap.
                    let resolved = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate)
                    guard resolved.year == candidateComponents.year,
                          resolved.month == candidateComponents.month,
                          resolved.day == candidateComponents.day,
                          resolved.hour == hour,
                          resolved.minute == minute else {
                        continue
                    }

                    return candidate
                }
            }
        }

        return nil
    }

    private func matchesDay(_ date: Date, calendar: Calendar) -> Bool {
        let month = calendar.component(.month, from: date)
        guard months.values.contains(month) else { return false }

        let dayOfMonthMatches = daysOfMonth.values.contains(calendar.component(.day, from: date))
        let cronWeekday = calendar.component(.weekday, from: date) - 1
        let weekdayMatches = weekdays.values.contains(cronWeekday)

        // A field counts as unrestricted when it starts with `*`, so `*/2` behaves like crontab's.
        if daysOfMonth.isStarPrefixed && weekdays.isStarPrefixed {
            return dayOfMonthMatches && weekdayMatches
        }
        if daysOfMonth.isStarPrefixed {
            return weekdayMatches
        }
        if weekdays.isStarPrefixed {
            return dayOfMonthMatches
        }

        // Traditional crontab semantics: restricted day-of-month and weekday fields are ORed.
        return dayOfMonthMatches || weekdayMatches
    }

    private static func parseField(
        _ source: String,
        name: String,
        range: ClosedRange<Int>,
        normalizeSunday: Bool = false
    ) throws -> Field {
        guard !source.isEmpty else { throw ParseError.emptyValue(field: name) }

        var values = Set<Int>()
        for item in source.split(separator: ",", omittingEmptySubsequences: false) {
            guard !item.isEmpty else { throw ParseError.emptyValue(field: name) }
            let parts = item.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count <= 2 else {
                throw ParseError.invalidStep(String(item), field: name)
            }

            let base = String(parts[0])
            let step: Int
            if parts.count == 2 {
                guard let parsedStep = Int(parts[1]), parsedStep > 0 else {
                    throw ParseError.invalidStep(String(item), field: name)
                }
                step = parsedStep
            } else {
                step = 1
            }

            let itemRange: ClosedRange<Int>
            if base == "*" {
                itemRange = range
            } else if base.contains("-") {
                let bounds = base.split(separator: "-", omittingEmptySubsequences: false)
                guard bounds.count == 2,
                      let lower = Int(bounds[0]),
                      let upper = Int(bounds[1]),
                      lower <= upper else {
                    throw ParseError.invalidRange(base, field: name)
                }
                try validate(lower, field: name, range: range)
                try validate(upper, field: name, range: range)
                itemRange = lower...upper
            } else {
                guard let value = Int(base) else {
                    throw ParseError.invalidValue(base, field: name)
                }
                try validate(value, field: name, range: range)
                itemRange = parts.count == 2 ? value...range.upperBound : value...value
            }

            for value in stride(from: itemRange.lowerBound, through: itemRange.upperBound, by: step) {
                values.insert(normalizeSunday && value == 7 ? 0 : value)
            }
        }

        return Field(values: values, isStarPrefixed: source.hasPrefix("*"))
    }

    private static func validate(_ value: Int, field: String, range: ClosedRange<Int>) throws {
        guard range.contains(value) else {
            throw ParseError.outOfRange(value, field: field, range: range)
        }
    }
}

// MARK: - UI Lookup Cache

/// Caches parse and next-fire results so per-second UI refreshes never re-scan the search window.
@MainActor
enum CronScheduleLookup {
    enum Outcome: Equatable {
        case next(Date)
        case invalid(String)
        case unsatisfiable
    }

    private struct CacheEntry {
        let outcome: Outcome
        let computedAt: Date
    }

    private static var cache: [String: CacheEntry] = [:]

    static func outcome(for source: String, now: Date = Date()) -> Outcome {
        let key = source.trimmingCharacters(in: .whitespacesAndNewlines)

        if let entry = cache[key] {
            switch entry.outcome {
            case .next(let date) where date > now:
                return entry.outcome
            case .invalid, .unsatisfiable:
                // Parse failures depend only on the text, so they stay valid until the text changes.
                return entry.outcome
            case .next:
                break // Fire date has passed; recompute below.
            }
        }

        let outcome: Outcome
        do {
            let expression = try CronExpression(key)
            if let next = expression.nextDate(after: now) {
                outcome = .next(next)
            } else {
                outcome = .unsatisfiable
            }
        } catch {
            outcome = .invalid(error.localizedDescription)
        }

        if cache.count > 64 {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = CacheEntry(outcome: outcome, computedAt: now)
        return outcome
    }

    /// Returns up to `count` upcoming fire dates, or an empty array when the expression never matches.
    static func upcomingDates(for source: String, count: Int, now: Date = Date()) -> [Date] {
        guard let expression = try? CronExpression(source) else { return [] }
        var result: [Date] = []
        var cursor = now
        for _ in 0..<count {
            guard let next = expression.nextDate(after: cursor) else { break }
            result.append(next)
            cursor = next
        }
        return result
    }
}
