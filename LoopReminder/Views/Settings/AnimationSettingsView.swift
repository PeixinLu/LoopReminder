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
                iconColor: .accentColor,
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
                .padding(.trailing, 10)
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
            SettingRow(icon: "display.2", iconColor: .accentColor, title: "显示屏幕") {
                FusedCapsuleGroup(
                    options: AppSettings.ScreenSelection.allCases,
                    selection: $settings.screenSelection,
                    labelFor: { $0.rawValue }
                )
            }

            InfoHint(settings.screenSelection.description, color: .accentColor)
        }
    }

    private var positionSection: some View {
        SettingRow(icon: "location.fill", iconColor: .accentColor, title: "位置") {
            PositionGridPicker(selection: $settings.overlayPosition)
        }
    }

    private var animationTypeSection: some View {
        SettingRow(icon: "sparkles", iconColor: .accentColor, title: "动画类型") {
            FusedCapsuleGroup(
                options: AppSettings.AnimationStyle.allCases,
                selection: $settings.animationStyle,
                labelFor: { $0.rawValue }
            )
        }
    }

    private var edgePaddingSection: some View {
        SettingRow(icon: "arrow.up.to.line.square.fill", iconColor: .accentColor, title: "屏幕边缘距离", fillWidth: true) {
            SliderControl(
                value: $settings.overlayEdgePadding,
                range: 0...100,
                step: 5,
                format: "%.0f",
                color: .accentColor
            )
        }
    }

}

// MARK: - 位置网格选择器

/// 遥控器风格位置选择器：三行网格，中行合并，带文本说明
struct PositionGridPicker: View {
    @Binding var selection: AppSettings.OverlayPosition

    var body: some View {
        VStack(spacing: 0) {
            // 第一行：三个位置
            HStack(spacing: 0) {
                gridCell(.topLeft)
                dividerV
                gridCell(.topCenter)
                dividerV
                gridCell(.topRight)
            }
            dividerH
            // 第二行：居中（合并整行）
            gridCell(.center)
            dividerH
            // 第三行：三个位置
            HStack(spacing: 0) {
                gridCell(.bottomLeft)
                dividerV
                gridCell(.bottomCenter)
                dividerV
                gridCell(.bottomRight)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func gridCell(_ position: AppSettings.OverlayPosition) -> some View {
        let isSelected = selection == position
        return Button {
            selection = position
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon(for: position))
                    .font(.system(size: 12, weight: .medium))
                Text(position.rawValue)
                    .font(.caption)
            }
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                Rectangle()
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dividerV: some View {
        Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1)
    }

    private var dividerH: some View {
        Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 1)
    }

    private func icon(for position: AppSettings.OverlayPosition) -> String {
        switch position {
        case .topLeft: return "arrow.up.left"
        case .topCenter: return "arrow.up"
        case .topRight: return "arrow.up.right"
        case .center: return "scope"
        case .bottomLeft: return "arrow.down.left"
        case .bottomCenter: return "arrow.down"
        case .bottomRight: return "arrow.down.right"
        }
    }
}


#Preview {
    AnimationSettingsView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
        .frame(width: 680, height: 600)
}
