import SwiftUI

struct AnimationSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题 - 固定
            PageHeader(
                icon: "wand.and.stars",
                iconColor: .purple,
                title: "动画和定位",
                subtitle: "自定义通知动画和位置"
            )

            // 内容区域
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    // 屏幕选择
                    screenSelectionSection

                    Divider().padding(.vertical, DesignTokens.Spacing.xs)

                    // 位置和动画
                    positionSection
                    edgePaddingSection
                    animationTypeSection
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
        }
        .onAppear {
            sendStylePreviewNow()
        }
        .onChange(of: animationSettingsHash) { _, _ in
            scheduleStylePreview()
        }
        .onDisappear {
            debounceTask?.cancel()
            controller.closeStylePreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsWindowWillClose)) { _ in
            debounceTask?.cancel()
            controller.closeStylePreview()
        }
    }

    // MARK: - Computed Properties

    /// 计算当前动画和定位设置的哈希值，用于检测变化
    private var animationSettingsHash: Int {
        var hasher = Hasher()
        hasher.combine(settings.screenSelection)
        hasher.combine(settings.overlayPosition)
        hasher.combine(settings.animationStyle)
        hasher.combine(settings.overlayEdgePadding)
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

    // MARK: - Setting Sections

    private var screenSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "display.2", iconColor: .indigo, title: "显示屏幕") {
                Picker("", selection: $settings.screenSelection) {
                    ForEach(AppSettings.ScreenSelection.allCases, id: \.self) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            InfoHint(settings.screenSelection.description, color: .indigo)
        }
    }

    private var positionSection: some View {
        SettingRow(icon: "location.fill", iconColor: .blue, title: "位置") {
            Picker("", selection: $settings.overlayPosition) {
                ForEach(AppSettings.OverlayPosition.allCases, id: \.self) { position in
                    Text(position.rawValue).tag(position)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    private var animationTypeSection: some View {
        SettingRow(icon: "sparkles", iconColor: .pink, title: "动画类型") {
            Picker("", selection: $settings.animationStyle) {
                ForEach(AppSettings.AnimationStyle.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    private var edgePaddingSection: some View {
        SettingRow(icon: "arrow.up.to.line.square.fill", iconColor: .teal, title: "屏幕边缘距离", fillWidth: true) {
            SliderControl(
                value: $settings.overlayEdgePadding,
                range: 0...100,
                step: 5,
                format: "%.0f",
                color: .teal
            )
        }
    }
}
