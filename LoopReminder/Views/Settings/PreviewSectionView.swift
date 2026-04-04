import SwiftUI
import Combine

struct PreviewSectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @Binding var sendingTest: Bool
    var showTimerList: Bool = false // 是否显示计时器列表
    var onNavigateToTimers: (() -> Void)? = nil // 跳转到计时器页面

    var body: some View {
        VStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            if showTimerList {
                // 显示计时器列表
                timerListView
            } else {
                // 显示单个计时器预览
                singleTimerPreviewView
            }
            
            Spacer()
        }
    }
    
    // MARK: - Single Timer Preview View
    
    private var singleTimerPreviewView: some View {
        VStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            // 预览区域
            previewArea
            
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)
            
            // 测试按钮
            testButton
        }
    }
    
    // MARK: - Timer List View
    
    private var timerListView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "timer.circle.fill")
                    .foregroundStyle(.blue)
                Text("通知效果预览")
                    .font(.headline)
                Spacer()
            }
            
            // 预览区域
            previewAreaForFocusedTimer
            
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)
            
            // 计时器列表（带配置按钮）
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Text("计时器列表")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        onNavigateToTimers?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                                .font(.caption)
                            Text("计时器配置")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)
                }
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(settings.timers) { timer in
                            TimerListItemView(
                                timer: timer,
                                isFocused: settings.focusedTimerID == timer.id,
                                isRunning: settings.isRunning,
                                onToggle: {
                                    toggleTimer(timer)
                                },
                                onFocus: {
                                    settings.focusedTimerID = timer.id
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            
            // 测试按钮
            testButton
        }
        .frame(width: 340)
    }
    
    // MARK: - Preview Area
    
    private var previewArea: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "eye.fill")
                    .foregroundStyle(.blue)
                Text("通知效果预览")
                    .font(.headline)
            }
            
            previewNotificationContainer
            
            Text("实际显示效果可能因系统设置而略有不同")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Preview Area For Focused Timer
    
    private var previewAreaForFocusedTimer: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            previewNotificationContainer
            
            Text("预览当前焦点的计时器")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Preview Notification Container
    
    private var previewNotificationContainer: some View {
        ZStack {
            // 外层：黑色边框，模拟显示器外壳
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            
            // 内层：透明的屏幕区域（使用视觉效果实现真正的透明）
            VisualEffectTransparentView()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(8) // 边框宽度
                .overlay(
                    GeometryReader { geometry in
                        let screenWidth = geometry.size.width - 16
                        let screenHeight = geometry.size.height - 16
                        
                        if let focusedTimer = getFocusedTimer() {
                            let notifWidth = settings.overlayWidth
                            let notifHeight = settings.overlayHeight
                            
                            let widthScale = notifWidth > screenWidth ? screenWidth / notifWidth : 1.0
                            let heightScale = notifHeight > screenHeight ? screenHeight / notifHeight : 1.0
                            let scale = min(widthScale, heightScale, 1.0)
                            
                            let backgroundColor = focusedTimer.customColor?.toColor() ?? settings.getOverlayColor()
                            
                            ZStack {
                                OverlayNotificationView(
                                    emoji: focusedTimer.emoji,
                                    title: focusedTimer.title,
                                    message: focusedTimer.body,
                                    backgroundColor: backgroundColor,
                                    backgroundOpacity: settings.overlayOpacity,
                                    stayDuration: 999,
                                    enableFadeOut: false,
                                    fadeOutDelay: 0,
                                    fadeOutDuration: 1,
                                    titleFontSize: settings.overlayTitleFontSize * scale,
                                    bodyFontSize: settings.overlayBodyFontSize * scale,
                                    iconSize: settings.overlayIconSize * scale,
                                    cornerRadius: settings.overlayCornerRadius * scale,
                                    contentSpacing: settings.overlayContentSpacing * scale,
                                    useBlur: settings.overlayUseBlur,
                                    blurIntensity: settings.overlayBlurIntensity,
                                    overlayWidth: settings.overlayWidth * scale,
                                    overlayHeight: settings.overlayHeight * scale,
                                    animationStyle: .fade,
                                    position: .center,
                                    padding: 0,
                                    textColor: nil,
                                    overlayMaterial: settings.overlayMaterial,
                                    liquidGlassStyle: settings.liquidGlassStyle,
                                    onDismiss: { _ in }
                                )
                            }
                        }
                    }
                    .padding(8)
                )
        }
        .frame(width: 340, height: 240)
    }
    
    // MARK: - Test Button
    
    private var testButton: some View {
        Button {
            guard let focusedTimer = getFocusedTimer(), focusedTimer.isContentValid() else {
                return
            }
            
            sendingTest = true
            Task {
                await controller.sendTest(for: focusedTimer, settings: settings)
                try? await Task.sleep(nanoseconds: 500_000_000)
                sendingTest = false
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if sendingTest {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.caption)
                }
                Text(sendingTest ? "发送中..." : "测试通知效果")
                    .font(.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(sendingTest || settings.isRunning || getFocusedTimer()?.isContentValid() != true)
        .frame(width: 340)
    }
    
    // MARK: - Helper Methods
    
    private func getFocusedTimer() -> TimerItem? {
        if let focusedID = settings.focusedTimerID {
            return settings.timers.first { $0.id == focusedID }
        }
        return settings.timers.first
    }

    private func toggleTimer(_ timer: TimerItem) {
        // 删除旧的 toggle 逻辑，不再需要
    }
}

// MARK: - Visual Effect Transparent View

struct VisualEffectTransparentView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // 保持设置不变
    }
}

// MARK: - Timer List Item View

struct TimerListItemView: View {
    let timer: TimerItem
    let isFocused: Bool
    let isRunning: Bool
    let onToggle: () -> Void
    let onFocus: () -> Void
    
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    
    @State private var countdownText: String = ""
    @State private var progressValue: Double = 0.0
    private let timer2 = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // 图标和名称
                HStack(spacing: 6) {
                    Text(timer.emoji)
                        .font(.body)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timer.displayName)
                            .font(.callout)
                            .lineLimit(1)
                        // 显示时间信息
                        Text(formattedSchedule(for: timer))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 休息和自定义颜色标记
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if timer.reminderType == .interval && timer.isRestEnabled {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .help("休息 \(timer.formattedRestInterval())")
                    }

                    if timer.customColor != nil {
                        Circle()
                            .fill(timer.customColor?.toColor() ?? .gray)
                            .frame(width: 8, height: 8)
                            .help("自定义颜色")
                    }
                }
                
                // 启动/停止按钮
                if timer.isContentValid() {
                    Button {
                        if timer.isRunning {
                            controller.stopTimer(timer.id, settings: settings)
                        } else {
                            controller.startTimer(timer.id, settings: settings)
                        }
                    } label: {
                        Image(systemName: timer.isRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(timer.isRunning ? .orange : .green)
                    }
                    .buttonStyle(.plain)
                    .help(timer.isRunning ? "暂停计时器" : "启动计时器")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            
            // 进度条
            if timer.isRunning {
                VStack(spacing: 4) {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.15))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: progressWidth, height: 3)
                            .animation(.linear(duration: 0.3), value: progressValue)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    
                    if !countdownText.isEmpty {
                        HStack {
                            Text(countdownText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                        }
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.bottom, DesignTokens.Spacing.xs)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall)
                .fill(isFocused ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall)
                .strokeBorder(isFocused ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onFocus()
        }
        .onReceive(timer2) { _ in
            if timer.isRunning {
                updateCountdown()
            }
        }
    }
    
    private var progressWidth: CGFloat {
        // 计算进度条宽度
        return 316 * progressValue // 340 - 2*12 padding
    }
    
    private func updateCountdown() {
        guard timer.isRunning else {
            countdownText = ""
            progressValue = 0.0
            return
        }
        
        let now = Date()
        let lastFire = timer.lastFireDate ?? now
        let nextFire = lastFire.addingTimeInterval(timer.intervalSeconds)
        let remaining = nextFire.timeIntervalSince(now)
        
        if remaining <= 1.0 {
            countdownText = "下次通知：即将发送..."
            progressValue = 1.0
            return
        }
        
        let elapsed = timer.intervalSeconds - remaining
        progressValue = max(0, min(1.0, elapsed / timer.intervalSeconds))
        
        let seconds = Int(remaining)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            countdownText = String(format: "下次通知：%d:%02d:%02d", hours, minutes, secs)
        } else if minutes > 0 {
            countdownText = String(format: "下次通知：%d:%02d", minutes, secs)
        } else {
            countdownText = String(format: "下次通知：%d秒", secs)
        }
    }

    /// 格式化提醒计划显示文本
    private func formattedSchedule(for timer: TimerItem) -> String {
        if timer.reminderType == .interval {
            return "[循环] " + timer.formattedInterval()
        } else {
            // 定点提醒
            let enabledTimes = timer.scheduledTimes.filter { $0.enabled }
            if enabledTimes.isEmpty {
                return "[定点] 无启用的提醒时间"
            } else if enabledTimes.count == 1 {
                let time = enabledTimes[0]
                return String(format: "[定点] 每天 %02d:%02d", time.hour, time.minute)
            } else {
                let firstTime = enabledTimes[0]
                return String(format: "[定点] 每天 %02d:%02d 等%d个时间点", firstTime.hour, firstTime.minute, enabledTimes.count)
            }
        }
    }
}
