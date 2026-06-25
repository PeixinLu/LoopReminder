import SwiftUI
import AppKit

extension Color {
    func components() -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else {
            return (0.5, 0.5, 0.5, 1)
        }
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    func hsbaComponents() -> (hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else {
            return (0, 0, 0.5, 1)
        }
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b), Double(a))
    }

    var hexString: String {
        let rgb = components()
        let red = Int((rgb.red * 255).rounded())
        let green = Int((rgb.green * 255).rounded())
        let blue = Int((rgb.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    init?(hexString: String) {
        guard let normalized = Self.normalizedHexString(from: hexString) else {
            return nil
        }

        let hex = String(normalized.dropFirst())
        guard let value = Int(hex, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    static func normalizedHexString(from input: String) -> String? {
        var hex = formattedHexInput(from: input)
        hex.removeFirst()

        guard hex.count == 3 || hex.count == 6,
              hex.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }

        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }

        return "#\(hex)"
    }

    static func formattedHexInput(from input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        while text.hasPrefix("#") {
            text.removeFirst()
        }

        let hex = text
            .filter { $0.isHexDigit }
            .prefix(6)

        return "#\(String(hex))"
    }
}
