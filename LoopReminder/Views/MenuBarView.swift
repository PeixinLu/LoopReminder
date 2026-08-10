import SwiftUI

/// 菜单栏下拉视图
struct MenuBarView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 打开设置按钮（文本按钮，无背景）
            MenuBarTextButton(
                icon: "gearshape",
                title: "打开设置",
                shortcut: "⌘,",
                action: openSettings
            )

            // 计时器列表
            if !settings.timers.isEmpty {
                Divider()
                    .padding(.horizontal, 4)

                // 计时器标题 + 全部启停按钮
                HStack {
                    Text("计时器")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
                    MenuBarPillButton(
                        icon: hasRunningTimer ? "stop.fill" : "play.fill",
                        title: hasRunningTimer ? "全部停止" : "全部启动",
                        tint: hasRunningTimer ? .orange : .green,
                        action: toggleAll
                    )
                }
                .padding(.horizontal, 8)

                ForEach(settings.timers) { timer in
                    TimerRowView(
                        timer: timer,
                        isEditingDisabled: settings.editingTimerID == timer.id,
                        onToggle: { toggleTimer(timer) }
                    )
                }
            }

            Divider()
                .padding(.horizontal, 4)

            // 退出按钮（文本按钮，无背景）
            MenuBarTextButton(
                icon: "rectangle.portrait.and.arrow.right",
                title: "退出 LoopReminder",
                shortcut: "⌘Q",
                action: quitApp
            )
        }
        .padding(12)
        .frame(width: 280)
    }

    // MARK: - Actions

    private func openSettings() {
        // 先关闭菜单
        dismiss()
        // 延迟打开设置窗口，确保菜单已关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
        }
    }

    private func toggleAll() {
        let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })

        if hasRunningTimer {
            // 停止所有正在运行的计时器
            for timer in settings.timers where timer.isRunning {
                controller.stopTimer(timer.id, settings: settings)
            }
            settings.isRunning = false
        } else {
            // 启动所有有效的计时器
            settings.isRunning = true
            controller.start(settings: settings)
        }
    }

    private func toggleTimer(_ timer: TimerItem) {
        // 编辑态下禁止启动
        guard settings.editingTimerID != timer.id else { return }
        if timer.isRunning {
            controller.stopTimer(timer.id, settings: settings)
        } else {
            controller.startTimer(timer.id, settings: settings)
        }
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - 菜单栏文本按钮（无背景）

struct MenuBarTextButton: View {
    let icon: String
    let title: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    private var appearance: MenuBarControlAppearance {
        MenuBarControlAppearance(isHovered: isHovered, isPressed: isPressed, isEnabled: true)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(appearance.backgroundOpacity))
            )
            .contentShape(Rectangle())
            .scaleEffect(appearance.scale)
            .opacity(appearance.foregroundOpacity)
        }
        .buttonStyle(PressablePlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.08)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isPressed = false
                    }
                }
        )
    }
}

struct MenuBarPillButton: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    private var appearance: MenuBarControlAppearance {
        MenuBarControlAppearance(isHovered: isHovered, isPressed: isPressed, isEnabled: true)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(isHovered ? 0.24 : 0.15))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(isHovered ? 0.35 : 0), lineWidth: 1)
            )
            .contentShape(Capsule())
            .scaleEffect(appearance.scale)
        }
        .buttonStyle(PressablePlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.08)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - 菜单栏圆角按钮

struct MenuBarButton: View {
    let icon: String
    let title: String
    var iconColor: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressablePlainButtonStyle())
    }
}

// MARK: - 计时器行视图

struct TimerRowView: View {
    let timer: TimerItem
    let isEditingDisabled: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    /// 格式化提醒计划显示文本
    private var scheduleText: String {
        switch timer.reminderType {
        case .interval:
            return "循环 · " + timer.formattedInterval()
        case .scheduled:
            let enabledTimes = timer.scheduledTimes.filter { $0.enabled }
            if enabledTimes.isEmpty {
                return "定点 · 无启用的时间"
            } else if enabledTimes.count == 1 {
                let time = enabledTimes[0]
                return String(format: "定点 · 每天 %02d:%02d", time.hour, time.minute)
            } else {
                let firstTime = enabledTimes[0]
                return String(format: "定点 · %02d:%02d 等%d个", firstTime.hour, firstTime.minute, enabledTimes.count)
            }
        case .cron:
            return "Cron · \(timer.cronExpression)"
        }
    }

    var body: some View {
        let isEnabled = timer.isContentValid() && !isEditingDisabled
        let appearance = MenuBarControlAppearance(isHovered: isHovered, isPressed: false, isEnabled: isEnabled)

        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Emoji 图标
                Text(timer.emoji)
                    .font(.system(size: 16))
                    .frame(width: 24)

                // 计时器名称和状态
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    // 显示类型和间隔/定点时间
                    HStack(spacing: 4) {
                        if timer.isRunning {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                        Text(scheduleText)
                            .font(.caption2)
                            .foregroundStyle(timer.isRunning ? .green : .secondary)
                    }
                }

                Spacer()

                TimerToggleIndicator(
                    isRunning: timer.isRunning,
                    isEnabled: isEnabled,
                    isHovered: isHovered
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(appearance.backgroundOpacity + 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(isHovered && isEnabled ? 0.12 : 0), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .opacity(appearance.foregroundOpacity)
        }
        .buttonStyle(PressablePlainButtonStyle())
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
            if hovering && isEnabled {
                NSCursor.pointingHand.push()
            } else if isEnabled {
                NSCursor.pop()
            }
        }
    }
}

struct TimerToggleIndicator: View {
    let isRunning: Bool
    let isEnabled: Bool
    let isHovered: Bool

    private var appearance: MenuBarControlAppearance {
        MenuBarControlAppearance(isHovered: isHovered, isPressed: false, isEnabled: isEnabled)
    }

    private var tint: Color {
        isRunning ? .orange : .green
    }

    var body: some View {
        Image(systemName: isRunning ? "stop.fill" : "play.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(tint)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isHovered && isEnabled ? 0.45 : 0), lineWidth: 1)
            )
            .shadow(color: tint.opacity(isHovered && isEnabled ? 0.35 : 0), radius: 4, y: 1)
            .scaleEffect(appearance.scale)
            .opacity(appearance.foregroundOpacity)
            .accessibilityHidden(true)
    }
}

struct PressablePlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
}
