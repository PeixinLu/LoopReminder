import SwiftUI
import AppKit

enum TimerPowerSwitchDirection {
    case leftOffRightOn
    case leftOnRightOff
    case topOnBottomOff
    case topOffBottomOn

    var isVertical: Bool {
        switch self {
        case .leftOffRightOn, .leftOnRightOff:
            return false
        case .topOnBottomOff, .topOffBottomOn:
            return true
        }
    }
}

struct TimerPowerSwitch: View {
    let isOn: Bool
    var isEnabled: Bool = true
    var direction: TimerPowerSwitchDirection = .leftOffRightOn
    var onColor: Color = Color(red: 0.18, green: 0.72, blue: 0.38)
    var offColor: Color = Color.secondary.opacity(0.22)
    var knobColor: Color = .white
    var cornerRadius: CGFloat = 12
    var knobCornerRadius: CGFloat? = 4
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var knobWidth: CGFloat? = nil
    var knobHeight: CGFloat? = nil
    var action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    private var size: CGSize {
        if direction.isVertical {
            return CGSize(width: width ?? 30, height: height ?? 44)
        }
        return CGSize(width: width ?? 44, height: height ?? 30)
    }

    private var knobSize: CGFloat {
        direction.isVertical ? 20 : 20
    }

    private var travel: CGFloat {
        (direction.isVertical ? size.height : size.width) - knobSize - 1
    }

    private var knobOffset: CGSize {
        switch direction {
        case .leftOffRightOn:
            return CGSize(width: isOn ? travel / 2 : -travel / 2, height: 0)
        case .leftOnRightOff:
            return CGSize(width: isOn ? -travel / 2 : travel / 2, height: 0)
        case .topOnBottomOff:
            return CGSize(width: 0, height: isOn ? -travel / 2 : travel / 2)
        case .topOffBottomOn:
            return CGSize(width: 0, height: isOn ? travel / 2 : -travel / 2)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var resolvedKnobCornerRadius: CGFloat {
        knobCornerRadius ?? max(4, cornerRadius - 3)
    }

    private var knobShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: resolvedKnobCornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                shape
                    .fill(isOn ? onColor : offColor)

                shape
                    .stroke(borderColor, lineWidth: 1)

                knobShape
                    .fill(knobColor)
                    .frame(width: resolvedKnobWidth, height: resolvedKnobHeight)
                    .shadow(color: .black.opacity(isEnabled ? 0.18 : 0.06), radius: 3, y: 1)
                    .offset(knobOffset)
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(isPressed ? 0.97 : (isHovering && isEnabled ? 1.025 : 1))
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isOn)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovering = hovering
            if hovering && isEnabled {
                NSCursor.pointingHand.push()
            } else if isEnabled {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityLabel(isOn ? "开启计时器" : "关闭计时器")
        .accessibilityValue(isOn ? "开启" : "关闭")
    }

    private var resolvedKnobWidth: CGFloat {
        knobWidth ?? (direction.isVertical ? 18 : 6)
    }

    private var resolvedKnobHeight: CGFloat {
        knobHeight ?? (direction.isVertical ? 6 : 18)
    }

    private var borderColor: Color {
        if !isEnabled {
            return Color.secondary.opacity(0.14)
        }
        return isHovering ? Color.primary.opacity(0.20) : Color.primary.opacity(0.08)
    }
}

#Preview("Timer Power Switch") {
    VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 18) {
            TimerPowerSwitch(isOn: false) {}
            TimerPowerSwitch(isOn: true) {}
            TimerPowerSwitch(isOn: true, isEnabled: false) {}
        }

        HStack(spacing: 18) {
            TimerPowerSwitch(isOn: true, direction: .leftOnRightOff, onColor: .blue) {}
            TimerPowerSwitch(isOn: true, direction: .topOnBottomOff, onColor: .orange) {}
            TimerPowerSwitch(isOn: false, direction: .topOffBottomOn, onColor: .purple) {}
        }

        HStack(spacing: 18) {
            TimerPowerSwitch(isOn: false, cornerRadius: 14, width: 48, height: 30) {}
            TimerPowerSwitch(isOn: true, cornerRadius: 14, width: 52, height: 32) {}
            TimerPowerSwitch(isOn: true, cornerRadius: 14, knobCornerRadius: 4, width: 56, height: 34, knobWidth: 8, knobHeight: 20) {}
        }
    }
    .padding()
    .frame(width: 340)
}
