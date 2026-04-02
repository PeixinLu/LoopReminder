# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Loop Reminder is a macOS menu bar app that provides customizable recurring reminders. Built with SwiftUI and MenuBarExtra, it supports multiple timers, overlay notifications, and system notifications with extensive styling options.

## Build Commands

```bash
# Build the app (Release configuration)
xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release build

# Build with archive (for distribution)
xcodebuild -project LoopReminder.xcodeproj -scheme LoopReminder -configuration Release -archivePath build/LoopReminder.xcarchive archive

# Open in Xcode
open LoopReminder.xcodeproj
```

## Architecture

### Core Components

- **AppSettings** (`LoopReminder/Models/AppSettings.swift`): Central `ObservableObject` managing all user preferences. Persists via UserDefaults with Combine bindings. Loads defaults from `DefaultSettings.json`.

- **ReminderController** (`LoopReminder/Controllers/ReminderController.swift`): `ObservableObject` managing timer lifecycle, notification dispatching, and overlay window management. Supports multiple concurrent timers.

- **TimerItem** (`LoopReminder/Models/TimerItem.swift`): Model for individual timer configuration. `Identifiable` and `Cododable` - supports multiple timers per app instance.

### App Structure

- **MenuBarExtra**: App lives in menu bar (no Dock icon by default, uses `.accessory` activation policy)
- **Window("配置", id: "settings")**: Settings window opened from menu bar or on first launch (unless silent launch enabled)

### Data Flow

1. `AppSettings` publishes all configuration values with UserDefaults persistence
2. `ReminderController` reads settings and manages `Timer` objects per `TimerItem`
3. Overlay notifications use `NSPanel` with `OverlayNotificationView` as content
4. Notifications can stack vertically when multiple timers fire simultaneously

### Key Patterns

- Settings use enums for type-safe options (e.g., `OverlayPosition`, `AnimationStyle`, `OverlayColor`)
- Default values centralized in `DefaultSettings.json` - loaded via `DefaultSettingsConfig` struct
- Overlay windows tracked in dictionary by timer UUID for multi-notification support

## Dependencies

- **LaunchAtLogin-Modern**: Boot login management (sindresorhus/LaunchAtLogin-Modern)
- **Sparkle**: Auto-update framework (sparkle-project/Sparkle)

## Release Process

Releases are automated via `.github/workflows/release.yml` triggered by version tags (`v*`). The workflow:
1. Builds archive without code signing
2. Applies ad-hoc signature
3. Generates Sparkle appcast with ED25519 key
4. Creates GitHub release and deploys appcast to Pages

## File Organization

```
LoopReminder/
├── Models/           # AppSettings, TimerItem, UpdateChecker
├── Controllers/      # ReminderController, EventLogger
├── Views/
│   ├── ContentView.swift          # Menu bar dropdown content
│   ├── SettingsView.swift         # Main settings container
│   ├── Settings/                  # Settings sub-views (Basic, Style, Animation, etc.)
│   └── OverlayNotificationView.swift  # Overlay notification display
├── Extensions/       # ColorExtension (RGB component extraction)
├── Resources/        # DefaultSettings.json
└── loopRemiderApp.swift  # App entry point, AppDelegate, MenuBarExtra setup
```