import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: ReminderController

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
        NavigationSplitView {
            // 侧边栏
            List(selection: $selectedCategory) {
                Section("设置") {
                    ForEach(SettingsCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
            // 内容区
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
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .frame(width: 720, height: 600)
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
