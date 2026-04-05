import SwiftUI
import AppKit
import Combine

// MARK: - Notification Names

extension Notification.Name {
    static let openSettingsWindow = Notification.Name("openSettingsWindow")
}

// App Delegate to handle lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: ReminderController?
    var settings: AppSettings?
    var openSettingsHandler: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 默认使用 accessory 模式，不在 Dock 显示
        NSApp.setActivationPolicy(.accessory)

        // 监听打开设置窗口的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettingsNotification),
            name: .openSettingsWindow,
            object: nil
        )
    }

    @objc private func handleOpenSettingsNotification() {
        openSettingsHandler?()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理定时器和通知
        controller?.cleanup()
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户点击 Dock 图标或 Command+Tab 切换时，显示设置窗口
        if !flag {
            // 查找并激活窗口
            if let window = NSApp.windows.first(where: { $0.title == "Loop Reminder" || $0.identifier?.rawValue == "settings" }) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
        return true
    }
}

@main
struct LoopReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var controller = ReminderController()
    @Environment(\.openWindow) private var openWindow
    @State private var settingsWindowOpen = false
    @State private var hasLaunched = false

    var body: some Scene {
        // 首次启动时根据设置决定是否打开窗口
        let _ = Task {
            if !hasLaunched {
                hasLaunched = true
                // 设置打开设置窗口的回调
                appDelegate.openSettingsHandler = openSettingsWindow
                appDelegate.controller = controller
                // 等待 scene 初始化完成
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                await MainActor.run {
                    // 只有在非静默启动模式下才打开设置窗口
                    if !settings.silentLaunch {
                        openSettingsWindow()
                    }
                    // 启动时自动开始计时
                    if settings.autoStartTimersOnLaunch {
                        settings.isRunning = true
                        controller.start(settings: settings)
                    }
                }
            }
        }

        return Group {
            // 菜单栏 - 保持应用运行
            MenuBarExtra {
                MenuBarView()
                    .environmentObject(settings)
                    .environmentObject(controller)
            } label: {
                let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
                Image(systemName: hasRunningTimer ? "bell.fill" : "bell")
                    .font(.system(size: 14))
            }
            .menuBarExtraStyle(.window)

            // 配置窗口
            Window("Loop Reminder", id: "settings") {
                SettingsView()
                    .environmentObject(settings)
                    .environmentObject(controller)
                    .onAppear {
                        appDelegate.controller = controller
                        settingsWindowOpen = true
                        // 窗口显示时切换到 regular 模式
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .onDisappear {
                        settingsWindowOpen = false
                        // 切换回 accessory 模式，隐藏 Dock 图标
                        NSApp.setActivationPolicy(.accessory)
                        // 发送通知，让所有组件保存修改
                        NotificationCenter.default.post(name: .settingsWindowWillClose, object: nil)
                    }
            }
            .windowResizability(.contentSize)
            .defaultPosition(.center)
            .defaultSize(width: 1200, height: 700)
            .commands {
                CommandGroup(replacing: .newItem) { }
            }
        }
    }

    // 打开设置窗口
    func openSettingsWindow() {
        // 先激活应用，这会关闭 MenuBarExtra 的 popover
        NSApp.activate(ignoringOtherApps: true)

        // 先查找是否已有窗口
        if let existingWindow = NSApp.windows.first(where: { $0.title == "Loop Reminder" || $0.identifier?.rawValue == "settings" }) {
            // 切换到 regular 模式
            NSApp.setActivationPolicy(.regular)
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
        } else {
            // 切换到 regular 模式
            NSApp.setActivationPolicy(.regular)
            // 创建新窗口
            openWindow(id: "settings")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                // 确保窗口置前
                if let window = NSApp.windows.first(where: { $0.title == "Loop Reminder" || $0.identifier?.rawValue == "settings" }) {
                    window.orderFrontRegardless()
                }
            }
        }
    }
}