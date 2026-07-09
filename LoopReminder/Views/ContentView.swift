import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Loop Reminder")
                .font(.title2)
                .bold()

            Text(settings.isRunning ? "状态：已开启" : "状态：已关闭")
                .foregroundStyle(settings.isRunning ? .green : .secondary)

            HStack {
                Text("频率")
                Spacer()
                Text("每 \(settings.formattedInterval())")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("提示：这是一个菜单栏应用。打开菜单栏图标进行 开启/关闭、配置、退出。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 360)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .environmentObject(ReminderController())
}
