import Foundation

func expectEmoji(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func testNormalizesFirstComposedCharacter() {
    let emoji = EmojiSelection.normalizedEmoji(from: "🧘🏽‍♀️abc")

    expectEmoji(emoji == "🧘🏽‍♀️", "selection should keep the first composed emoji character")
}

func testRejectsWhitespaceOnlySelection() {
    let emoji = EmojiSelection.normalizedEmoji(from: "   ")

    expectEmoji(emoji == nil, "whitespace-only selection should be ignored")
}

func testRecentEmojiListDeduplicatesAndLimits() {
    let existing = ["🔔", "💧", "☕️", "💊"]
    let next = EmojiSelection.recentEmojis(afterSelecting: "💧", existing: existing, limit: 3)

    expectEmoji(next == ["💧", "🔔", "☕️"], "recent list should move selected emoji to front, deduplicate, and limit size")
}

@main
struct EmojiSelectionTestRunner {
    static func main() {
        testNormalizesFirstComposedCharacter()
        testRejectsWhitespaceOnlySelection()
        testRecentEmojiListDeduplicatesAndLimits()
        print("PASS")
    }
}
