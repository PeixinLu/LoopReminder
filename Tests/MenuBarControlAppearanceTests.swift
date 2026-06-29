import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func testHoverStateAddsVisibleFeedback() {
    let normal = MenuBarControlAppearance(isHovered: false, isPressed: false, isEnabled: true)
    let hovered = MenuBarControlAppearance(isHovered: true, isPressed: false, isEnabled: true)

    expect(hovered.backgroundOpacity > normal.backgroundOpacity, "hover should increase background opacity")
    expect(hovered.foregroundOpacity >= normal.foregroundOpacity, "hover should keep or increase foreground opacity")
    expect(hovered.scale > normal.scale, "hover should make the item feel interactive")
}

func testPressedStateIsStrongerThanHover() {
    let hovered = MenuBarControlAppearance(isHovered: true, isPressed: false, isEnabled: true)
    let pressed = MenuBarControlAppearance(isHovered: true, isPressed: true, isEnabled: true)

    expect(pressed.backgroundOpacity > hovered.backgroundOpacity, "pressed should have stronger background feedback")
    expect(pressed.scale < hovered.scale, "pressed should compress slightly")
}

func testDisabledStateSuppressesInteractiveFeedback() {
    let disabledHovered = MenuBarControlAppearance(isHovered: true, isPressed: true, isEnabled: false)

    expect(disabledHovered.backgroundOpacity == 0, "disabled controls should not show hover or press background")
    expect(disabledHovered.foregroundOpacity < 1, "disabled controls should appear muted")
    expect(disabledHovered.scale == 1, "disabled controls should not scale")
}

@main
struct MenuBarControlAppearanceTestRunner {
    static func main() {
        testHoverStateAddsVisibleFeedback()
        testPressedStateIsStrongerThanHover()
        testDisabledStateSuppressesInteractiveFeedback()
        print("PASS")
    }
}
