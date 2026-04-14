import Foundation
import NaturalLanguage

public protocol MessageSuggestionGenerating: Sendable {
    func suggestions(
        from message: ChoreMessage,
        members: [Member],
        now: Date
    ) -> [ChoreSuggestion]
}

public struct OnDeviceMessageSuggestionEngine: MessageSuggestionGenerating {
    public init() {}

    public func suggestions(
        from message: ChoreMessage,
        members: [Member],
        now: Date
    ) -> [ChoreSuggestion] {
        let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return [] }

        let lowercased = trimmed.lowercased()
        guard containsActionSignal(lowercased) else { return [] }

        let assignee = bestMemberMatch(in: lowercased, members: members)
        let title = choreTitle(from: trimmed, assignee: assignee)
        guard !title.isEmpty else { return [] }

        return [
            ChoreSuggestion(
                sourceMessageID: message.id,
                title: title,
                assigneeID: assignee?.id,
                dueDate: dueDate(in: trimmed, now: now),
                urgency: urgency(in: lowercased),
                reminderCadence: reminderCadence(in: lowercased),
                createdAt: now
            )
        ]
    }

    private func containsActionSignal(_ text: String) -> Bool {
        let signals = [
            "please",
            "remind",
            "need",
            "needs",
            "can you",
            "could you",
            "take out",
            "clean",
            "wash",
            "fold",
            "vacuum",
            "unload",
            "load",
            "trash",
            "laundry",
            "dishes",
            "dishwasher",
            "bathroom",
            "floor"
        ]
        return signals.contains { text.contains($0) }
    }

    private func bestMemberMatch(in text: String, members: [Member]) -> Member? {
        let normalized = text.components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return members.first { member in
            let candidate = member.displayName.lowercased()
            return normalized == candidate
                || normalized.contains("\(candidate) ")
                || text.contains("@\(candidate)")
        }
    }

    private func choreTitle(from raw: String, assignee: Member?) -> String {
        var text = raw
        if let assignee {
            text = text.replacingOccurrences(
                of: assignee.displayName,
                with: "",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }

        let removablePatterns = [
            "please",
            "can you",
            "could you",
            "remind me to",
            "remind",
            "needs to",
            "need to",
            "by tomorrow",
            "tomorrow",
            "tonight",
            "today",
            "this morning",
            "this afternoon",
            "this evening",
            "urgent",
            "asap",
            "every week",
            "weekly",
            "daily"
        ]
        for pattern in removablePatterns {
            text = text.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }

        let words = tokenizedWords(in: text)
        let compact = words.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard let first = compact.first else { return "" }
        return first.uppercased() + compact.dropFirst()
    }

    private func tokenizedWords(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                words.append(token)
            }
            return true
        }
        return words
    }

    private func dueDate(in text: String, now: Date) -> Date? {
        let lowered = text.lowercased()
        let calendar = Calendar.current
        if lowered.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }
        if lowered.contains("tonight") || lowered.contains("today") {
            return calendar.startOfDay(for: now)
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.date
    }

    private func urgency(in text: String) -> SuggestionUrgency {
        if text.contains("urgent") || text.contains("asap") || text.contains("right now") {
            return .urgent
        }
        if text.contains("soon") || text.contains("tonight") || text.contains("today") {
            return .soon
        }
        return .normal
    }

    private func reminderCadence(in text: String) -> String? {
        if text.contains("every week") || text.contains("weekly") {
            return "weekly"
        }
        if text.contains("every day") || text.contains("daily") {
            return "daily"
        }
        return nil
    }
}
