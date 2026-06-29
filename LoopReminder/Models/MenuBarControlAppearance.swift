import Foundation

struct MenuBarControlAppearance {
    let isHovered: Bool
    let isPressed: Bool
    let isEnabled: Bool

    var backgroundOpacity: Double {
        guard isEnabled else { return 0 }
        if isPressed { return 0.16 }
        if isHovered { return 0.10 }
        return 0
    }

    var foregroundOpacity: Double {
        isEnabled ? 1 : 0.45
    }

    var scale: Double {
        return 1
    }
}
