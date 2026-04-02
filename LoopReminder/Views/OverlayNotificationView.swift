import SwiftUI

struct OverlayNotificationView: View {
    let emoji: String
    let title: String
    let message: String
    let backgroundColor: Color
    let backgroundOpacity: Double
    let stayDuration: Double // 停留时间
    let enableFadeOut: Bool // 是否启用渐透明
    let fadeOutDelay: Double // 变淡延迟
    let fadeOutDuration: Double // 变淡持续时间
    let titleFontSize: Double
    let bodyFontSize: Double
    let iconSize: Double
    let cornerRadius: Double
    let contentSpacing: Double
    let useBlur: Bool
    let blurIntensity: Double
    let overlayWidth: Double
    let overlayHeight: Double
    let animationStyle: AppSettings.AnimationStyle
    let position: AppSettings.OverlayPosition
    let padding: Double
    let textColor: Color?
    let overlayMaterial: AppSettings.OverlayMaterial
    let liquidGlassStyle: AppSettings.LiquidGlassStyle
    let onDismiss: (Bool) -> Void
    
    @State private var opacity: Double = 1.0
    @State private var scale: Double = 1.0
    @State private var offset: CGSize = .zero
    @State private var backgroundOpacityMultiplier: Double = 1.0 // ... existing code ...
    // 背景透明度乘数，用于淡化效果而不影响整个视图
    
    var body: some View {
        GeometryReader { geometry in
            let isLiquidMaterial = overlayMaterial == .liquidGlass
            let prefersHighContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            let prefersReducedTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            let primaryTextColor = resolvedPrimaryTextColor(isLiquidMaterial: isLiquidMaterial, prefersHighContrast: prefersHighContrast)
            let secondaryTextColor = resolvedSecondaryTextColor(isLiquidMaterial: isLiquidMaterial, prefersHighContrast: prefersHighContrast)
            let textShadowColor = resolvedTextShadowColor(isLiquidMaterial: isLiquidMaterial, prefersHighContrast: prefersHighContrast)
            
            // 处理字段显示逻辑
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBody = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 通知卡片
            VStack(spacing: contentSpacing) {
                // 判断是否只有emoji（标题和描述都为空）
                if trimmedTitle.isEmpty && trimmedBody.isEmpty && !trimmedEmoji.isEmpty {
                    // 只有emoji时，居中显示
                    HStack {
                        Spacer()
                        Text(trimmedEmoji)
                            .font(.system(size: iconSize))
                        Spacer()
                    }
                } else {
                    // 标准布局：emoji/图标在左，文字在右
                    HStack(spacing: contentSpacing) {
                        // 如果emoji为空且标题不为空，显示扁平铃铛图标（启动通知）
                        if trimmedEmoji.isEmpty && !trimmedTitle.isEmpty {
                            Image(systemName: "bell.fill")
                                .font(.system(size: iconSize))
                                .foregroundColor(primaryTextColor)
                        } else if !trimmedEmoji.isEmpty {
                            // 显示emoji
                            Text(trimmedEmoji)
                                .font(.system(size: iconSize))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // 只在title不为空时显示
                            if !trimmedTitle.isEmpty {
                                Text(trimmedTitle)
                                    .font(.system(size: titleFontSize, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundColor(primaryTextColor)
                                    .shadow(color: textShadowColor, radius: 9, x: 0, y: 0)
                            }
                            
                            // 只在body不为空时显示
                            if !trimmedBody.isEmpty {
                                Text(trimmedBody)
                                    .font(.system(size: bodyFontSize))
                                    .monospacedDigit()
                                    .foregroundColor(secondaryTextColor)
                                    .lineLimit(2)
                                    .shadow(color: textShadowColor, radius: 8, x: 0, y: 0)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.vertical, overlayWidth < 150 ? 10 : 20)
            .padding(.horizontal, overlayWidth < 150 ? 8 : 20)
            .frame(width: overlayWidth, height: overlayHeight)
            .background(
                Group {
                    switch overlayMaterial {
                    case .basic:
                        ZStack {
                            if useBlur {
                                // 模糊背景
                                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                // 第一层颜色叠加（基础颜色层）
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(backgroundColor.opacity(backgroundOpacity * 0.5 * backgroundOpacityMultiplier))
                                // 第二层颜色叠加（强化颜色层）
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(backgroundColor.opacity(backgroundOpacity * blurIntensity * 0.6 * backgroundOpacityMultiplier))
                            } else {
                                // 纯色背景
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(backgroundColor.opacity(backgroundOpacity * backgroundOpacityMultiplier))
                            }
                        }
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    case .liquidGlass:
                        // 使用 NSGlassEffectView：兼顾液态玻璃观感与更稳定的实时背板更新
                        if #available(macOS 26.0, *) {
                            ZStack {
                                if prefersReducedTransparency {
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .fill(backgroundColor.opacity(max(0.45, backgroundOpacity * 0.7) * backgroundOpacityMultiplier))
                                } else {
                                    LiquidGlassEffectView(
                                        cornerRadius: cornerRadius,
                                        style: liquidGlassStyle,
                                        tintColor: liquidGlassTintColor(
                                            multiplier: backgroundOpacityMultiplier,
                                            prefersHighContrast: prefersHighContrast
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                }

                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(.white.opacity(0.42 * backgroundOpacityMultiplier), lineWidth: 0.8)
                            }
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                        } else {
                            // 旧系统回退
                            ZStack {
                                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(backgroundColor.opacity(backgroundOpacity * 0.28 * backgroundOpacityMultiplier))
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(.white.opacity(0.35 * backgroundOpacityMultiplier), lineWidth: 0.8)
                            }
                            .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 6)
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(offset)
            // 只有卡片区域响应点击
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss(true) // ... existing code ...
                // true 表示用户手动点击关闭
            }
            // 根据position和padding计算对齐位置
            .padding(edgeInsetsForPosition())
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignmentForPosition())
            .onAppear {
                applyEntryAnimation(containerSize: geometry.size)
                startExitTimer(containerSize: geometry.size)
            }
            // 缓冲区不响应鼠标事件
            .allowsHitTesting(true)
        }
        // 窗口级别：只有卡片内容响应点击
        .background(Color.clear.allowsHitTesting(false))
    }
    
    // 根据位置返回对齐方式
    private func alignmentForPosition() -> Alignment {
        switch position {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        case .topCenter:
            return .top
        case .center:
            return .center
        case .bottomCenter:
            return .bottom
        }
    }
    
    // 根据位置返回EdgeInsets（保持padding距离）
    private func edgeInsetsForPosition() -> EdgeInsets {
        switch position {
        case .topLeft:
            return EdgeInsets(top: padding, leading: padding, bottom: 0, trailing: 0)
        case .topRight:
            return EdgeInsets(top: padding, leading: 0, bottom: 0, trailing: padding)
        case .bottomLeft:
            return EdgeInsets(top: 0, leading: padding, bottom: padding + 80, trailing: 0)
        case .bottomRight:
            return EdgeInsets(top: 0, leading: 0, bottom: padding + 80, trailing: padding)
        case .topCenter:
            return EdgeInsets(top: padding, leading: 0, bottom: 0, trailing: 0)
        case .center:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .bottomCenter:
            return EdgeInsets(top: 0, leading: 0, bottom: padding + 80, trailing: 0)
        }
    }
    
    private func applyEntryAnimation(containerSize: CGSize) {
        switch animationStyle {
        case .fade:
            opacity = 0
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1.0
            }
        case .slide:
            // 计算从哪个边进入：根据 position 选择最近的边
            let direction = slideDirectionForPosition()
            let extra: CGFloat = 60
            
            switch direction {
            case .fromLeft:
                // 从左侧外飞入（负x）
                offset = CGSize(width: -(containerSize.width/2 + overlayWidth/2 + extra), height: 0)
            case .fromRight:
                // 从右侧外飞入（正x）
                offset = CGSize(width: containerSize.width/2 + overlayWidth/2 + extra, height: 0)
            case .fromTop:
                // 从顶部外飞入（向上 = 负y）
                offset = CGSize(width: 0, height: -(containerSize.height/2 + overlayHeight/2 + extra))
            case .fromBottom:
                // 从底部外飞入（向下 = 正y）
                offset = CGSize(width: 0, height: containerSize.height/2 + overlayHeight/2 + extra)
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = .zero
            }
        case .scale:
            scale = 0.5
            opacity = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func startExitTimer(containerSize: CGSize) {
        if enableFadeOut {
            // 启用渐透明：先停留，然后开始变淡到10%
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDelay) {
                applyFadeOutAnimation()
            }
            // ... existing code ...
            // 在stayDuration时刻执行退出动画
            DispatchQueue.main.asyncAfter(deadline: .now() + stayDuration) {
                applyExitAnimation(containerSize: containerSize)
            }
        } else {
            // 不启用渐透明：到时间后直接执行退出动画
            DispatchQueue.main.asyncAfter(deadline: .now() + stayDuration) {
                applyExitAnimation(containerSize: containerSize)
            }
        }
    }
    
    // 渐透明动画：淡化背景到最低10%透明度后保持，保持一般视图可见
    private func applyFadeOutAnimation() {
        withAnimation(.linear(duration: fadeOutDuration)) {
            backgroundOpacityMultiplier = 0.5 // ... existing code ...
            // 淡化背景不是整个视图，保持边框清晰
        }
    }
    
    private func applyExitAnimation(containerSize: CGSize) {
        switch animationStyle {
        case .fade:
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 0.0
                scale = 0.95
                backgroundOpacityMultiplier = 0.1 // ... existing code ...
                // 应用褊出动画时也保持背景格外蠟化
            }
        case .slide:
            let direction = slideDirectionForPosition()
            let extra: CGFloat = 60
            
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 0.0
                switch direction {
                case .fromLeft:
                    offset = CGSize(width: -(containerSize.width/2 + overlayWidth/2 + extra), height: 0)
                case .fromRight:
                    offset = CGSize(width: containerSize.width/2 + overlayWidth/2 + extra, height: 0)
                case .fromTop:
                    offset = CGSize(width: 0, height: -(containerSize.height/2 + overlayHeight/2 + extra))
                case .fromBottom:
                    offset = CGSize(width: 0, height: containerSize.height/2 + overlayHeight/2 + extra)
                }
            }
        case .scale:
            withAnimation(.easeIn(duration: 0.3)) {
                scale = 0.5
                opacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss(false) // ... existing code ...
            // false 表示通知自动消失
        }
    }
    
    // 根据position确定从哪个边进入/退出
    private func slideDirectionForPosition() -> SlideDirection {
        switch position {
        case .topLeft, .bottomLeft:
            return .fromLeft
        case .topRight, .bottomRight:
            return .fromRight
        case .topCenter:
            return .fromTop
        case .bottomCenter:
            return .fromBottom
        case .center:
            // center位置：默认从上方进入
            return .fromTop
        }
    }
    
    private enum SlideDirection {
        case fromLeft
        case fromRight
        case fromTop
        case fromBottom
    }
    
    private func resolvedPrimaryTextColor(isLiquidMaterial: Bool, prefersHighContrast: Bool) -> Color {
        if isLiquidMaterial {
            // 液态玻璃模式：根据系统外观选择颜色
            let isDarkMode = isDarkModeEnabled()
            return isDarkMode ? .white : .black
        }
        // 基本材质：使用白色
        return .white
    }

    private func resolvedSecondaryTextColor(isLiquidMaterial: Bool, prefersHighContrast: Bool) -> Color {
        if isLiquidMaterial {
            // 液态玻璃模式：根据系统外观选择颜色
            let isDarkMode = isDarkModeEnabled()
            return isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85)
        }
        // 基本材质：使用白色
        return .white.opacity(0.95)
    }

    private func resolvedTextShadowColor(isLiquidMaterial: Bool, prefersHighContrast: Bool) -> Color {
        if isLiquidMaterial {
            // 液态玻璃模式：根据系统外观选择阴影颜色
            let isDarkMode = isDarkModeEnabled()
            return isDarkMode ? .black.opacity(prefersHighContrast ? 0.5 : 0.3) : .white.opacity(prefersHighContrast ? 0.4 : 0.2)
        }
        return .black.opacity(prefersHighContrast ? 0.78 : 0.62)
    }

    private func isDarkModeEnabled() -> Bool {
        guard let appearance = NSApp?.effectiveAppearance else { return true }
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        return bestMatch == .darkAqua
    }

    @available(macOS 26.0, *)
    private func liquidGlassTintColor(multiplier: Double, prefersHighContrast: Bool) -> NSColor? {
        let components = backgroundColor.components()
        let contrastBoost = prefersHighContrast ? 1.2 : 1.0
        let alpha = max(0, min(1, backgroundOpacity * 0.18 * multiplier * contrastBoost))
        return NSColor(
            calibratedRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: alpha
        )
    }
}

// MARK: - Visual Effect Blur
// 自定义视觉效果模糊视图，实现整体模糊效果
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

@available(macOS 26.0, *)
private struct LiquidGlassEffectView: NSViewRepresentable {
    let cornerRadius: Double
    let style: AppSettings.LiquidGlassStyle
    let tintColor: NSColor?

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        view.style = style.nsStyle
        view.tintColor = tintColor
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style.nsStyle
        nsView.tintColor = tintColor
    }
}

@available(macOS 26.0, *)
private extension AppSettings.LiquidGlassStyle {
    var nsStyle: NSGlassEffectView.Style {
        switch self {
        case .clear:
            return .clear
        case .regular:
            return .regular
        }
    }
}
