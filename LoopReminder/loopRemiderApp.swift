import SwiftUI
import AppKit

// App Delegate to handle lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: ReminderController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 默认使用 accessory 模式，不在 Dock 显示
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理定时器和通知
        controller?.cleanup()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户点击 Dock 图标或 Command+Tab 切换时，显示设置窗口
        if !flag {
            // 查找并激活窗口
            if let window = NSApp.windows.first(where: { $0.title == "配置" || $0.identifier?.rawValue == "settings" }) {
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
                // 等待 scene 初始化完成
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                await MainActor.run {
                    // 只有在非静默启动模式下才打开设置窗口
                    if !settings.silentLaunch {
                        openSettingsWindow()
                    }
                }
            }
        }
        
        return Group {
        // 菜单栏
        MenuBarExtra {
            // 检查是否有任何计时器在运行
            let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
            
            Button(hasRunningTimer ? "全部停止" : "全部启动") {
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
            
            Divider()
            
            // 各个计时器的启停开关
            if !settings.timers.isEmpty {
                Section("计时器") {
                    ForEach(settings.timers) { timer in
                        Toggle(isOn: Binding(
                            get: { timer.isRunning },
                            set: { isOn in
                                if isOn {
                                    controller.startTimer(timer.id, settings: settings)
                                } else {
                                    controller.stopTimer(timer.id, settings: settings)
                                }
                            }
                        )) {
                            Text(timer.displayName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .disabled(!timer.isContentValid())
                    }
                }
                
                Divider()
            }

            Button("设置中心") {
                openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("退出 LoopReminder") {
                NSApp.terminate(nil)
            }
        } label: {
            // 只要有任何计时器在运行，就使用 fill 图标
            let hasRunningTimer = settings.timers.contains(where: { $0.isRunning })
            Image(systemName: hasRunningTimer ? "bell.fill" : "bell")
                .font(.system(size: 14))
        }
        .menuBarExtraStyle(.menu)

        // 配置窗口（使用普通 Window 而非 Settings）
        Window("配置", id: "settings") {
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
        .windowStyle(.hiddenTitleBar)
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
        // 先查找是否已有窗口
        if let existingWindow = NSApp.windows.first(where: { $0.title == "配置" || $0.identifier?.rawValue == "settings" }) {
            // 切换到 regular 模式
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
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
                if let window = NSApp.windows.first(where: { $0.title == "配置" || $0.identifier?.rawValue == "settings" }) {
                    window.orderFrontRegardless()
                }
            }
        }
    }
}
