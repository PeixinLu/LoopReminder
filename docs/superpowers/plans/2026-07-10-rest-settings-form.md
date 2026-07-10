# 休息一下表单 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在循环提醒的编辑表单中提供可开启、可设置的每计时器休息配置。

**Architecture:** 在 `TimerEditorSheet` 中维护休息分钟数文本状态，保存时转换为模型的秒数。新增 `RestSettingsEditor`，仅在循环提醒时渲染；它直接绑定既有 `TimerItem.isRestEnabled` 和 `TimerItem.restSeconds`，定点模式不修改它们。

**Tech Stack:** SwiftUI、Swift 6、xcodebuild。

## Global Constraints

- 仅在 `ReminderType.interval` 显示配置，切换提醒类型不清空休息配置。
- 开关关闭时保留时长，开启时默认或恢复为 5 分钟。
- 允许 1...120 的整数分钟；保存为 `TimerItem.restSeconds`。
- 不修改 `TimerItem`、`AppSettings` 或 `ReminderController`。

---

### Task 1: 表单状态与保存校验

**Files:**

- Modify: `LoopReminder/Views/Settings/TimerManagementView.swift:934-1127`
- Test: `Tests/TimerEditorRestSettingsTests.swift`

**Interfaces:**

- Produces: `TimerEditorRestSettings.minutes(from:)`, `seconds(fromMinutes:)`, `validatedMinutes(_:) -> Int?`.

- [ ] **Step 1: Write the failing test**

```swift
expect(TimerEditorRestSettings.validatedMinutes("5") == 5, "valid minutes accepted")
expect(TimerEditorRestSettings.validatedMinutes("0") == nil, "zero rejected")
expect(TimerEditorRestSettings.validatedMinutes("121") == nil, "over-limit rejected")
expect(TimerEditorRestSettings.seconds(fromMinutes: 5) == 300, "minutes saved as seconds")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swiftc LoopReminder/Views/Settings/TimerEditorRestSettings.swift Tests/TimerEditorRestSettingsTests.swift -o /tmp/rest-settings-tests && /tmp/rest-settings-tests`

Expected: compilation fails because `TimerEditorRestSettings` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `TimerEditorRestSettings` with:

```swift
enum TimerEditorRestSettings {
    static func minutes(from seconds: Double) -> Int { min(120, max(1, Int((seconds / 60).rounded()))) }
    static func seconds(fromMinutes minutes: Int) -> Double { Double(minutes * 60) }
    static func validatedMinutes(_ value: String) -> Int? {
        guard let minutes = Int(value), value == String(minutes), (1...120).contains(minutes) else { return nil }
        return minutes
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swiftc LoopReminder/Views/Settings/TimerEditorRestSettings.swift Tests/TimerEditorRestSettingsTests.swift -o /tmp/rest-settings-tests && /tmp/rest-settings-tests`

Expected: `PASS`.

- [ ] **Step 5: Integrate state**

Initialize `@State private var restMinutes` from `TimerEditorRestSettings.minutes(from: draft.timer.restSeconds)`. When saving an interval reminder with rest enabled, validate it and assign `timer.restSeconds = TimerEditorRestSettings.seconds(fromMinutes: minutes)`; otherwise preserve the existing value.

### Task 2: 休息配置行

**Files:**

- Modify: `LoopReminder/Views/Settings/TimerManagementView.swift:1000-1040, 2040-2110`
- Modify: `LoopReminder/Views/Settings/TimerEditorRestSettings.swift`

**Interfaces:**

- Consumes: `TimerEditorRestSettings.validatedMinutes`.
- Produces: `RestSettingsEditor(isEnabled:minutes:)`.

- [ ] **Step 1: Write the failing test**

Add:

```swift
expect(TimerEditorRestSettings.minutes(from: 300) == 5, "stored five minutes shown as five")
expect(TimerEditorRestSettings.minutes(from: 0) == 1, "invalid stored zero clamps to one")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swiftc LoopReminder/Views/Settings/TimerEditorRestSettings.swift Tests/TimerEditorRestSettingsTests.swift -o /tmp/rest-settings-tests && /tmp/rest-settings-tests`

Expected: the new clamp assertion fails until `minutes(from:)` implements its lower bound.

- [ ] **Step 3: Write minimal implementation**

Insert a `TimerConfigRow` between the schedule and notification-stay rows only when `timer.reminderType == .interval`. `RestSettingsEditor` shows a `Toggle("启用休息", isOn: $isEnabled)`, an inline `Text(isEnabled ? "休息 \\(minutes) 分钟" : "未开启")`, and—only when enabled—the existing compact `IntervalConfigEditor` styling with a minutes-only picker and step buttons bound to `minutes`.

- [ ] **Step 4: Build the application**

Run: `xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add LoopReminder/Views/Settings/TimerManagementView.swift LoopReminder/Views/Settings/TimerEditorRestSettings.swift Tests/TimerEditorRestSettingsTests.swift
git commit -m "feat: add rest settings to timer editor"
```
