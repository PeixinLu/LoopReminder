//
//  TimerManagementView.swift
//  LoopReminder
//
//  计时器管理页面
//

import SwiftUI
import Combine

struct TimerManagementView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    
    @State private var expandedTimerID: UUID? = nil
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case timerEmoji(UUID)
        case timerTitle(UUID)
        case timerBody(UUID)
        case timerInterval(UUID)
        case timerRest(UUID)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 页面标题
            PageHeader(
                icon: "bell.badge.fill",
                iconColor: .blue,
                title: "计时器管理",
                subtitle: "管理您的循环提醒计时器"
            )
            
            // 内容区域 - 可滚动
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        // 停留时间设置
                        stayDurationSection
                        
                        Divider().padding(.vertical, DesignTokens.Spacing.xs)
                        
                        // 操作按钮组
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            startStopAllButton
                            addTimerButton
                        }
                        
                        // 计时器列表
                        ForEach($settings.timers) { $timer in
                            TimerItemCard(
                                timer: $timer,
                                isExpanded: Binding(
                                    get: { expandedTimerID == timer.id },
                                    set: { isExpanded in
                                        withAnimation(.spring(response: 0.3)) {
                                            if isExpanded {
                                                expandedTimerID = timer.id
                                                // 展开时设置为焦点
                                                settings.focusedTimerID = timer.id
                                            } else {
                                                if expandedTimerID == timer.id {
                                                    expandedTimerID = nil
                                                }
                                            }
                                        }
                                    }
                                ),
                                isFocused: settings.focusedTimerID == timer.id,
                                isRunning: settings.isRunning,
                                onFocus: {
                                    settings.focusedTimerID = timer.id
                                },
                                onDelete: {
                                    deleteTimer(timer)
                                },
                                focusedField: $focusedField
                            )
                            .id(timer.id) // 添加 id 修饰符，确保计时器更新时视图刷新
                        }
                        
                        // 提示信息
                        InfoHint("计时器颜色会优先于全局配置", color: .blue)
                        
                        // 计时器数量提示
                        if settings.timers.count >= 8 {
                            InfoHint("已达到最大限制（8个计时器）。过多的计时器会增加心智负担", color: .red)
                        } else if settings.timers.count > 3 {
                            InfoHint("当前有\(settings.timers.count)个计时器。过多的计时器可能增加心智负担，建议精简使用", color: .orange)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .padding(.trailing, DesignTokens.Spacing.xl)
                    .frame(width: proxy.size.width - DesignTokens.Spacing.xl, alignment: .leading)
                }
            }
        }
        .onAppear {
            // 默认焦点在第一个计时器
            if settings.focusedTimerID == nil, let firstTimer = settings.timers.first {
                settings.focusedTimerID = firstTimer.id
            }
        }
        .onChange(of: settings.focusedTimerID) { oldID, newID in
            // 焦点计时器变化时，延迟一帧确保 UI 刷新
            if oldID != newID {
                DispatchQueue.main.async {
                    // 强制触发 UI 更新
                    self.settings.objectWillChange.send()
                }
            }
        }
    }
    
    // MARK: - Buttons
    
    private var stayDurationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SettingRow(icon: "timer", iconColor: .orange, title: "停留时间") {
                let maxStayDuration = max(1.0, settings.intervalSeconds - 1.0)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Slider(value: $settings.overlayStayDuration, in: 1...min(60, maxStayDuration), step: 0.5)
                        .disabled(settings.isRunning)
                        .frame(width: DesignTokens.Layout.sliderWidth)
                        .onChange(of: settings.overlayStayDuration) { _, _ in
                            settings.validateTimingSettings()
                        }
                    Text(String(format: "%.1f秒", settings.overlayStayDuration))
                        .font(DesignTokens.Typography.value)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .frame(width: DesignTokens.Layout.valueDisplayWidth, alignment: .trailing)
                }
            }
            
            InfoHint("通知显示后停留的时间，最大为下次通知时间-过渡动画时间", color: .orange)
        }
    }
    
    private var startStopAllButton: some View {
        let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
        
        return Button {
            toggleAllTimers()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: hasRunningTimer ? "pause.circle.fill" : "play.circle.fill")
                Text(hasRunningTimer ? "全部停止" : "全部启动")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(hasRunningTimer ? .orange : .green)
    }
    
    // MARK: - Add Timer Button
    
    private var addTimerButton: some View {
        Button {
            addNewTimer()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                Text("添加新计时器")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        // .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(settings.timers.count >= 8)
        .opacity(settings.timers.count >= 8 ? 0.5 : 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func toggleAllTimers() {
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
    
    private func addNewTimer() {
        // 限制最大计时器数量为8个
        guard settings.timers.count < 8 else {
            return
        }
        
        let timerNumber = settings.timers.count + 1
        let newTimer = TimerItem(
            emoji: "🔔",
            title: "计时器 \(timerNumber)",
            body: "起来活动一下"
        )
        settings.timers.append(newTimer)
        
        // 自动展开并设置焦点
        withAnimation(.spring(response: 0.3)) {
            expandedTimerID = newTimer.id
            settings.focusedTimerID = newTimer.id
        }
    }
    
    private func deleteTimer(_ timer: TimerItem) {
        // 至少保留一个计时器
        guard settings.timers.count > 1 else {
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            if let index = settings.timers.firstIndex(where: { $0.id == timer.id }) {
                settings.timers.remove(at: index)
                
                // 如果删除的是焦点计时器，焦点移到第一个
                if settings.focusedTimerID == timer.id {
                    settings.focusedTimerID = settings.timers.first?.id
                }
                
                // 如果删除的是展开的计时器，收起
                if expandedTimerID == timer.id {
                    expandedTimerID = nil
                }
            }
        }
    }
}

// MARK: - Timer Item Card

struct TimerItemCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController
    @Binding var timer: TimerItem
    @Binding var isExpanded: Bool
    var isFocused: Bool
    var isRunning: Bool
    var onFocus: () -> Void
    var onDelete: () -> Void
    var focusedField: FocusState<TimerManagementView.FocusedField?>.Binding
    
    @State private var intervalInputValue: String = ""
    @State private var intervalSelectedUnit: TimeUnit = .minutes
    @State private var restInputValue: String = ""
    @State private var restSelectedUnit: TimeUnit = .minutes
    @State private var selectedColorType: TimerItem.TimerColor.ColorType = .black
    @State private var customColor: Color = .gray
    @State private var countdownText: String = ""
    @State private var progressValue: Double = 0.0
    @State private var timerID: UUID = UUID() // 保存计时器ID，避免访问已删除的timer对象
    @State private var needsSave: Bool = false // 标记是否有未保存的修改
    @State private var isIntervalFocused: Bool = false // 间隔输入框是否有焦点
    @State private var isRestFocused: Bool = false // 休息输入框是否有焦点
    @State private var intervalValidationMessage: String? = nil // 间隔验证消息
    @State private var restValidationMessage: String? = nil // 休息验证消息
    @State private var isHovering: Bool = false // 鼠标悬停状态
    
    private let timer2 = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    enum TimeUnit: String, CaseIterable {
        case seconds = "秒"
        case minutes = "分钟"
        
        var multiplier: Double {
            switch self {
            case .seconds: return 1
            case .minutes: return 60
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 折叠状态显示
            collapsedView
            
            // 展开状态显示
            if isExpanded {
                expandedView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 350, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadius)
                .fill(isFocused ? Color.blue.opacity(0.05) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadius)
                .strokeBorder(isFocused ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .onAppear {
            timerID = timer.id // 初始化时保存ID
            initializeInputValues()
            initializeColorSelection()
        }
        .onDisappear {
            // 组件消失时（例如切换到其他计时器），立即保存未保存的修改
            if needsSave {
                // 立即保存，不等待异步
                saveIntervalIfNeeded()
                saveRestIntervalIfNeeded()
                
                // 强制触发 settings 更新，确保 UI 刷新
                settings.objectWillChange.send()
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            // 收起时保存修改
            if !newValue && needsSave {
                saveIntervalIfNeeded()
                saveRestIntervalIfNeeded()
                // 强制触发 settings 更新
                settings.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Collapsed View
    
    private var collapsedView: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 计时器图标和名称
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(timer.emoji)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timer.displayName)
                            .font(.headline)
                        // 显示关键信息：频率和内容
                        HStack(spacing: 4) {
                            Text(timer.formattedInterval())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(timer.title.isEmpty ? timer.body : timer.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // 休息和自定义颜色标记
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if timer.isRestEnabled {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .help("休息 \(timer.formattedRestInterval())")
                    }
                    
                    if timer.customColor != nil {
                        Circle()
                            .fill(timer.customColor?.toColor() ?? .gray)
                            .frame(width: 10, height: 10)
                            .help("自定义颜色")
                    }
                }
                
                // 悬停时显示删除按钮
                if isHovering && settings.timers.count > 1 {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("删除计时器")
                    .transition(.scale.combined(with: .opacity))
                }
                
                // 启动/停止按钮
                if timer.isContentValid() {
                    Button {
                        toggleTimerRunning()
                    } label: {
                        Image(systemName: isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(isTimerRunning ? .orange : .green)
                    }
                    .buttonStyle(.plain)
                    .help(isTimerRunning ? "暂停计时器" : "启动计时器")
                }
                
                // 设置按钮（圆形）
                Button {
                    isExpanded.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 28, height: 28)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                .help("编辑计时器")
            }
            .padding(DesignTokens.Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onFocus()
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            
            // 进度条
            if isTimerRunning {
                GeometryReader { proxy in
                    let clampedProgress = max(0, min(1.0, progressValue))
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.15))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: proxy.size.width * clampedProgress, height: 3)
                            .animation(.linear(duration: 0.3), value: clampedProgress)
                    }
                }
                .frame(height: 3)
                
                if !countdownText.isEmpty {
                    HStack {
                        Text(countdownText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.sm)
                }
            }
        }
    .onReceive(timer2) { _ in
            // 检查计时器是否仍然存在于数组中（防止删除后仍触发更新导致崩溃）
            guard settings.timers.contains(where: { $0.id == timerID }) else {
                return
            }
            if isTimerRunning {
                updateCountdown()
            }
        }
    }
    
    private var isTimerRunning: Bool {
        timer.isRunning
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // 计时器设置标题
                Text("计时器设置")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.secondary)
                
                // 通知内容
                SettingRow(icon: "face.smiling", iconColor: .green, title: "图标", labelWidth: 70) {
                    HStack(spacing: 6) {
                        TextField("", text: $timer.emoji)
                            .textFieldStyle(.roundedBorder)
                            .disabled(settings.isRunning)
                            .focused(focusedField, equals: .timerEmoji(timer.id))
                            .frame(width: 50)
                        
                        Button {
                            // 聚焦到emoji输入框，触发emoji选择器
                            focusedField.wrappedValue = .timerEmoji(timer.id)
                            // 延迟一下再触发，确保聚焦已生效
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NSApp.orderFrontCharacterPalette(nil)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "face.smiling")
                                    .font(.caption)
                                Text("Emoji")
                                    .font(.caption)
                            }
                        }
                        .controlSize(.small)
                        .disabled(settings.isRunning)
                    }
                }
                
                SettingRow(icon: "textformat", iconColor: .green, title: "标题", labelWidth: 70) {
                    TextField("计时器名称", text: $timer.title)
                        .textFieldStyle(.roundedBorder)
                        .disabled(settings.isRunning)
                        .focused(focusedField, equals: .timerTitle(timer.id))
                }
                
                SettingRow(icon: "text.alignleft", iconColor: .green, title: "描述", labelWidth: 70) {
                    TextField("通知内容", text: $timer.body, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .disabled(settings.isRunning)
                        .focused(focusedField, equals: .timerBody(timer.id))
                }

                // 提醒类型选择
                HStack {
                    Text("提醒类型")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Picker("", selection: $timer.reminderType) {
                    ForEach(ReminderType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(settings.isRunning)

                if timer.reminderType == .interval {
                    InfoHint("按照设定的时间间隔循环提醒", color: .blue)
                } else {
                    InfoHint("在每天的指定时间点提醒", color: .purple)
                }

                // 通知频率（仅间隔提醒模式）
                if timer.reminderType == .interval {
                    SettingRow(icon: "timer", iconColor: .blue, title: "间隔", labelWidth: 70) {
                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                TextField("间隔", text: $intervalInputValue, onEditingChanged: { isEditing in
                                    isIntervalFocused = isEditing
                                    if !isEditing {
                                        saveIntervalIfNeeded()
                                    }
                                })
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .disabled(settings.isRunning)
                                .focused(focusedField, equals: .timerInterval(timer.id))
                                .onSubmit {
                                    saveIntervalIfNeeded()
                                }
                                .onChange(of: intervalInputValue) { _, newValue in
                                    let filtered = newValue.filter { "0123456789.".contains($0) }
                                    if filtered != newValue {
                                        intervalInputValue = filtered
                                    } else {
                                        // 标记有修改，需要保存
                                        needsSave = true
                                        // 实时验证
                                        updateIntervalValidation()
                                    }
                                }

                                Picker("", selection: $intervalSelectedUnit) {
                                    ForEach(TimeUnit.allCases, id: \.self) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                                .disabled(settings.isRunning)
                                .onChange(of: intervalSelectedUnit) { _, _ in
                                    updateIntervalValidation()
                                    saveIntervalIfNeeded()
                                }
                            }

                            // 显示格式化后的时间
                            Text(timer.formattedInterval())
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)

                            // 显示验证消息
                            if let message = intervalValidationMessage {
                                Text(message)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                // 定点时间配置（仅定点提醒模式）
                if timer.reminderType == .scheduled {
                    scheduledTimesSection
                }
                
                // 休息一下
                HStack {
                    Text("休息一下")
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $timer.isRestEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(settings.isRunning)
                }
                
                if timer.isRestEnabled {
                    SettingRow(icon: "pause.circle.fill", iconColor: .purple, title: "时长", labelWidth: 70) {
                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                TextField("时长", text: $restInputValue, onEditingChanged: { isEditing in
                                    isRestFocused = isEditing
                                    if !isEditing {
                                        saveRestIntervalIfNeeded()
                                    }
                                })
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .disabled(settings.isRunning)
                                .focused(focusedField, equals: .timerRest(timer.id))
                                .onSubmit {
                                    saveRestIntervalIfNeeded()
                                }
                                .onChange(of: restInputValue) { _, newValue in
                                    let filtered = newValue.filter { "0123456789.".contains($0) }
                                    if filtered != newValue {
                                        restInputValue = filtered
                                    } else {
                                        // 标记有修改，需要保存
                                        needsSave = true
                                        // 实时验证
                                        updateRestValidation()
                                    }
                                }
                                
                                Picker("", selection: $restSelectedUnit) {
                                    ForEach(TimeUnit.allCases, id: \.self) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                                .disabled(settings.isRunning)
                                .onChange(of: restSelectedUnit) { _, _ in
                                    updateRestValidation()
                                    saveRestIntervalIfNeeded()
                                }
                            }
                            
                            // 显示格式化后的时间
                            Text(timer.formattedRestInterval())
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.purple)
                            
                            // 显示验证消息
                            if let message = restValidationMessage {
                                Text(message)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                
                // 颜色配置
                colorConfigSection
                
                // 删除按钮
                if settings.timers.count > 1 {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("删除此计时器")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(settings.isRunning)
                }
                
                if settings.isRunning {
                    LockHint("请先暂停才能修改")
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Color Config Section
    
    private var colorConfigSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("通知颜色")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { timer.customColor != nil },
                    set: { enabled in
                        if enabled {
                            // 启用自定义颜色，使用当前全局配置
                            timer.customColor = TimerItem.TimerColor.from(
                                appSettingsColor: settings.overlayColor,
                                customColor: settings.overlayCustomColor
                            )
                            selectedColorType = timer.customColor?.colorType ?? .black
                            if selectedColorType == .custom {
                                customColor = timer.customColor?.toColor() ?? .gray
                            }
                        } else {
                            // 禁用自定义颜色
                            timer.customColor = nil
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(settings.isRunning)
            }
            
            if timer.customColor != nil {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Picker("颜色", selection: $selectedColorType) {
                        ForEach(TimerItem.TimerColor.ColorType.allCases, id: \.self) { colorType in
                            Text(colorType.rawValue).tag(colorType)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(settings.isRunning)
                    .onChange(of: selectedColorType) { _, newValue in
                        updateTimerColor(newValue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if selectedColorType == .custom {
                        ColorPicker("自定义颜色", selection: $customColor)
                            .disabled(settings.isRunning)
                            .onChange(of: customColor) { _, newColor in
                                let components = newColor.components()
                                timer.customColor = TimerItem.TimerColor(
                                    colorType: .custom,
                                    customR: components.red,
                                    customG: components.green,
                                    customB: components.blue
                                )
                            }
                    }
                    
                    InfoHint("此计时器的颜色会优先于全局颜色", color: .orange)
                }
            }
        }
    }

    // MARK: - Scheduled Times Section

    private var scheduledTimesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("提醒时间")
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // 时间点列表
            ForEach(timer.scheduledTimes) { time in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    // 启用开关
                    Toggle("", isOn: Binding(
                        get: { time.enabled },
                        set: { newValue in
                            if let index = timer.scheduledTimes.firstIndex(where: { $0.id == time.id }) {
                                timer.scheduledTimes[index].enabled = newValue
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(settings.isRunning)

                    // 时间选择器
                    DatePicker("", selection: Binding(
                        get: {
                            Calendar.current.date(from: DateComponents(hour: time.hour, minute: time.minute)) ?? Date()
                        },
                        set: { newDate in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            if let index = timer.scheduledTimes.firstIndex(where: { $0.id == time.id }) {
                                timer.scheduledTimes[index].hour = components.hour ?? 9
                                timer.scheduledTimes[index].minute = components.minute ?? 0
                            }
                        }
                    ), displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .disabled(settings.isRunning)

                    Spacer()

                    // 删除按钮
                    if timer.scheduledTimes.count > 1 {
                        Button {
                            timer.scheduledTimes.removeAll { $0.id == time.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(settings.isRunning)
                    }
                }
            }

            // 添加新时间点按钮
            Button {
                let newTime = ScheduledTime(hour: 12, minute: 0, enabled: true)
                timer.scheduledTimes.append(newTime)
            } label: {
                Label("添加时间点", systemImage: "plus.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(settings.isRunning)

            if timer.scheduledTimes.filter({ $0.enabled }).isEmpty {
                InfoHint("请至少启用一个提醒时间点", color: .orange)
            }
        }
    }

    // MARK: - Helper Methods
    
    private func initializeInputValues() {
        // 初始化间隔输入
        let intervalSeconds = timer.intervalSeconds
        if intervalSeconds >= 60 && Int(intervalSeconds) % 60 == 0 {
            intervalSelectedUnit = .minutes
            intervalInputValue = String(Int(intervalSeconds / 60))
        } else {
            intervalSelectedUnit = .seconds
            intervalInputValue = String(Int(intervalSeconds))
        }
        
        // 初始化休息输入
        let restSeconds = timer.restSeconds
        if restSeconds >= 60 && Int(restSeconds) % 60 == 0 {
            restSelectedUnit = .minutes
            restInputValue = String(Int(restSeconds / 60))
        } else {
            restSelectedUnit = .seconds
            restInputValue = String(Int(restSeconds))
        }
    }
    
    private func initializeColorSelection() {
        if let timerColor = timer.customColor {
            selectedColorType = timerColor.colorType
            if timerColor.colorType == .custom {
                customColor = timerColor.toColor()
            }
        }
    }
    
    /// 更新间隔验证消息
    private func updateIntervalValidation() {
        guard let value = Double(intervalInputValue), value > 0 else {
            intervalValidationMessage = nil
            return
        }
        
        let seconds = value * intervalSelectedUnit.multiplier
        
        if seconds < 5 {
            intervalValidationMessage = "⚠️ 最小值为5秒，将自动调整"
        } else if seconds > 7200 {
            intervalValidationMessage = "⚠️ 最大值为2小时，将自动调整"
        } else {
            intervalValidationMessage = nil
        }
    }
    
    /// 更新休息验证消息
    private func updateRestValidation() {
        guard let value = Double(restInputValue), value > 0 else {
            restValidationMessage = nil
            return
        }
        
        let seconds = value * restSelectedUnit.multiplier
        
        if seconds < 5 {
            restValidationMessage = "⚠️ 最小值为5秒，将自动调整"
        } else if seconds > 7200 {
            restValidationMessage = "⚠️ 最大值为2小时，将自动调整"
        } else {
            restValidationMessage = nil
        }
    }
    
    /// 保存间隔时间（如果有修改）
    private func saveIntervalIfNeeded() {
        guard needsSave else { return }
        
        guard let value = Double(intervalInputValue), value > 0 else {
            initializeInputValues()
            intervalValidationMessage = nil
            needsSave = false
            return
        }
        
        var seconds = value * intervalSelectedUnit.multiplier
        if seconds < 5 { seconds = 5 }
        if seconds > 7200 { seconds = 7200 }
        
        // 更新计时器值
        timer.intervalSeconds = seconds
        
        // 立即刷新显示
        initializeInputValues()
        intervalValidationMessage = nil // 保存后清除验证消息
        needsSave = false
        
        // 强制触发父级 settings 对象的更新通知
        DispatchQueue.main.async {
            self.settings.objectWillChange.send()
        }
    }
    
    /// 验证并更新间隔时间（保留兼容性）
    private func validateAndUpdateInterval() {
        needsSave = true
        saveIntervalIfNeeded()
    }
    
    /// 保存休息时间（如果有修改）
    private func saveRestIntervalIfNeeded() {
        guard needsSave else { return }
        
        guard let value = Double(restInputValue), value > 0 else {
            initializeInputValues()
            restValidationMessage = nil
            needsSave = false
            return
        }
        
        var seconds = value * restSelectedUnit.multiplier
        if seconds < 5 { seconds = 5 }
        if seconds > 7200 { seconds = 7200 }
        
        // 更新计时器值
        timer.restSeconds = seconds
        
        // 立即刷新显示
        initializeInputValues()
        restValidationMessage = nil // 保存后清除验证消息
        needsSave = false
        
        // 强制触发父级 settings 对象的更新通知
        DispatchQueue.main.async {
            self.settings.objectWillChange.send()
        }
    }
    
    /// 验证并更新休息时间（保留兼容性）
    private func validateAndUpdateRestInterval() {
        needsSave = true
        saveRestIntervalIfNeeded()
    }
    
    private func updateTimerColor(_ colorType: TimerItem.TimerColor.ColorType) {
        if colorType == .custom {
            let components = customColor.components()
            timer.customColor = TimerItem.TimerColor(
                colorType: .custom,
                customR: components.red,
                customG: components.green,
                customB: components.blue
            )
        } else {
            timer.customColor = TimerItem.TimerColor(colorType: colorType)
        }
    }
    
    private func toggleTimerRunning() {
        // 先主动移除焦点，确保输入框触发保存
        if isIntervalFocused {
            focusedField.wrappedValue = nil
            // 等待焦点移除后再保存
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.saveIntervalIfNeeded()
                self.performToggleTimer()
            }
        } else if isRestFocused {
            focusedField.wrappedValue = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.saveRestIntervalIfNeeded()
                self.performToggleTimer()
            }
        } else {
            // 没有焦点时直接执行
            if needsSave {
                saveIntervalIfNeeded()
                saveRestIntervalIfNeeded()
            }
            performToggleTimer()
        }
    }
    
    private func performToggleTimer() {
        if timer.isRunning {
            // 停止当前计时器
            controller.stopTimer(timer.id, settings: settings)
        } else {
            // 启动当前计时器
            controller.startTimer(timer.id, settings: settings)
        }
    }
    
    private func updateCountdown() {
        guard isTimerRunning else {
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
}

// MARK: - Preview

#Preview {
    TimerManagementView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
        .frame(width: 600, height: 700)
}
