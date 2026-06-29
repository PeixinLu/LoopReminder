import SwiftUI

struct TimerCustomColorPreset: Identifiable, Codable, Equatable {
    static let maximumCount = 10

    var id: String
    var red: Double
    var green: Double
    var blue: Double

    init(id: String = Self.makeID(), red: Double, green: Double, blue: Double) {
        self.id = id
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    init(id: String = Self.makeID(), color: Color) {
        let components = color.components()
        self.init(id: id, red: components.red, green: components.green, blue: components.blue)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    func matches(_ color: Color, tolerance: Double = 0.001) -> Bool {
        let components = color.components()
        return abs(red - components.red) <= tolerance
            && abs(green - components.green) <= tolerance
            && abs(blue - components.blue) <= tolerance
    }

    static func addingPreset(to presets: [TimerCustomColorPreset], color: Color) -> [TimerCustomColorPreset] {
        guard presets.count < maximumCount else {
            return presets
        }

        let existingIDs = Set(presets.map(\.id))
        return presets + [TimerCustomColorPreset(id: makeID(excluding: existingIDs), color: color)]
    }

    static func makeID(excluding existingIDs: Set<String> = []) -> String {
        var id: String
        repeat {
            id = UUID().uuidString
        } while existingIDs.contains(id)

        return id
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
