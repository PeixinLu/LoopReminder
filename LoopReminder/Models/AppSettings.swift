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
        static let showStartNotification = "showStartNotification"
        static let isRestEnabled = "isRestEnabled"
        static let restSeconds = "restSeconds"
        // 多计时器
        static let timers = "timers"
        static let focusedTimerID = "focusedTimerID"
        static let reminderEvents = "reminderEvents"
        static let timerCustomColorPresets = "timerCustomColorPresets"
        static let recentEmojis = "recentEmojis"
        // 材质选项
        static let overlayMaterial = "overlayMaterial"
        static let liquidGlassStyle = "liquidGlassStyle"
        static let overlayGlassTintModeExperiment = "overlayGlassTintModeExperiment"
        static let overlayGlassTintColorR = "overlayGlassTintColorR"
        static let overlayGlassTintColorG = "overlayGlassTintColorG"
        static let overlayGlassTintColorB = "overlayGlassTintColorB"
        static let overlayGlassTintAlpha = "overlayGlassTintAlpha"
        static let overlayGlassTextColorMode = "overlayGlassTextColorMode"
        static let liquidGlassPreset = "liquidGlassPreset"
        static let liquidGlassPresetColorSource = "liquidGlassPresetColorSource"
        #if DEBUG
        static let overlayWindowHostExperiment = "overlayWindowHostExperiment"
        #endif
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
    @Published var showStartNotification: Bool

    // 多计时器支持
    @Published var timers: [TimerItem]
    @Published var focusedTimerID: UUID?
    @Published var reminderEvents: [ReminderEvent]
    @Published var timerCustomColorPresets: [TimerCustomColorPreset]
    @Published var recentEmojis: [String]

    // 编辑状态（跨窗口共享，非持久化）
    @Published var editingTimerID: UUID?

    // 材质选项
    @Published var overlayMaterial: OverlayMaterial
    @Published var liquidGlassStyle: LiquidGlassStyle
    @Published var overlayGlassTintModeExperiment: OverlayGlassTintExperiment
    @Published var overlayGlassTintColor: Color
    @Published var overlayGlassTintAlpha: Double
    @Published var overlayGlassTextColorMode: OverlayGlassTextColorMode
    @Published var liquidGlassPreset: LiquidGlassPresetID
    @Published var liquidGlassPresetColorSource: LiquidGlassPresetColorSource
    #if DEBUG
    @Published var overlayWindowHostExperiment: OverlayWindowHostExperiment
    #endif

    // MARK: - Enums

    enum NotificationMode: String, CaseIterable {
        case overlay = "屏幕遮罩"
        case system = "系统通知"
    }

    enum OverlayMaterial: String, CaseIterable {
        case basic = "基本"
        case liquidGlass = "液态玻璃"
    }

    enum OverlayGlassTintExperiment: String, CaseIterable {
        case focusLiteDefault
        case off
        case systemDefault
        case overlayColor
        case custom

        var displayName: String {
            switch self {
            case .focusLiteDefault:
                return "FocusLite默认"
            case .off:
                return "关闭"
            case .systemDefault:
                return "系统黑白"
            case .overlayColor:
                return "通知颜色"
            case .custom:
                return "自定义"
            }
        }

        var detail: String {
            switch self {
            case .focusLiteDefault:
                return "常规=nil，通透/私有样式使用随外观切换的黑白 tint，alpha 固定 61.8%。"
            case .off:
                return "tintColor=nil，用于观察 NSGlassEffectView 原始材质表现。"
            case .systemDefault:
                return "使用随深浅色切换的黑/白 tint，可独立调整 alpha。"
            case .overlayColor:
                return "使用当前通知背景色作为 tint，可独立调整 alpha。"
            case .custom:
                return "使用下方自定义颜色作为 tint，可独立调整 alpha。"
            }
        }
    }

    enum OverlayGlassTextColorMode: String, CaseIterable {
        case automatic
        case black
        case white

        var displayName: String {
            switch self {
            case .automatic:
                return "自动"
            case .black:
                return "黑"
            case .white:
                return "白"
            }
        }
    }

    enum LiquidGlassPresetColorSource: String, CaseIterable {
        case presetDefault
        case customNotificationColor

        var displayName: String {
            switch self {
            case .presetDefault:
                return "预设默认"
            case .customNotificationColor:
                return "自定义通知颜色"
            }
        }
    }

    struct LiquidGlassPresetRGB {
        let red: Double
        let green: Double
        let blue: Double

        var color: Color {
            Color(red: red, green: green, blue: blue)
        }
    }

    struct LiquidGlassPresetMode {
        let liquidGlassStyle: LiquidGlassStyle
        let textColorMode: OverlayGlassTextColorMode
        let tintAlpha: Double
        let tintBrightness: Double
        let tintRGB: LiquidGlassPresetRGB
    }

    struct LiquidGlassPresetDefinition {
        let id: LiquidGlassPresetID
        let name: String
        let summary: String
        let supportsCustomColor: Bool
        let light: LiquidGlassPresetMode
        let dark: LiquidGlassPresetMode

        func mode(for appearance: LiquidGlassAppearance) -> LiquidGlassPresetMode {
            appearance == .dark ? dark : light
        }
    }

    enum LiquidGlassAppearance {
        case light
        case dark
    }

    enum LiquidGlassPresetID: String, CaseIterable {
        case inspector
        case monogram
        case textDeep
        case appIcons
        case bubbles
        case controlCenter
        case regular

        var definition: LiquidGlassPresetDefinition {
            switch self {
            case .inspector:
                let mode = LiquidGlassPresetMode(
                    liquidGlassStyle: .inspector,
                    textColorMode: .automatic,
                    tintAlpha: 0,
                    tintBrightness: 0,
                    tintRGB: LiquidGlassPresetRGB(red: 0, green: 0, blue: 0)
                )
                return LiquidGlassPresetDefinition(
                    id: self,
                    name: "极致超薄",
                    summary: "通透薄玻璃，很透明但是又有一点点蒙层的感觉，不支持背景颜色，复杂背景可读性较差",
                    supportsCustomColor: false,
                    light: mode,
                    dark: mode
                )
            case .monogram:
                let mode = LiquidGlassPresetMode(
                    liquidGlassStyle: .monogram,
                    textColorMode: .automatic,
                    tintAlpha: 0,
                    tintBrightness: 0,
                    tintRGB: LiquidGlassPresetRGB(red: 0, green: 0, blue: 0)
                )
                return LiquidGlassPresetDefinition(
                    id: self,
                    name: "极致通透",
                    summary: "通透厚玻璃，极致的完全透明，带较大的扭曲质感，文本跟随系统深浅色切换，不支持背景颜色，可读性极差",
                    supportsCustomColor: false,
                    light: mode,
                    dark: mode
                )
            case .textDeep:
                let mode = LiquidGlassPresetMode(
                    liquidGlassStyle: .text,
                    textColorMode: .white,
                    tintAlpha: 0.8,
                    tintBrightness: 0.1,
                    tintRGB: LiquidGlassPresetRGB(red: 0.1, green: 0.1, blue: 0.1)
                )
                return LiquidGlassPresetDefinition(
                    id: self,
                    name: "通透",
                    summary: "轻磨砂玻璃，背景颜色比较深，白色字体，支持自定义背景颜色",
                    supportsCustomColor: true,
                    light: mode,
                    dark: mode
                )
            case .appIcons:
                let mode = LiquidGlassPresetMode(
                    liquidGlassStyle: .appIcons,
                    textColorMode: .automatic,
                    tintAlpha: 0.2,
                    tintBrightness: 1,
                    tintRGB: LiquidGlassPresetRGB(red: 1, green: 1, blue: 1)
                )
                return LiquidGlassPresetDefinition(
                    id: self,
                    name: "标准",
                    summary: "磨砂玻璃，文本颜色自适应浅色和深色背景，支持自定义背景颜色",
                    supportsCustomColor: true,
                    light: mode,
                    dark: mode
                )
            case .bubbles:
                let mode = LiquidGlassPresetMode(
                    liquidGlassStyle: .bubbles,
                    textColorMode: .automatic,
                    tintAlpha: 0,
                    tintBrightness: 0,
                    tintRGB: LiquidGlassPresetRGB(red: 0, green: 0, blue: 0)
                )
                return LiquidGlassPresetDefinition(
                    id: self,
                    name: "优化",
                    summary: "磨砂玻璃，做了文本可读性优化，但是不支持自定义背景颜色",
                    supportsCustomColor: false,
                    light: mode,
                    dark: mode
                )
            case .controlCenter:
                let mode = LiquidGlassPresetMode(
                    liquidGlassStyle: .controlCenter,
                    textColorMode: .white,
                    tintAlpha: 0.4,
                    tintBrightness: 0.076,
                    tintRGB: LiquidGlassPresetRGB(red: 0.076, green: 0.076, blue: 0.076)
                )
                return LiquidGlassPresetDefinition(
                    id: self,
                    name: "厚",
                    summary: "厚磨砂玻璃-暗，提供类似控制中心的质感，支持颜色，明度稍暗确保白字的可读性",
                    supportsCustomColor: true,
                    light: mode,
                    dark: mode
                )
            case .regular:
                let mode = LiquidGlassPresetMode(
                    liquidGlassStyle: .regular,
                    textColorMode: .automatic,
                    tintAlpha: 0,
                    tintBrightness: 0,
                    tintRGB: LiquidGlassPresetRGB(red: 0, green: 0, blue: 0)
                )
                return LiquidGlassPresetDefinition(
                    id: self,
                    name: "稳定",
                    summary: "由于 macOS 26 优化问题，只开放了极少数液态玻璃 API，当其他预设表现异常时，请选用此项",
                    supportsCustomColor: false,
                    light: mode,
                    dark: mode
                )
            }
        }
    }

    enum LiquidGlassStyle: String, CaseIterable {
        case regular
        case clear
        case dock
        case appIcons
        case widgets
        case text
        case avPlayer
        case faceTime
        case controlCenter
        case notificationCenter
        case monogram
        case bubbles
        case identity
        case focusBorder
        case focusPlatter
        case keyboard
        case sidebar
        case abuttedSidebar
        case inspector
        case control
        case loupe
        case slider
        case camera
        case cartouchePopover

        var displayName: String {
            switch self {
            case .regular: return "常规"
            case .clear: return "通透"
            case .dock: return "Dock"
            case .appIcons: return "AppIcons"
            case .widgets: return "Widgets"
            case .text: return "Text"
            case .avPlayer: return "AvPlayer"
            case .faceTime: return "FaceTime"
            case .controlCenter: return "ControlCenter"
            case .notificationCenter: return "NotificationCenter"
            case .monogram: return "Monogram"
            case .bubbles: return "Bubbles"
            case .identity: return "Identity"
            case .focusBorder: return "FocusBorder"
            case .focusPlatter: return "FocusPlatter"
            case .keyboard: return "Keyboard"
            case .sidebar: return "Sidebar"
            case .abuttedSidebar: return "AbuttedSidebar"
            case .inspector: return "Inspector"
            case .control: return "Control"
            case .loupe: return "Loupe"
            case .slider: return "Slider"
            case .camera: return "Camera"
            case .cartouchePopover: return "CartouchePopover"
            }
        }

        static func fromStoredValue(_ value: String) -> LiquidGlassStyle? {
            if let style = LiquidGlassStyle(rawValue: value) {
                return style
            }
            switch value {
            case "常规":
                return .regular
            case "清晰", "通透":
                return .clear
            case "Dock":
                return .dock
            default:
                return nil
            }
        }
    }

    #if DEBUG
    enum OverlayWindowHostExperiment: String, CaseIterable {
        case currentPanel
        case panelFloatingLevel
        case windowFloating
        case focusLiteWindow

        var displayName: String {
            switch self {
            case .currentPanel:
                return "A 当前面板"
            case .panelFloatingLevel:
                return "C 浮动面板"
            case .windowFloating:
                return "E 浮动窗口"
            case .focusLiteWindow:
                return "F FocusLite窗口"
            }
        }

        var detail: String {
            switch self {
            case .currentPanel:
                return "NSPanel + nonactivating + popUpMenu"
            case .panelFloatingLevel:
                return "NSPanel + nonactivating + floating"
            case .windowFloating:
                return "NSWindow + borderless + floating"
            case .focusLiteWindow:
                return "Key NSWindow + borderless + floating + firstResponder"
            }
        }
    }
    #endif

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
        case white = "白色"
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
        self.notificationMode = .overlay  // 强制使用屏幕遮罩，忽略用户设置

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
        self.overlayEnableFadeOut = false  // 强制关闭，忽略用户设置
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
        self.showStartNotification = defaults.object(forKey: Keys.showStartNotification) as? Bool ?? true

        // Load - 多计时器
        if let timersData = defaults.data(forKey: Keys.timers),
           let decodedTimers = try? JSONDecoder().decode([TimerItem].self, from: timersData),
           !decodedTimers.isEmpty {
            self.timers = Self.normalizedTimerIdentifiers(decodedTimers)
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
            self.timers = Self.normalizedTimerIdentifiers([defaultTimer])
        }

        // Load - 材质选项
        let materialRawValue = defaults.string(forKey: Keys.overlayMaterial) ?? config.overlay.material
        self.overlayMaterial = OverlayMaterial(rawValue: materialRawValue) ?? .basic

        let liquidGlassStyleRawValue = defaults.string(forKey: Keys.liquidGlassStyle) ?? config.overlay.liquidGlassStyle
        self.liquidGlassStyle = LiquidGlassStyle.fromStoredValue(liquidGlassStyleRawValue) ?? .regular

        let tintModeRawValue = defaults.string(forKey: Keys.overlayGlassTintModeExperiment) ?? OverlayGlassTintExperiment.focusLiteDefault.rawValue
        self.overlayGlassTintModeExperiment = OverlayGlassTintExperiment(rawValue: tintModeRawValue) ?? .focusLiteDefault
        let tintRed = defaults.object(forKey: Keys.overlayGlassTintColorR) as? Double ?? 1.0
        let tintGreen = defaults.object(forKey: Keys.overlayGlassTintColorG) as? Double ?? 1.0
        let tintBlue = defaults.object(forKey: Keys.overlayGlassTintColorB) as? Double ?? 1.0
        self.overlayGlassTintColor = Color(red: tintRed, green: tintGreen, blue: tintBlue)
        self.overlayGlassTintAlpha = defaults.object(forKey: Keys.overlayGlassTintAlpha) as? Double ?? 0.618
        let textColorModeRawValue = defaults.string(forKey: Keys.overlayGlassTextColorMode) ?? OverlayGlassTextColorMode.automatic.rawValue
        self.overlayGlassTextColorMode = OverlayGlassTextColorMode(rawValue: textColorModeRawValue) ?? .automatic
        let presetRawValue = defaults.string(forKey: Keys.liquidGlassPreset) ?? LiquidGlassPresetID.appIcons.rawValue
        self.liquidGlassPreset = LiquidGlassPresetID(rawValue: presetRawValue) ?? .appIcons
        let presetColorSourceRawValue = defaults.string(forKey: Keys.liquidGlassPresetColorSource) ?? LiquidGlassPresetColorSource.presetDefault.rawValue
        self.liquidGlassPresetColorSource = LiquidGlassPresetColorSource(rawValue: presetColorSourceRawValue) ?? .presetDefault
        #if DEBUG
        let hostExperimentRawValue = defaults.string(forKey: Keys.overlayWindowHostExperiment) ?? OverlayWindowHostExperiment.currentPanel.rawValue
        self.overlayWindowHostExperiment = OverlayWindowHostExperiment(rawValue: hostExperimentRawValue) ?? .currentPanel
        #endif

        if let eventsData = defaults.data(forKey: Keys.reminderEvents),
           let decodedEvents = try? JSONDecoder().decode([ReminderEvent].self, from: eventsData) {
            self.reminderEvents = decodedEvents
        } else {
            self.reminderEvents = []
        }

        if let presetsData = defaults.data(forKey: Keys.timerCustomColorPresets),
           let decodedPresets = try? JSONDecoder().decode([TimerCustomColorPreset].self, from: presetsData) {
            self.timerCustomColorPresets = decodedPresets
        } else {
            self.timerCustomColorPresets = []
        }

        self.recentEmojis = defaults.stringArray(forKey: Keys.recentEmojis) ?? ["🔔", "⏰", "💧", "💊", "🏃", "😴"]

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

        $reminderEvents.dropFirst().sink { [weak self] events in
            if let encoded = try? JSONEncoder().encode(events) {
                self?.defaults.set(encoded, forKey: Keys.reminderEvents)
            }
        }.store(in: &cancellables)

        $timerCustomColorPresets.dropFirst().sink { [weak self] presets in
            if let encoded = try? JSONEncoder().encode(presets) {
                self?.defaults.set(encoded, forKey: Keys.timerCustomColorPresets)
            }
        }.store(in: &cancellables)

        $recentEmojis.dropFirst().sink { [weak self] emojis in
            self?.defaults.set(emojis, forKey: Keys.recentEmojis)
        }.store(in: &cancellables)

        // Persist changes - 定点提醒
        // Persist changes - 材质选项
        $overlayMaterial.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayMaterial) }.store(in: &cancellables)
        $liquidGlassStyle.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.liquidGlassStyle) }.store(in: &cancellables)
        $overlayGlassTintModeExperiment.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayGlassTintModeExperiment) }.store(in: &cancellables)
        $overlayGlassTintAlpha.dropFirst().sink { [weak self] in self?.defaults.set($0, forKey: Keys.overlayGlassTintAlpha) }.store(in: &cancellables)
        $overlayGlassTextColorMode.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayGlassTextColorMode) }.store(in: &cancellables)
        $liquidGlassPreset.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.liquidGlassPreset) }.store(in: &cancellables)
        $liquidGlassPresetColorSource.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.liquidGlassPresetColorSource) }.store(in: &cancellables)
        $overlayGlassTintColor.dropFirst().sink { [weak self] color in
            guard let self else { return }
            let components = color.components()
            self.defaults.set(components.red, forKey: Keys.overlayGlassTintColorR)
            self.defaults.set(components.green, forKey: Keys.overlayGlassTintColorG)
            self.defaults.set(components.blue, forKey: Keys.overlayGlassTintColorB)
        }.store(in: &cancellables)
        #if DEBUG
        $overlayWindowHostExperiment.dropFirst().sink { [weak self] in self?.defaults.set($0.rawValue, forKey: Keys.overlayWindowHostExperiment) }.store(in: &cancellables)
        #endif

        // Guardrails
        if intervalSeconds < config.interval.min { intervalSeconds = config.interval.min }
        if intervalSeconds > config.interval.max { intervalSeconds = config.interval.max }
        if restSeconds < config.interval.min { restSeconds = config.interval.min }
        if restSeconds > config.interval.max { restSeconds = config.interval.max }
        if overlayOpacity < 0.1 { overlayOpacity = 0.1 }
        if overlayOpacity > 1.0 { overlayOpacity = 1.0 }
        if overlayGlassTintAlpha < 0 { overlayGlassTintAlpha = 0 }
        if overlayGlassTintAlpha > 1 { overlayGlassTintAlpha = 1 }

        validateTimingSettings()
    }

    private static func normalizedTimerIdentifiers(_ timers: [TimerItem]) -> [TimerItem] {
        var seenTimerIDs = Set<UUID>()
        var seenScheduledTimeIDs = Set<UUID>()

        return timers.map { timer in
            var normalizedTimer = timer
            if seenTimerIDs.contains(normalizedTimer.id) {
                normalizedTimer.id = UUID()
                normalizedTimer.isRunning = false
                normalizedTimer.startedAtEpoch = 0
            }
            seenTimerIDs.insert(normalizedTimer.id)

            normalizedTimer.scheduledTimes = normalizedTimer.scheduledTimes.map { scheduledTime in
                var normalizedTime = scheduledTime
                if seenScheduledTimeIDs.contains(normalizedTime.id) {
                    normalizedTime.id = UUID()
                }
                seenScheduledTimeIDs.insert(normalizedTime.id)
                return normalizedTime
            }
            return normalizedTimer
        }
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

    func recordReminderFired(timerID: UUID, scheduledAt: Date = Date(), firedAt: Date = Date()) -> UUID {
        let event = ReminderEvent(timerID: timerID, scheduledAt: scheduledAt, firedAt: firedAt)
        reminderEvents.append(event)
        trimReminderEvents()
        return event.id
    }

    func resolveReminderEvent(_ eventID: UUID?, as status: ReminderEventStatus, resolvedAt: Date = Date()) {
        guard let eventID,
              let index = reminderEvents.firstIndex(where: { $0.id == eventID }),
              reminderEvents[index].status == .fired else {
            return
        }

        reminderEvents[index].status = status
        reminderEvents[index].resolvedAt = resolvedAt
    }

    private func trimReminderEvents() {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        reminderEvents.removeAll { $0.firedAt < cutoff }
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
        case .white: return .white
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

    @discardableResult
    func saveTimerCustomColorPreset(id: String? = nil, color: Color) -> TimerCustomColorPreset? {
        if let id,
           let index = timerCustomColorPresets.firstIndex(where: { $0.id == id }) {
            let nextPreset = TimerCustomColorPreset(id: id, color: color)
            timerCustomColorPresets[index] = nextPreset
            return nextPreset
        }

        guard timerCustomColorPresets.count < TimerCustomColorPreset.maximumCount else {
            return nil
        }

        let existingIDs = Set(timerCustomColorPresets.map(\.id))
        let nextPreset = TimerCustomColorPreset(id: TimerCustomColorPreset.makeID(excluding: existingIDs), color: color)
        timerCustomColorPresets.append(nextPreset)
        return nextPreset
    }

    func recordRecentEmoji(_ emoji: String) {
        recentEmojis = EmojiSelection.recentEmojis(afterSelecting: emoji, existing: recentEmojis, limit: 20)
    }

    func isContentValid() -> Bool {
        let trimmedTitle = notifTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = notifBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = notifEmoji.trimmingCharacters(in: .whitespacesAndNewlines)

        return !trimmedTitle.isEmpty || !trimmedBody.isEmpty || !trimmedEmoji.isEmpty
    }
}
