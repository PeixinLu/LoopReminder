import SwiftUI
import AppKit

@MainActor
private enum GlassDebugLog {
    static func log(_ message: String) {
        EventLogger.shared.log("[材质排查] \(message)")
    }
}

private func setGlassVariant(_ view: NSView, _ value: Int) {
    let selector = NSSelectorFromString("set_variant:")
    guard view.responds(to: selector) else { return }
    typealias Fn = @convention(c) (AnyObject, Selector, Int) -> Void
    let imp = view.method(for: selector)
    let fn = unsafeBitCast(imp, to: Fn.self)
    fn(view, selector, value)
}

private func setGlassScrimState(_ view: NSView, _ value: Bool) {
    let selector = NSSelectorFromString("set_scrimState:")
    guard view.responds(to: selector) else { return }
    typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> Void
    let imp = view.method(for: selector)
    let fn = unsafeBitCast(imp, to: Fn.self)
    fn(view, selector, value)
}

private func setGlassSubduedState(_ view: NSView, _ value: Bool) {
    let selector = NSSelectorFromString("set_subduedState:")
    guard view.responds(to: selector) else { return }
    typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> Void
    let imp = view.method(for: selector)
    let fn = unsafeBitCast(imp, to: Fn.self)
    fn(view, selector, value)
}

enum OverlayNotificationDismissReason {
    case ignored
    case completed
    case missed
}

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
    var glassTintMode: AppSettings.OverlayGlassTintExperiment = .focusLiteDefault
    var glassTintColor: Color = .white
    var glassTintAlpha: Double = 0.618
    var glassTextColorMode: AppSettings.OverlayGlassTextColorMode = .automatic
    let onDismiss: (OverlayNotificationDismissReason) -> Void
    
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
            let glassTextColor = resolvedGlassTextColor()
            let primaryTextColor: Color? = isLiquidMaterial ? glassTextColor : resolvedPrimaryTextColor(prefersHighContrast: prefersHighContrast)
            let secondaryTextColor: Color? = isLiquidMaterial ? glassTextColor : resolvedSecondaryTextColor(prefersHighContrast: prefersHighContrast)
            let textShadowColor: Color = isLiquidMaterial ? .clear : resolvedTextShadowColor(prefersHighContrast: prefersHighContrast)
            
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
                            
                            HStack(alignment: .center, spacing: 8) {
                                if !trimmedBody.isEmpty {
                                    Text(trimmedBody)
                                        .font(.system(size: bodyFontSize))
                                        .monospacedDigit()
                                        .foregroundColor(secondaryTextColor)
                                        .lineLimit(2)
                                        .shadow(color: textShadowColor, radius: 8, x: 0, y: 0)
                                }

                                Spacer(minLength: 0)

                                notificationActionButton(
                                    systemImage: "xmark",
                                    help: "忽略",
                                    color: secondaryTextColor,
                                    useBackground: !isLiquidMaterial
                                ) {
                                    onDismiss(.ignored)
                                }

                                notificationActionButton(
                                    systemImage: "checkmark",
                                    help: "完成",
                                    color: secondaryTextColor,
                                    useBackground: !isLiquidMaterial
                                ) {
                                    onDismiss(.completed)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.vertical, overlayWidth < 150 ? 10 : 20)
            .padding(.horizontal, overlayWidth < 150 ? 8 : 20)
            .frame(width: overlayWidth, height: overlayHeight)
            .modifier(
                OverlayNotificationMaterialModifier(
                    overlayMaterial: overlayMaterial,
                    liquidGlassStyle: liquidGlassStyle,
                    backgroundColor: backgroundColor,
                    backgroundOpacity: backgroundOpacity,
                    backgroundOpacityMultiplier: backgroundOpacityMultiplier,
                    useBlur: useBlur,
                    blurIntensity: blurIntensity,
                    cornerRadius: cornerRadius,
                    prefersReducedTransparency: prefersReducedTransparency,
                    glassTintMode: glassTintMode,
                    glassTintColor: glassTintColor,
                    glassTintAlpha: glassTintAlpha
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(offset)
            // 只有卡片区域响应点击
            .contentShape(Rectangle())
            .onTapGesture {
                onDismiss(.ignored)
            }
            // 根据position和padding计算对齐位置
            .padding(edgeInsetsForPosition())
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignmentForPosition())
            .onAppear {
                logMaterialAppearance(
                    containerSize: geometry.size,
                    isLiquidMaterial: isLiquidMaterial,
                    prefersHighContrast: prefersHighContrast,
                    prefersReducedTransparency: prefersReducedTransparency
                )
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
            onDismiss(.missed)
        }
    }

    private func notificationActionButton(systemImage: String, help: String, color: Color?, useBackground: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: max(9, bodyFontSize - 1), weight: .semibold))
                .foregroundStyle(color ?? .primary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(useBackground ? .black.opacity(0.16) : .clear))
        }
        .buttonStyle(.plain)
        .help(help)
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
    
    private func resolvedPrimaryTextColor(prefersHighContrast: Bool) -> Color {
        // 基本材质：使用白色
        return .white
    }

    private func resolvedSecondaryTextColor(prefersHighContrast: Bool) -> Color {
        // 基本材质：使用白色
        return .white.opacity(0.95)
    }

    private func resolvedGlassTextColor() -> Color? {
        switch glassTextColorMode {
        case .automatic:
            return nil
        case .black:
            return .black
        case .white:
            return .white
        }
    }

    private func resolvedTextShadowColor(prefersHighContrast: Bool) -> Color {
        return .black.opacity(prefersHighContrast ? 0.78 : 0.62)
    }

    private func logMaterialAppearance(
        containerSize: CGSize,
        isLiquidMaterial: Bool,
        prefersHighContrast: Bool,
        prefersReducedTransparency: Bool
    ) {
        GlassDebugLog.log(
            """
            OverlayNotificationView出现: material=\(overlayMaterial.rawValue), liquidStyle=\(liquidGlassStyle.displayName), isLiquid=\(isLiquidMaterial), size=\(Int(overlayWidth))x\(Int(overlayHeight)), container=\(Int(containerSize.width))x\(Int(containerSize.height)), cornerRadius=\(String(format: "%.1f", cornerRadius)), opacity=\(String(format: "%.2f", backgroundOpacity)), useBlur=\(useBlur), blurIntensity=\(String(format: "%.2f", blurIntensity)), reducedTransparency=\(prefersReducedTransparency), highContrast=\(prefersHighContrast)
            """
        )
        if isLiquidMaterial {
            GlassDebugLog.log("液态玻璃路径: macOS 26 使用 NSGlassEffectView.contentView；tintMode=\(glassTintMode.displayName), tintAlpha=\(String(format: "%.3f", glassTintAlpha)), textColor=\(glassTextColorMode.displayName)；overlayOpacity/useBlur/blurIntensity 不参与当前液态玻璃背景。")
        }
    }
}

private struct OverlayNotificationMaterialModifier: ViewModifier {
    let overlayMaterial: AppSettings.OverlayMaterial
    let liquidGlassStyle: AppSettings.LiquidGlassStyle
    let backgroundColor: Color
    let backgroundOpacity: Double
    let backgroundOpacityMultiplier: Double
    let useBlur: Bool
    let blurIntensity: Double
    let cornerRadius: Double
    let prefersReducedTransparency: Bool
    let glassTintMode: AppSettings.OverlayGlassTintExperiment
    let glassTintColor: Color
    let glassTintAlpha: Double

    func body(content: Content) -> some View {
        switch overlayMaterial {
        case .basic:
            content
                .background(basicBackground)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        case .liquidGlass:
            liquidGlassContent(content)
        }
    }

    @ViewBuilder
    private var basicBackground: some View {
        ZStack {
            if useBlur {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(shape)
                shape
                    .fill(backgroundColor.opacity(backgroundOpacity * 0.5 * backgroundOpacityMultiplier))
                shape
                    .fill(backgroundColor.opacity(backgroundOpacity * blurIntensity * 0.6 * backgroundOpacityMultiplier))
            } else {
                shape
                    .fill(backgroundColor.opacity(backgroundOpacity * backgroundOpacityMultiplier))
            }
        }
    }

    @ViewBuilder
    private func liquidGlassContent(_ content: Content) -> some View {
        if #available(macOS 26.0, *) {
            NSGlassEffectHostView(
                content: content,
                cornerRadius: cornerRadius,
                style: liquidGlassStyle,
                backgroundColor: backgroundColor,
                tintMode: glassTintMode,
                tintColor: glassTintColor,
                tintAlpha: glassTintAlpha
            )
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        } else {
            content
                .background(
                    ZStack {
                        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                            .clipShape(shape)
                        shape
                            .fill(backgroundColor.opacity(backgroundOpacity * 0.28 * backgroundOpacityMultiplier))
                    }
                )
                .overlay(liquidGlassStroke(opacity: 0.35))
                .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 6)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius)
    }

    private func liquidGlassStroke(opacity: Double) -> some View {
        shape
            .stroke(.white.opacity(opacity * backgroundOpacityMultiplier), lineWidth: 0.8)
    }
}

@available(macOS 26.0, *)
private struct NSGlassEffectHostView<Content: View>: NSViewRepresentable {
    let content: Content
    let cornerRadius: Double
    let style: AppSettings.LiquidGlassStyle
    let backgroundColor: Color
    let tintMode: AppSettings.OverlayGlassTintExperiment
    let tintColor: Color
    let tintAlpha: Double

    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        applyConfiguration(to: glassView)
        glassView.contentView = makeHostingView(in: glassView)
        logGlassViewState(glassView, phase: "makeNSView")
        return glassView
    }

    func updateNSView(_ glassView: NSGlassEffectView, context: Context) {
        if let hostingView = glassView.contentView as? NSHostingView<Content> {
            hostingView.rootView = content
        } else {
            glassView.contentView = makeHostingView(in: glassView)
        }
        applyConfiguration(to: glassView)
        logGlassViewState(glassView, phase: "updateNSView")
    }

    private func makeHostingView(in glassView: NSGlassEffectView) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = glassView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        return hostingView
    }

    private func applyConfiguration(to glassView: NSGlassEffectView) {
        glassView.cornerRadius = cornerRadius
        glassView.tintColor = resolvedTintColor
        glassView.style = style.nsGlassStyle
        applyPrivateGlassConfiguration(to: glassView)
    }

    private var resolvedTintColor: NSColor? {
        switch tintMode {
        case .focusLiteDefault:
            guard style.baseGlassStyle == .clear else { return nil }
            return systemAppearanceTint(alpha: 0.618)
        case .off:
            return nil
        case .systemDefault:
            return systemAppearanceTint(alpha: clampedTintAlpha)
        case .overlayColor:
            return nsColor(from: backgroundColor, alpha: clampedTintAlpha)
        case .custom:
            return nsColor(from: tintColor, alpha: clampedTintAlpha)
        }
    }

    private var clampedTintAlpha: Double {
        min(max(tintAlpha, 0), 1)
    }

    private func systemAppearanceTint(alpha: Double) -> NSColor {
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let base = isDarkMode ? NSColor.black : NSColor.white
        return base.withAlphaComponent(alpha)
    }

    private func nsColor(from color: Color, alpha: Double) -> NSColor {
        let components = color.components()
        return NSColor(
            calibratedRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: alpha
        )
    }

    private func applyPrivateGlassConfiguration(to glassView: NSGlassEffectView) {
        if style.variantValue != 0 {
            setGlassVariant(glassView, style.variantValue)
        }
        setGlassScrimState(glassView, style.scrimState)
        setGlassSubduedState(glassView, style.subduedState)
    }

    private func logGlassViewState(_ glassView: NSGlassEffectView, phase: String) {
        GlassDebugLog.log(
            """
            NSGlassEffectView.\(phase): style=\(style.displayName), base=\(style.baseGlassStyle.displayName), nsStyle=\(style.nsGlassStyle == .regular ? "regular" : "clear"), tintMode=\(tintMode.displayName), tint=\(describeColor(resolvedTintColor)), cornerRadius=\(String(format: "%.1f", cornerRadius)), variant=\(style.variantValue), scrim=\(style.scrimState), subdued=\(style.subduedState), selectors(variant/scrim/subdued)=\(glassView.responds(to: NSSelectorFromString("set_variant:")))/\(glassView.responds(to: NSSelectorFromString("set_scrimState:")))/\(glassView.responds(to: NSSelectorFromString("set_subduedState:"))), frame=\(Int(glassView.frame.width))x\(Int(glassView.frame.height)), contentView=\(glassView.contentView.map { String(describing: type(of: $0)) } ?? "nil")
            """
        )
    }

    private func describeColor(_ color: NSColor?) -> String {
        guard let color else { return "nil" }
        if let rgb = color.usingColorSpace(.sRGB) {
            return String(
                format: "rgba(%.3f, %.3f, %.3f, %.3f)",
                rgb.redComponent,
                rgb.greenComponent,
                rgb.blueComponent,
                rgb.alphaComponent
            )
        }
        return "colorspace=\(color.colorSpace.localizedName ?? "unknown"), alpha=\(String(format: "%.3f", color.alphaComponent))"
    }
}

@available(macOS 26.0, *)
private extension AppSettings.LiquidGlassStyle {
    var baseGlassStyle: AppSettings.LiquidGlassStyle {
        switch self {
        case .regular:
            return .regular
        default:
            return .clear
        }
    }

    var nsGlassStyle: NSGlassEffectView.Style {
        baseGlassStyle == .regular ? .regular : .clear
    }

    var variantValue: Int {
        switch self {
        case .regular, .clear:
            return 0
        case .dock:
            return 3
        case .appIcons:
            return 4
        case .widgets:
            return 5
        case .text:
            return 6
        case .avPlayer:
            return 7
        case .faceTime:
            return 8
        case .controlCenter:
            return 9
        case .notificationCenter:
            return 10
        case .monogram:
            return 11
        case .bubbles:
            return 12
        case .identity:
            return 13
        case .focusBorder:
            return 14
        case .focusPlatter:
            return 15
        case .keyboard:
            return 16
        case .sidebar:
            return 17
        case .abuttedSidebar:
            return 18
        case .inspector:
            return 19
        case .control:
            return 20
        case .loupe:
            return 21
        case .slider:
            return 22
        case .camera:
            return 23
        case .cartouchePopover:
            return 24
        }
    }

    var scrimState: Bool {
        false
    }

    var subduedState: Bool {
        false
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
