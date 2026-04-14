import SwiftUI

enum RuntimeEnvironment {
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }

    static var preferredDestination: ChatDestination? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("UITEST_ROUTE=") }) else {
            return nil
        }
        let raw = String(argument.dropFirst("UITEST_ROUTE=".count))
        switch raw {
        case "join", "joinStart":
            return .joinStart
        case "me", "settings":
            return .settings
        case "dm":
            return .thread("thread-dm-sam")
        case "group", "messages", "chats", "chores", "household":
            return .thread("thread-pine")
        default:
            if raw.hasPrefix("thread:") {
                return .thread(String(raw.dropFirst("thread:".count)))
            }
            return nil
        }
    }

    static var shouldCompleteOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_COMPLETE_ONBOARDING")
    }

    static var shouldSeedConversation: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SEED_CONVERSATION")
            || ProcessInfo.processInfo.arguments.contains("UITEST_SEED_HOUSEHOLD")
    }

    static var shouldSeedChores: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SEED_CHORES")
    }

    static var shouldDisableCloudKit: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_DISABLE_CLOUDKIT")
    }

    static var requestedParticipantName: String? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("UITEST_PARTICIPANT=") || $0.hasPrefix("UITEST_MEMBER=")
        }) else {
            return nil
        }
        if argument.hasPrefix("UITEST_PARTICIPANT=") {
            return String(argument.dropFirst("UITEST_PARTICIPANT=".count))
        }
        return String(argument.dropFirst("UITEST_MEMBER=".count))
    }

    static var fakeVoiceTranscript: String {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("UITEST_FAKE_VOICE_TRANSCRIPT=")
        }) else {
            return "Sam please sweep the floor tomorrow"
        }
        return String(argument.dropFirst("UITEST_FAKE_VOICE_TRANSCRIPT=".count))
    }

    static var shouldUseLargeText: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_LARGE_TEXT")
    }
}
