import Foundation

func expectCatalog(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func testChineseKeywordSearchFindsReminderEmoji() {
    let results = EmojiCatalog.search("喝水")

    expectCatalog(results.contains(where: { $0.symbol == "💧" }), "Chinese keyword should find water drop")
}

func testEnglishUnicodeNameSearchFindsEmoji() {
    let results = EmojiCatalog.search("sleep")

    expectCatalog(results.contains(where: { $0.symbol == "😴" }), "English name search should find sleeping face")
}

func testBlankQueryReturnsRecommendedEmoji() {
    let results = EmojiCatalog.search("")

    expectCatalog(!results.isEmpty, "blank query should return recommended emoji")
    expectCatalog(results.contains(where: { $0.symbol == "🔔" }), "recommended emoji should include bell")
}

func testSectionsExposeAllGroupsAndExpandedCommonEmoji() {
    let sections = EmojiCatalog.sections()

    expectCatalog(sections.map(\.group) == EmojiCatalogGroup.allCases, "sections should expose every group in catalog order")
    expectCatalog(sections.allSatisfy { !$0.items.isEmpty }, "each section should contain at least one emoji")
    expectCatalog(EmojiCatalog.items.count >= 120, "catalog should include an expanded set of common emoji")
    expectCatalog(EmojiCatalog.search("刷牙").contains(where: { $0.symbol == "🪥" }), "expanded health emoji should be searchable")
}

func testCatalogSymbolsAreUniqueForSwiftUIIdentity() {
    let symbols = EmojiCatalog.items.map(\.symbol)

    expectCatalog(Set(symbols).count == symbols.count, "catalog symbols should be unique because symbols are SwiftUI item IDs")
}

@main
struct EmojiCatalogTestRunner {
    static func main() {
        testChineseKeywordSearchFindsReminderEmoji()
        testEnglishUnicodeNameSearchFindsEmoji()
        testBlankQueryReturnsRecommendedEmoji()
        testSectionsExposeAllGroupsAndExpandedCommonEmoji()
        testCatalogSymbolsAreUniqueForSwiftUIIdentity()
        print("PASS")
    }
}
