import SwiftUI
import UserNotifications
import AppKit
import Combine
import os

@MainActor
final class ReminderController: ObservableObject {
    @Published var isResting: Bool = false

    // 多计时器支持
    private var timers: [UUID: Timer] = [:] // 每个计时器的 Timer
    private var restTimers: [UUID: Timer] = [:] // 每个计时器的休息 Timer
    private var restingTimers: Set<UUID> = [] // 正在休息的计时器

    // 定点提醒支持
    private var scheduledTimers: [UUID: Timer] = [:] // 定点提醒的 Timer

    // 多通知管理
    private var overlayWindows: [UUID: NSPanel] = [:] // 每个计时器的通知窗口
    private var notificationOrder: [UUID] = [] // 通知显示顺序（从上到下）
    private var windowScreens: [UUID: NSScreen] = [:] // 记录每个窗口所在的屏幕
    
    private let center = UNUserNotificationCenter.current()
    private var overlayWindow: NSPanel?  // 使用 NSPanel 替代 NSWindow 以支持全屏模式
    private weak var settingsRef: AppSettings?
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    private var lastLockDate: Date?
    private let logger = EventLogger.shared
    private struct NotificationContent {
        let emoji: String
        let title: String
        let body: String
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
        ensureLockMonitoring()
        stop()

        // 启动所有有效的计时器，根据各自的提醒类型调度
        let validTimers = settings.timers.filter { $0.isContentValid() }
        guard !validTimers.isEmpty else {
            print("⚠️ 无法启动：至少需要有一个内容有效的计时器")
            return
        }

        logger.log("启动计时器: 共 \(validTimers.count) 个, 模式 \(settings.notificationMode.rawValue)")

        for timer in validTimers {
            switch timer.reminderType {
            case .interval:
                scheduleIntervalTimer(for: timer, settings: settings)
            case .scheduled:
                scheduleScheduledTimers(for: timer, settings: settings)
            }
            // 标记为运行中
            if let index = settings.timers.firstIndex(where: { $0.id == timer.id }) {
                settings.timers[index].isRunning = true
            }
        }

        // 启动时弹出一次通知
        if settings.showStartNotification {
            Task {
                await self.sendStartNotification(settings: settings, count: validTimers.count)
            }
        }
    }

    // MARK: - Interval Timer Scheduling

    private func scheduleIntervalTimer(for timer: TimerItem, settings: AppSettings) {
        let now = Date()
        let nextDate = now.addingTimeInterval(timer.intervalSeconds)
        scheduleTimer(for: timer.id, fireAt: nextDate, interval: timer.intervalSeconds, settings: settings)
        logger.log("间隔计时器已安排: \(timer.displayName), 间隔 \(timer.intervalSeconds) 秒")
    }

    // MARK: - Scheduled Timer Scheduling

    private func scheduleScheduledTimers(for timer: TimerItem, settings: AppSettings) {
        let enabledTimes = timer.scheduledTimes.filter { $0.enabled }
        guard !enabledTimes.isEmpty else {
            logger.log("⚠️ 计时器 \(timer.displayName) 没有启用的定点时间")
            return
        }

        for scheduledTime in enabledTimes {
            let nextFireDate = calculateNextFireDate(hour: scheduledTime.hour, minute: scheduledTime.minute)
            scheduleScheduledTimer(for: timer, timeID: scheduledTime.id, fireAt: nextFireDate, settings: settings)
        }

        logger.log("定点计时器已安排: \(timer.displayName), 共 \(enabledTimes.count) 个时间点")
    }

    /// 计算下一个触发时间
    private func calculateNextFireDate(hour: Int, minute: Int) -> Date {
        let now = Date()
        let calendar = Calendar.current

        // 构造今天的指定时间
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        let todayTarget = calendar.date(from: components) ?? now

        // 如果今天的指定时间已经过了，则设置为明天
        if todayTarget <= now {
            components.day! += 1
            return calendar.date(from: components) ?? now
        } else {
            return todayTarget
        }
    }

    /// 安排定点提醒定时器
    private func scheduleScheduledTimer(for timer: TimerItem, timeID: UUID, fireAt date: Date, settings: AppSettings) {
        // 每天 24 小时 = 86400 秒
        let interval: TimeInterval = 86400

        let t = Timer(fire: date, interval: interval, repeats: true) { [weak self, weak settings] _ in
            guard let self, let settings else { return }
            Task {
                await self.sendScheduledNotification(timer: timer, settings: settings)
            }
        }
        self.scheduledTimers[timeID] = t
        RunLoop.main.add(t, forMode: .common)

        logger.log("定点提醒已安排: \(timer.displayName) - \(date.formatted(date: .abbreviated, time: .shortened))")
    }

    /// 发送定点提醒通知
    private func sendScheduledNotification(timer: TimerItem, settings: AppSettings) async {
        let content = buildContent(timer: timer)
        let style = buildOverlayStyle(timer: timer, settings: settings)

        logger.log("定点提醒触发: \(timer.displayName) - \(content.title.isEmpty ? "(无标题)" : content.title)")

        // 播放提示音
        playSound(for: timer)

        // 创建临时 TimerItem 用于发送通知（不影响原有计时器状态）
        let tempTimerItem = TimerItem(
            emoji: timer.emoji,
            title: timer.title,
            body: timer.body,
            intervalSeconds: 86400,
            isRestEnabled: false,
            restSeconds: 0,
            customColor: timer.customColor,
            lastFireEpoch: Date().timeIntervalSince1970
        )

        switch settings.notificationMode {
        case .system:
            await sendSystemNotification(content: content)
        case .overlay:
            showOverlayNotification(timer: tempTimerItem, settings: settings, content: content, style: style, triggerRestOnDismiss: false)
        }
    }

    func stop() {
        // 停止所有计时器
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()

        for (_, timer) in restTimers {
            timer.invalidate()
        }
        restTimers.removeAll()
        restingTimers.removeAll()

        // 停止定点提醒计时器
        for (_, timer) in scheduledTimers {
            timer.invalidate()
        }
        scheduledTimers.removeAll()

        // 标记所有计时器为未运行
        if var allTimers = settingsRef?.timers {
            for i in allTimers.indices {
                allTimers[i].isRunning = false
            }
            settingsRef?.timers = allTimers
        }

        isResting = false
        // 停止时关闭所有未关闭的通知弹窗
        closeOverlay()
        logger.log("计时器已停止")
    }
    
    // 启动单个计时器
    func startTimer(_ timerID: UUID, settings: AppSettings) {
        guard let timer = settings.timers.first(where: { $0.id == timerID }),
              timer.isContentValid() else {
            print("⚠️ 无法启动计时器：内容无效")
            return
        }

        settingsRef = settings
        ensureLockMonitoring()

        // 如果已经在运行，先停止
        if timers[timerID] != nil || !scheduledTimers.filter({ $0.key == timerID }).isEmpty {
            stopTimer(timerID, settings: settings)
        }

        // 根据提醒类型调度
        switch timer.reminderType {
        case .interval:
            scheduleIntervalTimer(for: timer, settings: settings)
        case .scheduled:
            scheduleScheduledTimers(for: timer, settings: settings)
        }

        // 标记为运行中
        if let index = settings.timers.firstIndex(where: { $0.id == timerID }) {
            settings.timers[index].isRunning = true
        }

        logger.log("启动计时器: \(timer.displayName)")

        // 启动单个计时器时也显示通知
        if settings.showStartNotification {
            Task {
                await self.sendSingleTimerStartNotification(timerName: timer.displayName, settings: settings)
            }
        }
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
        updateRestingState()

        // 停止该计时器关联的所有定点提醒定时器
        if let timerItem = settings.timers.first(where: { $0.id == timerID }) {
            for scheduledTime in timerItem.scheduledTimes {
                if let scheduledTimer = scheduledTimers[scheduledTime.id] {
                    scheduledTimer.invalidate()
                    scheduledTimers.removeValue(forKey: scheduledTime.id)
                }
            }
        }

        // 标记为未运行
        if let index = settings.timers.firstIndex(where: { $0.id == timerID }) {
            settings.timers[index].isRunning = false
        }
        
        // 关闭该计时器的通知弹窗（如果有）
        if let window = overlayWindows[timerID] {
            // 从字典和顺序中移除
            overlayWindows.removeValue(forKey: timerID)
            windowScreens.removeValue(forKey: timerID)
            
            if let index = notificationOrder.firstIndex(of: timerID) {
                notificationOrder.remove(at: index)
            }
            
            // 立即重新布局其他通知
            relayoutNotifications(settings: settings)
            
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
            logger.log("停止计时器: \(timerName)")
        }
    }

    func cleanup() {
        stop()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        // 退出应用时强制标记为未运行，避免下次启动仍显示倒计时
        settingsRef?.isRunning = false
        // 重置所有计时器的 lastFireEpoch
        if var timers = settingsRef?.timers {
            for i in timers.indices {
                timers[i].lastFireEpoch = 0
            }
            settingsRef?.timers = timers
        }
        logger.log("应用清理完成，计时状态重置")
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

    private func scheduleRestTimer(for timerID: UUID, timerItem: TimerItem, settings: AppSettings) {
        restingTimers.insert(timerID)
        updateRestingState()
        let restInterval = timerItem.restSeconds

        // 更新UI状态
        if let index = settings.timers.firstIndex(where: { $0.id == timerID }) {
            settings.timers[index].lastFireEpoch = Date().timeIntervalSince1970
        }

        let t = Timer.scheduledTimer(withTimeInterval: restInterval, repeats: false) { [weak self, weak settings] _ in
            guard let self, let settings else { return }
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
    }
    
    private func updateRestingState() {
        isResting = !restingTimers.isEmpty
    }

    func sendTest(for timer: TimerItem, settings: AppSettings) async {
        // 验证内容是否有效
        guard timer.isContentValid() else {
            print("⚠️ 无法发送测试通知：标题、描述和Emoji至少需要有一项不为空")
            return
        }
        
        // 测试通知不影响常规计时
        await sendNotification(for: timer, settings: settings, isTest: true, triggerRestOnDismiss: false)
    }

    private func sendNotification(for timer: TimerItem, settings: AppSettings, isTest: Bool = false, content: NotificationContent? = nil, overlayStyle: OverlayStyle? = nil, triggerRestOnDismiss: Bool = true, skipSound: Bool = false) async {
        if !isTest {
            // 更新计时器的 lastFireEpoch
            if let index = settings.timers.firstIndex(where: { $0.id == timer.id }) {
                settings.timers[index].markFiredNow()
            }
        }

        let payload = content ?? buildContent(timer: timer)
        let style = overlayStyle ?? buildOverlayStyle(timer: timer, settings: settings)
        logger.log("发送通知: \(payload.title.isEmpty ? "(无标题)" : payload.title) | 模式 \(settings.notificationMode.rawValue)\(isTest ? " [测试]" : "")\(skipSound ? " [静音]" : "")")

        // 播放提示音
        if !skipSound {
            playSound(for: timer)
        }

        switch settings.notificationMode {
        case .system:
            await sendSystemNotification(content: payload)
        case .overlay:
            showOverlayNotification(timer: timer, settings: settings, content: payload, style: style, triggerRestOnDismiss: triggerRestOnDismiss)
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
            skipSound: true // 启动通知不播放声音
        )
    }
    
    private func sendStartNotification(settings: AppSettings, count: Int) async {
        await sendStartLikeNotification(
            settings: settings,
            title: "已启动",
            body: "\(count)个计时器"
        )
    }
    
    private func sendSingleTimerStartNotification(timerName: String, settings: AppSettings) async {
        await sendStartLikeNotification(
            settings: settings,
            title: "已启动",
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
            stayDuration: settings.overlayStayDuration,
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
            liquidGlassStyle: settings.liquidGlassStyle
        )
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
            liquidGlassStyle: settings.liquidGlassStyle
        )
    }

    private func isDarkModeEnabled() -> Bool {
        guard let appearance = NSApp?.effectiveAppearance else { return true }
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua
    }
    
    // MARK: - Lock/Unlock Handling
    
    private func ensureLockMonitoring() {
        let center = DistributedNotificationCenter.default()
        
        if lockObserver == nil {
            lockObserver = center.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor in
                    self?.lastLockDate = Date()
                }
            }
        }
        
        if unlockObserver == nil {
            unlockObserver = center.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor in
                    self?.handleUnlock()
                }
            }
        }
    }
    
    private func removeLockObservers() {
        let center = DistributedNotificationCenter.default()
        if let observer = lockObserver {
            center.removeObserver(observer)
            lockObserver = nil
        }
        if let observer = unlockObserver {
            center.removeObserver(observer)
            unlockObserver = nil
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
        }
    }
    
    private func handleUnlock() {
        guard let settings = settingsRef, settings.resetOnWakeEnabled else { return }
        guard let lockDate = lastLockDate else { return }
        lastLockDate = nil
        
        let elapsed = Date().timeIntervalSince(lockDate)
        guard elapsed >= 300 else { return } // 锁屏超过5分钟重置计时器
        guard settings.isRunning else { return }
        
        restartAfterUnlock(settings: settings)
    }
    
    private func restartAfterUnlock(settings: AppSettings) {
        stop()
        
        let now = Date()
        let validTimers = settings.timers.filter { $0.isContentValid() }
        
        // 为每个有效的计时器重新安排定时器
        for timer in validTimers {
            let nextDate = now.addingTimeInterval(timer.intervalSeconds)
            scheduleTimer(for: timer.id, fireAt: nextDate, interval: timer.intervalSeconds, settings: settings)
        }
        
        Task {
            if settings.showStartNotification {
                await sendResetNotification(settings: settings)
            }
        }
        logger.log("解锁后重置计时器")
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
    
    private func showOverlayNotification(timer: TimerItem, settings: AppSettings, content: NotificationContent, style: OverlayStyle, triggerRestOnDismiss: Bool) {
        // 关闭该计时器的旧通知（同个计时器的通知会覆盖）
        if let existingWindow = overlayWindows[timer.id] {
            // 立即从字典和顺序中移除，防止新通知计算位置时把旧窗口算进去
            overlayWindows.removeValue(forKey: timer.id)
            windowScreens.removeValue(forKey: timer.id)
            
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
        
        let window = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],  // 使用 nonactivatingPanel 以不激活窗口
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        // 使用 popUpMenu 级别确保在全屏应用上方显示
        window.level = .popUpMenu
        // 配置窗口行为：可加入所有空间、在全屏应用上方显示
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        // 确保窗口不会被激活打断用户操作
        window.hidesOnDeactivate = false
        // 关键：设置为浮动面板，允许在全屏应用上方显示
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        
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
            onDismiss: { [weak self, weak window, timerID = timer.id] isUserDismiss in
                Task {
                    guard let self, let w = window else { return }
                    // 检查是否是该计时器的窗口（防止处理已被替换的旧窗口）
                    if let current = self.overlayWindows[timerID], current === w {
                        // 从字典和顺序中移除（先移除再关闭，确保重新布局时不会计算它）
                        self.overlayWindows.removeValue(forKey: timerID)
                        
                        if let index = self.notificationOrder.firstIndex(of: timerID) {
                            self.notificationOrder.remove(at: index)
                        }
                        
                        self.windowScreens.removeValue(forKey: timerID)
                        
                        // 立即重新布局其他通知（带动画的上移）
                        self.relayoutNotifications(settings: settings)
                        
                        // 然后关闭窗口（使用渐隐动画）
                        NSAnimationContext.runAnimationGroup({ context in
                            context.duration = 0.2
                            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                            w.animator().alphaValue = 0
                        }, completionHandler: { [weak w] in
                            w?.orderOut(nil)
                            w?.close()
                        })
                        
                        // 只有用户手动关闭通知时才触发休息机制
                        if triggerRestOnDismiss && isUserDismiss && timer.isRestEnabled {
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
        
        window.contentView = NSHostingView(rootView: overlayView)
        // 使用 orderFrontRegardless 确保窗口显示在最前方，即使在全屏模式下
        window.orderFrontRegardless()
        
        // 添加到窗口字典和顺序列表
        self.overlayWindows[timer.id] = window
        self.notificationOrder.append(timer.id)
        self.windowScreens[timer.id] = screen // 记录窗口所在的屏幕
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
        
        // 兼容旧的单窗口模式
        if let window = overlayWindow {
            window.orderOut(nil)
            window.close()
            overlayWindow = nil
        }
    }
}
