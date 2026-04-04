//  统一设计系统 - 管理所有设计常量和可复用组件

import SwiftUI
import AppKit

// MARK: - Design Tokens

/// 设计令牌：统一管理所有间距、尺寸、颜色常量
enum DesignTokens {
    
    // MARK: - Spacing (间距系统 - 基于 4pt 网格)
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Layout (布局常量)
    
    enum Layout {
        /// 内容区域水平内边距
        static let contentPadding: CGFloat = 24
        /// Section 之间的间距
        static let sectionSpacing: CGFloat = 8
        /// Section 内部间距
        static let sectionInnerSpacing: CGFloat = 12
        /// 表单行垂直内边距
        static let rowVerticalPadding: CGFloat = 6
        /// 标签区域固定宽度
        static let labelWidth: CGFloat = 100
        /// 滑块控件固定宽度
        static let sliderWidth: CGFloat = 140
        /// 数值显示固定宽度
        static let valueDisplayWidth: CGFloat = 55
        /// 输入框固定宽度
        static let inputFieldWidth: CGFloat = 60
        /// 表单内容最大宽度
        static let formFieldMaxWidth: CGFloat = 280
        /// Picker 固定宽度
        static let pickerWidth: CGFloat = 140
        /// 圆角半径
        static let cornerRadius: CGFloat = 10
        static let cornerRadiusSmall: CGFloat = 6
    }
    
    // MARK: - Typography (字体系统)
    
    enum Typography {
        /// 页面标题
        static let pageTitle: Font = .title3
        /// 页面副标题
        static let pageSubtitle: Font = .caption
        /// Section 标题
        static let sectionTitle: Font = .subheadline
        /// 行标题
        static let rowTitle: Font = .subheadline
        /// 提示文本
        static let hint: Font = .caption
        /// 数值显示
        static let value: Font = .system(.body, design: .rounded)
    }
    
    // MARK: - Colors (颜色语义)
    
    enum Colors {
        static let primary = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let purple = Color.purple
        static let pink = Color.pink
        static let teal = Color.teal
        static let indigo = Color.indigo
        static let cyan = Color.cyan
        
        /// 禁用状态透明度
        static let disabledOpacity: Double = 0.5
        /// 次要文本透明度
        static let secondaryOpacity: Double = 0.5
        /// 提示信息背景透明度
        static let hintBackgroundOpacity: Double = 0.08
    }
    
    // MARK: - Icon (图标尺寸)
    
    enum Icon {
        /// 页面标题图标
        static let pageHeader: CGFloat = 26
        /// 普通行图标
        static let row: CGFloat = 16
    }
}

// MARK: - 页面标题组件

/// 统一的页面标题组件
struct PageHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Icon.pageHeader))
                .foregroundStyle(iconColor.gradient)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(DesignTokens.Typography.pageTitle)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(DesignTokens.Typography.pageSubtitle)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }
}

// MARK: - Section 容器组件

/// 统一的 Section 容器
struct SettingsSection<Content: View>: View {
    let title: String?
    let showDivider: Bool
    @ViewBuilder let content: () -> Content
    
    init(
        title: String? = nil,
        showDivider: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showDivider = showDivider
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let title = title {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(.secondary)
            }
            
            content()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        
        if showDivider {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }
}

// MARK: - 锁定状态提示组件

/// 运行中锁定状态提示
struct LockHint: View {
    let message: String
    
    init(_ message: String = "请先暂停才能修改") {
        self.message = message
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(DesignTokens.Typography.hint)
                .foregroundStyle(DesignTokens.Colors.warning)
            Text(message)
                .font(DesignTokens.Typography.hint)
                .foregroundStyle(DesignTokens.Colors.warning)
            Spacer()
        }
        .padding(.leading, DesignTokens.Spacing.xs)
    }
}

// MARK: - 信息提示组件

/// 通用信息提示
struct InfoHint: View {
    let message: String
    let color: Color
    
    init(_ message: String, color: Color = .blue) {
        self.message = message
        self.color = color
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(DesignTokens.Typography.hint)
                .foregroundStyle(color.opacity(0.6))
            Text(message)
                .font(DesignTokens.Typography.hint)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.leading, DesignTokens.Spacing.xs)
    }
}

// MARK: - 验证提示组件

/// 输入验证提示
struct ValidationHint: View {
    let text: String
    let isWarning: Bool
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: isWarning ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(DesignTokens.Typography.hint)
                .foregroundStyle(isWarning ? DesignTokens.Colors.warning : DesignTokens.Colors.success)
            Text(text)
                .font(DesignTokens.Typography.hint)
                .foregroundStyle(isWarning ? DesignTokens.Colors.warning : DesignTokens.Colors.success)
            Spacer()
        }
        .padding(.leading, DesignTokens.Spacing.xs)
    }
}

// MARK: - 空状态组件

/// 统一的空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    
    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignTokens.Typography.hint)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxxl)
    }
}

// MARK: - 改进的 SettingRow 组件

/// 统一的设置行组件（优化版）
struct SettingRowV2<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String?
    @ViewBuilder let content: () -> Content
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.content = content
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 左侧标签区
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.rowTitle)
                        .fontWeight(.medium)
                    
                    if let description = description {
                        Text(description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: DesignTokens.Layout.labelWidth, alignment: .leading)
            
            Spacer()
            
            // 右侧控件区
            content()
        }
        .padding(.vertical, DesignTokens.Layout.rowVerticalPadding)
    }
}

// MARK: - 设置开关行组件

/// 带描述的开关设置行
struct SettingToggleRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String?
    @ViewBuilder let content: () -> Content
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.content = content
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

// MARK: - 滑块控件组件

/// 标准滑块控件（带数值显示）
struct SliderControl: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let unit: String
    let color: Color
    let disabled: Bool
    let valueMultiplier: Double
    let showTicks: Bool // 是否显示刻度

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        format: String = "%.0f",
        unit: String = "",
        color: Color = .blue,
        disabled: Bool = false,
        valueMultiplier: Double = 1,
        showTicks: Bool = false // 默认隐藏刻度
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.format = format
        self.unit = unit
        self.color = color
        self.disabled = disabled
        self.valueMultiplier = valueMultiplier
        self.showTicks = showTicks
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if showTicks {
                // 显示刻度：使用标准 Slider
                Slider(value: $value, in: range, step: step)
                    .disabled(disabled)
                    .frame(width: DesignTokens.Layout.sliderWidth)
            } else {
                // 隐藏刻度：使用自定义 NSSlider
                ContinuousSlider(value: $value, range: range, step: step, disabled: disabled)
                    .frame(width: DesignTokens.Layout.sliderWidth)
            }

            Text(String(format: format, value * valueMultiplier) + unit)
                .font(DesignTokens.Typography.value)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: DesignTokens.Layout.valueDisplayWidth, alignment: .trailing)
        }
    }
}

/// 无刻度的连续滑块（macOS）
struct ContinuousSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let disabled: Bool

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged)
        slider.isEnabled = !disabled
        slider.allowsTickMarkValuesOnly = false // 关键：不限制只能选择刻度值
        slider.numberOfTickMarks = 0 // 隐藏刻度
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
        nsView.isEnabled = !disabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, step: step)
    }

    class Coordinator: NSObject {
        var value: Binding<Double>
        let step: Double

        init(value: Binding<Double>, step: Double) {
            self.value = value
            self.step = step
        }

        @objc func valueChanged(_ slider: NSSlider) {
            // 步进到最近的刻度值
            let rawValue = slider.doubleValue
            let steppedValue = round(rawValue / step) * step
            value.wrappedValue = steppedValue
        }
    }
}

// MARK: - 警告卡片组件

/// 警告提示卡片
struct WarningCard<Content: View>: View {
    let color: Color
    @ViewBuilder let content: () -> Content
    
    init(color: Color = .orange, @ViewBuilder content: @escaping () -> Content) {
        self.color = color
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            content()
        }
        .padding(DesignTokens.Spacing.md)
        .background(color.opacity(DesignTokens.Colors.hintBackgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall))
    }
}

// MARK: - 锁定状态卡片

/// 运行中锁定提示卡片
struct LockCard: View {
    let message: String
    
    init(message: String = "请先暂停才能修改") {
        self.message = message
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "lock.fill")
                .foregroundStyle(DesignTokens.Colors.warning)
            Text(message)
                .font(.callout)
                .foregroundStyle(DesignTokens.Colors.warning)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadiusSmall)
                .fill(DesignTokens.Colors.warning.opacity(0.1))
        )
    }
}

// MARK: - 运行状态遮罩修饰符

extension View {
    /// 根据运行状态应用禁用样式
    func runningStateStyle(isRunning: Bool) -> some View {
        self.opacity(isRunning ? DesignTokens.Colors.disabledOpacity : 1.0)
    }
}
