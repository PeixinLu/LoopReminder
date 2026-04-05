import SwiftUI
import LaunchAtLogin

struct BasicSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 页面标题 - 固定
            PageHeader(
                icon: "gear",
                iconColor: .blue,
                title: "基本设置",
                subtitle: "配置一些启动项"
            )

            // 内容区域 - 可滚动
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // 启动设置
                    launchSettingsSection
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
                .padding(.trailing, DesignTokens.Spacing.xl)
            }
        }
    }

    // MARK: - Launch Settings Section

    private var launchSettingsSection: some View {
        SettingsSection(title: "启动设置") {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // 开机启动
                SettingToggleRow(
                    icon: "power.circle.fill",
                    iconColor: .orange,
                    title: "开机启动",
                    description: "系统启动时自动运行此应用"
                ) {
                    LaunchAtLogin.Toggle().labelsHidden().toggleStyle(.switch)
                }

                Divider().opacity(0.5)

                // 静默启动
                SettingToggleRow(
                    icon: "eye.slash.fill",
                    iconColor: .gray,
                    title: "静默启动",
                    description: "启动时不自动打开设置页面"
                ) {
                    Toggle("", isOn: $settings.silentLaunch)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider().opacity(0.5)

                // 启动时自动开始计时
                SettingToggleRow(
                    icon: "play.circle.fill",
                    iconColor: .green,
                    title: "启动时自动开始计时",
                    description: "应用启动后自动运行所有计时器"
                ) {
                    Toggle("", isOn: $settings.autoStartTimersOnLaunch)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider().opacity(0.5)

                // 启动计时器时显示提示
                SettingToggleRow(
                    icon: "bell.badge",
                    iconColor: .blue,
                    title: "启动计时器时显示提示",
                    description: "启动或重置计时器时显示通知提示"
                ) {
                    Toggle("", isOn: $settings.showStartNotification)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider().opacity(0.5)

                // 锁屏唤醒重计时
                SettingToggleRow(
                    icon: "lock.rotation",
                    iconColor: .blue,
                    title: "从锁屏唤醒后重新计时",
                    description: "锁屏超过 5 分钟重新进入系统时，自动重置计时器"
                ) {
                    Toggle("", isOn: $settings.resetOnWakeEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func openNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    BasicSettingsView()
        .environmentObject(AppSettings())
        .frame(width: 600)
        .padding()
}