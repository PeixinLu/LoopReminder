//
//  TimerManagementView.swift
//  LoopReminder
//
//  计时器管理页面
//

import SwiftUI
import AppKit
import Combine

private enum TimerEditorMetrics {
    static let compoundControlWidth: CGFloat = 196
    static let sheetWidth: CGFloat = 640
    static let sheetHorizontalPadding: CGFloat = 28
    static let sheetVerticalPadding: CGFloat = 24
    static let sheetContentWidth: CGFloat = sheetWidth - sheetHorizontalPadding * 2
    static let panelCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 8
}

extension Notification.Name {
    static let settingsWindowWillClose = Notification.Name("settingsWindowWillClose")
}

struct TimerManagementView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var expandedTimerID: UUID?
    @State private var editingDraft: TimerEditorDraft?
    @State private var pendingDelete: TimerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            PageHeader(
                icon: "bell.badge.fill",
                iconColor: .accentColor,
                title: "计时器管理",
                subtitle: "管理您的循环提醒计时器"
            ) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    startStopAllButton
                    addTimerButton
                }
            }

            if settings.timers.isEmpty {
                TimerEmptyStateView {
                    editingDraft = .new(defaultTimer())
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        ForEach($settings.timers) { $timer in
                            TimerManagerListItemView(
                                timer: $timer,
                                events: events(for: timer.id),
                                isExpanded: expandedTimerID == timer.id,
                                onToggleExpanded: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                        expandedTimerID = expandedTimerID == timer.id ? nil : timer.id
                                        settings.focusedTimerID = timer.id
                                    }
                                },
                                onToggleRunning: { toggleTimer(timer) },
                                onEdit: {
                                    guard !timer.isRunning else { return }
                                    editingDraft = .edit(timer)
                                },
                                onDuplicate: { duplicateTimer(timer) },
                                onDelete: { pendingDelete = timer }
                            )
                        }

                        InfoHint("计时器颜色、提示音和通知停留时间均可在单个计时器中独立配置", color: .accentColor)
                    }
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .padding(.trailing, 10)
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            TimerEditorSheet(draft: draft) { savedTimer, originalID in
                saveTimer(savedTimer, originalID: originalID)
            }
            .environmentObject(settings)
        }
        .onChange(of: editingDraft) { _, newDraft in
            // 同步编辑状态到 AppSettings，供菜单栏检查编辑锁
            settings.editingTimerID = newDraft?.originalID
        }
        .alert(
            "删除计时器？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { timer in
            Button("删除", role: .destructive) {
                deleteTimer(timer)
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: { timer in
            Text("“\(timer.displayName)” 删除后无法恢复。")
        }
    }

    private var startStopAllButton: some View {
        let hasRunningTimer = settings.timers.contains { $0.isRunning }

        return Button {
            toggleAllTimers()
        } label: {
            Label(hasRunningTimer ? "关闭全部" : "全部开启", systemImage: hasRunningTimer ? "power.circle.fill" : "power.circle")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(hasRunningTimer ? .orange : .green)
        .disabled(settings.timers.isEmpty)
    }

    private var addTimerButton: some View {
        Button {
            editingDraft = .new(defaultTimer())
        } label: {
            Label("添加新计时器", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func events(for timerID: UUID) -> [ReminderEvent] {
        settings.reminderEvents.filter { $0.timerID == timerID }
    }

    private func defaultTimer() -> TimerItem {
        TimerItem(
            emoji: "🔔",
            title: settings.timers.isEmpty ? "提醒" : "计时器 \(settings.timers.count + 1)",
            body: "起来活动一下",
            intervalSeconds: 1800,
            stayDurationMode: .untilNextNotification,
            stayDurationSeconds: settings.overlayStayDuration
        )
    }

    private func toggleAllTimers() {
        let hasRunningTimer = settings.timers.contains { $0.isRunning }

        if hasRunningTimer {
            for timer in settings.timers where timer.isRunning {
                controller.stopTimer(timer.id, settings: settings)
            }
            settings.isRunning = false
        } else {
            controller.start(settings: settings)
        }
    }

    private func toggleTimer(_ timer: TimerItem) {
        if timer.isRunning {
            controller.stopTimer(timer.id, settings: settings)
        } else {
            controller.startTimer(timer.id, settings: settings)
        }
    }

    private func saveTimer(_ timer: TimerItem, originalID: UUID?) {
        var savedTimer = timer
        savedTimer.scheduledTimes = sortedUniqueTimes(savedTimer.scheduledTimes)

        if let originalID, let index = settings.timers.firstIndex(where: { $0.id == originalID }) {
            savedTimer.isRunning = false
            savedTimer.startedAtEpoch = settings.timers[index].startedAtEpoch
            settings.timers[index] = savedTimer
            settings.focusedTimerID = savedTimer.id
            expandedTimerID = savedTimer.id
        } else {
            settings.timers.append(savedTimer)
            settings.focusedTimerID = savedTimer.id
            expandedTimerID = savedTimer.id
        }
    }

    private func duplicateTimer(_ timer: TimerItem) {
        var copy = timer
        copy.id = UUID()
        copy.scheduledTimes = copy.scheduledTimes.map {
            ScheduledTime(id: UUID(), hour: $0.hour, minute: $0.minute, enabled: true)
        }
        copy.title = "\(timer.displayName) 副本"
        copy.isRunning = false
        copy.lastFireEpoch = 0
        copy.startedAtEpoch = 0
        settings.timers.append(copy)
        settings.focusedTimerID = copy.id
        expandedTimerID = copy.id
    }

    private func deleteTimer(_ timer: TimerItem) {
        if timer.isRunning {
            controller.stopTimer(timer.id, settings: settings)
        }
        settings.timers.removeAll { $0.id == timer.id }
        settings.reminderEvents.removeAll { $0.timerID == timer.id }
        if expandedTimerID == timer.id {
            expandedTimerID = nil
        }
        if settings.focusedTimerID == timer.id {
            settings.focusedTimerID = settings.timers.first?.id
        }
        pendingDelete = nil
    }

    private func sortedUniqueTimes(_ times: [ScheduledTime]) -> [ScheduledTime] {
        var seen = Set<Int>()
        let sorted = times
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
            .filter { time in
                let key = time.hour * 60 + time.minute
                if seen.contains(key) {
                    return false
                }
                seen.insert(key)
                return true
            }
            .map { ScheduledTime(id: $0.id, hour: $0.hour, minute: $0.minute, enabled: true) }

        return sorted.isEmpty ? [ScheduledTime(hour: 9, minute: 0, enabled: true)] : sorted
    }
}

struct TimerEditorDraft: Identifiable, Equatable {
    let id = UUID()
    let originalID: UUID?
    let timer: TimerItem

    static func new(_ timer: TimerItem) -> TimerEditorDraft {
        TimerEditorDraft(originalID: nil, timer: timer)
    }

    static func edit(_ timer: TimerItem) -> TimerEditorDraft {
        TimerEditorDraft(originalID: timer.id, timer: timer)
    }

    static func == (lhs: TimerEditorDraft, rhs: TimerEditorDraft) -> Bool {
        lhs.id == rhs.id
    }
}

private struct TimerEmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "timer")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("暂无计时器")
                    .font(.headline)
                Text("添加一个循环提醒开始使用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                onAdd()
            } label: {
                Label("添加新计时器", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadius)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

private enum TimerRowMetrics {
    static let rowCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 12
}

private struct TimerManagerListItemView: View {
    @Binding var timer: TimerItem
    let events: [ReminderEvent]
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onToggleRunning: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isEditHovering = false
    @State private var isDeleteHovering = false
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                TimerPowerSwitch(
                    isOn: timer.isRunning,
                    isEnabled: timer.isContentValid(),
                    action: onToggleRunning
                )
                .help(timer.isRunning ? "关闭计时器" : "开启计时器")

                Text(timer.emoji)
                    .font(.system(size: 30))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: TimerRowMetrics.controlCornerRadius)
                            .fill((timer.customColor?.toColor() ?? .accentColor).opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text(timer.displayName)
                            .font(.headline)
                            .lineLimit(1)

                        TimerTypeBadge(text: reminderBadgeText)
                    }

                    if !bodySummary.isEmpty {
                        Text(bodySummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    TimerRowActionButton(
                        title: "编辑",
                        systemImage: "slider.horizontal.3",
                        isHovered: isEditHovering,
                        isDisabled: timer.isRunning,
                        tint: .secondary
                    ) {
                        onEdit()
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isEditHovering = hovering
                        }
                    }
                    .disabled(timer.isRunning)
                    .help(timer.isRunning ? "请先关闭才能编辑" : "编辑")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isDeleteHovering ? .red : .secondary)
                            .frame(width: 34, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: TimerRowMetrics.controlCornerRadius)
                                    .fill(isDeleteHovering ? Color.red.opacity(0.10) : Color.secondary.opacity(0.055))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isDeleteHovering = hovering
                        }
                    }
                    .help("删除")
                }
                .frame(width: 112, alignment: .trailing)
            }
            .padding(DesignTokens.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpanded()
            }

            if timer.isRunning {
                TimerProgressFooterView(timer: timer, now: now)
            }

            if isExpanded {
                TimerDetailView(timer: timer, events: events)
                    .padding(DesignTokens.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: TimerRowMetrics.rowCornerRadius)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TimerRowMetrics.rowCornerRadius)
                .stroke(timer.isRunning ? Color.green.opacity(0.28) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TimerRowMetrics.rowCornerRadius))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
        .onReceive(ticker) { date in
            now = date
        }
        .contextMenu {
            Button(timer.isRunning ? "关闭" : "开启") {
                onToggleRunning()
            }
            .disabled(!timer.isContentValid())

            Button("编辑") {
                onEdit()
            }
            .disabled(timer.isRunning)

            Button("复制") {
                onDuplicate()
            }

            Divider()

            Button("删除", role: .destructive) {
                onDelete()
            }
        }
    }

    private var reminderBadgeText: String {
        switch timer.reminderType {
        case .interval:
            return "间隔｜\(scheduleRuleSummary)"
        case .scheduled:
            return "定点｜\(scheduleRuleSummary)"
        }
    }

    private var scheduleRuleSummary: String {
        switch timer.reminderType {
        case .interval:
            return "每 \(timer.formattedInterval())"
        case .scheduled:
            let times = timer.scheduledTimes.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
            guard !times.isEmpty else { return "无时间点" }
            let values = times.prefix(3).map { $0.formattedTime() }.joined(separator: " / ")
            return times.count > 3 ? "\(values) 等 \(times.count) 个" : values
        }
    }

    private var bodySummary: String {
        timer.body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var rowBackgroundColor: Color {
        if timer.isRunning {
            return Color.green.opacity(isHovering ? 0.075 : 0.055)
        }

        return Color.secondary.opacity(isHovering ? 0.075 : 0.055)
    }
}

private struct TimerTypeBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Color.secondary.opacity(0.78))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.055))
            )
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.095), lineWidth: 1)
            )
    }
}

private struct TimerRowActionButton: View {
    let title: String
    let systemImage: String
    let isHovered: Bool
    let isDisabled: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.35) : (isHovered ? .primary : tint))
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: TimerRowMetrics.controlCornerRadius)
                        .fill(isHovered && !isDisabled ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.055))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TimerProgressFooterView: View {
    let timer: TimerItem
    let now: Date

    var body: some View {
        VStack(spacing: 4) {
            if timer.reminderType == .interval {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.14))
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 3)
            }

            HStack {
                Text(nextReminderText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.sm)
        }
    }

    private var progress: Double {
        guard timer.reminderType == .interval else { return 0 }
        let last = timer.lastFireDate ?? now
        let elapsed = now.timeIntervalSince(last)
        return min(1, max(0, elapsed / max(timer.intervalSeconds, 1)))
    }

    private var nextReminderText: String {
        switch timer.reminderType {
        case .interval:
            let last = timer.lastFireDate ?? now
            let next = last.addingTimeInterval(timer.intervalSeconds)
            let remaining = max(0, Int(next.timeIntervalSince(now)))
            return "下次通知：\(formatRemaining(remaining))"
        case .scheduled:
            guard let next = nextScheduledTime else { return "无提醒时间" }
            return "下次提醒：\(next.formattedTime())"
        }
    }

    private var nextScheduledTime: ScheduledTime? {
        let calendar = Calendar.current
        let current = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return timer.scheduledTimes
            .min { lhs, rhs in
                distance(from: current, to: lhs) < distance(from: current, to: rhs)
            }
    }

    private func distance(from current: Int, to time: ScheduledTime) -> Int {
        let total = time.hour * 60 + time.minute
        return total > current ? total - current : total + 1440 - current
    }

    private func formatRemaining(_ seconds: Int) -> String {
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        if seconds >= 60 {
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return "\(seconds)秒"
    }
}

private struct TimerDetailView: View {
    let timer: TimerItem
    let events: [ReminderEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()

            HStack(alignment: .top, spacing: DesignTokens.Spacing.xl) {
                VStack(alignment: .leading, spacing: 6) {
                    TimerColorDetailLine(timerColor: timer.customColor)
                    DetailLine(label: "提示音", value: timer.soundName ?? "无")
                    DetailLine(label: "停留", value: timer.stayDurationMode == .fixed ? "\(Int(timer.stayDurationSeconds)) 秒" : "直到下次通知")
                    if timer.reminderType == .scheduled {
                        scheduledTimesDetail
                    }
                }

                Spacer(minLength: 12)
            }

            ReminderStatsChartView(timer: timer, events: events)
        }
    }

    private var scheduledTimesDetail: some View {
        let times = timer.scheduledTimes.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        return Group {
            if times.isEmpty {
                DetailLine(label: "时间点", value: "无时间点")
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Text("时间点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .leading)
                    FlowLayout(spacing: 6) {
                        ForEach(times) { time in
                            Text(time.formattedTime())
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                    }
                }
            }
        }
    }
}

private struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

private struct TimerColorDetailLine: View {
    let timerColor: TimerItem.TimerColor?

    private var color: Color {
        timerColor?.toColor() ?? .secondary
    }

    private var label: String {
        timerColor?.colorType.rawValue ?? "默认"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("颜色")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
                    )

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct ReminderStatsChartView: View {
    let timer: TimerItem
    let events: [ReminderEvent]

    @State private var hoverLocation: CGPoint?

    private var todayEvents: [ReminderEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDateInToday($0.firedAt) }
    }

    private var axisRange: ReminderChartAxisRange {
        ReminderChartAxisRange.automatic(
            eventDates: todayEvents.map(\.firedAt),
            runningStart: runningStartDate
        )
    }

    private var runningStartDate: Date? {
        guard timer.isRunning else { return nil }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard timer.startedAtEpoch > 0 else { return startOfDay }
        return Date(timeIntervalSince1970: timer.startedAtEpoch)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))

                GeometryReader { proxy in
                    Canvas { context, size in
                        drawActiveRange(in: context, size: size)
                        drawEventLines(in: context, size: size)
                        drawHoverLine(in: context, size: size)
                    }

                    HStack {
                        let labels = axisRange.labelDates()
                        ForEach(Array(labels.enumerated()), id: \.offset) { index, date in
                            Text(timeString(for: date))
                            if index < labels.count - 1 {
                                Spacer()
                            }
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                    if let hoverLocation {
                        Text(timeStringWithSeconds(for: axisRange.date(atX: Double(snappedX(hoverLocation.x, width: proxy.size.width)), width: Double(proxy.size.width))))
                            .font(.caption2)
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)))
                            .offset(x: min(max(4, hoverLocation.x - 30), proxy.size.width - 64), y: proxy.size.height - 22)
                    }

                    HoverTrackingView { point in
                        hoverLocation = point
                    } onEnded: {
                        hoverLocation = nil
                    }
                }
            }
            .frame(height: 116)

            HStack(spacing: DesignTokens.Spacing.xl) {
                Text("提醒次数：\(todayEvents.count)")
                Text("完成次数：\(todayEvents.filter { $0.status == .completed }.count)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func drawActiveRange(in context: GraphicsContext, size: CGSize) {
        guard let runningStartDate else { return }
        let start = max(runningStartDate, axisRange.start)
        let end = min(Date(), axisRange.end)
        guard end > start else { return }
        let startX = xPosition(for: start, width: size.width)
        let endX = xPosition(for: end, width: size.width)
        let rect = CGRect(x: min(startX, endX), y: 28, width: abs(endX - startX), height: size.height - 42)
        context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(.green.opacity(0.14)))
    }

    private func drawEventLines(in context: GraphicsContext, size: CGSize) {
        let eventPositions = todayEvents.map { (event: $0, x: xPosition(for: $0.firedAt, width: size.width)) }

        // 确定当前 hover 吸附到的竖线索引
        let snappedEventIndex: Int?
        if let hoverLocation {
            let snappedXPos = snappedX(hoverLocation.x, width: size.width)
            snappedEventIndex = eventPositions.firstIndex(where: { abs($0.x - snappedXPos) < 0.5 })
        } else {
            snappedEventIndex = nil
        }

        // 计算每条竖线到相邻竖线的最小间距（像素）
        let proximityThreshold: CGFloat = 6

        for (index, item) in eventPositions.enumerated() {
            let x = item.x
            let color: Color = item.event.status == .completed ? .green : .blue

            let neighborDistances = eventPositions.compactMap { other -> CGFloat? in
                let dist = abs(other.x - x)
                return dist > 0.5 ? dist : nil
            }
            let minDistance = neighborDistances.min() ?? .greatestFiniteMagnitude

            // 线宽：hover 吸附 → 粗线；紧密相邻 → 极细防粘连；普通 → 细线
            let lineWidth: CGFloat
            if snappedEventIndex == index {
                lineWidth = 3
            } else if minDistance < proximityThreshold {
                lineWidth = 0.5
            } else {
                lineWidth = 1
            }

            var path = Path()
            path.move(to: CGPoint(x: x, y: 28))
            path.addLine(to: CGPoint(x: x, y: size.height - 18))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }

    private func drawHoverLine(in context: GraphicsContext, size: CGSize) {
        guard let hoverLocation else { return }
        let x = snappedX(hoverLocation.x, width: size.width)
        var path = Path()
        path.move(to: CGPoint(x: x, y: 18))
        path.addLine(to: CGPoint(x: x, y: size.height - 22))
        context.stroke(path, with: .color(.gray.opacity(0.7)), style: StrokeStyle(lineWidth: 1))
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        CGFloat(axisRange.xPosition(for: date, width: Double(width)))
    }

    private func snappedX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let eventXs = todayEvents.map { xPosition(for: $0.firedAt, width: width) }
        guard let nearest = eventXs.min(by: { abs($0 - x) < abs($1 - x) }), abs(nearest - x) < 8 else {
            return min(max(0, x), width)
        }
        return nearest
    }

    private func timeString(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: axisRange.start)
        let secondsSinceStartOfDay = date.timeIntervalSince(startOfDay)
        if secondsSinceStartOfDay >= 86_400 {
            return "24:00"
        }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    private func timeStringWithSeconds(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: axisRange.start)
        let secondsSinceStartOfDay = date.timeIntervalSince(startOfDay)
        if secondsSinceStartOfDay >= 86_400 {
            return "24:00:00"
        }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        return String(format: "%02d:%02d:%02d", hour, minute, second)
    }
}

private struct HoverTrackingView: NSViewRepresentable {
    let onMoved: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMoved = onMoved
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMoved = onMoved
        nsView.onEnded = onEnded
    }
}

private final class TrackingNSView: NSView {
    var onMoved: ((CGPoint) -> Void)?
    var onEnded: (() -> Void)?
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMoved?(point)
    }

    override func mouseExited(with event: NSEvent) {
        onEnded?()
    }
}

private struct TimerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    let originalID: UUID?
    let onSave: (TimerItem, UUID?) -> Void

    @State private var timer: TimerItem
    @State private var intervalValue: String
    @State private var intervalUnit: TimerTimeUnit
    @State private var selectedColorType: TimerItem.TimerColor.ColorType = .blue
    @State private var customColor: Color = .blue
    @State private var validationMessage: String?

    init(draft: TimerEditorDraft, onSave: @escaping (TimerItem, UUID?) -> Void) {
        self.originalID = draft.originalID
        self.onSave = onSave
        self._timer = State(initialValue: draft.timer)
        let initialUnit: TimerTimeUnit = draft.timer.intervalSeconds >= 60 && Int(draft.timer.intervalSeconds) % 60 == 0 ? .minutes : .seconds
        self._intervalUnit = State(initialValue: initialUnit)
        self._intervalValue = State(initialValue: initialUnit == .minutes ? String(Int(draft.timer.intervalSeconds / 60)) : String(Int(draft.timer.intervalSeconds)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                NotificationContentEditor(timer: $timer)
                configurationPanel

                if let validationMessage {
                    InfoHint(validationMessage, color: .orange)
                }
            }
            .frame(width: TimerEditorMetrics.sheetContentWidth, alignment: .leading)
            .padding(.horizontal, TimerEditorMetrics.sheetHorizontalPadding)
            .padding(.vertical, TimerEditorMetrics.sheetVerticalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(width: TimerEditorMetrics.sheetWidth, height: 620)
        .navigationTitle(editorTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            initializeColor()
        }
    }

    private var editorTitle: String {
        originalID == nil ? "添加计时器" : "编辑计时器"
    }

    private var configurationPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("计时器配置")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                TimerConfigRow(title: "提醒类型", description: "选择提醒触发方式") {
                    ReminderScheduleEditor(
                        selection: $timer.reminderType,
                        timer: timer,
                        intervalSummary: intervalSummary,
                        intervalValue: $intervalValue,
                        intervalUnit: $intervalUnit,
                        scheduledTimes: $timer.scheduledTimes
                    )
                }

                TimerConfigDivider()

                TimerConfigRow(title: "通知停留", description: "控制通知显示多久") {
                    StayDurationEditor(mode: $timer.stayDurationMode, seconds: $timer.stayDurationSeconds)
                }

                TimerConfigDivider()

                TimerConfigRow(title: "自定义颜色", description: "覆盖全局通知颜色") {
                    ColorOverrideEditor(
                        selectedColorType: $selectedColorType,
                        customColor: $customColor,
                        timerColor: Binding(
                            get: { timer.customColor },
                            set: { timer.customColor = $0 }
                        ),
                        customPresets: settings.timerCustomColorPresets,
                        onSaveCustomPreset: { presetID, color in
                            settings.saveTimerCustomColorPreset(id: presetID, color: color)
                        }
                    )
                }

                TimerConfigDivider()

                TimerConfigRow(title: "提示音", description: "通知触发时播放声音") {
                    SoundSelectionEditor(soundName: $timer.soundName)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.panelCornerRadius)
                    .fill(Color.secondary.opacity(0.055))
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var canSave: Bool {
        timer.isContentValid() && validationMessage == nil
    }

    private var intervalSummary: String {
        guard let value = Int(intervalValue), value > 0 else {
            return "按固定间隔循环"
        }
        return "每 \(value) \(intervalUnit.rawValue) 提醒"
    }

    private func initializeColor() {
        if let customColor = timer.customColor {
            selectedColorType = customColor.colorType
            self.customColor = customColor.toColor()
        }
    }

    private func save() {
        guard validate() else { return }
        if timer.reminderType == .interval {
            let value = Double(intervalValue) ?? 0
            timer.intervalSeconds = max(intervalUnit == .seconds ? 5 : 60, value * intervalUnit.multiplier)
        } else {
            timer.scheduledTimes = uniqueSortedTimes(timer.scheduledTimes)
        }
        onSave(timer, originalID)
        dismiss()
    }

    private func validate() -> Bool {
        validationMessage = nil

        if timer.reminderType == .interval {
            guard let value = Double(intervalValue), value.rounded(.down) == value, value > 0 else {
                validationMessage = "间隔必须是正整数"
                return false
            }
            if intervalUnit == .seconds && value < 5 {
                validationMessage = "单位为秒时，间隔至少为 5 秒"
                return false
            }
            if intervalUnit == .minutes && value < 1 {
                validationMessage = "单位为分钟时，间隔至少为 1 分钟"
                return false
            }
        } else {
            let times = uniqueSortedTimes(timer.scheduledTimes)
            guard !times.isEmpty else {
                validationMessage = "请至少保留一个定点时间"
                return false
            }
            let keys = times.map { $0.hour * 60 + $0.minute }
            if Set(keys).count != keys.count {
                validationMessage = "定点时间不能重复"
                return false
            }
        }

        return true
    }

    private func uniqueSortedTimes(_ times: [ScheduledTime]) -> [ScheduledTime] {
        var seen = Set<Int>()
        let sorted = times.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }.filter { time in
            let key = time.hour * 60 + time.minute
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
            .map { ScheduledTime(id: $0.id, hour: $0.hour, minute: $0.minute, enabled: true) }

        return sorted.isEmpty ? [ScheduledTime(hour: 9, minute: 0, enabled: true)] : sorted
    }
}

private struct TimerConfigRow<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 150, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}

private struct TimerConfigDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 150 + DesignTokens.Spacing.lg)
    }
}

private struct ReminderScheduleEditor: View {
    @Binding var selection: ReminderType
    let timer: TimerItem
    let intervalSummary: String
    @Binding var intervalValue: String
    @Binding var intervalUnit: TimerTimeUnit
    @Binding var scheduledTimes: [ScheduledTime]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ReminderTypeSelector(
                selection: $selection,
                timer: timer,
                intervalSummary: intervalSummary
            )

            if selection == .interval {
                IntervalConfigEditor(value: $intervalValue, unit: $intervalUnit)
            } else {
                ScheduledTimesEditor(times: $scheduledTimes)
            }
        }
    }
}

private struct ReminderTypeSelector: View {
    @Binding var selection: ReminderType
    let timer: TimerItem
    let intervalSummary: String

    var body: some View {
        HStack(spacing: 0) {
            ReminderTypeCard(
                type: .interval,
                title: "间隔提醒",
                subtitle: intervalSummary,
                isSelected: selection == .interval
            ) {
                selection = .interval
            }

            ReminderTypeCard(
                type: .scheduled,
                title: "定点提醒",
                subtitle: scheduledSubtitle,
                isSelected: selection == .scheduled
            ) {
                selection = .scheduled
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    private var scheduledSubtitle: String {
        let count = timer.scheduledTimes.count
        return count == 0 ? "每天指定时间触发" : "每天 \(count) 个时间点"
    }
}

private struct ReminderTypeCard: View {
    let type: ReminderType
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.09) : Color(nsColor: .controlBackgroundColor).opacity(0.65))
        }
        .buttonStyle(.plain)
    }
}

private struct StayDurationEditor: View {
    @Binding var mode: TimerItem.StayDurationMode
    @Binding var seconds: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: 0) {
                StayModeButton(title: "直到下次通知", subtitle: "自动替换", isSelected: mode == .untilNextNotification) {
                    mode = .untilNextNotification
                }
                StayModeButton(title: "固定时长", subtitle: "\(Int(seconds)) 秒", isSelected: mode == .fixed) {
                    mode = .fixed
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )

            if mode == .fixed {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("短")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $seconds, in: 1...120, step: 1)
                    Text("长")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct StayModeButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.09) : Color(nsColor: .controlBackgroundColor).opacity(0.65))
        }
        .buttonStyle(.plain)
    }
}

private struct ColorOverrideEditor: View {
    @Binding var selectedColorType: TimerItem.TimerColor.ColorType
    @Binding var customColor: Color
    @Binding var timerColor: TimerItem.TimerColor?
    let customPresets: [TimerCustomColorPreset]
    let onSaveCustomPreset: (String?, Color) -> TimerCustomColorPreset?

    @State private var isCustomPickerPresented = false
    @State private var editingPresetID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 6) {
                Text("内置预设")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    defaultColorButton
                    transparentColorButton

                    ForEach(colorOptions, id: \.self) { colorType in
                        colorButton(colorType, label: colorType.rawValue)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("自定义预设")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(customPresets) { preset in
                        customPresetButton(preset)
                    }

                    customColorButton
                }
            }
        }
    }

    private var defaultColorButton: some View {
        ColorLabelChoiceButton(
            label: "跟随全局",
            isSelected: timerColor == nil,
            swatch: {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.14))
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            },
            action: {
                timerColor = nil
            }
        )
        .help("使用外观里的统一配色")
    }

    private var transparentColorButton: some View {
        ColorLabelChoiceButton(
            label: "透明",
            isSelected: timerColor?.colorType == .transparent,
            swatch: {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .overlay(Circle().stroke(Color.secondary.opacity(0.28), lineWidth: 1))
                    Image(systemName: "slash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            },
            action: {
                selectedColorType = .transparent
                timerColor = TimerItem.TimerColor(colorType: .transparent)
            }
        )
        .help("透明")
    }

    private var customColorButton: some View {
        let canAddCustomPreset = customPresets.count < TimerCustomColorPreset.maximumCount

        return ColorTextChoiceButton(
            label: "自定义",
            detail: canAddCustomPreset ? "新增预设" : "最多 10 个",
            isSelected: false,
            swatch: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(Circle().stroke(Color.secondary.opacity(0.28), lineWidth: 1))
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            },
            action: {
                guard canAddCustomPreset else { return }
                editingPresetID = nil
                if let savedPreset = onSaveCustomPreset(nil, customColor) {
                    selectedColorType = .custom
                    editingPresetID = savedPreset.id
                    customColor = savedPreset.color
                    timerColor = timerColor(from: savedPreset)
                    isCustomPickerPresented = true
                }
            }
        )
        .disabled(!canAddCustomPreset)
        .help("自定义")
    }

    private var colorOptions: [TimerItem.TimerColor.ColorType] {
        [.slate, .sky, .violet, .emerald, .amber, .rose, .teal]
    }

    private func colorButton(_ colorType: TimerItem.TimerColor.ColorType, label: String) -> some View {
        ColorChoiceButton(
            label: label,
            isSelected: timerColor?.colorType == colorType,
            swatch: {
                ZStack {
                    Circle()
                        .fill(TimerItem.TimerColor(colorType: colorType).toColor())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.28), lineWidth: 1))
                }
            },
            action: {
                selectedColorType = colorType
                timerColor = TimerItem.TimerColor(colorType: colorType)
            }
        )
        .help(label)
    }

    private func customPresetButton(_ preset: TimerCustomColorPreset) -> some View {
        HStack(spacing: 2) {
            ColorChoiceButton(
                label: "自定义颜色",
                isSelected: timerColor?.colorType == .custom && timerColorMatches(preset),
                swatch: {
                    Circle()
                        .fill(preset.color)
                        .overlay(Circle().stroke(Color.secondary.opacity(0.28), lineWidth: 1))
                },
                action: {
                    selectedColorType = .custom
                    customColor = preset.color
                    timerColor = timerColor(from: preset)
                }
            )
            .popover(
                isPresented: Binding(
                    get: { isCustomPickerPresented && editingPresetID == preset.id },
                    set: { isPresented in
                        if !isPresented, editingPresetID == preset.id {
                            isCustomPickerPresented = false
                        }
                    }
                )
            ) {
                CustomColorPalettePopover(color: $customColor) { color in
                    selectedColorType = .custom
                    if let savedPreset = onSaveCustomPreset(preset.id, color) {
                        editingPresetID = savedPreset.id
                        customColor = savedPreset.color
                        timerColor = timerColor(from: savedPreset)
                    }
                } onDone: {
                    isCustomPickerPresented = false
                }
            }

            Button {
                editCustomPreset(preset)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 20, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("编辑自定义颜色")
        }
        .background(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
    }

    private func editCustomPreset(_ preset: TimerCustomColorPreset) {
        selectedColorType = .custom
        editingPresetID = preset.id
        customColor = preset.color
        timerColor = timerColor(from: preset)
        isCustomPickerPresented = true
    }

    private func timerColor(from preset: TimerCustomColorPreset) -> TimerItem.TimerColor {
        return TimerItem.TimerColor(
            colorType: .custom,
            customPresetID: preset.id,
            customR: preset.red,
            customG: preset.green,
            customB: preset.blue
        )
    }

    private func timerColorMatches(_ preset: TimerCustomColorPreset) -> Bool {
        guard let timerColor, timerColor.colorType == .custom else { return false }
        return timerColor.customPresetID == preset.id
    }
}

struct CustomColorPalettePopover: View {
    @Binding var color: Color
    let onChange: (Color) -> Void
    let onDone: () -> Void

    var body: some View {
        CustomColorPaletteEditor(color: $color, onChange: onChange)
            .onDisappear(perform: onDone)
    }
}

private struct CustomColorPaletteEditor: View {
    @Binding var color: Color
    let onChange: (Color) -> Void

    @State private var brightness: Double = 0.92
    @State private var hexInput: String = "#000000"

    private let hueSteps = 14
    private let saturationSteps = 5

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("自定义颜色")
                    .font(.headline)
                Spacer()
                RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                    .fill(color)
                    .frame(width: 64, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                            .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                    )
            }

            VStack(spacing: 6) {
                ForEach((0..<saturationSteps).reversed(), id: \.self) { saturationIndex in
                    HStack(spacing: 6) {
                        ForEach(0..<hueSteps, id: \.self) { hueIndex in
                            paletteCell(
                                hue: Double(hueIndex) / Double(hueSteps),
                                saturation: Double(saturationIndex + 1) / Double(saturationSteps)
                            )
                        }
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: TimerEditorMetrics.panelCornerRadius).fill(Color.secondary.opacity(0.07)))

            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("明度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $brightness, in: 0.35...1, step: 0.01)
                    .onChange(of: brightness) { _, _ in
                        let hsba = color.hsbaComponents()
                        updateColor(hue: hsba.hue, saturation: hsba.saturation, brightness: brightness)
                    }
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("HEX")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("#RRGGBB", text: $hexInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        commitHexInput()
                    }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 330)
        .onAppear {
            brightness = max(color.hsbaComponents().brightness, 0.35)
            hexInput = color.hexString
        }
    }

    private func paletteCell(hue: Double, saturation: Double) -> some View {
        let cellColor = Color(hue: hue, saturation: saturation, brightness: brightness)

        return Button {
            updateColor(hue: hue, saturation: saturation, brightness: brightness)
        } label: {
            RoundedRectangle(cornerRadius: TimerEditorMetrics.smallCornerRadius)
                .fill(cellColor)
                .frame(width: 16, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: TimerEditorMetrics.smallCornerRadius)
                        .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func updateColor(hue: Double, saturation: Double, brightness: Double) {
        let next = Color(hue: hue, saturation: saturation, brightness: brightness)
        color = next
        setHexInput(next.hexString)
        onChange(next)
    }

    private func commitHexInput() {
        let formatted = Color.formattedHexInput(from: hexInput)
        guard let normalized = Color.normalizedHexString(from: formatted) else {
            setHexInput(formatted)
            return
        }

        setHexInput(normalized)

        guard let next = Color(hexString: normalized) else {
            return
        }

        color = next
        brightness = max(next.hsbaComponents().brightness, 0.35)
        onChange(next)
    }

    private func setHexInput(_ value: String) {
        guard hexInput != value else {
            return
        }

        hexInput = value
    }
}

private struct ColorChoiceButton<Swatch: View>: View {
    let label: String
    let isSelected: Bool
    @ViewBuilder let swatch: () -> Swatch
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            swatch()
                .frame(width: 16, height: 16)
                .frame(width: 26, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                        .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                        .stroke(isSelected ? Color.accentColor.opacity(0.36) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ColorLabelChoiceButton<Swatch: View>: View {
    let label: String
    let isSelected: Bool
    @ViewBuilder let swatch: () -> Swatch
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                swatch()
                    .frame(width: 16, height: 16)

                Text(label)
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor).opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                    .stroke(isSelected ? Color.accentColor.opacity(0.36) : Color.secondary.opacity(0.14), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ColorTextChoiceButton<Swatch: View>: View {
    let label: String
    let detail: String
    let isSelected: Bool
    @ViewBuilder let swatch: () -> Swatch
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                swatch()
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                    .fill(isSelected ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor).opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                    .stroke(isSelected ? Color.accentColor.opacity(0.36) : Color.secondary.opacity(0.14), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)，\(detail)")
    }
}

private struct SoundSelectionEditor: View {
    @Binding var soundName: String?

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Button("无") {
                    soundName = nil
                }
                Divider()
                ForEach(SystemSound.allCases, id: \.self) { sound in
                    Button(sound.rawValue) {
                        soundName = sound.rawValue
                    }
                }
            } label: {
                HStack {
                    Text(soundName ?? "无")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: TimerEditorMetrics.compoundControlWidth - 54, height: 30)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                previewSound()
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(soundName == nil)
            .help("播放预览")
        }
        .frame(width: TimerEditorMetrics.compoundControlWidth)
        .background(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .fixedSize()
    }

    private func previewSound() {
        guard let soundName else { return }
        NSSound(named: NSSound.Name(soundName))?.play()
    }
}
private struct NotificationContentEditor: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    @Binding var timer: TimerItem
    @FocusState private var focusedField: Field?
    @State private var isEmojiPickerPresented = false
    @State private var isSendingTest = false

    private enum Field: Hashable {
        case title
        case body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("通知内容")
                .font(DesignTokens.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            HStack(spacing: DesignTokens.Spacing.lg) {
                Button {
                    focusedField = nil
                    isEmojiPickerPresented.toggle()
                } label: {
                    Text(timer.emoji.isEmpty ? "🔔" : timer.emoji)
                        .font(.system(size: 36))
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color.secondary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("选择 Emoji")
                .popover(isPresented: $isEmojiPickerPresented) {
                    EmojiPickerPopover(
                        selectedEmoji: timer.emoji,
                        recentEmojis: settings.recentEmojis
                    ) { emoji in
                        timer.emoji = emoji
                        settings.recordRecentEmoji(emoji)
                        isEmojiPickerPresented = false
                    }
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    TextField("标题", text: $timer.title)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .title)
                    TextField("副标题", text: $timer.body, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...3)
                        .focused($focusedField, equals: .body)
                }

                Button {
                    sendTestNotification()
                } label: {
                    Label(isSendingTest ? "发送中" : "测试效果", systemImage: "play.circle.fill")
                        .frame(minWidth: 86)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!timer.isContentValid() || isSendingTest)
                .help("测试当前通知内容")
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.panelCornerRadius)
                    .fill(Color.secondary.opacity(0.06))
            )
        }
    }

    private func sendTestNotification() {
        focusedField = nil
        isSendingTest = true
        Task {
            await controller.sendTest(for: timer, settings: settings)
            isSendingTest = false
        }
    }
}

private struct EmojiPickerPopover: View {
    let selectedEmoji: String
    let recentEmojis: [String]
    let onSelect: (String) -> Void

    @State private var searchText = ""

    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 6), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("选择 Emoji")
                    .font(.headline)
                Spacer()
                Text(selectedEmoji.isEmpty ? "🔔" : selectedEmoji)
                    .font(.title2)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.secondary.opacity(0.08)))
            }

            TextField("搜索英文名称或中文关键词", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if !recentEmojis.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近使用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(recentEmojis.prefix(8), id: \.self) { emoji in
                            emojiButton(emoji)
                        }
                    }
                }
            }

            ScrollView {
                if trimmedSearchText.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(displayedSections) { section in
                            emojiSection(section)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(displayedItems) { item in
                            emojiButton(item.symbol)
                                .help("\(item.unicodeName) \(item.keywords.joined(separator: " "))")
                        }
                    }
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 260)

            Text(footerText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 340)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedSections: [EmojiCatalogSection] {
        EmojiCatalog.sections()
    }

    private var displayedItems: [EmojiCatalogItem] {
        EmojiCatalog.search(trimmedSearchText)
    }

    private var footerText: String {
        if displayedItems.isEmpty {
            return "未找到匹配项"
        }
        return "支持英文名称和提醒场景中文关键词"
    }

    private func emojiSection(_ section: EmojiCatalogSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.group.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(section.items) { item in
                    emojiButton(item.symbol)
                        .help("\(item.unicodeName) \(item.keywords.joined(separator: " "))")
                }
            }
        }
    }

    private func emojiButton(_ emoji: String) -> some View {
        Button {
            onSelect(emoji)
        } label: {
            Text(emoji)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                        .fill(emoji == selectedEmoji ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                        .stroke(emoji == selectedEmoji ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum TimerTimeUnit: String, CaseIterable {
    case seconds = "秒"
    case minutes = "分钟"

    var multiplier: Double {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        }
    }
}

private struct IntervalConfigEditor: View {
    @Binding var value: String
    @Binding var unit: TimerTimeUnit

    private let stepButtonWidth: CGFloat = 34
    private let valueWidth: CGFloat = 62
    private let dividerWidth: CGFloat = 1
    private var unitWidth: CGFloat {
        TimerEditorMetrics.compoundControlWidth - stepButtonWidth * 2 - valueWidth - dividerWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", delta: -1, accessibilityLabel: "减少间隔")

            TextField("间隔", text: $value)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .rounded))
                .monospacedDigit()
                .frame(width: 62, height: 30)
                .onChange(of: value) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    value = filtered
                }

            stepButton(systemName: "plus", delta: 1, accessibilityLabel: "增加间隔")

            Divider()
                .frame(width: dividerWidth, height: 20)

            Menu {
                ForEach(TimerTimeUnit.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        unit = option
                        clampValueForUnit()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(unit.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(width: unitWidth, height: 30)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .frame(width: TimerEditorMetrics.compoundControlWidth)
        .background(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .fixedSize()
    }

    private func stepButton(systemName: String, delta: Int, accessibilityLabel: String) -> some View {
        Button {
            step(delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: stepButtonWidth, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func step(_ delta: Int) {
        let current = Int(value) ?? minimum
        value = String(max(minimum, current + delta))
    }

    private func clampValueForUnit() {
        let current = Int(value) ?? minimum
        value = String(max(minimum, current))
    }

    private var minimum: Int {
        unit == .seconds ? 5 : 1
    }
}

private struct ScheduledTimesEditor: View {
    @Binding var times: [ScheduledTime]
    @State private var activeTimeID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            FlowLayout(spacing: 8) {
                ForEach(times) { time in
                    ScheduledTimePill(
                        time: timeBinding(for: time.id),
                        existingKeys: existingKeys(excluding: time.id),
                        canDelete: times.count > 1,
                        isPickerPresented: Binding(
                            get: { activeTimeID == time.id },
                            set: { isPresented in
                                if isPresented {
                                    activeTimeID = time.id
                                } else {
                                    activeTimeID = nil
                                    sortTimesAnimatedAfterDelay()
                                }
                            }
                        )
                    ) {
                        guard times.count > 1 else { return }
                        times.removeAll { $0.id == time.id }
                    }
                }

                Button {
                    addTime()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加时间点")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(height: 30)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            ensureAtLeastOneTime()
            normalizeTimes()
        }
        .onChange(of: times) { _, _ in
            ensureAtLeastOneTime()
        }
    }

    private func existingKeys(excluding id: UUID) -> Set<Int> {
        Set(times.filter { $0.id != id }.map { $0.hour * 60 + $0.minute })
    }

    private func timeBinding(for id: UUID) -> Binding<ScheduledTime> {
        Binding(
            get: {
                times.first { $0.id == id } ?? ScheduledTime(id: id, hour: 0, minute: 0, enabled: true)
            },
            set: { updatedTime in
                guard let index = times.firstIndex(where: { $0.id == id }) else { return }
                times[index] = ScheduledTime(id: updatedTime.id, hour: updatedTime.hour, minute: updatedTime.minute, enabled: true)
            }
        )
    }

    private func addTime() {
        let used = Set(times.map { $0.hour * 60 + $0.minute })
        let candidate = (0..<1440).first { !used.contains($0) } ?? 0
        let newTime = ScheduledTime(hour: candidate / 60, minute: candidate % 60, enabled: true)
        times.append(newTime)
        activeTimeID = newTime.id
    }

    private func ensureAtLeastOneTime() {
        if times.isEmpty {
            times = [ScheduledTime(hour: 9, minute: 0, enabled: true)]
        }
    }

    private func normalizeTimes() {
        times = times.map { ScheduledTime(id: $0.id, hour: $0.hour, minute: $0.minute, enabled: true) }
    }

    private func sortTimesAnimated() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            times.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        }
    }

    private func sortTimesAnimatedAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard activeTimeID == nil else { return }
            sortTimesAnimated()
        }
    }
}

private struct ScheduledTimePill: View {
    @Binding var time: ScheduledTime
    let existingKeys: Set<Int>
    let canDelete: Bool
    @Binding var isPickerPresented: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isPickerPresented = true
            } label: {
                Text(time.formattedTime())
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: 58, height: 24)
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius))
            .popover(isPresented: $isPickerPresented) {
                TimeGridPicker(time: $time, disabledKeys: existingKeys) {
                    isPickerPresented = false
                }
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(canDelete ? .red : .secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canDelete)
            .help(canDelete ? "删除时间点" : "至少保留一个时间点")
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(isPickerPresented ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(isPickerPresented ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Capsule())
        .onTapGesture {
            isPickerPresented = true
        }
    }
}

private struct TimeGridPicker: View {
    @Binding var time: ScheduledTime
    let disabledKeys: Set<Int>
    let onCommit: () -> Void

    @State private var inputState = TimeSegmentInputState()
    @State private var isKeyboardFocused = false
    @State private var isSessionActive = false

    private let hourColumns = Array(repeating: GridItem(.fixed(30), spacing: 5), count: 12)
    private let minuteColumns = Array(repeating: GridItem(.fixed(37), spacing: 4), count: 10)
    private let hourCellWidth: CGFloat = 30
    private let minuteCellWidth: CGFloat = 37
    private let gridWidth: CGFloat = 415

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("选择时间")
                    .font(.headline)
                Spacer()
                segmentedTimeInput
            }
            .frame(width: gridWidth)

            Text("支持键盘输入，回车确定")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("小时")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: hourColumns, spacing: 4) {
                ForEach(0..<24, id: \.self) { hour in
                    timeCell(String(format: "%02d", hour), width: hourCellWidth, selected: time.hour == hour, disabled: false) {
                        time.hour = hour
                        inputState.clearBuffers()
                        focusKeyboardInput()
                    }
                }
            }
            .frame(width: gridWidth, alignment: .leading)

            Text("分钟")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: minuteColumns, spacing: 4) {
                ForEach(0..<60, id: \.self) { minute in
                    timeCell(String(format: "%02d", minute), width: minuteCellWidth, selected: time.minute == minute, disabled: disabledKeys.contains(time.hour * 60 + minute)) {
                        time.minute = minute
                        inputState.clearBuffers()
                        focusKeyboardInput()
                    }
                }
            }
            .frame(width: gridWidth, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(width: 455, height: 366, alignment: .topLeading)
        .background(
            KeyboardCaptureView(
                isFocused: $isKeyboardFocused,
                onCharacter: handleKeyboardCharacter
            )
            .frame(width: 0, height: 0)
        )
        .onAppear {
            isSessionActive = true
            inputState.focus(.hour)
            focusKeyboardInput()
        }
        .onDisappear {
            endSession()
        }
    }

    private var segmentedTimeInput: some View {
        HStack(spacing: 0) {
            timeSegment(.hour)
            Text(":")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 1)
            timeSegment(.minute)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TimerEditorMetrics.controlCornerRadius)
                .stroke(isKeyboardFocused ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            focusKeyboardInput()
        }
    }

    private func timeSegment(_ segment: TimeSegmentInputState.Segment) -> some View {
        Text(inputState.segmentText(segment, hour: time.hour, minute: time.minute))
            .font(.system(.title3, design: .rounded))
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(Color.accentColor)
            .frame(width: 30)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: TimerEditorMetrics.smallCornerRadius)
                    .fill(inputState.focusedSegment == segment ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .onTapGesture {
                inputState.focus(segment)
                focusKeyboardInput()
            }
    }

    private func handleKeyboardCharacter(_ character: Character) {
        guard isSessionActive else { return }

        var hour = time.hour
        var minute = time.minute
        let action = inputState.handle(character: character, hour: &hour, minute: &minute, disabledKeys: disabledKeys)

        if time.hour != hour {
            time.hour = hour
        }
        if time.minute != minute {
            time.minute = minute
        }

        if action == .commit {
            closePicker()
            return
        }
        focusKeyboardInput()
    }

    private func closePicker() {
        endSession()
        DispatchQueue.main.async {
            if !isSessionActive {
                onCommit()
            }
        }
    }

    private func endSession() {
        isSessionActive = false
        isKeyboardFocused = false
        inputState.clearBuffers()
    }

    private func focusKeyboardInput() {
        guard isSessionActive else { return }

        DispatchQueue.main.async {
            if isSessionActive {
                isKeyboardFocused = true
            }
        }
    }

    private func timeCell(_ text: String, width: CGFloat, selected: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .monospacedDigit()
                .frame(width: width, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: TimerEditorMetrics.smallCornerRadius)
                        .fill(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.28 : 1)
    }
}

private struct KeyboardCaptureView: NSViewRepresentable {
    @Binding var isFocused: Bool
    let onCharacter: (Character) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCharacter = onCharacter
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onCharacter = onCharacter

        if isFocused, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class KeyCaptureNSView: NSView {
    var onCharacter: ((Character) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            onCharacter?("\n")
            return
        }

        if event.keyCode == 48 {
            onCharacter?("\t")
            return
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            super.keyDown(with: event)
            return
        }

        for character in characters {
            onCharacter?(character)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var cursor = CGPoint.zero
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > width, cursor.x > 0 {
                cursor.x = 0
                cursor.y += lineHeight + spacing
                lineHeight = 0
            }
            cursor.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: cursor.y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursor = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > bounds.maxX, cursor.x > bounds.minX {
                cursor.x = bounds.minX
                cursor.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: cursor, proposal: ProposedViewSize(size))
            cursor.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private enum SystemSound: String, CaseIterable {
    case basso = "Basso"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case glass = "Glass"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case tink = "Tink"
}

#Preview("计时器管理") {
    TimerManagementView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
        .frame(width: 680, height: 760)
}

#Preview("计时器列表项") {
    TimerManagerListItemView(
        timer: .constant(TimerItem(emoji: "💧", title: "喝水", body: "保持补水", intervalSeconds: 900, customColor: .init(colorType: .blue))),
        events: [
            ReminderEvent(timerID: UUID(), scheduledAt: Date(), firedAt: Date(), status: .completed)
        ],
        isExpanded: true,
        onToggleExpanded: {},
        onToggleRunning: {},
        onEdit: {},
        onDuplicate: {},
        onDelete: {}
    )
    .padding()
    .frame(width: 620)
}

#Preview("编辑弹窗") {
    TimerEditorSheet(draft: .new(TimerItem(emoji: "🔔", title: "提醒", body: "起来活动一下"))) { _, _ in }
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
}

#Preview("时间选择器") {
    TimeGridPicker(time: .constant(ScheduledTime(hour: 9, minute: 30)), disabledKeys: [9 * 60 + 0, 12 * 60 + 30]) {}
        .padding()
}

#Preview("统计图") {
    let timerID = UUID()
    let timer = TimerItem(id: timerID, emoji: "💧", title: "喝水", body: "保持补水")
    ReminderStatsChartView(
        timer: timer,
        events: [
            ReminderEvent(timerID: timerID, scheduledAt: Date(), firedAt: Date().addingTimeInterval(-3600), status: .completed),
            ReminderEvent(timerID: timerID, scheduledAt: Date(), firedAt: Date().addingTimeInterval(-1200), status: .ignored)
        ]
    )
    .padding()
    .frame(width: 620)
}
