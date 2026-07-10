import SwiftUI
import UserNotifications
import AppKit
import Combine
import os

@MainActor
final class ReminderController: ObservableObject {
    private static let stylePreviewTimerID = UUID(uuidString: "00000000-0000-0000-0000-00000000A11E") ?? UUID()

    private enum SuspensionKind: Equatable {
        case screenLock
        case systemSleep
    }

    @Published var isResting: Bool = false

    // 多计时器支持
    private var timers: [UUID: Timer] = [:] // 每个计时器的 Timer
    private var restTimers: [UUID: Timer] = [:] // 每个计时器的休息 Timer
    private var restingTimers: Set<UUID> = [] // 正在休息的计时器
    private var restDueDates: [UUID: Date] = [:]

    // 定点提醒支持
    private var scheduledTimers: [UUID: Timer] = [:] // 定点提醒的 Timer，key 为 ScheduledTime.id
    private var scheduledTimerOwners: [UUID: UUID] = [:] // ScheduledTime.id -> TimerItem.id

    // 多通知管理
    private var overlayWindows: [UUID: NSWindow] = [:] // 每个计时器的通知窗口
    private var overlayEventIDs: [UUID: UUID] = [:]
    private var notificationOrder: [UUID] = [] // 通知显示顺序（从上到下）
    private var windowScreens: [UUID: NSScreen] = [:] // 记录每个窗口所在的屏幕
    private var overlayCardLocalRects: [UUID: NSRect] = [:] // 通知卡片在窗口内的真实响应区域
    private var overlayMouseLocalMonitor: Any?
    private var overlayMouseGlobalMonitor: Any?
    
    private let center = UNUserNotificationCenter.current()
    private var overlayWindow: NSWindow?  // 使用 NSWindow 基类以支持材质宿主 A/B 实验
    private weak var settingsRef: AppSettings?
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    private var workspaceWillSleepObserver: NSObjectProtocol?
    private var workspaceDidWakeObserver: NSObjectProtocol?
    private var suspensionStartedAt: Date?
    private var suspensionKind: SuspensionKind?
    private var lastRecoveryAt: Date?
    private let logger = EventLogger.shared
    private struct NotificationContent {
        var emoji: String
        var title: String
        var body: String
    }
    
    deinit {
        cleanupObservers()
    }
    
    private struct OverlayStyle {
        let backgroundColor: Color
        let backgroundOpacity: Double
        let stayDuration: Double
        let enableFadeOut: Bool
        let fadeOutDelay: Double
        let fadeOutDuration: Double
        let titleFontSize: Double
        let bodyFontSize: Double
        let iconSize: Double
        let cornerRadius: Double
        let contentSpacing: Double
        let useBlur: Bool
        let blurIntensity: Double
        let overlayWidth: Double
        let overlayHeight: Double
        let animationStyle: AppSettings.AnimationStyle
        let position: AppSettings.OverlayPosition
        let padding: Double
        let textColor: Color?
        let overlayMaterial: AppSettings.OverlayMaterial
        let liquidGlassStyle: AppSettings.LiquidGlassStyle
        let glassTintMode: AppSettings.OverlayGlassTintExperiment
        let glassTintColor: Color
        let glassTintAlpha: Double
        let glassTextColorMode: AppSettings.OverlayGlassTextColorMode
    }

    func ensurePermission() async {
        do {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            }
        } catch {
            logger.log("请求通知权限失败: \(error.localizedDescription)")
        }
    }

    func start(settings: AppSettings) {
        settingsRef = settings
        ensureLifecycleMonitoring()
        stopRuntime(markTimersOff: false)

        // 启动所有有效的计时器，根据各自的提醒类型调度
        let validTimers = settings.timers.filter { $0.isContentValid() }
        guard !validTimers.isEmpty else {
            print("⚠️ 无法开启：至少需要有一个内容有效的计时器")
            reconcileTimerStates(settings: settings)
            return
        }

        logger.log("开启计时器: 共 \(validTimers.count) 个, 模式 \(settings.notificationMode.rawValue)")

        var openedCount = 0
        for timer in validTimers {
            if startTimer(timer.id, settings: settings, showsStartNotification: false) {
                openedCount += 1
            }
        }
        reconcileTimerStates(settings: settings)

        // 用户主动批量开启时弹出一次通知
        if openedCount > 0 && settings.showStartNotification {
            Task {
                await self.sendStartNotification(settings: settings, count: openedCount)
            }
        }
    }

    func restoreEnabledTimers(settings: AppSettings) {
        settingsRef = settings
        ensureLifecycleMonitoring()
        stopRuntime(markTimersOff: false, closeNotifications: false)

        let enabledTimerIDs = settings.timers.filter(\.isRunning).map(\.id)
        for timerID in enabledTimerIDs {
            _ = startTimer(timerID, settings: settings, showsStartNotification: false)
        }
        reconcileTimerStates(settings: settings)
    }

    func isTimerScheduled(_ timerID: UUID, settings: AppSettings) -> Bool {
        timers[timerID] != nil ||
        restTimers[timerID] != nil ||
        scheduledTimerOwners.contains { $0.value == timerID }
    }

    func reconcileTimerStates(settings: AppSettings) {
        let timerIDs = settings.timers.map(\.id)
        for timerID in timerIDs where !settings.timers.contains(where: { $0.id == timerID && $0.isRunning }) && isTimerScheduled(timerID, settings: settings) {
            stopTimer(timerID, settings: settings)
        }

        for index in settings.timers.indices where settings.timers[index].isRunning && !isTimerScheduled(settings.timers[index].id, settings: settings) {
            settings.timers[index].isRunning = false
            settings.timers[index].startedAtEpoch = 0
        }
        updateAggregateRunningState(settings: settings)
    }

    private func setTimerSwitch(_ timerID: UUID, isOn: Bool, settings: AppSettings, startedAt: Date? = nil) {
        if let index = settings.timers.firstIndex(where: { $0.id == timerID }) {
            settings.timers[index].isRunning = isOn
            settings.timers[index].startedAtEpoch = isOn ? (startedAt ?? Date()).timeIntervalSince1970 : 0
        }
        updateAggregateRunningState(settings: settings)
    }

    private func updateAggregateRunningState(settings: AppSettings) {
        settings.isRunning = settings.timers.contains { $0.isRunning }
    }

    // MARK: - Interval Timer Scheduling

    @discardableResult
    private func scheduleIntervalTimer(for timer: TimerItem, settings: AppSettings) -> Bool {
        let now = Date()
        let nextDate = now.addingTimeInterval(timer.intervalSeconds)
        scheduleTimer(for: timer.id, fireAt: nextDate, interval: timer.intervalSeconds, settings: settings)
        logger.log("间隔计时器已安排: \(timer.displayName), 间隔 \(timer.intervalSeconds) 秒")
        return true
    }

    // MARK: - Scheduled Timer Scheduling

    @discardableResult
    private func scheduleScheduledTimers(for timer: TimerItem, settings: AppSettings) -> Bool {
        let scheduledTimes = timer.scheduledTimes
        guard !scheduledTimes.isEmpty else {
            logger.log("⚠️ 计时器 \(timer.displayName) 没有定点时间")
            return false
        }

        for scheduledTime in scheduledTimes {
            let nextFireDate = calculateNextFireDate(hour: scheduledTime.hour, minute: scheduledTime.minute)
            scheduleScheduledTimer(for: timer, timeID: scheduledTime.id, fireAt: nextFireDate, settings: settings)
        }

        logger.log("定点计时器已安排: \(timer.displayName), 共 \(scheduledTimes.count) 个时间点")
        return true
    }

    /// 计算下一个触发时间
    private func calculateNextFireDate(hour: Int, minute: Int) -> Date {
        ReminderRecoverySchedule.nextScheduledDate(hour: hour, minute: minute, now: Date())
    }

    /// 安排定点提醒定时器
    private func scheduleScheduledTimer(for timer: TimerItem, timeID: UUID, fireAt date: Date, settings: AppSettings) {
        if let existingTimer = scheduledTimers[timeID] {
            existingTimer.invalidate()
        }

        let t = Timer(fire: date, interval: 0, repeats: false) { [weak self, weak settings] _ in
            guard let self, let settings else { return }
            Task {
                await self.handleScheduledTimerFire(timerID: timer.id, timeID: timeID, settings: settings)
            }
        }
        self.scheduledTimers[timeID] = t
        self.scheduledTimerOwners[timeID] = timer.id
        RunLoop.main.add(t, forMode: .common)

        logger.log("定点提醒已安排: \(timer.displayName) - \(date.formatted(date: .abbreviated, time: .shortened))")
    }

    private func handleScheduledTimerFire(timerID: UUID, timeID: UUID, settings: AppSettings) async {
        scheduledTimers.removeValue(forKey: timeID)
        scheduledTimerOwners.removeValue(forKey: timeID)

        guard let timer = settings.timers.first(where: { $0.id == timerID }),
              timer.isRunning,
              let scheduledTime = timer.scheduledTimes.first(where: { $0.id == timeID }) else {
            return
        }

        await sendScheduledNotification(timer: timer, settings: settings)

        guard let currentTimer = settings.timers.first(where: { $0.id == timerID }),
              currentTimer.isRunning,
              currentTimer.scheduledTimes.contains(where: { $0.id == timeID }) else {
            return
        }

        let nextFireDate = calculateNextFireDate(hour: scheduledTime.hour, minute: scheduledTime.minute)
        scheduleScheduledTimer(for: currentTimer, timeID: timeID, fireAt: nextFireDate, settings: settings)
    }

    /// 发送定点提醒通知
    private func sendScheduledNotification(timer: TimerItem, settings: AppSettings) async {
        logger.log("定点提醒触发: \(timer.displayName)")
        await sendNotification(for: timer, settings: settings, triggerRestOnDismiss: false)
    }

    func stop() {
        stopRuntime(markTimersOff: true)
        logger.log("计时器已关闭")
    }

    private func stopRuntime(markTimersOff: Bool, closeNotifications: Bool = true) {
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()

        for (_, timer) in restTimers {
            timer.invalidate()
        }
        restTimers.removeAll()
        restingTimers.removeAll()
        restDueDates.removeAll()

        // 停止定点提醒计时器
        for (_, timer) in scheduledTimers {
            timer.invalidate()
        }
        scheduledTimers.removeAll()
        scheduledTimerOwners.removeAll()

        if var allTimers = settingsRef?.timers {
            for i in allTimers.indices {
                if markTimersOff {
                    allTimers[i].isRunning = false
                }
                allTimers[i].startedAtEpoch = 0
            }
            settingsRef?.timers = allTimers
            settingsRef?.isRunning = allTimers.contains { $0.isRunning }
        }

        isResting = false
        if closeNotifications {
            for (_, eventID) in overlayEventIDs {
                settingsRef?.resolveReminderEvent(eventID, as: .missed)
            }
            overlayEventIDs.removeAll()
            closeOverlay()
        }
    }
    
    // 启动单个计时器
    @discardableResult
    func startTimer(_ timerID: UUID, settings: AppSettings, showsStartNotification: Bool = true) -> Bool {
        guard let timer = settings.timers.first(where: { $0.id == timerID }),
              timer.isContentValid() else {
            print("⚠️ 无法开启计时器：内容无效")
            setTimerSwitch(timerID, isOn: false, settings: settings)
            return false
        }

        settingsRef = settings
        ensureLifecycleMonitoring()

        // 如果已经开启，先取消旧调度再重排
        if isTimerScheduled(timerID, settings: settings) {
            stopTimer(timerID, settings: settings)
        }

        let didSchedule: Bool
        switch timer.reminderType {
        case .interval:
            didSchedule = scheduleIntervalTimer(for: timer, settings: settings)
        case .scheduled:
            didSchedule = scheduleScheduledTimers(for: timer, settings: settings)
        }

        guard didSchedule else {
            setTimerSwitch(timerID, isOn: false, settings: settings)
            return false
        }

        setTimerSwitch(timerID, isOn: true, settings: settings, startedAt: Date())

        logger.log("开启计时器: \(timer.displayName)")

        // 用户主动开启单个计时器时显示通知
        if showsStartNotification && settings.showStartNotification {
            Task {
                await self.sendSingleTimerStartNotification(timerName: timer.displayName, settings: settings)
            }
        }
        return true
    }
    
    // 停止单个计时器
    func stopTimer(_ timerID: UUID, settings: AppSettings) {
        // 停止主计时器
        if let timer = timers[timerID] {
            timer.invalidate()
            timers.removeValue(forKey: timerID)
        }

        // 停止休息计时器
        if let restTimer = restTimers[timerID] {
            restTimer.invalidate()
            restTimers.removeValue(forKey: timerID)
        }
        restingTimers.remove(timerID)
        restDueDates.removeValue(forKey: timerID)
        updateRestingState()

        invalidateScheduledTimers(for: timerID)

        setTimerSwitch(timerID, isOn: false, settings: settings)
        
        // 关闭该计时器的通知弹窗（如果有）
        if let window = overlayWindows[timerID] {
            settings.resolveReminderEvent(overlayEventIDs[timerID], as: .missed)
            overlayEventIDs.removeValue(forKey: timerID)
            // 从字典和顺序中移除
            overlayWindows.removeValue(forKey: timerID)
            windowScreens.removeValue(forKey: timerID)
            overlayCardLocalRects.removeValue(forKey: timerID)
            
            if let index = notificationOrder.firstIndex(of: timerID) {
                notificationOrder.remove(at: index)
            }
            
            // 立即重新布局其他通知
            relayoutNotifications(settings: settings)
            removeOverlayMouseTrackingIfNeeded()
            
            // 然后关闭窗口（使用渐隐动画）
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 0
            }, completionHandler: { [weak window] in
                window?.orderOut(nil)
                window?.close()
            })
        }
        
        if let timerName = settings.timers.first(where: { $0.id == timerID })?.displayName {
            logger.log("关闭计时器: \(timerName)")
        }
    }

    private func invalidateScheduledTimers(for timerID: UUID) {
        let ownedTimeIDs = scheduledTimerOwners
            .filter { $0.value == timerID }
            .map(\.key)
        for timeID in ownedTimeIDs {
            if let scheduledTimer = scheduledTimers[timeID] {
                scheduledTimer.invalidate()
            }
            scheduledTimers.removeValue(forKey: timeID)
            scheduledTimerOwners.removeValue(forKey: timeID)
        }
    }

    func cleanup() {
        stopRuntime(markTimersOff: false)
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        // 退出应用时只清理真实调度，不重置持久化开关状态
        if var timers = settingsRef?.timers {
            for i in timers.indices {
                timers[i].lastFireEpoch = 0
                timers[i].startedAtEpoch = 0
            }
            settingsRef?.timers = timers
            settingsRef?.isRunning = timers.contains { $0.isRunning }
        }
        logger.log("应用清理完成，计时器开关状态已保留")
    }

    private func scheduleTimer(for timerID: UUID, fireAt date: Date, interval: TimeInterval, settings: AppSettings) {
        // 更新触发时间，以便UI能正确显示倒计时
        if let index = settings.timers.firstIndex(where: { $0.id == timerID }) {
            settings.timers[index].lastFireEpoch = date.timeIntervalSince1970 - interval
        }

        let t = Timer(fire: date, interval: interval, repeats: true) { [weak self, weak settings] _ in
            guard let self, let settings else { return }
            Task {
                if let timerItem = settings.timers.first(where: { $0.id == timerID }) {
                    await self.sendNotification(for: timerItem, settings: settings)
                }
            }
        }
        self.timers[timerID] = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func scheduleRestTimer(for timerID: UUID, timerItem: TimerItem, settings: AppSettings, fireAt date: Date? = nil) {
        restingTimers.insert(timerID)
        updateRestingState()
        let restInterval = timerItem.restSeconds
        let fireDate = date ?? Date().addingTimeInterval(restInterval)
        restDueDates[timerID] = fireDate

        // 更新UI状态
        if let index = settings.timers.firstIndex(where: { $0.id == timerID }) {
            settings.timers[index].lastFireEpoch = fireDate.timeIntervalSince1970 - restInterval
        }

        let t = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self, weak settings] _ in
            guard let self, let settings else { return }
            self.restTimers.removeValue(forKey: timerID)
            self.restDueDates.removeValue(forKey: timerID)
            self.restingTimers.remove(timerID)
            self.updateRestingState()
            // 休息结束后，安排下一次常规通知
            if let timerItem = settings.timers.first(where: { $0.id == timerID }) {
                self.scheduleTimer(
                    for: timerID,
                    fireAt: Date().addingTimeInterval(timerItem.intervalSeconds),
                    interval: timerItem.intervalSeconds,
                    settings: settings
                )
            }
        }
        self.restTimers[timerID] = t
        RunLoop.main.add(t, forMode: .common)
    }
    
    private func updateRestingState() {
        isResting = !restingTimers.isEmpty
    }

    func sendTest(for timer: TimerItem, settings: AppSettings, skipSound: Bool = false) async {
        // 验证内容是否有效
        guard timer.isContentValid() else {
            print("⚠️ 无法发送测试通知：标题、描述和Emoji至少需要有一项不为空")
            return
        }

        // 构建测试通知内容，标记为"测试"
        var testContent = buildContent(timer: timer)
        testContent.title = "[测试] " + testContent.title

        // 测试通知不影响常规计时
        await sendNotification(for: timer, settings: settings, isTest: true, content: testContent, triggerRestOnDismiss: false, skipSound: skipSound)
    }

    func sendStylePreview(settings: AppSettings) async {
        let previewTimer = TimerItem(
            id: Self.stylePreviewTimerID,
            emoji: "✨",
            title: "外观预览",
            body: "这是一条专用测试通知",
            intervalSeconds: 5,
            customColor: nil
        )

        let previewContent = NotificationContent(
            emoji: previewTimer.emoji,
            title: "[外观预览] \(previewTimer.title)",
            body: previewTimer.body
        )

        let baseStyle = buildOverlayStyle(timer: previewTimer, settings: settings)
        let previewStyle = OverlayStyle(
            backgroundColor: baseStyle.backgroundColor,
            backgroundOpacity: baseStyle.backgroundOpacity,
            stayDuration: 24 * 60 * 60,
            enableFadeOut: false,
            fadeOutDelay: 0,
            fadeOutDuration: 0,
            titleFontSize: baseStyle.titleFontSize,
            bodyFontSize: baseStyle.bodyFontSize,
            iconSize: baseStyle.iconSize,
            cornerRadius: baseStyle.cornerRadius,
            contentSpacing: baseStyle.contentSpacing,
            useBlur: baseStyle.useBlur,
            blurIntensity: baseStyle.blurIntensity,
            overlayWidth: baseStyle.overlayWidth,
            overlayHeight: baseStyle.overlayHeight,
            animationStyle: baseStyle.animationStyle,
            position: baseStyle.position,
            padding: baseStyle.padding,
            textColor: baseStyle.textColor,
            overlayMaterial: baseStyle.overlayMaterial,
            liquidGlassStyle: baseStyle.liquidGlassStyle,
            glassTintMode: baseStyle.glassTintMode,
            glassTintColor: baseStyle.glassTintColor,
            glassTintAlpha: baseStyle.glassTintAlpha,
            glassTextColorMode: baseStyle.glassTextColorMode
        )

        await sendNotification(
            for: previewTimer,
            settings: settings,
            isTest: true,
            content: previewContent,
            overlayStyle: previewStyle,
            triggerRestOnDismiss: false,
            skipSound: true
        )
    }

    func closeStylePreview() {
        let timerID = Self.stylePreviewTimerID
        overlayEventIDs.removeValue(forKey: timerID)
        windowScreens.removeValue(forKey: timerID)
        overlayCardLocalRects.removeValue(forKey: timerID)
        notificationOrder.removeAll { $0 == timerID }

        guard let window = overlayWindows.removeValue(forKey: timerID) else { return }
        window.orderOut(nil)
        window.close()
        removeOverlayMouseTrackingIfNeeded()
    }

    private func sendNotification(for timer: TimerItem, settings: AppSettings, isTest: Bool = false, content: NotificationContent? = nil, overlayStyle: OverlayStyle? = nil, triggerRestOnDismiss: Bool = true, skipSound: Bool = false, showsActionButtons: Bool = true) async {
        if !isTest {
            // 更新计时器的 lastFireEpoch
            if let index = settings.timers.firstIndex(where: { $0.id == timer.id }) {
                settings.timers[index].markFiredNow()
            }
        }

        let payload = content ?? buildContent(timer: timer)
        let style = overlayStyle ?? buildOverlayStyle(timer: timer, settings: settings)
        let eventID = isTest ? nil : settings.recordReminderFired(timerID: timer.id, scheduledAt: Date(), firedAt: Date())
        logger.log("发送通知: \(payload.title.isEmpty ? "(无标题)" : payload.title) | 模式 \(settings.notificationMode.rawValue)\(isTest ? " [测试]" : "")\(skipSound ? " [静音]" : "")")

        // 播放提示音
        if !skipSound {
            playSound(for: timer)
        }

        switch settings.notificationMode {
        case .system:
            await sendSystemNotification(content: payload)
            settings.resolveReminderEvent(eventID, as: .missed)
        case .overlay:
            showOverlayNotification(timer: timer, settings: settings, content: payload, style: style, triggerRestOnDismiss: triggerRestOnDismiss, eventID: eventID, showsActionButtons: showsActionButtons)
        }
    }

    /// 播放提示音
    private func playSound(for timer: TimerItem) {
        guard let soundName = timer.soundName else {
            logger.log("提示音已禁用（静音）")
            return
        }
        DispatchQueue.main.async {
            if let sound = NSSound(named: NSSound.Name(soundName)) {
                sound.play()
                self.logger.log("播放提示音: \(soundName)")
            } else {
                self.logger.log("⚠️ 未找到提示音: \(soundName)")
            }
        }
    }
    
    private func sendStartLikeNotification(settings: AppSettings, title: String, body: String) async {
        // 使用第一个计时器来发送启动通知
        guard let firstTimer = settings.timers.first else { return }

        let content = NotificationContent(
            emoji: "", // 不使用 emoji，由视图层显示图标
            title: title,
            body: body
        )
        let style = buildStartOverlayStyle(settings: settings)
        logger.log(title)
        await sendNotification(
            for: firstTimer,
            settings: settings,
            isTest: true,
            content: content,
            overlayStyle: style,
            triggerRestOnDismiss: false,
            skipSound: true, // 启动通知不播放声音
            showsActionButtons: false
        )
    }
    
    private func sendStartNotification(settings: AppSettings, count: Int) async {
        await sendStartLikeNotification(
            settings: settings,
            title: "已开启",
            body: "\(count)个计时器"
        )
    }
    
    private func sendSingleTimerStartNotification(timerName: String, settings: AppSettings) async {
        await sendStartLikeNotification(
            settings: settings,
            title: "已开启",
            body: timerName
        )
    }
    
    private func sendResetNotification(settings: AppSettings) async {
        await sendStartLikeNotification(
            settings: settings,
            title: "已重置",
            body: ""
        )
    }
    
    private func buildContent(timer: TimerItem, customTitle: String? = nil, customBody: String? = nil, customEmoji: String? = nil) -> NotificationContent {
        let emoji = (customEmoji ?? timer.emoji).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (customTitle ?? timer.title).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = customBody ?? timer.body
        return NotificationContent(emoji: emoji, title: title, body: body)
    }
    
    private func buildOverlayStyle(timer: TimerItem, settings: AppSettings) -> OverlayStyle {
        // 计时器自定义颜色优先于全局配置
        let backgroundColor = timer.customColor?.toColor() ?? settings.getOverlayColor()

        return OverlayStyle(
            backgroundColor: backgroundColor,
            backgroundOpacity: settings.overlayOpacity,
            stayDuration: overlayStayDuration(for: timer),
            enableFadeOut: settings.overlayEnableFadeOut,
            fadeOutDelay: settings.overlayFadeOutDelay,
            fadeOutDuration: settings.overlayFadeOutDuration,
            titleFontSize: settings.overlayTitleFontSize,
            bodyFontSize: settings.overlayBodyFontSize,
            iconSize: settings.overlayIconSize,
            cornerRadius: settings.overlayCornerRadius,
            contentSpacing: settings.overlayContentSpacing,
            useBlur: settings.overlayUseBlur,
            blurIntensity: settings.overlayBlurIntensity,
            overlayWidth: settings.overlayWidth,
            overlayHeight: settings.overlayHeight,
            animationStyle: settings.animationStyle,
            position: settings.overlayPosition,
            padding: settings.overlayEdgePadding,
            textColor: nil,
            overlayMaterial: settings.overlayMaterial,
            liquidGlassStyle: settings.liquidGlassStyle,
            glassTintMode: settings.overlayGlassTintModeExperiment,
            glassTintColor: settings.overlayGlassTintColor,
            glassTintAlpha: settings.overlayGlassTintAlpha,
            glassTextColorMode: settings.overlayGlassTextColorMode
        )
    }

    private func overlayStayDuration(for timer: TimerItem) -> Double {
        if timer.stayDurationMode == .fixed {
            return max(1, timer.stayDurationSeconds)
        }

        switch timer.reminderType {
        case .interval:
            return max(1, timer.intervalSeconds)
        case .scheduled:
            let scheduledTimes = timer.scheduledTimes
            guard !scheduledTimes.isEmpty else { return max(1, settingsRef?.overlayStayDuration ?? 5) }
            let nextDates = scheduledTimes.map { calculateNextFireDate(hour: $0.hour, minute: $0.minute) }
            let nextDate = nextDates.min() ?? Date().addingTimeInterval(300)
            return max(1, nextDate.timeIntervalSince(Date()))
        }
    }
    
    private func buildStartOverlayStyle(settings: AppSettings) -> OverlayStyle {
        let isDark = isDarkModeEnabled()
        let background = isDark ? Color(red: 0.12, green: 0.14, blue: 0.16) : Color.white
        let opacity = isDark ? 0.85 : 0.95
        let textColor: Color = isDark ? .white : Color(red: 0.12, green: 0.14, blue: 0.16)

        return OverlayStyle(
            backgroundColor: background,
            backgroundOpacity: opacity,
            stayDuration: 1.5,
            enableFadeOut: false, // 启动提示不单独淡化内容，只做整体淡入淡出
            fadeOutDelay: 0,
            fadeOutDuration: 0.25,
            titleFontSize: 14,
            bodyFontSize: 12,
            iconSize: 18,
            cornerRadius: 12,
            contentSpacing: 6,
            useBlur: true,
            blurIntensity: 0.5,
            overlayWidth: 120,
            overlayHeight: 60,
            animationStyle: .fade,
            position: settings.overlayPosition,
            padding: settings.overlayEdgePadding,
            textColor: textColor,
            overlayMaterial: settings.overlayMaterial,
            liquidGlassStyle: settings.liquidGlassStyle,
            glassTintMode: settings.overlayGlassTintModeExperiment,
            glassTintColor: settings.overlayGlassTintColor,
            glassTintAlpha: settings.overlayGlassTintAlpha,
            glassTextColorMode: settings.overlayGlassTextColorMode
        )
    }

    private func isDarkModeEnabled() -> Bool {
        guard let appearance = NSApp?.effectiveAppearance else { return true }
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua
    }
    
    // MARK: - Sleep / Wake Recovery

    private func ensureLifecycleMonitoring() {
        let distributedCenter = DistributedNotificationCenter.default()

        if lockObserver == nil {
            lockObserver = distributedCenter.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recordSuspensionStart(kind: .screenLock)
                }
            }
        }

        if unlockObserver == nil {
            unlockObserver = distributedCenter.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleRecovery()
                }
            }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        if workspaceWillSleepObserver == nil {
            workspaceWillSleepObserver = workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recordSuspensionStart(kind: .systemSleep)
                }
            }
        }

        if workspaceDidWakeObserver == nil {
            workspaceDidWakeObserver = workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleRecovery()
                }
            }
        }
    }

    private func recordSuspensionStart(kind: SuspensionKind) {
        if suspensionStartedAt == nil {
            suspensionStartedAt = Date()
        }
        if kind == .systemSleep {
            suspensionKind = .systemSleep
        } else if suspensionKind == nil {
            suspensionKind = .screenLock
        }
    }
    
    nonisolated private func cleanupObservers() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let center = DistributedNotificationCenter.default()
            if let observer = self.lockObserver {
                center.removeObserver(observer)
            }
            if let observer = self.unlockObserver {
                center.removeObserver(observer)
            }
            let workspaceCenter = NSWorkspace.shared.notificationCenter
            if let observer = self.workspaceWillSleepObserver {
                workspaceCenter.removeObserver(observer)
            }
            if let observer = self.workspaceDidWakeObserver {
                workspaceCenter.removeObserver(observer)
            }
            if let monitor = self.overlayMouseLocalMonitor {
                NSEvent.removeMonitor(monitor)
                self.overlayMouseLocalMonitor = nil
            }
            if let monitor = self.overlayMouseGlobalMonitor {
                NSEvent.removeMonitor(monitor)
                self.overlayMouseGlobalMonitor = nil
            }
        }
    }
    
    private func handleRecovery() {
        guard let settings = settingsRef else { return }

        let now = Date()
        if let lastRecoveryAt, now.timeIntervalSince(lastRecoveryAt) < 1 {
            return
        }
        lastRecoveryAt = now

        let suspensionStart = suspensionStartedAt
        let didSleep = suspensionKind == .systemSleep
        suspensionStartedAt = nil
        suspensionKind = nil
        recoverActiveTimers(settings: settings, suspendedFrom: didSleep ? suspensionStart : nil, now: now)

        let elapsed = suspensionStart.map { now.timeIntervalSince($0) } ?? 0
        if ReminderRecoverySchedule.shouldResetInterval(isEnabled: settings.resetOnWakeEnabled, elapsed: elapsed) {
            resetIntervalTimersAfterUnlock(settings: settings)
        }
    }

    private func recoverActiveTimers(settings: AppSettings, suspendedFrom: Date?, now: Date) {
        let activeTimers = settings.timers.filter { $0.isRunning && $0.isContentValid() }

        for timer in activeTimers {
            switch timer.reminderType {
            case .interval:
                if let activeTimer = timers[timer.id] {
                    activeTimer.invalidate()
                    timers.removeValue(forKey: timer.id)
                }

                if restingTimers.contains(timer.id) {
                    if let restTimer = restTimers[timer.id] {
                        restTimer.invalidate()
                        restTimers.removeValue(forKey: timer.id)
                    }
                    let restDueDate = restDueDates[timer.id] ?? Date(timeIntervalSince1970: timer.lastFireEpoch + timer.restSeconds)
                    scheduleRestTimer(for: timer.id, timerItem: timer, settings: settings, fireAt: max(now, restDueDate))
                } else {
                    let nextDate = ReminderRecoverySchedule.nextIntervalDate(
                        lastFireEpoch: timer.lastFireEpoch,
                        interval: timer.intervalSeconds,
                        now: now
                    )
                    scheduleTimer(for: timer.id, fireAt: nextDate, interval: timer.intervalSeconds, settings: settings)
                }

            case .scheduled:
                invalidateScheduledTimers(for: timer.id)

                if let suspendedFrom {
                    for missedTime in ReminderRecoverySchedule.missedScheduledTimes(
                        times: timer.scheduledTimes,
                        from: suspendedFrom,
                        through: now
                    ) {
                        logger.log("定点提醒已错过（系统休眠）：\(timer.displayName) - \(missedTime.formattedTime())")
                    }
                }

                for scheduledTime in timer.scheduledTimes {
                    let nextDate = ReminderRecoverySchedule.nextScheduledDate(
                        hour: scheduledTime.hour,
                        minute: scheduledTime.minute,
                        now: now
                    )
                    scheduleScheduledTimer(for: timer, timeID: scheduledTime.id, fireAt: nextDate, settings: settings)
                }
            }
        }

        updateRestingState()
        logger.log("系统唤醒后已恢复 \(activeTimers.count) 个计时器")
    }
    
    private func resetIntervalTimersAfterUnlock(settings: AppSettings) {
        let now = Date()
        let intervalTimers = settings.timers.filter { $0.isRunning && $0.reminderType == .interval && $0.isContentValid() }
        
        // 只重置已开启的循环提醒，定点提醒保持原计划
        for timer in intervalTimers {
            if let activeTimer = timers[timer.id] {
                activeTimer.invalidate()
                timers.removeValue(forKey: timer.id)
            }
            if let restTimer = restTimers[timer.id] {
                restTimer.invalidate()
                restTimers.removeValue(forKey: timer.id)
            }
            restingTimers.remove(timer.id)
            restDueDates.removeValue(forKey: timer.id)
            let nextDate = now.addingTimeInterval(timer.intervalSeconds)
            scheduleTimer(for: timer.id, fireAt: nextDate, interval: timer.intervalSeconds, settings: settings)
            setTimerSwitch(timer.id, isOn: true, settings: settings, startedAt: now)
        }
        updateRestingState()
        
        Task {
            if settings.showStartNotification {
                await sendResetNotification(settings: settings)
            }
        }
        logger.log("解锁后重置循环提醒倒计时")
    }

    private func sendSystemNotification(content payload: NotificationContent) async {
        await ensurePermission()

        let notificationContent = UNMutableNotificationContent()
        let emoji = payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if !emoji.isEmpty {
            notificationContent.title = title.isEmpty ? emoji : "\(emoji) \(title)"
        } else {
            notificationContent.title = title.isEmpty ? "提醒" : title
        }

        notificationContent.body = payload.body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notificationContent,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            logger.log("发送系统通知失败: \(error.localizedDescription)")
        }
    }
    
    private func showOverlayNotification(timer: TimerItem, settings: AppSettings, content: NotificationContent, style: OverlayStyle, triggerRestOnDismiss: Bool, eventID: UUID? = nil, showsActionButtons: Bool = true) {
        // 关闭该计时器的旧通知（同个计时器的通知会覆盖）
        if let existingWindow = overlayWindows[timer.id] {
            settings.resolveReminderEvent(overlayEventIDs[timer.id], as: .missed)
            overlayEventIDs.removeValue(forKey: timer.id)
            // 立即从字典和顺序中移除，防止新通知计算位置时把旧窗口算进去
            overlayWindows.removeValue(forKey: timer.id)
            windowScreens.removeValue(forKey: timer.id)
            overlayCardLocalRects.removeValue(forKey: timer.id)
            
            if let index = notificationOrder.firstIndex(of: timer.id) {
                notificationOrder.remove(at: index)
            }
            
            // 立即关闭旧窗口（不等待、不动画，直接关闭）
            existingWindow.alphaValue = 0
            existingWindow.orderOut(nil)
            existingWindow.close()
            
            // 重新布局其他通知（如果有的话）
            if !overlayWindows.isEmpty {
                relayoutNotifications(settings: settings)
            }
        }
        
        // 获取主屏幕或第一个可用屏幕
        let screen: NSScreen?
        switch settings.screenSelection {
        case .active:
            // 活跃屏幕：包含当前获得焦点的窗口所在的屏幕
            screen = NSScreen.main ?? NSScreen.screens.first
        case .mouse:
            // 鼠标所在屏幕：根据鼠标光标位置确定屏幕
            let mouseLocation = NSEvent.mouseLocation
            screen = NSScreen.screens.first { screen in
                screen.frame.contains(mouseLocation)
            } ?? NSScreen.main ?? NSScreen.screens.first
        }
        
        guard let screen else {
            logger.log("未找到可用屏幕，遮罩通知未显示")
            return
        }
        let screenFrame = screen.visibleFrame
        
        let windowWidth: CGFloat = style.overlayWidth
        let windowHeight: CGFloat = style.overlayHeight
        let padding: CGFloat = style.padding
        
        // 为动画添加缓冲区，避免裁切感
        let buffer: CGFloat = 100
        
        // 计算新通知的位置：在所有现有通知的下方
        let verticalSpacing: CGFloat = 12 // 通知之间的间隔
        var totalOffset: CGFloat = 0
        
        // 计算已有通知的总高度（只计算在同一屏幕上的通知）
        for existingTimerID in notificationOrder {
            if let existingWindow = overlayWindows[existingTimerID],
               windowScreens[existingTimerID] === screen {
                totalOffset += windowHeight + verticalSpacing
            }
        }
        
        // 检查是否会超出屏幕边界
        let maxOffset: CGFloat
        switch style.position {
        case .topLeft, .topRight, .topCenter:
            // 从上往下堆叠，检查下边界
            maxOffset = screenFrame.height - windowHeight - padding * 2
        case .bottomLeft, .bottomRight, .bottomCenter:
            // 从下往上堆叠，检查上边界
            maxOffset = screenFrame.height - windowHeight - padding * 2
        case .center:
            // 中心堆叠，检查上边界
            maxOffset = (screenFrame.height / 2) - padding
        }
        
        // 如果超出边界，限制偏移量
        if totalOffset > maxOffset {
            totalOffset = maxOffset
            logger.log("⚠️ 通知数量过多，部分通知可能重叠")
        }
        
        // 窗口尺寸包含缓冲区
        let expandedWidth: CGFloat
        let expandedHeight: CGFloat
        
        // 窗口位置：基于位置设置，垂直方向错开
        let windowRect: NSRect
        switch style.position {
        case .topLeft:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer
            windowRect = NSRect(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - expandedHeight - padding - totalOffset,
                width: expandedWidth,
                height: expandedHeight
            )
        case .topRight:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer
            windowRect = NSRect(
                x: screenFrame.maxX - expandedWidth - padding,
                y: screenFrame.maxY - expandedHeight - padding - totalOffset,
                width: expandedWidth,
                height: expandedHeight
            )
        case .bottomLeft:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer + 80
            windowRect = NSRect(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding + totalOffset,
                width: expandedWidth,
                height: expandedHeight
            )
        case .bottomRight:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer + 80
            windowRect = NSRect(
                x: screenFrame.maxX - expandedWidth - padding,
                y: screenFrame.minY + padding + totalOffset,
                width: expandedWidth,
                height: expandedHeight
            )
        case .topCenter:
            expandedWidth = windowWidth
            expandedHeight = windowHeight + buffer
            windowRect = NSRect(
                x: screenFrame.midX - expandedWidth / 2,
                y: screenFrame.maxY - expandedHeight - padding - totalOffset,
                width: expandedWidth,
                height: expandedHeight
            )
        case .center:
            expandedWidth = windowWidth + buffer
            expandedHeight = windowHeight + buffer
            // center 位置向上堆叠
            windowRect = NSRect(
                x: screenFrame.midX - expandedWidth / 2,
                y: screenFrame.midY - expandedHeight / 2 - totalOffset,
                width: expandedWidth,
                height: expandedHeight
            )
        case .bottomCenter:
            expandedWidth = windowWidth
            expandedHeight = windowHeight + buffer + 80
            windowRect = NSRect(
                x: screenFrame.midX - expandedWidth / 2,
                y: screenFrame.minY + padding + totalOffset,
                width: expandedWidth,
                height: expandedHeight
            )
        }
        
        let window = makeOverlayWindow(contentRect: windowRect, settings: settings)
        let cardLocalRect = overlayCardLocalRect(
            expandedWidth: expandedWidth,
            expandedHeight: expandedHeight,
            cardWidth: windowWidth,
            cardHeight: windowHeight,
            padding: padding,
            position: style.position
        )

        let overlayView = OverlayNotificationView(
            emoji: content.emoji,
            title: content.title,
            message: content.body,
            backgroundColor: style.backgroundColor,
            backgroundOpacity: style.backgroundOpacity,
            stayDuration: style.stayDuration,
            enableFadeOut: style.enableFadeOut,
            fadeOutDelay: style.fadeOutDelay,
            fadeOutDuration: style.fadeOutDuration,
            titleFontSize: style.titleFontSize,
            bodyFontSize: style.bodyFontSize,
            iconSize: style.iconSize,
            cornerRadius: style.cornerRadius,
            contentSpacing: style.contentSpacing,
            useBlur: style.useBlur,
            blurIntensity: style.blurIntensity,
            overlayWidth: style.overlayWidth,
            overlayHeight: style.overlayHeight,
            animationStyle: style.animationStyle,
            position: style.position,
            padding: padding,
            textColor: style.textColor,
            overlayMaterial: style.overlayMaterial,
            liquidGlassStyle: style.liquidGlassStyle,
            glassTintMode: style.glassTintMode,
            glassTintColor: style.glassTintColor,
            glassTintAlpha: style.glassTintAlpha,
            glassTextColorMode: style.glassTextColorMode,
            showsActionButtons: showsActionButtons,
            onDismiss: { [weak self, weak window, timerID = timer.id] reason in
                Task {
                    guard let self, let w = window else { return }
                    // 检查是否是该计时器的窗口（防止处理已被替换的旧窗口）
                    if let current = self.overlayWindows[timerID], current === w {
                        let resolvedStatus: ReminderEventStatus
                        switch reason {
                        case .completed:
                            resolvedStatus = .completed
                        case .ignored:
                            resolvedStatus = .ignored
                        case .missed:
                            resolvedStatus = .missed
                        }
                        settings.resolveReminderEvent(self.overlayEventIDs[timerID], as: resolvedStatus)
                        self.overlayEventIDs.removeValue(forKey: timerID)

                        // 从字典和顺序中移除（先移除再关闭，确保重新布局时不会计算它）
                        self.overlayWindows.removeValue(forKey: timerID)
                        self.overlayCardLocalRects.removeValue(forKey: timerID)
                        
                        if let index = self.notificationOrder.firstIndex(of: timerID) {
                            self.notificationOrder.remove(at: index)
                        }
                        
                        self.windowScreens.removeValue(forKey: timerID)
                        
                        // 立即重新布局其他通知（带动画的上移）
                        self.relayoutNotifications(settings: settings)
                        self.removeOverlayMouseTrackingIfNeeded()
                        
                        // 然后关闭窗口（使用渐隐动画）
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.2
                            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                            w.animator().alphaValue = 0
                        }, completionHandler: { [weak w] in
                            w?.orderOut(nil)
                            w?.close()
                        })
                        
                        // 只有循环提醒类型且用户主动处理通知时才触发休息机制
                        if triggerRestOnDismiss && reason != .missed && timer.reminderType == .interval && timer.isRestEnabled {
                            // 停止当前计时器的定时器
                            if let t = self.timers[timerID] {
                                t.invalidate()
                                self.timers.removeValue(forKey: timerID)
                            }
                            // 开始休息
                            self.scheduleRestTimer(for: timerID, timerItem: timer, settings: settings)
                        }
                    } else {
                        // 该窗口已被新窗口替换，仅需关闭它，不做其他处理
                        w.alphaValue = 0
                        w.orderOut(nil)
                        w.close()
                    }
                    
                    // 兼容旧的单窗口模式
                    if let current = self.overlayWindow, current === w {
                        w.alphaValue = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak w] in
                            w?.orderOut(nil)
                            w?.close()
                        }
                        self.overlayWindow = nil
                    }
                }
            }
        )
        
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 14, *) {
            hostingView.layer?.wantsExtendedDynamicRangeContent = true
        }
        window.contentView = hostingView
        #if DEBUG
        if settings.overlayWindowHostExperiment == .focusLiteWindow {
            window.makeFirstResponder(hostingView)
        }
        #endif
        // 使用 orderFrontRegardless 确保窗口显示在最前方，即使在全屏模式下
        window.orderFrontRegardless()
        
        // 添加到窗口字典和顺序列表
        self.overlayWindows[timer.id] = window
        self.overlayCardLocalRects[timer.id] = cardLocalRect
        if let eventID {
            self.overlayEventIDs[timer.id] = eventID
        }
        self.notificationOrder.append(timer.id)
        self.windowScreens[timer.id] = screen // 记录窗口所在的屏幕
        ensureOverlayMouseTracking()
        updateOverlayMouseEventPassthrough()
    }

    private func makeOverlayWindow(contentRect: NSRect, settings: AppSettings) -> NSWindow {
        #if DEBUG
        switch settings.overlayWindowHostExperiment {
        case .currentPanel:
            return makeOverlayPanel(
                contentRect: contentRect,
                level: .popUpMenu,
                hasShadow: true
            )
        case .panelFloatingLevel:
            return makeOverlayPanel(
                contentRect: contentRect,
                level: .floating,
                hasShadow: true
            )
        case .windowFloating:
            return makeOverlayPlainWindow(
                contentRect: contentRect,
                level: .floating,
                hasShadow: true
            )
        case .focusLiteWindow:
            return makeOverlayFocusLiteWindow(
                contentRect: contentRect,
                level: .floating,
                hasShadow: true
            )
        }
        #else
        return makeOverlayPanel(
            contentRect: contentRect,
            level: .popUpMenu,
            hasShadow: true
        )
        #endif
    }

    private func overlayCardLocalRect(expandedWidth: CGFloat, expandedHeight: CGFloat, cardWidth: CGFloat, cardHeight: CGFloat, padding: CGFloat, position: AppSettings.OverlayPosition) -> NSRect {
        let x: CGFloat
        let y: CGFloat

        switch position {
        case .topLeft:
            x = padding
            y = expandedHeight - padding - cardHeight
        case .topRight:
            x = expandedWidth - padding - cardWidth
            y = expandedHeight - padding - cardHeight
        case .bottomLeft:
            x = padding
            y = padding + 80
        case .bottomRight:
            x = expandedWidth - padding - cardWidth
            y = padding + 80
        case .topCenter:
            x = (expandedWidth - cardWidth) / 2
            y = expandedHeight - padding - cardHeight
        case .center:
            x = (expandedWidth - cardWidth) / 2
            y = (expandedHeight - cardHeight) / 2
        case .bottomCenter:
            x = (expandedWidth - cardWidth) / 2
            y = padding + 80
        }

        return NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
    }

    private func ensureOverlayMouseTracking() {
        if overlayMouseLocalMonitor == nil {
            overlayMouseLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
                Task { @MainActor in
                    self?.updateOverlayMouseEventPassthrough()
                }
                return event
            }
        }

        if overlayMouseGlobalMonitor == nil {
            overlayMouseGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
                Task { @MainActor in
                    self?.updateOverlayMouseEventPassthrough()
                }
            }
        }
    }

    private func removeOverlayMouseTrackingIfNeeded() {
        guard overlayWindows.isEmpty else {
            updateOverlayMouseEventPassthrough()
            return
        }

        if let monitor = overlayMouseLocalMonitor {
            NSEvent.removeMonitor(monitor)
            overlayMouseLocalMonitor = nil
        }
        if let monitor = overlayMouseGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            overlayMouseGlobalMonitor = nil
        }
    }

    private func updateOverlayMouseEventPassthrough() {
        let mouseLocation = NSEvent.mouseLocation

        for (timerID, window) in overlayWindows {
            guard let localRect = overlayCardLocalRects[timerID] else {
                window.ignoresMouseEvents = true
                continue
            }

            let screenRect = NSRect(
                x: window.frame.minX + localRect.minX,
                y: window.frame.minY + localRect.minY,
                width: localRect.width,
                height: localRect.height
            )
            window.ignoresMouseEvents = !screenRect.contains(mouseLocation)
        }
    }

    private func makeOverlayPanel(contentRect: NSRect, level: NSWindow.Level, hasShadow: Bool) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureOverlayWindow(panel, level: level, hasShadow: hasShadow)
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        return panel
    }

    private func makeOverlayPlainWindow(contentRect: NSRect, level: NSWindow.Level, hasShadow: Bool) -> NSWindow {
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        configureOverlayWindow(window, level: level, hasShadow: hasShadow)
        return window
    }

    #if DEBUG
    private func makeOverlayFocusLiteWindow(contentRect: NSRect, level: NSWindow.Level, hasShadow: Bool) -> NSWindow {
        let window = OverlayFocusLiteExperimentWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        configureOverlayWindow(window, level: level, hasShadow: hasShadow)
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        return window
    }
    #endif

    private func configureOverlayWindow(_ window: NSWindow, level: NSWindow.Level, hasShadow: Bool) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = level
        window.hasShadow = hasShadow
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
    }

    private func overlayWindowHostDescription(settings: AppSettings) -> String {
        #if DEBUG
        return "\(settings.overlayWindowHostExperiment.displayName) (\(settings.overlayWindowHostExperiment.detail))"
        #else
        return "Release 当前面板 (NSPanel + nonactivating + popUpMenu)"
        #endif
    }
    
    // 重新布局所有通知（当有通知消失时，其他通知上移）
    private func relayoutNotifications(settings: AppSettings) {
        let windowHeight: CGFloat = settings.overlayHeight
        let padding: CGFloat = settings.overlayEdgePadding
        let verticalSpacing: CGFloat = 12
        
        // 按屏幕分组重新布局
        var screenGroups: [NSScreen: [UUID]] = [:]
        
        for timerID in notificationOrder {
            guard let window = overlayWindows[timerID],
                  let screen = windowScreens[timerID] else { continue }
            
            if screenGroups[screen] == nil {
                screenGroups[screen] = []
            }
            screenGroups[screen]?.append(timerID)
        }
        
        // 为每个屏幕分别布局
        for (screen, timerIDs) in screenGroups {
            let screenFrame = screen.visibleFrame
            var currentOffset: CGFloat = 0
            
            // 计算最大允许偏移（避免超出屏幕）
            let maxOffset: CGFloat
            switch settings.overlayPosition {
            case .topLeft, .topRight, .topCenter:
                maxOffset = screenFrame.height - windowHeight - padding * 2
            case .bottomLeft, .bottomRight, .bottomCenter:
                maxOffset = screenFrame.height - windowHeight - padding * 2
            case .center:
                maxOffset = (screenFrame.height / 2) - padding
            }
            
            // 按顺序重新布局每个通知
            for timerID in timerIDs {
                guard let window = overlayWindows[timerID] else { continue }
                
                // 检查是否超出边界
                if currentOffset > maxOffset {
                    // 超出边界的通知保持在边界内（可能重叠）
                    currentOffset = maxOffset
                }
                
                let expandedHeight = window.frame.height
                var newFrame = window.frame
                
                // 根据位置设置计算新位置
                switch settings.overlayPosition {
                case .topLeft, .topRight, .topCenter:
                    // 从上往下堆叠
                    newFrame.origin.y = screenFrame.maxY - expandedHeight - padding - currentOffset
                case .bottomLeft, .bottomRight, .bottomCenter:
                    // 从下往上堆叠
                    newFrame.origin.y = screenFrame.minY + padding + currentOffset
                case .center:
                    // 中心向上堆叠
                    newFrame.origin.y = screenFrame.midY - expandedHeight / 2 - currentOffset
                }
                
                // 带动画的移动窗口
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(newFrame, display: true)
                })
                
                currentOffset += windowHeight + verticalSpacing
            }
        }
    }
    
    private func closeOverlay() {
        // 关闭所有通知窗口
        for (_, window) in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
        notificationOrder.removeAll()
        windowScreens.removeAll()
        overlayCardLocalRects.removeAll()
        removeOverlayMouseTrackingIfNeeded()
        
        // 兼容旧的单窗口模式
        if let window = overlayWindow {
            window.orderOut(nil)
            window.close()
            overlayWindow = nil
        }
    }
}

#if DEBUG
private final class OverlayFocusLiteExperimentWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
#endif
