import SwiftUI

struct StyleSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题 - 固定
            PageHeader(
                icon: "paintbrush.fill",
                iconColor: .pink,
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
                    colorSection
                    opacitySection

                    Divider().padding(.vertical, DesignTokens.Spacing.xs)

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
            }
        }
        .onChange(of: styleSettingsHash) { _, _ in
            scheduleTestNotification()
        }
        .onDisappear {
            debounceTask?.cancel()
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
        hasher.combine(settings.liquidGlassStyle)
        return hasher.finalize()
    }

    // MARK: - Actions

    private func scheduleTestNotification() {
        // 取消之前的任务
        debounceTask?.cancel()

        // 延迟 0.5 秒后发送测试通知（防抖）
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            // 发送测试通知（自动触发，静音）
            if let focusedTimer = getFocusedTimer(), focusedTimer.isContentValid() {
                await controller.sendTest(for: focusedTimer, settings: settings, skipSound: true)
            }
        }
    }

    private func getFocusedTimer() -> TimerItem? {
        if let focusedID = settings.focusedTimerID {
            return settings.timers.first { $0.id == focusedID }
        }
        return settings.timers.first
    }

    // MARK: - Setting Sections

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "paintpalette.fill", iconColor: .purple, title: "颜色") {
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
        SettingRow(icon: "circle.lefthalf.filled", iconColor: .orange, title: "不透明度", fillWidth: true) {
            SliderControl(
                value: $settings.overlayOpacity,
                range: 0.1...1.0,
                step: 0.05,
                format: "%.0f",
                unit: "%",
                color: .orange,
                valueMultiplier: 100
            )
        }
    }

    private var widthSection: some View {
        SettingRow(icon: "arrow.left.and.right", iconColor: .blue, title: "宽度", fillWidth: true) {
            SliderControl(
                value: $settings.overlayWidth,
                range: 50...600,
                step: 10,
                format: "%.0f",
                color: .blue
            )
        }
    }

    private var heightSection: some View {
        SettingRow(icon: "arrow.up.and.down", iconColor: .green, title: "高度", fillWidth: true) {
            SliderControl(
                value: $settings.overlayHeight,
                range: 30...300,
                step: 10,
                format: "%.0f",
                color: .green
            )
        }
    }

    private var cornerRadiusSection: some View {
        SettingRow(icon: "app.fill", iconColor: .indigo, title: "圆角", fillWidth: true) {
            SliderControl(
                value: $settings.overlayCornerRadius,
                range: 0...30,
                step: 2,
                format: "%.0f",
                color: .indigo
            )
        }
    }

    private var contentSpacingSection: some View {
        SettingRow(icon: "arrow.left.and.right.square", iconColor: .cyan, title: "图标与内容间距", fillWidth: true) {
            SliderControl(
                value: $settings.overlayContentSpacing,
                range: 4...30,
                step: 2,
                format: "%.0f",
                color: .cyan
            )
        }
    }

    private var titleFontSizeSection: some View {
        SettingRow(icon: "textformat.size", iconColor: .red, title: "标题字号", fillWidth: true) {
            SliderControl(
                value: $settings.overlayTitleFontSize,
                range: 12...30,
                step: 1,
                format: "%.0f",
                color: .red
            )
        }
    }

    private var bodyFontSizeSection: some View {
        SettingRow(icon: "text.alignleft", iconColor: .pink, title: "描述字号", fillWidth: true) {
            SliderControl(
                value: $settings.overlayBodyFontSize,
                range: 10...24,
                step: 1,
                format: "%.0f",
                color: .pink
            )
        }
    }

    private var iconSizeSection: some View {
        SettingRow(icon: "face.smiling", iconColor: .yellow, title: "图标大小", fillWidth: true) {
            SliderControl(
                value: $settings.overlayIconSize,
                range: 20...80,
                step: 5,
                format: "%.0f",
                color: .yellow
            )
        }
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "cube.transparent", iconColor: .purple, title: "材质") {
                Picker("", selection: $settings.overlayMaterial) {
                    ForEach(AppSettings.OverlayMaterial.allCases, id: \.self) { material in
                        Text(material.rawValue).tag(material)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if settings.overlayMaterial == .basic {
                // 基本材质：显示模糊效果选项
                SettingRow(icon: "camera.filters", iconColor: .purple, title: "模糊效果") {
                    Toggle("", isOn: $settings.overlayUseBlur)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if settings.overlayUseBlur {
                    SettingRow(icon: "slider.horizontal.3", iconColor: .purple, title: "模糊强度", fillWidth: true) {
                        SliderControl(
                            value: $settings.overlayBlurIntensity,
                            range: 0.1...1.0,
                            step: 0.1,
                            format: "%.0f",
                            unit: "%",
                            color: .purple,
                            valueMultiplier: 100
                        )
                    }
                }

                InfoHint("基本材质使用传统模糊效果，提供稳定的视觉体验", color: .purple)
            } else {
                // 液态玻璃材质：显示效果类型选项
                SettingRow(icon: "drop.fill", iconColor: .cyan, title: "液态玻璃效果") {
                    Picker("", selection: $settings.liquidGlassStyle) {
                        ForEach(AppSettings.LiquidGlassStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                InfoHint("液态玻璃是 macOS 26 新增的视觉效果，提供更通透的质感", color: .cyan)
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

            if !fillWidth {
                Spacer()
            }

            content()
                .layoutPriority(1)
        }
        .padding(.vertical, DesignTokens.Layout.rowVerticalPadding)
    }
}