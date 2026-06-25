import SwiftUI
import Foundation

func expectPreset(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func testPresetRoundTripsThroughJSON() {
    let preset = TimerCustomColorPreset(red: 0.2, green: 0.4, blue: 0.6)
    let data = try! JSONEncoder().encode([preset])
    let decoded = try! JSONDecoder().decode([TimerCustomColorPreset].self, from: data)

    expectPreset(decoded.count == 1, "decoded preset count should match")
    expectPreset(!decoded[0].id.isEmpty, "id should round-trip as a non-empty string")
    expectPreset(decoded[0].red == 0.2, "red should round-trip")
    expectPreset(decoded[0].green == 0.4, "green should round-trip")
    expectPreset(decoded[0].blue == 0.6, "blue should round-trip")
}

func testPresetMatchesEquivalentColor() {
    let preset = TimerCustomColorPreset(red: 0.2, green: 0.4, blue: 0.6)

    expectPreset(preset.matches(Color(red: 0.2, green: 0.4, blue: 0.6)), "preset should match equivalent SwiftUI color")
    expectPreset(!preset.matches(Color(red: 0.21, green: 0.4, blue: 0.6)), "preset should reject different color")
}

func testPresetClampsComponentValues() {
    let preset = TimerCustomColorPreset(red: -0.25, green: 0.5, blue: 1.25)

    expectPreset(preset.red == 0, "red should clamp to lower bound")
    expectPreset(preset.green == 0.5, "green should remain unchanged")
    expectPreset(preset.blue == 1, "blue should clamp to upper bound")
}

func testAddingPresetDoesNotReuseMatchingColor() {
    let existing = TimerCustomColorPreset(id: "existing-color", red: 0.2, green: 0.4, blue: 0.6)
    let presets = TimerCustomColorPreset.addingPreset(
        to: [existing],
        color: Color(red: 0.2, green: 0.4, blue: 0.6)
    )

    expectPreset(presets.count == 2, "matching colors should still create a new preset")
    expectPreset(presets[0].id == existing.id, "existing preset should remain unchanged")
    expectPreset(presets[1].id != existing.id, "new preset should get a distinct id")
}

func testAddingPresetUsesUniqueStringID() {
    let existing = TimerCustomColorPreset(id: "existing-color", red: 0.2, green: 0.4, blue: 0.6)
    let presets = TimerCustomColorPreset.addingPreset(
        to: [existing],
        color: Color(red: 0.7, green: 0.4, blue: 0.6)
    )

    expectPreset(presets.count == 2, "new preset should be appended")
    expectPreset(!presets[1].id.isEmpty, "new preset id should be non-empty")
    expectPreset(presets[1].id != existing.id, "new preset id should not collide with existing ids")
}

func testAddingPresetStopsAtMaximumCount() {
    let existing = (0..<TimerCustomColorPreset.maximumCount).map { index in
        TimerCustomColorPreset(id: "color-\(index)", red: Double(index) / 20, green: 0.4, blue: 0.6)
    }

    let presets = TimerCustomColorPreset.addingPreset(
        to: existing,
        color: Color(red: 0.9, green: 0.4, blue: 0.6)
    )

    expectPreset(presets.count == TimerCustomColorPreset.maximumCount, "preset count should stay capped")
    expectPreset(presets.map(\.id) == existing.map(\.id), "cap should leave existing presets unchanged")
}

func testHexInputNormalizesCompatibleFormats() {
    expectPreset(Color.normalizedHexString(from: "fff") == "#FFFFFF", "short hex should expand")
    expectPreset(Color.normalizedHexString(from: "#fff") == "#FFFFFF", "short hex with hash should expand")
    expectPreset(Color.normalizedHexString(from: "##1a2b3c") == "#1A2B3C", "duplicate hashes and lowercase should normalize")
}

func testHexInputFormatsPartialText() {
    expectPreset(Color.formattedHexInput(from: "a") == "#A", "partial lowercase input should uppercase")
    expectPreset(Color.formattedHexInput(from: "##abc") == "#ABC", "duplicate hashes should be collapsed while typing")
    expectPreset(Color.formattedHexInput(from: "#12zz34") == "#1234", "non-hex characters should be removed while typing")
}

func testHexInputRejectsInvalidValues() {
    expectPreset(Color.normalizedHexString(from: "12") == nil, "incomplete hex should be rejected")
    expectPreset(Color.normalizedHexString(from: "GGG") == nil, "non-hex characters should be rejected")
}

func testColorFormatsAsHexString() {
    let color = Color(red: 1, green: 0.5, blue: 0)

    expectPreset(color.hexString == "#FF8000", "color should format to uppercase six-digit hex")
}

@main
struct TimerCustomColorPresetTestRunner {
    static func main() {
        testPresetRoundTripsThroughJSON()
        testPresetMatchesEquivalentColor()
        testPresetClampsComponentValues()
        testAddingPresetDoesNotReuseMatchingColor()
        testAddingPresetUsesUniqueStringID()
        testAddingPresetStopsAtMaximumCount()
        testHexInputNormalizesCompatibleFormats()
        testHexInputFormatsPartialText()
        testHexInputRejectsInvalidValues()
        testColorFormatsAsHexString()
        print("PASS")
    }
}
