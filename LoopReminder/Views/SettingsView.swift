import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

    @State private var sendingTest = false
    @State private var selectedCategory: SettingsCategory = .timers
    
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
    }

    // MARK: - Computed Properties

    /// 是否显示预览区域
    private var shouldShowPreview: Bool {
        // 在所有页面显示预览（除了关于、更新、日志页面）
        selectedCategory != .about && selectedCategory != .update && selectedCategory != .logs
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
