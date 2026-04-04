import SwiftUI
import Combine
import Foundation
import LaunchAtLogin

// MARK: - Default Settings Config
struct DefaultSettingsConfig: Codable {
    struct Notification: Codable {
        let title: String
        let body: String
        let emoji: String
    }

    struct Interval: Codable {
        let `default`: Double
        let min: Double
        let max: Double
    }

    struct Rest: Codable {
        let enabled: Bool
        let `default`: Double
    }

    struct Overlay: Codable {
        struct CustomColor: Codable {
            let r: Double
            let g: Double
            let b: Double
        }

        let position: String
        let color: String
        let opacity: Double
        let stayDuration: Double
        let enableFadeOut: Bool
        let fadeOutDelay: Double
        let fadeOutDuration: Double
        let width: Double
        let height: Double
        let minWidth: Double
        let minHeight: Double
        let maxWidth: Double
        let maxHeight: Double
        let titleFontSize: Double
        let bodyFontSize: Double
        let iconSize: Double
        let cornerRadius: Double
        let edgePadding: Double
        let contentSpacing: Double
        let useBlur: Bool
        let blurIntensity: Double
        let customColor: CustomColor
        let material: String
        let liquidGlassStyle: String
    }

    struct Animation: Codable {
        let style: String
    }

    struct Screen: Codable {
        let selection: String
    }

    struct System: Codable {
        let resetOnWake: Bool
    }

    let notification: Notification
    let interval: Interval
    let rest: Rest
    let notificationMode: String
    let overlay: Overlay
    let animation: Animation
    let screen: Screen
    let system: System
}

@MainActor
final class AppSettings: ObservableObject {
    // 默认配置
    static var defaultConfig: DefaultSettingsConfig = {
        guard let url = Bundle.main.url(forResource: "DefaultSettings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(DefaultSettingsConfig.self, from: data) else {
            fatalError("无法加载默认配置文件 DefaultSettings.json")
        }
        return config
    }()

    private enum Keys {
        static let isRunning = "isRunning"
        static let intervalSeconds = "intervalSeconds"
        static let notifTitle = "notifTitle"
        static let notifBody = "notifBody"
        static let notifEmoji = "notifEmoji"
        static let lastFire = "lastFire"
        static let notificationMode = "notificationMode"
        static let overlayPosition = "overlayPosition"
        static let overlayColor = "overlayColor"
        static let overlayOpacity = "overlayOpacity"
        static let overlayFadeDelay = "overlayFadeDelay"
        static let overlayStayDuration = "overlayStayDuration"
        static let overlayEnableFadeOut = "overlayEnableFadeOut"
        static let overlayFadeOutDelay = "overlayFadeOutDelay"
        static let overlayFadeOutDuration = "overlayFadeOutDuration"
        static let animationStyle = "animationStyle"
        static let overlayTitleFontSize = "overlayTitleFontSize"
        static let overlayIconSize = "overlayIconSize"
        static let overlayCornerRadius = "overlayCornerRadius"
        static let overlayEdgePadding = "overlayEdgePadding"
        static let overlayContentSpacing = "overlayContentSpacing"
        static let overlayUseBlur = "overlayUseBlur"
        static let overlayBlurIntensity = "overlayBlurIntensity"
        static let overlayWidth = "overlayWidth"
        static let overlayHeight = "overlayHeight"
        static let overlayCustomColorR = "overlayCustomColorR"
        static let overlayCustomColorG = "overlayCustomColorG"
        static let overlayCustomColorB = "overlayCustomColorB"
        static let overlayBodyFontSize = "overlayBodyFontSize"
        static let screenSelection = "screenSelection"
        static let silentLaunch = "silentLaunch"
        static let resetOnWake = "resetOnWake"
        static let autoStartTimersOnLaunch = "autoStartTimersOnLaunch"
        static let showStartNotification = "showStartNotification"
        static let isRestEnabled = "isRestEnabled"
        static let restSeconds = "restSeconds"
        // 多计时器
        static let timers = "timers"
        static let focusedTimerID = "focusedTimerID"
        // 材质选项
        static let overlayMaterial = "overlayMaterial"
        static let liquidGlassStyle = "liquidGlassStyle"
    }

    private let defaults = UserDefaults.standard
    private var cancellables: Set<AnyCancellable> = []

    // Observable values - 基本设置
    @Published var isRunning: Bool
    @Published var intervalSeconds: Double
    @Published var notificationMode: NotificationMode
    @Published var notifTitle: String
    @Published var notifBody: String
    @Published var notifEmoji: String
    @Published var lastFireEpoch: Double

    // Observable values - 休息一下
    @Published var isRestEnabled: Bool
    @Published var restSeconds: Double

    // Observable values - 通知样式
    @Published var overlayPosition: OverlayPosition
    @Published var overlayColor: OverlayColor
    @Published var overlayOpacity: Double
    @Published var overlayStayDuration: Double
    @Published var overlayEnableFadeOut: Bool
    @Published var overlayFadeOutDelay: Double
    @Published var overlayFadeOutDuration: Double
    @Published var animationStyle: AnimationStyle

    // 新增样式配置
    @Published var overlayTitleFontSize: Double
    @Published var overlayIconSize: Double
    @Published var overlayCornerRadius: Double
    @Published var overlayEdgePadding: Double
    @Published var overlayContentSpacing: Double
    @Published var overlayUseBlur: Bool
    @Published var overlayBlurIntensity: Double
    @Published var overlayWidth: Double
    @Published var overlayHeight: Double
    @Published var overlayCustomColor: Color
    @Published var overlayBodyFontSize: Double
    @Published var screenSelection: ScreenSelection

    // 静默启动设置
    @Published var silentLaunch: Bool
    @Published var resetOnWakeEnabled: Bool
    @Published var autoStartTimersOnLaunch: Bool
    @Published var showStartNotification: Bool

    // 多计时器支持
    @Published var timers: [TimerItem]
    @Published var focusedTimerID: UUID?

    // 材质选项
    @Published var overlayMaterial: OverlayMaterial
    @Published var liquidGlassStyle: LiquidGlassStyle

    // MARK: - Enums

    enum NotificationMode: String, CaseIterable {
        case overlay = "屏幕遮罩"
        case system = "系统通知"
    }

    enum OverlayMaterial: String, CaseIterable {
        case basic = "基本"
        case liquidGlass = "液态玻璃"
    }

    enum LiquidGlassStyle: String, CaseIterable {
        case clear = "清晰"
        case regular = "常规"
    }

    enum OverlayPosition: String, CaseIterable {
        case topLeft = "左上角"
        case topRight = "右上角"
        case bottomLeft = "左下角"
        case bottomRight = "右下角"
        case topCenter = "顶部居中"
        case center = "屏幕正中"
        case bottomCenter = "底部居中"
    }

    enum OverlayColor: String, CaseIterable {
        case black = "黑色"
        case blue = "蓝色"
        case purple = "紫色"
        case green = "绿色"
        case orange = "橙色"
        case red = "红色"
        case teal = "青色"
        case custom = "自定义"
    }

    enum AnimationStyle: String, CaseIterable {
        case fade = "淡化"
        case slide = "平移"
        case scale = "缩放"
    }

    enum ScreenSelection: String, CaseIterable {
        case active = "活跃屏幕"
        case mouse = "鼠标所在屏幕"

        var description: String {
            switch self {
            case .active:
                return "通知显示在当前获得焦点的屏幕"
            case .mouse:
                return "通知显示在鼠标光标所在的屏幕"
            }
        }
    }

    init() {
        let config = Self.defaultConfig

        // Load - 基本设置
        self.isRunning = defaults.object(forKey: Keys.isRunning) as? Bool ?? false
        self.intervalSeconds = defaults.object(forKey: Keys.intervalSeconds) as? Double ?? config.interval.default
        self.notifTitle = defaults.string(forKey: Keys.notifTitle) ?? config.notification.title
        self.notifBody = defaults.string(forKey: Keys.notifBody) ?? config.notification.body
        self.notifEmoji = defaults.string(forKey: Keys.notifEmoji) ?? config.notification.emoji
        self.lastFireEpoch = defaults.object(forKey: Keys.lastFire) as? Double ?? 0

        let modeRawValue = defaults.string(forKey: Keys.notificationMode) ?? config.notificationMode
        self.notificationMode = NotificationMode(rawValue: modeRawValue) ?? .overlay

        // Load - 休息一下
        self.isRestEnabled = defaults.object(forKey: Keys.isRestEnabled) as? Bool ?? config.rest.enabled
        self.restSeconds = defaults.object(forKey: Keys.restSeconds) as? Double ?? config.rest.default

        // Load - 通知样式
        let positionRawValue = defaults.string(forKey: Keys.overlayPosition) ?? config.overlay.position
        self.overlayPosition = OverlayPosition(rawValue: positionRawValue) ?? .topRight

        let colorRawValue = defaults.string(forKey: Keys.overlayColor) ?? config.overlay.color
        self.overlayColor = OverlayColor(rawValue: colorRawValue) ?? .black

        self.overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? config.overlay.opacity
        self.overlayStayDuration = defaults.object(forKey: Keys.overlayStayDuration) as? Double ?? config.overlay.stayDuration
        self.overlayEnableFadeOut = defaults.object(forKey: Keys.overlayEnableFadeOut) as? Bool ?? config.overlay.enableFadeOut
        self.overlayFadeOutDelay = defaults.object(forKey: Keys.overlayFadeOutDelay) as? Double ?? config.overlay.fadeOutDelay
        self.overlayFadeOutDuration = defaults.object(forKey: Keys.overlayFadeOutDuration) as? Double ?? config.overlay.fadeOutDuration

        let animationRawValue = defaults.string(forKey: Keys.animationStyle) ?? config.animation.style
        self.animationStyle = AnimationStyle(rawValue: animationRawValue) ?? .fade

        // Load - 新增样式配置
        self.overlayTitleFontSize = defaults.object(forKey: Keys.overlayTitleFontSize) as? Double ?? config.overlay.titleFontSize
        self.overlayIconSize = defaults.object(forKey: Keys.overlayIconSize) as? Double ?? config.overlay.iconSize
        self.overlayCornerRadius = defaults.object(forKey: Keys.overlayCornerRadius) as? Double ?? config.overlay.cornerRadius
        self.overlayEdgePadding = defaults.object(forKey: Keys.overlayEdgePadding) as? Double ?? config.overlay.edgePadding
        self.overlayContentSpacing = defaults.object(forKey: Keys.overlayContentSpacing) as? Double ?? config.overlay.contentSpacing
        self.overlayUseBlur = defaults.object(forKey: Keys.overlayUseBlur) as? Bool ?? config.overlay.useBlur
        self.overlayBlurIntensity = defaults.object(forKey: Keys.overlayBlurIntensity) as? Double ?? config.overlay.blurIntensity
        self.overlayWidth = defaults.object(forKey: Keys.overlayWidth) as? Double ?? config.overlay.width
        self.overlayHeight = defaults.object(forKey: Keys.overlayHeight) as? Double ?? config.overlay.height
        self.overlayBodyFontSize = defaults.object(forKey: Keys.overlayBodyFontSize) as? Double ?? config.overlay.bodyFontSize

        let r = defaults.object(forKey: Keys.overlayCustomColorR) as? Double ?? config.overlay.customColor.r
        let g = defaults.object(forKey: Keys.overlayCustomColorG) as? Double ?? config.overlay.customColor.g
        let b = defaults.object(forKey: Keys.overlayCustomColorB) as? Double ?? config.overlay.customColor.b
        self.overlayCustomColor = Color(red: r, green: g, blue: b)

        let screenSelectionRawValue = defaults.string(forKey: Keys.screenSelection) ?? config.screen.selection
        self.screenSelection = ScreenSelection(rawValue: screenSelectionRawValue) ?? .active

        // Load - 静默启动设置
        self.silentLaunch = defaults.object(forKey: Keys.silentLaunch) as? Bool ?? false
        self.resetOnWakeEnabled = defaults.object(forKey: Keys.resetOnWake) as? Bool ?? config.system.resetOnWake
        self.autoStartTimersOnLaunch = defaults.object(forKey: Keys.autoStartTimersOnLaunch) as? Bool ?? false
        self.showStartNotification = defaults.object(forKey: Keys.showStartNotification) as? Bool ?? true

        // Load - 多计时器
        if let timersData = defaults.data(forKey: Keys.timers),
           let decodedTimers = try? JSONDecoder().decode([TimerItem].self, from: timersData),
           !decodedTimers.isEmpty {
            self.timers = decodedTimers
        } else {
            let defaultTimer = TimerItem(
                emoji: defaults.string(forKey: Keys.notifEmoji) ?? config.notification.emoji,
                title: defaults.string(forKey: Keys.notifTitle) ?? config.notification.title,
                body: defaults.string(forKey: Keys.notifBody) ?? config.notification.body,
                intervalSeconds: defaults.object(forKey: Keys.intervalSeconds) as? Double ?? config.interval.default,
                isRestEnabled: defaults.object(forKey: Keys.isRestEnabled) as? Bool ?? config.rest.enabled,
                restSeconds: defaults.object(forKey: Keys.restSeconds) as? Double ?? config.rest.default,
                customColor: nil,
                lastFireEpoch: defaults.object(forKey: Keys.lastFire) as? Double ?? 0
            )
            self.timers = [defaultTimer]
        }

        // Load - 材质选项
        let materialRawValue = defaults.string(forKey: Keys.overlayMaterial) ?? config.overlay.material
        self.overlayMaterial = OverlayMaterial(rawValue: materialRawValue) ?? .basic

        let liquidGlassStyleRawValue = defaults.string(forKey: Keys.liquidGlassStyle) ?? config.overlay.liquidGlassStyle
        self.liquidGlassStyle = LiquidGlassStyle(rawValue: liquidGlassStyleRawValue) ?? .regular

        // Load - focusedTimerID
        if let focusedIDString = defaults.string(forKey: Keys.focusedTimerID) {
            self.focusedTimerID = UUID(uuidString: focusedIDString)
        } else {
            self.focusedTimerID = timers.first?.id
        }

        // Persist changes - 基本设置
        $isRunning.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.isRunning) }.store(in: &cancellables)
        $intervalSeconds.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.intervalSeconds) }.store(in: &cancellables)
        $notifTitle.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifTitle) }.store(in: &cancellables)
        $notifBody.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifBody) }.store(in: &cancellables)
        $notifEmoji.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.notifEmoji) }.store(in: &cancellables)
        $lastFireEpoch.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.lastFire) }.store(in: &cancellables)
        $notificationMode.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.notificationMode) }.store(in: &cancellables)

        // Persist changes - 休息一下
        $isRestEnabled.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.isRestEnabled) }.store(in: &cancellables)
        $restSeconds.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.restSeconds) }.store(in: &cancellables)

        // Persist changes - 通知样式
        $overlayPosition.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayPosition) }.store(in: &cancellables)
        $overlayColor.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayColor) }.store(in: &cancellables)
        $overlayOpacity.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayOpacity) }.store(in: &cancellables)
        $overlayStayDuration.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayStayDuration) }.store(in: &cancellables)
        $overlayEnableFadeOut.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayEnableFadeOut) }.store(in: &cancellables)
        $overlayFadeOutDelay.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayFadeOutDelay) }.store(in: &cancellables)
        $overlayFadeOutDuration.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayFadeOutDuration) }.store(in: &cancellables)
        $animationStyle.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.animationStyle) }.store(in: &cancellables)

        // Persist changes - 新增样式配置
        $overlayTitleFontSize.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayTitleFontSize) }.store(in: &cancellables)
        $overlayIconSize.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayIconSize) }.store(in: &cancellables)
        $overlayCornerRadius.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayCornerRadius) }.store(in: &cancellables)
        $overlayEdgePadding.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayEdgePadding) }.store(in: &cancellables)
        $overlayContentSpacing.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayContentSpacing) }.store(in: &cancellables)
        $overlayUseBlur.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayUseBlur) }.store(in: &cancellables)
        $overlayBlurIntensity.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayBlurIntensity) }.store(in: &cancellables)
        $overlayWidth.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayWidth) }.store(in: &cancellables)
        $overlayHeight.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayHeight) }.store(in: &cancellables)
        $overlayBodyFontSize.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayBodyFontSize) }.store(in: &cancellables)
        $overlayCustomColor.dropFirst().sink { [weak self] color in
            guard let self else { return }
            let components = color.components()
            self.defaults.set(components.red, forKey: Keys.overlayCustomColorR)
            self.defaults.set(components.green, forKey: Keys.overlayCustomColorG)
            self.defaults.set(components.blue, forKey: Keys.overlayCustomColorB)
        }.store(in: &cancellables)
        $screenSelection.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.screenSelection) }.store(in: &cancellables)

        // Persist changes - 静默启动设置
        $silentLaunch.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.silentLaunch) }.store(in: &cancellables)
        $resetOnWakeEnabled.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.resetOnWake) }.store(in: &cancellables)
        $autoStartTimersOnLaunch.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.autoStartTimersOnLaunch) }.store(in: &cancellables)
        $showStartNotification.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.showStartNotification) }.store(in: &cancellables)

        // Persist changes - 多计时器
        $timers.dropFirst().sink { [weak self] timers in
            if let encoded = try? JSONEncoder().encode(timers) {
                self?.defaults.set(encoded, forKey: Keys.timers)
            }
        }.store(in: &cancellables)

        $focusedTimerID.dropFirst().sink { [weak self] id in
            self?.defaults.set(id?.uuidString, forKey: Keys.focusedTimerID)
        }.store(in: &cancellables)

        // Persist changes - 定点提醒
        // Persist changes - 材质选项
        $overlayMaterial.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayMaterial) }.store(in: &cancellables)
        $liquidGlassStyle.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.liquidGlassStyle) }.store(in: &cancellables)

        // Guardrails
        if intervalSeconds < config.interval.min { intervalSeconds = config.interval.min }
        if intervalSeconds > config.interval.max { intervalSeconds = config.interval.max }
        if restSeconds < config.interval.min { restSeconds = config.interval.min }
        if restSeconds > config.interval.max { restSeconds = config.interval.max }
        if overlayOpacity < 0.3 { overlayOpacity = 0.3 }
        if overlayOpacity > 1.0 { overlayOpacity = 1.0 }

        validateTimingSettings()
    }

    func validateTimingSettings() {
        let transitionTime: Double = 1.0
        let maxStayDuration = intervalSeconds - transitionTime
        if overlayStayDuration > maxStayDuration {
            overlayStayDuration = max(1.0, maxStayDuration)
        }
        if overlayStayDuration < 1.0 { overlayStayDuration = 1.0 }

        let maxFadeOutDelay = overlayStayDuration - overlayFadeOutDuration
        if overlayFadeOutDelay > maxFadeOutDelay {
            overlayFadeOutDelay = max(0, maxFadeOutDelay)
        }
        if overlayFadeOutDelay < 0 { overlayFadeOutDelay = 0 }

        let maxFadeOutDuration = overlayStayDuration - overlayFadeOutDelay
        if overlayFadeOutDuration > maxFadeOutDuration {
            overlayFadeOutDuration = max(0.5, maxFadeOutDuration)
        }
        if overlayFadeOutDuration < 0.5 { overlayFadeOutDuration = 0.5 }
    }

    var lastFireDate: Date? {
        guard lastFireEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: lastFireEpoch)
    }

    func markFiredNow() {
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

    func getEffectiveFadeOutDuration() -> Double {
        guard overlayEnableFadeOut else { return 0 }
        return overlayFadeOutDuration
    }

    func getTotalDisplayDuration() -> Double {
        return overlayStayDuration
    }

    func getOverlayColor() -> Color {
        switch overlayColor {
        case .black: return .black
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        case .custom: return overlayCustomColor
        }
    }

    func isContentValid() -> Bool {
        let trimmedTitle = notifTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = notifBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = notifEmoji.trimmingCharacters(in: .whitespacesAndNewlines)

        return !trimmedTitle.isEmpty || !trimmedBody.isEmpty || !trimmedEmoji.isEmpty
    }
}