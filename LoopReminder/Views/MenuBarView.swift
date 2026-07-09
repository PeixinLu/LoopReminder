import SwiftUI

private enum MenuBarPreviewTuning {
    static let menuWidth: CGFloat = 280

    static let textButtonHeight: CGFloat = 30
    static let textButtonCornerRadius: CGFloat = 7
    static let textButtonHorizontalPadding: CGFloat = 8

    static let pillButtonWidth: CGFloat? = nil
    static let pillButtonHeight: CGFloat = 24
    static let pillButtonCornerRadius: CGFloat = 12
    static let pillButtonHorizontalPadding: CGFloat = 8

    static let timerRowHeight: CGFloat? = nil
    static let timerRowCornerRadius: CGFloat = 12
    static let maxVisibleTimerRows = 6
    static let timerListMaxHeight: CGFloat = 360

    static let timerSwitchWidth: CGFloat = 38
    static let timerSwitchHeight: CGFloat = 24
    static let timerSwitchKnobWidth: CGFloat = 6
    static let timerSwitchKnobHeight: CGFloat = 16
}

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
                        icon: hasRunningTimer ? "power.circle.fill" : "power.circle",
                        title: hasRunningTimer ? "关闭全部" : "全部开启",
                        tint: hasRunningTimer ? .orange : .green,
                        action: toggleAll
                    )
                }
                .padding(.horizontal, 8)

                timerListView
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
        .frame(width: MenuBarPreviewTuning.menuWidth)
    }

    // MARK: - Actions

    @ViewBuilder
    private var timerListView: some View {
        if shouldScrollTimerList {
            ScrollView {
                timerRows
            }
            .frame(height: MenuBarPreviewTuning.timerListMaxHeight)
        } else {
            timerRows
        }
    }

    private var timerRows: some View {
        VStack(spacing: 6) {
            ForEach(settings.timers) { timer in
                TimerRowView(
                    timer: timer,
                    isEditingDisabled: settings.editingTimerID == timer.id,
                    onToggle: { toggleTimer(timer) }
                )
            }
        }
    }

    private var shouldScrollTimerList: Bool {
        settings.timers.count > MenuBarPreviewTuning.maxVisibleTimerRows
    }

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
            // 开启所有有效的计时器
            controller.start(settings: settings)
        }
    }

    private func toggleTimer(_ timer: TimerItem) {
        // 编辑态下禁止开启
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
    var height: CGFloat = MenuBarPreviewTuning.textButtonHeight
    var cornerRadius: CGFloat = MenuBarPreviewTuning.textButtonCornerRadius
    var horizontalPadding: CGFloat = MenuBarPreviewTuning.textButtonHorizontalPadding
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
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
    var width: CGFloat? = MenuBarPreviewTuning.pillButtonWidth
    var height: CGFloat = MenuBarPreviewTuning.pillButtonHeight
    var cornerRadius: CGFloat = MenuBarPreviewTuning.pillButtonCornerRadius
    var horizontalPadding: CGFloat = MenuBarPreviewTuning.pillButtonHorizontalPadding
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
            .padding(.horizontal, horizontalPadding)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(isHovered ? 0.24 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(isHovered ? 0.35 : 0), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
    var rowHeight: CGFloat? = MenuBarPreviewTuning.timerRowHeight
    var rowCornerRadius: CGFloat = MenuBarPreviewTuning.timerRowCornerRadius
    var switchWidth: CGFloat = MenuBarPreviewTuning.timerSwitchWidth
    var switchHeight: CGFloat = MenuBarPreviewTuning.timerSwitchHeight
    var switchKnobWidth: CGFloat = MenuBarPreviewTuning.timerSwitchKnobWidth
    var switchKnobHeight: CGFloat = MenuBarPreviewTuning.timerSwitchKnobHeight
    let onToggle: () -> Void

    @State private var isHovered = false

    /// 格式化提醒计划显示文本
    private var scheduleText: String {
        if timer.reminderType == .interval {
            return "循环 · " + timer.formattedInterval()
        } else {
            let times = timer.scheduledTimes.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
            if times.isEmpty {
                return "定点 · 无时间点"
            } else if times.count == 1 {
                let time = times[0]
                return String(format: "定点 · 每天 %02d:%02d", time.hour, time.minute)
            } else {
                let firstTime = times[0]
                return String(format: "定点 · %02d:%02d 等%d个", firstTime.hour, firstTime.minute, times.count)
            }
        }
    }

    var body: some View {
        let isEnabled = timer.isContentValid() && !isEditingDisabled
        let appearance = MenuBarControlAppearance(isHovered: isHovered, isPressed: false, isEnabled: isEnabled)

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

            TimerPowerSwitch(
                isOn: timer.isRunning,
                isEnabled: isEnabled,
                cornerRadius: 10, width: switchWidth,
                height: switchHeight,
                knobWidth: switchKnobWidth,
                knobHeight: switchKnobHeight,
                action: {}
            )
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(appearance.backgroundOpacity + 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: rowCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(isHovered && isEnabled ? 0.12 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .opacity(appearance.foregroundOpacity)
        .onTapGesture {
            guard isEnabled else { return }
            onToggle()
        }
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

struct PressablePlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("菜单栏菜单 - 混合状态") {
    let settings = MenuBarPreviewData.settings
    MenuBarView()
        .environmentObject(settings)
        .environmentObject(ReminderController())
}

#Preview("菜单栏菜单 - 多计时器滚动") {
    let settings = MenuBarPreviewData.manyTimersSettings
    MenuBarView()
        .environmentObject(settings)
        .environmentObject(ReminderController())
}

#Preview("菜单栏按钮外观") {
    VStack(alignment: .leading, spacing: 12) {
        MenuBarTextButton(
            icon: "gearshape",
            title: "打开设置",
            shortcut: "⌘,",
            action: {}
        )

        HStack(spacing: 8) {
            Text("计时器")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            MenuBarPillButton(
                icon: "power.circle",
                title: "全部开启",
                tint: .green,
                action: {}
            )

            MenuBarPillButton(
                icon: "power.circle.fill",
                title: "关闭全部",
                tint: .orange,
                action: {}
            )
        }
        .padding(.horizontal, 8)

        HStack(spacing: 8) {
            MenuBarPillButton(
                icon: "power.circle",
                title: "宽 74 高 24",
                tint: .green,
                width: 74,
                height: 24,
                cornerRadius: 8,
                action: {}
            )

            MenuBarPillButton(
                icon: "power.circle.fill",
                title: "宽 82 高 28",
                tint: .orange,
                width: 82,
                height: 28,
                cornerRadius: 10,
                action: {}
            )
        }
        .padding(.horizontal, 8)

        TimerRowView(
            timer: MenuBarPreviewData.enabledIntervalTimer,
            isEditingDisabled: false,
            onToggle: {}
        )

        TimerRowView(
            timer: MenuBarPreviewData.disabledScheduledTimer,
            isEditingDisabled: false,
            onToggle: {}
        )

        TimerRowView(
            timer: MenuBarPreviewData.editingTimer,
            isEditingDisabled: true,
            switchWidth: 52,
            switchHeight: 32,
            switchKnobWidth: 8,
            switchKnobHeight: 20,
            onToggle: {}
        )

        Divider()
            .padding(.horizontal, 4)

        MenuBarTextButton(
            icon: "rectangle.portrait.and.arrow.right",
            title: "退出 LoopReminder",
            shortcut: "⌘Q",
            action: {}
        )
    }
    .padding(12)
    .frame(width: MenuBarPreviewTuning.menuWidth)
}

@MainActor
private enum MenuBarPreviewData {
    static var settings: AppSettings {
        let settings = AppSettings()
        let timers = [
            enabledIntervalTimer,
            disabledScheduledTimer,
            editingTimer
        ]
        settings.timers = timers
        settings.focusedTimerID = timers.first?.id
        settings.editingTimerID = editingTimer.id
        settings.isRunning = timers.contains { $0.isRunning }
        return settings
    }

    static var manyTimersSettings: AppSettings {
        let settings = AppSettings()
        let timers = (0..<14).map { index in
            TimerItem(
                emoji: index.isMultiple(of: 2) ? "⏱️" : "📍",
                title: "计时器 \(index + 1)",
                body: "菜单栏高度测试",
                intervalSeconds: Double(600 + index * 60),
                customColor: .init(colorType: index.isMultiple(of: 2) ? .blue : .emerald),
                reminderType: index.isMultiple(of: 2) ? .interval : .scheduled,
                scheduledTimes: [
                    ScheduledTime(hour: (9 + index) % 24, minute: 0),
                    ScheduledTime(hour: (14 + index) % 24, minute: 30)
                ]
            )
        }
        settings.timers = timers
        settings.focusedTimerID = timers.first?.id
        settings.isRunning = timers.contains { $0.isRunning }
        return settings
    }

    static var enabledIntervalTimer: TimerItem {
        var timer = TimerItem(
            emoji: "💧",
            title: "喝水",
            body: "保持补水",
            intervalSeconds: 900,
            customColor: .init(colorType: .blue)
        )
        timer.isRunning = true
        timer.startedAtEpoch = Date().timeIntervalSince1970
        timer.lastFireEpoch = Date().addingTimeInterval(-280).timeIntervalSince1970
        return timer
    }

    static var disabledScheduledTimer: TimerItem {
        TimerItem(
            emoji: "🌙",
            title: "晚间复盘",
            body: "记录今天的重要事项",
            customColor: .init(colorType: .violet),
            reminderType: .scheduled,
            scheduledTimes: [
                ScheduledTime(hour: 21, minute: 30),
                ScheduledTime(hour: 22, minute: 45)
            ]
        )
    }

    static var editingTimer: TimerItem {
        TimerItem(
            emoji: "🧘",
            title: "活动一下",
            body: "离开座位走一走",
            intervalSeconds: 1800,
            customColor: .init(colorType: .emerald)
        )
    }
}
