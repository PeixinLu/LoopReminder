import Foundation

enum EmojiSelection {
    static func normalizedEmoji(from value: Any) -> String? {
        let rawValue: String
        if let attributed = value as? NSAttributedString {
            rawValue = attributed.string
        } else if let string = value as? String {
            rawValue = string
        } else {
            rawValue = String(describing: value)
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstCharacter = trimmed.first else {
            return nil
        }
        return String(firstCharacter)
    }

    static func recentEmojis(afterSelecting emoji: String, existing: [String], limit: Int) -> [String] {
        let normalized = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, limit > 0 else {
            return Array(existing.prefix(max(0, limit)))
        }

        var result = [normalized]
        for item in existing where item != normalized && !result.contains(item) {
            result.append(item)
            if result.count >= limit {
                break
            }
        }
        return result
    }
}
