# 唤醒后计时器恢复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 macOS 锁屏或系统睡眠恢复后，无条件恢复所有已开启计时器的运行时调度，并仅在用户开启选项且经过五分钟时重置循环提醒。

**Architecture:** 日期计算和错过定点识别放入不依赖 AppKit 的 `ReminderRecoverySchedule`，由独立 Swift 脚本测试。 `ReminderController` 监听 `NSWorkspace` 睡眠/唤醒通知和现有锁屏通知，统一去重后执行 P0；满足设置与时长条件时再执行 P1。

**Tech Stack:** Swift 6、Foundation、AppKit、独立 Swift 测试运行器、xcodebuild。

## Global Constraints

- 保持应用内浮层通知方案，不增加 `UNCalendarNotificationTrigger`。
- 定点提醒恢复时绝不补发；仅记录错过日志并安排下一个未来时点。
- P0 恢复不受 `resetOnWakeEnabled` 影响；P1 仅在该选项为真且经过时间不少于 300 秒时执行。
- 所有 UI 与 `AppSettings` 访问保持在 `@MainActor`。

---

### Task 1: 恢复时间计算与测试

**Files:**

- Create: `LoopReminder/Models/ReminderRecoverySchedule.swift`
- Create: `Tests/ReminderRecoveryScheduleTests.swift`

**Interfaces:**

- Produces: `ReminderRecoverySchedule.nextScheduledDate(hour:minute:now:calendar:) -> Date`
- Produces: `ReminderRecoverySchedule.missedScheduledTimes(times:from:through:calendar:) -> [ScheduledTime]`
- Produces: `ReminderRecoverySchedule.nextIntervalDate(lastFireEpoch:interval:now:) -> Date`
- Produces: `ReminderRecoverySchedule.shouldResetInterval(isEnabled:elapsed:) -> Bool`

- [ ] **Step 1: Write the failing test**

```swift
func testNextScheduledDateMovesPastTimeToTomorrow() {
    let next = ReminderRecoverySchedule.nextScheduledDate(hour: 9, minute: 30, now: makeDate(day: 2, hour: 10, minute: 0), calendar: utcCalendar)
    expect(next == makeDate(day: 3, hour: 9, minute: 30), "past time moves to tomorrow")
}

func testMissedTimesOnlyIncludesSleepWindow() {
    let missed = ReminderRecoverySchedule.missedScheduledTimes(
        times: [ScheduledTime(hour: 9, minute: 30), ScheduledTime(hour: 12, minute: 0)],
        from: makeDate(day: 1, hour: 23, minute: 0),
        through: makeDate(day: 2, hour: 10, minute: 0),
        calendar: utcCalendar
    )
    expect(missed.map(\.formattedTime) == ["09:30"], "only 09:30 is missed")
}

func testOverdueIntervalSchedulesImmediately() {
    let now = makeDate(day: 2, hour: 10, minute: 0)
    let next = ReminderRecoverySchedule.nextIntervalDate(lastFireEpoch: makeDate(day: 2, hour: 9, minute: 0).timeIntervalSince1970, interval: 1800, now: now)
    expect(next == now, "overdue interval runs immediately")
}

func testIntervalResetRequiresOptionAndFiveMinutes() {
    expect(!ReminderRecoverySchedule.shouldResetInterval(isEnabled: false, elapsed: 600), "disabled option does not reset")
    expect(!ReminderRecoverySchedule.shouldResetInterval(isEnabled: true, elapsed: 299), "short sleep does not reset")
    expect(ReminderRecoverySchedule.shouldResetInterval(isEnabled: true, elapsed: 300), "five minutes resets")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swiftc LoopReminder/Models/TimerItem.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift -o /tmp/reminder-recovery-tests && /tmp/reminder-recovery-tests`

Expected: compilation fails because `ReminderRecoverySchedule` does not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
enum ReminderRecoverySchedule {
    static func nextScheduledDate(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: now)
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? now
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? now
    }

    static func missedScheduledTimes(times: [ScheduledTime], from: Date, through: Date, calendar: Calendar) -> [ScheduledTime] {
        guard through > from else { return [] }
        var result: [ScheduledTime] = []
        var day = calendar.startOfDay(for: from)
        let endDay = calendar.startOfDay(for: through)
        while day <= endDay {
            for time in times {
                if let candidate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day), candidate >= from && candidate < through {
                    result.append(time)
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? endDay.addingTimeInterval(1)
        }
        return result
    }

    static func nextIntervalDate(lastFireEpoch: Double, interval: TimeInterval, now: Date) -> Date {
        max(now, Date(timeIntervalSince1970: lastFireEpoch + interval))
    }

    static func shouldResetInterval(isEnabled: Bool, elapsed: TimeInterval) -> Bool {
        isEnabled && elapsed >= 300
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swiftc LoopReminder/Models/TimerItem.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift -o /tmp/reminder-recovery-tests && /tmp/reminder-recovery-tests`

Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift
git commit -m "test: cover reminder recovery schedules"
```

### Task 2: P0 生命周期监听与运行时重排

**Files:**

- Modify: `LoopReminder/Controllers/ReminderController.swift:31-38, 175-252, 428-465, 749-842`
- Modify: `Tests/ReminderRecoveryScheduleTests.swift`

**Interfaces:**

- Consumes: all `ReminderRecoverySchedule` methods from Task 1.
- Produces: `ensureLifecycleMonitoring()`, `handleSystemWillSleep()`, `handleRecovery(reason:)`, `recoverScheduledTimers(settings:from:now:)`.

- [ ] **Step 1: Write the failing test**

```swift
func testNextScheduledDateKeepsFutureTimeToday() {
    let next = ReminderRecoverySchedule.nextScheduledDate(hour: 9, minute: 30, now: makeDate(day: 2, hour: 9, minute: 0), calendar: utcCalendar)
    expect(next == makeDate(day: 2, hour: 9, minute: 30), "future time stays today")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swiftc LoopReminder/Models/TimerItem.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift -o /tmp/reminder-recovery-tests && /tmp/reminder-recovery-tests`

Expected: the new assertion fails until `nextScheduledDate` handles both future-today and past-tomorrow branches.

- [ ] **Step 3: Write minimal implementation**

Register `.willSleepNotification` and `.didWakeNotification` on `NSWorkspace.shared.notificationCenter`. Retain distributed lock observers, routing wake and unlock through `handleRecovery`. Record the first suspension time and ignore duplicate recovery calls within one second. P0 invalidates and recreates every active interval timer using `nextIntervalDate`; it recreates every active scheduled timer using `nextScheduledDate`. Before scheduling fixed-time items, log every `missedScheduledTimes` result as `定点提醒已错过（系统休眠）：<name> - <HH:mm>` without sending a notification.

- [ ] **Step 4: Run focused test to verify it passes**

Run: `swiftc LoopReminder/Models/TimerItem.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift -o /tmp/reminder-recovery-tests && /tmp/reminder-recovery-tests`

Expected: `PASS`.

- [ ] **Step 5: Build the application**

Run: `xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add LoopReminder/Controllers/ReminderController.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift
git commit -m "fix: recover timers after system wake"
```

### Task 3: P1 长时间休眠后的循环倒计时重置

**Files:**

- Modify: `LoopReminder/Controllers/ReminderController.swift:804-842`
- Modify: `Tests/ReminderRecoveryScheduleTests.swift`

**Interfaces:**

- Consumes: `ReminderRecoverySchedule.shouldResetInterval(isEnabled:elapsed:)` and existing `resetIntervalTimersAfterUnlock(settings:)`.
- Produces: a P1 branch that runs after P0 only when the policy returns true.

- [ ] **Step 1: Write the failing test**

```swift
func testIntervalResetPolicyDoesNotChangeForExactlyFiveMinutes() {
    expect(ReminderRecoverySchedule.shouldResetInterval(isEnabled: true, elapsed: 300), "300 seconds resets")
    expect(!ReminderRecoverySchedule.shouldResetInterval(isEnabled: true, elapsed: 299), "299 seconds does not reset")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swiftc LoopReminder/Models/TimerItem.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift -o /tmp/reminder-recovery-tests && /tmp/reminder-recovery-tests`

Expected: failure until the policy threshold comparison is inclusive.

- [ ] **Step 3: Write minimal implementation**

After P0 completes, call `resetIntervalTimersAfterUnlock(settings:)` only if `shouldResetInterval(isEnabled: settings.resetOnWakeEnabled, elapsed: elapsed)` is true. Do not invoke it for scheduled reminders; their P0 wall-clock schedules stay intact.

- [ ] **Step 4: Run focused test to verify it passes**

Run: `swiftc LoopReminder/Models/TimerItem.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift -o /tmp/reminder-recovery-tests && /tmp/reminder-recovery-tests`

Expected: `PASS`.

- [ ] **Step 5: Run full verification**

Run: `xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add LoopReminder/Controllers/ReminderController.swift LoopReminder/Models/ReminderRecoverySchedule.swift Tests/ReminderRecoveryScheduleTests.swift
git commit -m "fix: reset interval countdown after long wake"
```
