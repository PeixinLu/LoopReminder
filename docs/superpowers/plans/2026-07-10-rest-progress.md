# 休息中进度条 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让两个计时器列表在休息期间显示每计时器的紫色递减进度和“休息中”文案。

**Architecture:** `ReminderController` 发布休息截止时间；`TimerProgressState` 根据截止时间或循环参数计算呈现状态；设置和预览列表共用该计算。

**Tech Stack:** Swift、SwiftUI、Foundation、xcodebuild。

### Task 1: 进度状态计算

**Files:**
- Create: `LoopReminder/Models/TimerProgressState.swift`
- Create: `Tests/TimerProgressStateTests.swift`

- [ ] 先写测试：休息截止时间在未来时返回 `isResting == true`、`progress == remaining / restSeconds`；截止时间已过时返回普通循环进度。
- [ ] 运行 `swiftc LoopReminder/Models/TimerProgressState.swift Tests/TimerProgressStateTests.swift -o /tmp/timer-progress-tests && /tmp/timer-progress-tests`，确认实现前失败。
- [ ] 实现 `TimerProgressState.make(lastFireEpoch:intervalSeconds:restSeconds:restEndsAt:now:)`，返回 `isResting`、`progress`、`remainingSeconds`。
- [ ] 重跑测试，预期 `PASS`。

### Task 2: 控制器状态与 UI

**Files:**
- Modify: `LoopReminder/Controllers/ReminderController.swift`
- Modify: `LoopReminder/Views/Settings/TimerManagementView.swift`
- Modify: `LoopReminder/Views/Settings/PreviewSectionView.swift`

- [ ] 将 `restDueDates` 设为可发布状态，并提供 `restDueDate(for:)`。
- [ ] 在两个进度条用 `TimerProgressState`：休息时紫色轨道/填充、填充宽度随剩余时间缩短、文案为 `休息中 · mm:ss`；普通阶段保留绿色与原有文案。
- [ ] 运行 `xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release build`，预期 `** BUILD SUCCEEDED **`。
