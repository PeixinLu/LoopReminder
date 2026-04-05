import SwiftUI

struct UpdateCheckView: View {
    @StateObject private var updater = AppUpdater.shared

    private var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 页面标题 - 固定
            PageHeader(
                icon: "arrow.down.circle.fill",
                iconColor: .blue,
                title: "检查更新",
                subtitle: "当前版本：\(updater.versionDescription)"
            ) {
                Button("检查更新") {
                    updater.checkForUpdates()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // 内容区域 - 可滚动
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    Divider()

                    // 设置项
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        SettingRow(icon: "number.circle.fill", iconColor: .blue, title: "当前版本") {
                            Text(updater.versionDescription)
                                .foregroundColor(.secondary)
                        }

                        SettingRow(icon: "arrow.triangle.2.circlepath.circle.fill", iconColor: .purple, title: "自动检查更新") {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { updater.automaticallyChecksForUpdates },
                                    set: { newValue in
                                        updater.setAutomaticallyChecksForUpdates(newValue)
                                    }
                                )
                            )
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }

                    Divider()

                    InfoHint("点击「检查更新」后，Sparkle 会提示安装并在安装后自动替换并重启应用。", color: .blue)
                }
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
        }
    }
}

#Preview {
    UpdateCheckView()
}