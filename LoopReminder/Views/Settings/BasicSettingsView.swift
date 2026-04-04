import SwiftUI
import LaunchAtLogin

struct BasicSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var restInputValue: String = ""
    @State private var restSelectedUnit: TimeUnit = .minutes

    enum TimeUnit: String, CaseIterable {
        case seconds = "秒"
        case minutes = "分钟"

        var multiplier: Double {
            switch self {
            case .seconds:
                return 1
            case .minutes:
                return 60
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 页面标题 - 固定
            PageHeader(
                icon: "gear.fill",
                iconColor: .blue,
                title: "基本设置",
                subtitle: "配置一些启动项"
            )

            // 内容区域 - 可滚动
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // 1. 休息一下
                    restSection

                    // 2. 启动设置
                    launchSettingsSection

                    // 3. 通知方式
                    notificationModeSection
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
                .padding(.trailing, DesignTokens.Spacing.xl)
            }
        }
        .onAppear(perform: initializeRestInputValue)
    }

    // MARK: - Rest Section

    private var restSection: some View {
        SettingsSection(title: nil) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Section 标题 + Toggle
                HStack {
                    Text("休息一下")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $settings.isRestEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(settings.isRunning)
                }

                if settings.isRestEnabled {
                    SettingRow(icon: "timer", iconColor: .purple, title: "休息时长") {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            TextField("输入时长", text: $restInputValue, onEditingChanged: { isEditing in
                                if !isEditing {
                                    validateAndUpdateRestInterval()
                                }
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(width: DesignTokens.Layout.inputFieldWidth)
                            .disabled(settings.isRunning)

                            Picker("", selection: $restSelectedUnit) {
                                ForEach(TimeUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: DesignTokens.Layout.pickerWidth)
                            .disabled(settings.isRunning)
                            .onChange(of: restSelectedUnit) { _, _ in
                                validateAndUpdateRestInterval()
                            }

                            Text(settings.formattedRestInterval())
                                .font(DesignTokens.Typography.value)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                    
                    if let validationMessage = getRestIntervalValidationMessage() {
                        ValidationHint(
                            text: validationMessage.text,
                            isWarning: validationMessage.isWarning
                        )
                    }
                }

                InfoHint("手动关闭通知时触发休息，休息时间内计时器暂停，休息完毕后继续计时", color: .purple)

                if settings.isRunning {
                    LockHint("请先暂停才能修改")
                }
            }
        }
        .runningStateStyle(isRunning: settings.isRunning)
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

    // MARK: - Notification Mode Section

    private var notificationModeSection: some View {
        SettingsSection(showDivider: false) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // 标题和选择器
                HStack {
                    Label {
                        Text("通知方式")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.purple)
                    }

                    Spacer()

                    Picker("", selection: $settings.notificationMode) {
                        ForEach(AppSettings.NotificationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .disabled(settings.isRunning)
                }

                // 描述文字
                Text(settings.notificationMode == .system ? "使用macOS系统通知中心" : "在屏幕右上角显示遮罩通知")
                    .font(DesignTokens.Typography.hint)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DesignTokens.Spacing.xxl)

                // 系统通知模式提示
                if settings.notificationMode == .system {
                    WarningCard(color: .orange) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Image(systemName: "bell.badge")
                                    .font(DesignTokens.Typography.hint)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                    Text("提醒将发送到控制中心。需确保开启了通知权限")
                                        .font(DesignTokens.Typography.hint)
                                        .foregroundStyle(.secondary)
                                    Button(action: openNotificationSettings) {
                                        Text("[前往配置]")
                                            .font(DesignTokens.Typography.hint)
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Divider()

                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(DesignTokens.Typography.hint)
                                    .foregroundStyle(.orange)
                                Text("推荐使用遮罩通知！由于macOS的通知机制，内容相似的通知可能被静默合并，导致漏接提醒。")
                                    .font(DesignTokens.Typography.hint)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, DesignTokens.Spacing.xxl)
                }

                if settings.isRunning {
                    LockHint("请先暂停才能修改通知方式")
                        .padding(.leading, DesignTokens.Spacing.xxl)
                }
            }
        }
        .runningStateStyle(isRunning: settings.isRunning)
    }

    // MARK: - Helper Methods

    private func openNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }

    private func initializeRestInputValue() {
        let seconds = settings.restSeconds
        if seconds >= 60 && Int(seconds) % 60 == 0 {
            restSelectedUnit = .minutes
            restInputValue = String(Int(seconds / 60))
        } else {
            restSelectedUnit = .seconds
            restInputValue = String(Int(seconds))
        }
    }

    private func validateAndUpdateRestInterval() {
        guard let value = Double(restInputValue), value > 0 else {
            // 如果输入无效，恢复为当前设置的值
            initializeRestInputValue()
            return
        }

        var seconds = value * restSelectedUnit.multiplier

        // 限制范围：5秒到7200秒(2小时)
        if seconds < 5 {
            seconds = 5
        }
        if seconds > 7200 {
            seconds = 7200
        }

        settings.restSeconds = seconds

        // 更新输入框以反映修正后的值
        initializeRestInputValue()
    }

    // MARK: - Validation Message

    private struct ValidationMessage {
        let text: String
        let isWarning: Bool
    }

    private func getRestIntervalValidationMessage() -> ValidationMessage? {
        guard let value = Double(restInputValue), value > 0 else {
            return nil
        }

        let seconds = value * restSelectedUnit.multiplier

        if seconds < 5 {
            return ValidationMessage(
                text: "⚠ 低于最小值 5 秒，已自动调整为 5 秒",
                isWarning: true
            )
        } else if seconds > 7200 {
            return ValidationMessage(
                text: "⚠ 超过最大值 2 小时，已自动调整为 2 小时",
                isWarning: true
            )
        } else if seconds >= 60 && seconds <= 900 {
            return ValidationMessage(
                text: "✓ 休息时间合理",
                isWarning: false
            )
        }

        return nil
    }
}

// MARK: - Preview

#Preview {
    BasicSettingsView()
        .environmentObject(AppSettings())
        .frame(width: 600)
        .padding()
}
