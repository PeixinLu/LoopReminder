import SwiftUI

struct LogsView: View {
    @State private var logs: [String] = []
    private let logger = EventLogger.shared
    private let blockedKeywords = ["script", "javascript:", "<", ">", "file://", "vscode://", "http://", "https://"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题 + 操作按钮 - 固定
            HStack {
                PageHeader(
                    icon: "doc.text.magnifyingglass",
                    iconColor: .accentColor,
                    title: "日志",
                    subtitle: "记录通知发送、启动/重置/停止等关键事件"
                )
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: DesignTokens.Spacing.md) {
                    Button {
                        reload()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    
                    Button {
                        logger.clear()
                        reload()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                    
                    Button {
                        logger.openInFinder()
                    } label: {
                        Label("访达中打开", systemImage: "folder")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.trailing, DesignTokens.Spacing.lg)

            // 日志内容 - 可滚动
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    if logs.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.fill",
                            title: "暂无日志"
                        )
                    } else {
                        ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                            Text(sanitize(line))
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, DesignTokens.Spacing.xxs)
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .background(Color(.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall))
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
                .padding(.trailing, DesignTokens.Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
    }
    
    private func reload() {
        logs = logger.readAll().reversed()
    }
    
    private func sanitize(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\n", with: " ")
        for keyword in blockedKeywords {
            if result.localizedCaseInsensitiveContains(keyword) {
                result = result.replacingOccurrences(of: keyword, with: "***", options: .regularExpression, range: nil)
            }
        }
        return result
    }
}
