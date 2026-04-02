import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var sendingTest = false
    @State private var selectedCategory: SettingsCategory = .timers
    @State private var countdownText: String = ""
    @State private var progressValue: Double = 0.0
    @State private var isResting: Bool = false

    // 定时器 Publisher，每秒触发
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    enum SettingsCategory: String, CaseIterable, Identifiable {
        case timers = "计时器"
        case style = "通用外观"
        case animation = "动画和定位"
        case basic = "基本设置"
        case logs = "日志"
        case update = "检查更新"
        case about = "关于"

        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .timers: return "bell.badge.fill"
            case .style: return "paintbrush.fill"
            case .animation: return "wand.and.stars"
            case .basic: return "gear"
            case .logs: return "doc.text.magnifyingglass"
            case .update: return "arrow.down.circle"
            case .about: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧固定宽度的侧边栏
            VStack(spacing: 0) {
                List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .controlBackgroundColor))
                .padding(.top, 8)
                .padding(.leading, 6)
            }
            .frame(width: 170)
            .background(Color(nsColor: .controlBackgroundColor))
            
            // 分隔线
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            
            // 右侧内容区 - 水平布局
            HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                // 左侧：表单区域（各页面内部处理滚动）
                Group {
                    switch selectedCategory {
                    case .basic:
                        BasicSettingsView()
                    case .timers:
                        TimerManagementView()
                    case .style:
                        StyleSettingsView()
                    case .animation:
                        AnimationSettingsView()
                    case .logs:
                        LogsView()
                    case .update:
                        UpdateCheckView()
                    case .about:
                        AboutView()
                    }
                }
                .padding(.leading, DesignTokens.Spacing.lg)
                .frame(width: shouldShowPreview ? 390 : nil)
                .frame(maxWidth: shouldShowPreview ? nil : .infinity)
                
                // 右侧：预览区域
                if shouldShowPreview {
                    PreviewSectionView(
                        sendingTest: $sendingTest,
                        countdownText: $countdownText,
                        progressValue: $progressValue,
                        isResting: $isResting,
                        showTimerList: selectedCategory != .timers,
                        onNavigateToTimers: {
                            selectedCategory = .timers
                        }
                    )
                    .frame(width: 340)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.trailing, DesignTokens.Spacing.lg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 960, height: 680)
        .onAppear {
            if settings.isRunning {
                updateCountdown()
            }
        }
        .onReceive(timer) { _ in
            if settings.isRunning {
                updateCountdown()
            }
        }
        .onReceive(controller.$isResting) { resting in
            self.isResting = resting
        }
    }
    
    // MARK: - Computed Properties
    
    /// 是否显示预览区域
    private var shouldShowPreview: Bool {
        // 在所有页面显示预览（除了关于、更新、日志页面）
        selectedCategory != .about && selectedCategory != .update && selectedCategory != .logs
    }
    
    // MARK: - Helper Methods

    private func updateCountdown() {
        guard settings.isRunning else {
            countdownText = ""
            progressValue = 0.0
            return
        }

        if isResting {
            // 休息状态
            let now = Date()
            let lastFire = settings.lastFireDate ?? now
            let restEnd = lastFire.addingTimeInterval(settings.restSeconds)
            let remaining = restEnd.timeIntervalSince(now)

            if remaining <= 1.0 {
                countdownText = "休息结束，即将开始..."
                progressValue = 1.0
                return
            }

            let elapsed = settings.restSeconds - remaining
            progressValue = max(0, min(1.0, elapsed / settings.restSeconds))

            let seconds = Int(remaining)
            let minutes = seconds / 60
            let secs = seconds % 60

            countdownText = String(format: "休息中... %d:%02d", minutes, secs)
        } else {
            // 正常计时状态
            let now = Date()
            let lastFire = settings.lastFireDate ?? now
            let nextFire = lastFire.addingTimeInterval(settings.intervalSeconds)
            let remaining = nextFire.timeIntervalSince(now)

            if remaining <= 1.0 {
                countdownText = "下次通知：即将发送..."
                progressValue = 1.0
                return
            }

            let elapsed = settings.intervalSeconds - remaining
            progressValue = max(0, min(1.0, elapsed / settings.intervalSeconds))

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
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let controller = ReminderController()
    return SettingsView()
        .environmentObject(settings)
        .environmentObject(controller)
        .frame(width: 1200, height: 700)
}
