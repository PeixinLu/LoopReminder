import Foundation

enum CronScheduleKind: String, CaseIterable, Identifiable {
    case hourly = "每小时"
    case daily = "每天"
    case weekdays = "工作日"
    case weekly = "每周"
    case monthly = "每月"
    case custom = "自定义"

    var id: String { rawValue }
}

struct CronScheduleRule {
    var kind: CronScheduleKind
    var minute: Int
    var hour: Int
    var weekdays: Set<Int>
    var monthDay: Int
    var customExpression: String

    init(expression: String) {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        kind = .custom
        minute = 0
        hour = 9
        weekdays = [1, 2, 3, 4, 5]
        monthDay = 1
        customExpression = trimmed

        let fields = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard fields.count == 5,
              fields[3] == "*",
              let parsedMinute = Int(fields[0]), (0...59).contains(parsedMinute) else {
            return
        }

        minute = parsedMinute

        if fields[1] == "*", fields[2] == "*", fields[4] == "*" {
            kind = .hourly
            return
        }

        guard let parsedHour = Int(fields[1]), (0...23).contains(parsedHour) else { return }
        hour = parsedHour

        if fields[2] == "*", fields[4] == "1-5" {
            kind = .weekdays
        } else if fields[2] == "*", fields[4] == "*" {
            kind = .daily
        } else if fields[2] == "*", let parsedWeekdays = Self.parseWeekdays(fields[4]) {
            weekdays = parsedWeekdays
            kind = .weekly
        } else if fields[4] == "*", let parsedDay = Int(fields[2]), (1...31).contains(parsedDay) {
            monthDay = parsedDay
            kind = .monthly
        }
    }

    /// 重新按表达式推断规则类型，但保留已有的自定义表达式草稿
    mutating func reinterpret(expression: String, preservingCustomDraft draft: String?) {
        let rebuilt = CronScheduleRule(expression: expression)
        self = rebuilt
        if let draft, rebuilt.kind != .custom {
            customExpression = draft
        }
    }

    var expression: String {
        switch kind {
        case .hourly:
            return "\(minute) * * * *"
        case .daily:
            return "\(minute) \(hour) * * *"
        case .weekdays:
            return "\(minute) \(hour) * * 1-5"
        case .weekly:
            let days = weekdays.sorted().map(String.init).joined(separator: ",")
            return "\(minute) \(hour) * * \(days)"
        case .monthly:
            return "\(minute) \(hour) \(monthDay) * *"
        case .custom:
            return customExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var summary: String {
        switch kind {
        case .hourly:
            return "每小时第 \(minute) 分钟"
        case .daily:
            return "每天 \(formattedTime)"
        case .weekdays:
            return "每个工作日 \(formattedTime)"
        case .weekly:
            let dayText = Self.orderedWeekdays
                .filter { weekdays.contains($0.value) }
                .map(\.label)
                .joined(separator: "、")
            return "每周\(dayText) \(formattedTime)"
        case .monthly:
            return "每月 \(monthDay) 日 \(formattedTime)"
        case .custom:
            return "自定义 Cron 规则"
        }
    }

    static let orderedWeekdays: [(value: Int, label: String)] = [
        (1, "一"), (2, "二"), (3, "三"), (4, "四"), (5, "五"), (6, "六"), (0, "日")
    ]

    private var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    private static func parseWeekdays(_ value: String) -> Set<Int>? {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        var result = Set<Int>()
        for part in parts {
            guard let day = Int(part), (0...7).contains(day) else { return nil }
            result.insert(day == 7 ? 0 : day)
        }
        return result.isEmpty ? nil : result
    }
}
