import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
import NaturalLanguage

public protocol TaskExtractionEngine: Sendable {
    func extractTasks(
        from message: ChoreMessage,
        participants: [ChatParticipant],
        now: Date
    ) async -> [TaskDraft]
}

public typealias MessageSuggestionGenerating = TaskExtractionEngine

public enum TaskExtractionEngineFactory {
    public static func live() -> any TaskExtractionEngine {
        let fallback = RuleBasedTaskExtractionEngine()
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.availability == .available {
                return FoundationModelsTaskExtractionEngine(fallback: fallback)
            }
        }
        #endif
        return fallback
    }
}

public struct RuleBasedTaskExtractionEngine: TaskExtractionEngine {
    public init() {}

    public func extractTasks(
        from message: ChoreMessage,
        participants: [ChatParticipant],
        now: Date
    ) async -> [TaskDraft] {
        let trimmed = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return [] }

        let lowercased = trimmed.lowercased()
        guard containsActionSignal(lowercased) else { return [] }

        let assignee = bestParticipantMatch(in: lowercased, participants: participants)
        let title = choreTitle(from: trimmed, assignee: assignee)
        guard !title.isEmpty else { return [] }

        return [
            TaskDraft(
                threadID: message.threadID,
                sourceMessageID: message.id,
                title: title,
                assigneeID: assignee?.id,
                dueDate: dueDate(in: trimmed, now: now),
                urgency: urgency(in: lowercased),
                reminderCadence: reminderCadence(in: lowercased),
                confidence: assignee == nil ? 0.58 : 0.88,
                needsConfirmation: assignee == nil,
                createdAt: now
            )
        ]
    }

    fileprivate func dueDate(in text: String, now: Date) -> Date? {
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
            "floor",
            "sweep",
            "wipe",
            "mop"
        ]
        return signals.contains { text.contains($0) }
    }

    private func bestParticipantMatch(in text: String, participants: [ChatParticipant]) -> ChatParticipant? {
        let normalized = text.components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return participants.first { participant in
            guard !participant.isCurrentUser else { return false }
            let candidate = participant.displayName.lowercased()
            return normalized == candidate
                || normalized.contains("\(candidate) ")
                || normalized.contains(" \(candidate)")
                || text.contains("@\(candidate)")
        }
    }

    private func choreTitle(from raw: String, assignee: ChatParticipant?) -> String {
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
            "every day",
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

public typealias OnDeviceMessageSuggestionEngine = RuleBasedTaskExtractionEngine

#if canImport(FoundationModels)
@available(iOS 26.0, *)
public struct FoundationModelsTaskExtractionEngine: TaskExtractionEngine {
    private let fallback: RuleBasedTaskExtractionEngine

    public init(fallback: RuleBasedTaskExtractionEngine = RuleBasedTaskExtractionEngine()) {
        self.fallback = fallback
    }

    public func extractTasks(
        from message: ChoreMessage,
        participants: [ChatParticipant],
        now: Date
    ) async -> [TaskDraft] {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            return await fallback.extractTasks(from: message, participants: participants, now: now)
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            Extract task requests from a group chat or direct message.
            Return no tasks for ordinary conversation.
            Prefer the named assignee when the text names one of the participants.
            Mark needsConfirmation true when the assignee or task is unclear.
            Keep task titles short, concrete, and imperative.
            """
        )
        let participantNames = participants
            .filter { !$0.isCurrentUser }
            .map(\.displayName)
            .joined(separator: ", ")
        let prompt = """
        Participants: \(participantNames)
        Message: \(message.body)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedTaskExtraction.self,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0,
                    maximumResponseTokens: 180
                )
            )
            guard response.content.hasTask else { return [] }
            let assignee = response.content.assigneeName.flatMap { name in
                participants.first {
                    !$0.isCurrentUser
                        && $0.displayName.caseInsensitiveCompare(name) == .orderedSame
                }
            }
            let title = response.content.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return [] }
            return [
                TaskDraft(
                    threadID: message.threadID,
                    sourceMessageID: message.id,
                    title: title,
                    assigneeID: assignee?.id,
                    dueDate: response.content.dueDatePhrase.flatMap { fallback.dueDate(in: $0, now: now) },
                    urgency: SuggestionUrgency(rawValue: response.content.urgency) ?? .normal,
                    confidence: min(max(response.content.confidence, 0), 1),
                    needsConfirmation: response.content.needsConfirmation || assignee == nil,
                    createdAt: now
                )
            ]
        } catch {
            return await fallback.extractTasks(from: message, participants: participants, now: now)
        }
    }
}

@available(iOS 26.0, *)
@Generable(description: "A single extracted task request from a chat message")
private struct GeneratedTaskExtraction {
    @Guide(description: "Whether the message asks someone to do a concrete task")
    var hasTask: Bool

    @Guide(description: "Short task title without the assignee name")
    var title: String

    @Guide(description: "Participant display name assigned to the task, if clear")
    var assigneeName: String?

    @Guide(description: "Natural due date words from the message, such as today or tomorrow")
    var dueDatePhrase: String?

    @Guide(description: "normal, soon, or urgent")
    var urgency: String

    @Guide(description: "True when details need a human confirmation")
    var needsConfirmation: Bool

    @Guide(description: "Extraction confidence from 0 to 1", .range(0...1))
    var confidence: Double
}
#endif

public struct FakeTaskExtractionEngine: TaskExtractionEngine {
    private let drafts: [TaskDraft]

    public init(drafts: [TaskDraft]) {
        self.drafts = drafts
    }

    public func extractTasks(
        from message: ChoreMessage,
        participants: [ChatParticipant],
        now: Date
    ) async -> [TaskDraft] {
        drafts.map { draft in
            var output = draft
            output.threadID = message.threadID
            output.sourceMessageID = message.id
            output.createdAt = now
            return output
        }
    }
}
