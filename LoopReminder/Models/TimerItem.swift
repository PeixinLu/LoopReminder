import SwiftUI
import Foundation

// MARK: - Reminder Type

enum ReminderType: String, Codable, CaseIterable {
    case interval = "间隔提醒"
    case scheduled = "定点提醒"
}

enum ReminderEventStatus: String, Codable, CaseIterable {
    case fired
    case completed
    case ignored
    case missed
}

struct ReminderEvent: Identifiable, Codable {
    var id: UUID
    var timerID: UUID
    var scheduledAt: Date
    var firedAt: Date
    var resolvedAt: Date?
    var status: ReminderEventStatus

    init(
        id: UUID = UUID(),
        timerID: UUID,
        scheduledAt: Date,
        firedAt: Date = Date(),
        resolvedAt: Date? = nil,
        status: ReminderEventStatus = .fired
    ) {
        self.id = id
        self.timerID = timerID
        self.scheduledAt = scheduledAt
        self.firedAt = firedAt
        self.resolvedAt = resolvedAt
        self.status = status
    }
}

// MARK: - Scheduled Time

struct ScheduledTime: Identifiable, Codable {
    var id: UUID
    var hour: Int      // 0-23
    var minute: Int    // 0-59
    var enabled: Bool  // 是否启用该时间点

    init(id: UUID = UUID(), hour: Int = 9, minute: Int = 0, enabled: Bool = true) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.enabled = enabled
    }

    func formattedTime() -> String {
        return String(format: "%02d:%02d", hour, minute)
    }
}

// 计时器项目模型
struct TimerItem: Identifiable, Codable {
    enum StayDurationMode: String, Codable, CaseIterable {
        case untilNextNotification = "持续到下次通知"
        case fixed = "固定时长"
    }

    var id: UUID
    var emoji: String // 图标
    var title: String // 通知标题（也作为计时器名称）
    var body: String // 通知内容
    var intervalSeconds: Double // 通知间隔（秒）
    var isRestEnabled: Bool // 是否启用休息
    var restSeconds: Double // 休息时长（秒）
    var customColor: TimerColor? // 自定义颜色（优先于全局样式）
    var lastFireEpoch: Double // 上次触发时间
    var isRunning: Bool = false // 是否正在运行（不持久化）

    // 提醒类型
    var reminderType: ReminderType = .interval

    // 定点提醒时间列表
    var scheduledTimes: [ScheduledTime] = [ScheduledTime(hour: 9, minute: 0)]

    // 提示音（nil 表示静音）
    var soundName: String? = "Glass"

    // 通知停留时间
    var stayDurationMode: StayDurationMode = .untilNextNotification
    var stayDurationSeconds: Double = 5.0

    // 当前会话启动时间，仅用于界面统计展示，不持久化
    var startedAtEpoch: Double = 0

    // 计算属性：显示名称（使用标题，如果为空则用"计时器+数字"）
    var displayName: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "计时器" : trimmedTitle
    }
    
    /// 计时器颜色配置
    struct TimerColor: Codable, Equatable {
        var colorType: ColorType
        var customPresetID: String?
        var customR: Double?
        var customG: Double?
        var customB: Double?
        
        enum ColorType: String, Codable, CaseIterable {
            case white = "白色"
            case black = "黑色"
            case blue = "蓝色"
            case purple = "紫色"
            case green = "绿色"
            case orange = "橙色"
            case red = "红色"
            case teal = "青色"
            case slate = "石墨"
            case sky = "天蓝"
            case violet = "紫罗兰"
            case emerald = "翠绿"
            case amber = "琥珀"
            case rose = "玫瑰"
            case transparent = "透明"
            case custom = "自定义"
        }
        
        func toColor() -> Color {
            switch colorType {
            case .white: return .white
            case .black: return .black
            case .blue: return .blue
            case .purple: return .purple
            case .green: return .green
            case .orange: return .orange
            case .red: return .red
            case .teal: return .teal
            case .slate: return Color(red: 0.20, green: 0.25, blue: 0.33)
            case .sky: return Color(red: 0.05, green: 0.58, blue: 0.89)
            case .violet: return Color(red: 0.49, green: 0.23, blue: 0.93)
            case .emerald: return Color(red: 0.02, green: 0.59, blue: 0.41)
            case .amber: return Color(red: 0.96, green: 0.62, blue: 0.04)
            case .rose: return Color(red: 0.88, green: 0.11, blue: 0.28)
            case .transparent: return .clear
            case .custom:
                if let r = customR, let g = customG, let b = customB {
                    return Color(red: r, green: g, blue: b)
                }
                return .gray
            }
        }
        
        static func from(appSettingsColor: AppSettings.OverlayColor, customColor: Color? = nil) -> TimerColor {
            switch appSettingsColor {
            case .white:
                return TimerColor(colorType: .white)
            case .black:
                return TimerColor(colorType: .black)
            case .blue:
                return TimerColor(colorType: .blue)
            case .purple:
                return TimerColor(colorType: .purple)
            case .green:
                return TimerColor(colorType: .green)
            case .orange:
                return TimerColor(colorType: .orange)
            case .red:
                return TimerColor(colorType: .red)
            case .teal:
                return TimerColor(colorType: .teal)
            case .custom:
                if let color = customColor {
                    let components = color.components()
                    return TimerColor(
                        colorType: .custom,
                        customR: components.red,
                        customG: components.green,
                        customB: components.blue
                    )
                }
                return TimerColor(colorType: .custom, customR: 0.5, customG: 0.5, customB: 0.5)
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        emoji: String = "🔔",
        title: String = "提醒",
        body: String = "起来活动一下",
        intervalSeconds: Double = 1800,
        isRestEnabled: Bool = false,
        restSeconds: Double = 300,
        customColor: TimerColor? = nil,
        lastFireEpoch: Double = 0,
        reminderType: ReminderType = .interval,
        scheduledTimes: [ScheduledTime] = [ScheduledTime(hour: 9, minute: 0)],
        soundName: String? = "Glass",
        stayDurationMode: StayDurationMode = .untilNextNotification,
        stayDurationSeconds: Double = 5.0,
        startedAtEpoch: Double = 0
    ) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.body = body
        self.intervalSeconds = intervalSeconds
        self.isRestEnabled = isRestEnabled
        self.restSeconds = restSeconds
        self.customColor = customColor
        self.lastFireEpoch = lastFireEpoch
        self.reminderType = reminderType
        self.scheduledTimes = scheduledTimes
        self.soundName = soundName
        self.stayDurationMode = stayDurationMode
        self.stayDurationSeconds = stayDurationSeconds
        self.startedAtEpoch = startedAtEpoch
        self.isRunning = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        emoji = try container.decode(String.self, forKey: .emoji)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        intervalSeconds = try container.decode(Double.self, forKey: .intervalSeconds)
        isRestEnabled = try container.decode(Bool.self, forKey: .isRestEnabled)
        restSeconds = try container.decode(Double.self, forKey: .restSeconds)
        customColor = try container.decodeIfPresent(TimerColor.self, forKey: .customColor)
        lastFireEpoch = try container.decode(Double.self, forKey: .lastFireEpoch)
        reminderType = try container.decodeIfPresent(ReminderType.self, forKey: .reminderType) ?? .interval
        scheduledTimes = try container.decodeIfPresent([ScheduledTime].self, forKey: .scheduledTimes) ?? [ScheduledTime(hour: 9, minute: 0)]
        soundName = container.contains(.soundName) ? try container.decodeIfPresent(String.self, forKey: .soundName) : "Glass"
        stayDurationMode = try container.decodeIfPresent(StayDurationMode.self, forKey: .stayDurationMode) ?? .untilNextNotification
        stayDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .stayDurationSeconds) ?? 5.0
        isRunning = false
        startedAtEpoch = 0
    }
    
    var lastFireDate: Date? {
        guard lastFireEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: lastFireEpoch)
    }
    
    mutating func markFiredNow() {
        lastFireEpoch = Date().timeIntervalSince1970
    }
    
    func formattedInterval() -> String {
        let seconds = Int(intervalSeconds)
        if seconds < 60 {
            return "\(seconds) 秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            } else {
                return "\(minutes) 分 \(remainingSeconds) 秒"
            }
        } else {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes == 0 {
                return "\(hours) 小时"
            } else {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
        }
    }
    
    func formattedRestInterval() -> String {
        let seconds = Int(restSeconds)
        if seconds < 60 {
            return "\(seconds) 秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            } else {
                return "\(minutes) 分 \(remainingSeconds) 秒"
            }
        } else {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes == 0 {
                return "\(hours) 小时"
            } else {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
        }
    }
    
    /// 验证内容是否有效（至少有一项不为空）
    func isContentValid() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !trimmedTitle.isEmpty || !trimmedBody.isEmpty || !trimmedEmoji.isEmpty
    }
    
    // Codable: 不序列化 isRunning 字段
    enum CodingKeys: String, CodingKey {
        case id, emoji, title, body, intervalSeconds
        case isRestEnabled, restSeconds, customColor, lastFireEpoch
        case reminderType, scheduledTimes, soundName
        case stayDurationMode, stayDurationSeconds
    }
}
