import SwiftUI
import AppKit

struct StyleSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var debounceTask: Task<Void, Never>?
    @State private var keyMonitor: Any?
    @State private var isColorPopoverPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题 - 固定
            PageHeader(
                icon: "paintbrush.fill",
                iconColor: .accentColor,
                title: "通用外观",
                subtitle: "自定义屏幕遮罩通知外观"
            )

            // 内容区域
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // 材质设置
                    materialSection

                    Divider().padding(.vertical, DesignTokens.Spacing.xs)

                    // 颜色设置
                    if settings.overlayMaterial == .basic {
                        colorSection
                        opacitySection

                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                    }


                    // 尺寸设置
                    widthSection
                    heightSection

                    Divider().padding(.vertical, DesignTokens.Spacing.xs)

                    // 外观设置
                    cornerRadiusSection
                    contentSpacingSection

                    Divider().padding(.vertical, DesignTokens.Spacing.xs)

                    // 字体设置
                    titleFontSizeSection
                    bodyFontSizeSection
                    iconSizeSection
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
                .padding(.trailing, 10)
            }
        }
        .onAppear {
            applySelectedLiquidGlassPreset()
            installStyleShortcutMonitor()
            sendStylePreviewNow()
        }
        .onChange(of: styleSettingsHash) { _, _ in
            applySelectedLiquidGlassPreset()
            scheduleStylePreview()
        }
        .onDisappear {
            debounceTask?.cancel()
            removeStyleShortcutMonitor()
            controller.closeStylePreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsWindowWillClose)) { _ in
            debounceTask?.cancel()
            controller.closeStylePreview()
        }
    }

    // MARK: - Computed Properties

    /// 计算当前外观设置的哈希值，用于检测变化
    private var styleSettingsHash: Int {
        var hasher = Hasher()
        hasher.combine(settings.overlayMaterial)
        hasher.combine(settings.overlayColor)
        hasher.combine(settings.overlayOpacity)
        hasher.combine(settings.overlayWidth)
        hasher.combine(settings.overlayHeight)
        hasher.combine(settings.overlayCornerRadius)
        hasher.combine(settings.overlayContentSpacing)
        hasher.combine(settings.overlayTitleFontSize)
        hasher.combine(settings.overlayBodyFontSize)
        hasher.combine(settings.overlayIconSize)
        hasher.combine(settings.overlayUseBlur)
        hasher.combine(settings.overlayBlurIntensity)
        hasher.combine(settings.liquidGlassPreset)
        hasher.combine(settings.liquidGlassPresetColorSource)
        hasher.combine(settings.liquidGlassStyle)
        hasher.combine(settings.overlayGlassTintModeExperiment)
        hasher.combine(settings.overlayGlassTintAlpha)
        hasher.combine(settings.overlayGlassTextColorMode)
        let customColorComponents = settings.overlayCustomColor.components()
        hasher.combine(customColorComponents.red)
        hasher.combine(customColorComponents.green)
        hasher.combine(customColorComponents.blue)
        let tintComponents = settings.overlayGlassTintColor.components()
        hasher.combine(tintComponents.red)
        hasher.combine(tintComponents.green)
        hasher.combine(tintComponents.blue)
        return hasher.finalize()
    }

    // MARK: - Actions

    private func scheduleStylePreview() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await sendStylePreview()
        }
    }

    private func sendStylePreviewNow() {
        debounceTask?.cancel()
        Task {
            await sendStylePreview()
        }
    }

    private func sendStylePreview() async {
        await controller.sendStylePreview(settings: settings)
    }

    private func installStyleShortcutMonitor() {
        removeStyleShortcutMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard settings.overlayMaterial == .liquidGlass else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isForcedShortcut = modifiers.contains(.command) && modifiers.contains(.option)
            let isPlainShortcut = modifiers.isEmpty && shouldHandlePlainArrowShortcut()
            guard isForcedShortcut || isPlainShortcut else { return event }

            switch event.keyCode {
            case 124, 30: // right arrow, ]
                cycleLiquidGlassStyle(delta: 1)
                return nil
            case 123, 33: // left arrow, [
                cycleLiquidGlassStyle(delta: -1)
                return nil
            default:
                return event
            }
        }
    }

    private func removeStyleShortcutMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func cycleLiquidGlassStyle(delta: Int) {
        let presets = AppSettings.LiquidGlassPresetID.allCases
        guard let currentIndex = presets.firstIndex(of: settings.liquidGlassPreset) else {
            settings.liquidGlassPreset = presets.first ?? .appIcons
            return
        }

        let nextIndex = (currentIndex + delta + presets.count) % presets.count
        settings.liquidGlassPreset = presets[nextIndex]
    }

    private func shouldHandlePlainArrowShortcut() -> Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else { return true }
        if firstResponder is NSTextView {
            return false
        }
        if let control = firstResponder as? NSControl,
           control is NSSlider || control is NSTextField || control is NSPopUpButton || control is NSComboBox {
            return false
        }

        let className = String(describing: type(of: firstResponder))
        return !className.contains("Slider") &&
            !className.contains("TextField") &&
            !className.contains("PopUp") &&
            !className.contains("Color")
    }

    private var selectedLiquidGlassPresetDefinition: AppSettings.LiquidGlassPresetDefinition {
        settings.liquidGlassPreset.definition
    }

    private var currentLiquidGlassAppearance: AppSettings.LiquidGlassAppearance {
        let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua ? .dark : .light
    }

    private func applySelectedLiquidGlassPreset() {
        guard settings.overlayMaterial == .liquidGlass else { return }

        let definition = selectedLiquidGlassPresetDefinition
        let mode = definition.mode(for: currentLiquidGlassAppearance)
        settings.liquidGlassStyle = mode.liquidGlassStyle
        settings.overlayGlassTintModeExperiment = .custom
        settings.overlayGlassTintAlpha = mode.tintAlpha
        settings.overlayGlassTextColorMode = mode.textColorMode
        settings.overlayGlassTintColor = resolvedPresetTintColor(for: mode, definition: definition)
    }

    private func resolvedPresetTintColor(
        for mode: AppSettings.LiquidGlassPresetMode,
        definition: AppSettings.LiquidGlassPresetDefinition
    ) -> Color {
        guard definition.supportsCustomColor,
              settings.liquidGlassPresetColorSource == .customNotificationColor else {
            return mode.tintRGB.color
        }

        let source = settings.overlayCustomColor.hsbaComponents()
        return Color(
            hue: source.hue,
            saturation: source.saturation,
            brightness: mode.tintBrightness
        )
    }

    // MARK: - Setting Sections

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "paintpalette.fill", iconColor: .accentColor, title: "颜色") {
                Picker("", selection: $settings.overlayColor) {
                    ForEach(AppSettings.OverlayColor.allCases, id: \.self) { color in
                        Text(color.rawValue).tag(color)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            if settings.overlayColor == .custom {
                HStack {
                    ColorPicker("自定义颜色", selection: $settings.overlayCustomColor, supportsOpacity: false)
                }
            }
        }
    }

    private var opacitySection: some View {
        SettingRow(icon: "circle.lefthalf.filled", iconColor: .accentColor, title: "不透明度", fillWidth: true) {
            SliderControl(
                value: $settings.overlayOpacity,
                range: 0.1...1.0,
                step: 0.05,
                format: "%.0f",
                unit: "%",
                color: .accentColor,
                valueMultiplier: 100
            )
        }
    }

    private var widthSection: some View {
        SettingRow(icon: "arrow.left.and.right", iconColor: .accentColor, title: "宽度", fillWidth: true) {
            SliderControl(
                value: $settings.overlayWidth,
                range: 50...600,
                step: 10,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

    private var heightSection: some View {
        SettingRow(icon: "arrow.up.and.down", iconColor: .accentColor, title: "高度", fillWidth: true) {
            SliderControl(
                value: $settings.overlayHeight,
                range: 30...300,
                step: 10,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

    private var cornerRadiusSection: some View {
        SettingRow(icon: "app.fill", iconColor: .accentColor, title: "圆角", fillWidth: true) {
            SliderControl(
                value: $settings.overlayCornerRadius,
                range: 0...30,
                step: 2,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

    private var contentSpacingSection: some View {
        SettingRow(icon: "arrow.left.and.right.square", iconColor: .accentColor, title: "图标与内容间距", fillWidth: true) {
            SliderControl(
                value: $settings.overlayContentSpacing,
                range: 4...30,
                step: 2,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

    private var titleFontSizeSection: some View {
        SettingRow(icon: "textformat.size", iconColor: .accentColor, title: "标题字号", fillWidth: true) {
            SliderControl(
                value: $settings.overlayTitleFontSize,
                range: 12...30,
                step: 1,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

    private var bodyFontSizeSection: some View {
        SettingRow(icon: "text.alignleft", iconColor: .accentColor, title: "描述字号", fillWidth: true) {
            SliderControl(
                value: $settings.overlayBodyFontSize,
                range: 10...24,
                step: 1,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

    private var iconSizeSection: some View {
        SettingRow(icon: "face.smiling", iconColor: .accentColor, title: "图标大小", fillWidth: true) {
            SliderControl(
                value: $settings.overlayIconSize,
                range: 20...80,
                step: 5,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "cube.transparent", iconColor: .accentColor, title: "材质") {
                    FusedCapsuleGroup(
                        options: AppSettings.OverlayMaterial.allCases,
                        selection: $settings.overlayMaterial,
                        labelFor: { $0.rawValue }
                    )
                }

            if settings.overlayMaterial == .basic {
                // 基本材质：显示模糊效果选项
                SettingRow(icon: "camera.filters", iconColor: .accentColor, title: "模糊效果") {
                    Toggle("", isOn: $settings.overlayUseBlur)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if settings.overlayUseBlur {
                    SettingRow(icon: "slider.horizontal.3", iconColor: .accentColor, title: "模糊强度", fillWidth: true) {
                        SliderControl(
                            value: $settings.overlayBlurIntensity,
                            range: 0.1...1.0,
                            step: 0.1,
                            format: "%.0f",
                            unit: "%",
                            color: .accentColor,
                            valueMultiplier: 100
                        )
                    }
                }

                ControlAreaInfoHint("基本材质使用传统模糊效果，提供稳定的视觉体验", color: .accentColor)
            } else {
                ControlAreaInfoHint("液态玻璃是 macOS 26 新增的视觉效果，提供更通透的质感", color: .accentColor)
                SettingRow(icon: "sparkles", iconColor: .accentColor, title: "液态玻璃预设") {
                    liquidGlassPresetSelector
                }

                ControlAreaInfoHint(selectedLiquidGlassPresetDefinition.summary, color: .accentColor)

                if selectedLiquidGlassPresetDefinition.supportsCustomColor {
                    SettingRow(icon: "paintpalette.fill", iconColor: .accentColor, title: "背景颜色") {
                        liquidGlassColorSourceSelector
                    }
                } else {
                    ControlAreaInfoHint("该预设不支持自定义背景颜色，将使用预设默认参数。", color: .secondary)
                }
            }
        }
    }

    private var liquidGlassPresetSelector: some View {
        FusedCapsuleGroup(
            options: AppSettings.LiquidGlassPresetID.allCases,
            selection: Binding(
                get: { settings.liquidGlassPreset },
                set: { newPreset in
                    settings.liquidGlassPreset = newPreset
                    settings.liquidGlassPresetColorSource = .presetDefault
                    isColorPopoverPresented = false
                }
            ),
            labelFor: { $0.definition.name },
            uniformWidth: true
        )
    }

    private var liquidGlassColorSourceSelector: some View {
        FusedCapsuleGroup(
            options: AppSettings.LiquidGlassPresetColorSource.allCases,
            selection: Binding(
                get: { settings.liquidGlassPresetColorSource },
                set: { newSource in
                    if newSource == .customNotificationColor
                        && settings.liquidGlassPresetColorSource != .customNotificationColor {
                        settings.overlayCustomColor = settings.overlayGlassTintColor
                        isColorPopoverPresented = true
                    } else if newSource == .presetDefault {
                        isColorPopoverPresented = false
                    }
                    settings.liquidGlassPresetColorSource = newSource
                }
            ),
            labelFor: { $0.displayName }
        ) { _ in
            Circle()
                .fill(settings.overlayGlassTintColor)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.secondary.opacity(0.28), lineWidth: 1))
        }
        .popover(isPresented: $isColorPopoverPresented) {
            CustomColorPalettePopover(color: $settings.overlayCustomColor) { color in
                settings.overlayCustomColor = color
                settings.liquidGlassPresetColorSource = .customNotificationColor
            } onDone: {
                isColorPopoverPresented = false
            }
        }
    }
}

// MARK: - Setting Row Helper

struct SettingRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let labelWidth: CGFloat?
    let fillWidth: Bool // 控件是否占满宽度
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        labelWidth: CGFloat? = nil,
        fillWidth: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.labelWidth = labelWidth
        self.fillWidth = fillWidth
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(width: labelWidth ?? DesignTokens.Layout.labelWidth, alignment: .leading)

            content()
                .layoutPriority(1)
                .frame(
                    maxWidth: .infinity,
                    alignment: fillWidth ? .leading : .trailing
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Layout.rowVerticalPadding)
    }
}


#Preview {
    StyleSettingsView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
        .frame(width: 680, height: 700)
}
