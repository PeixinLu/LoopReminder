# Timer Management Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the redesigned timer management page with sheet-based editing, per-timer stay duration, actionable notifications, and daily reminder statistics.

**Architecture:** Reuse the existing `TimerItem`, `AppSettings`, `ReminderController`, and SwiftUI settings architecture. Keep new view components in existing compiled files to avoid Xcode project file churn, while splitting behavior into focused SwiftUI structs. Add reminder event persistence to `AppSettings` so overlay actions and stats share one data source.

**Tech Stack:** SwiftUI, AppKit `NSPanel`, Combine, UserDefaults persistence, Xcode project `LoopReminder.xcodeproj`.

## Global Constraints

- Do not require editing while a timer is running.
- Allow deleting the last timer and show an empty state.
- Every edited interface must have an Xcode preview.
- Build must pass with `xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release build`.

---

### Task 1: Data Model And Persistence

**Files:**
- Modify: `LoopReminder/Models/TimerItem.swift`
- Modify: `LoopReminder/Models/AppSettings.swift`

**Interfaces:**
- Produces: `TimerItem.StayDurationMode`, `TimerItem.stayDurationMode`, `TimerItem.stayDurationSeconds`
- Produces: `ReminderEvent`, `ReminderEventStatus`, `AppSettings.recordReminderFired`, `AppSettings.resolveReminderEvent`

- [ ] Add per-timer stay duration fields with backward-compatible `Codable` defaults.
- [ ] Add persisted reminder events in `AppSettings`.
- [ ] Add helper methods to append fired events and update their final status.

### Task 2: Notification Actions

**Files:**
- Modify: `LoopReminder/Views/OverlayNotificationView.swift`
- Modify: `LoopReminder/Controllers/ReminderController.swift`
- Modify: `LoopReminder/Views/Settings/PreviewSectionView.swift`

**Interfaces:**
- Consumes: `ReminderEventStatus`
- Produces: `OverlayNotificationDismissReason`

- [ ] Add compact Ignore and Complete buttons beside the subtitle.
- [ ] Replace boolean dismiss callback with explicit dismiss reasons.
- [ ] Record completed, ignored, and missed events from overlay lifecycle.
- [ ] Use per-timer stay duration when building overlay style.

### Task 3: Timer Management Page

**Files:**
- Replace: `LoopReminder/Views/Settings/TimerManagementView.swift`

**Interfaces:**
- Consumes: `TimerItem` fields, `AppSettings.reminderEvents`, `ReminderController.startTimer`, `ReminderController.stopTimer`

- [ ] Move all/start and add actions into `PageHeader` trailing content.
- [ ] Replace inline expanded editor with list rows, detail disclosure, and sheet editor.
- [ ] Add context menu with start/pause, edit, duplicate, delete.
- [ ] Add delete confirmation for all delete paths.
- [ ] Add empty state for zero timers.
- [ ] Add focused previews for the page, row, editor, time picker, and stats chart.

### Task 4: Build Verification

**Files:**
- Verify project only.

- [ ] Run `xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release build`.
- [ ] Fix compile errors until the command exits successfully.
