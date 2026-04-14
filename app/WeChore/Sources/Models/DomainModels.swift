import Foundation

public enum ChoreStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case open
    case inProgress
    case blocked
    case done
    case archived

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In Progress"
        case .blocked: "Blocked"
        case .done: "Done"
        case .archived: "Archived"
        }
    }
}

public enum SuggestionUrgency: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case soon
    case urgent

    public var id: String { rawValue }
}

public struct Household: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Member: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var displayName: String
    public var phoneNumber: String?
    public var faceTimeHandle: String?
    public var isCurrentUser: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        phoneNumber: String? = nil,
        faceTimeHandle: String? = nil,
        isCurrentUser: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.faceTimeHandle = faceTimeHandle
        self.isCurrentUser = isCurrentUser
        self.createdAt = createdAt
    }
}

public struct Chore: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var notes: String
    public var createdByMemberID: String
    public var assigneeID: String
    public var dueDate: Date?
    public var status: ChoreStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String = "",
        createdByMemberID: String,
        assigneeID: String,
        dueDate: Date? = nil,
        status: ChoreStatus = .open,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdByMemberID = createdByMemberID
        self.assigneeID = assigneeID
        self.dueDate = dueDate
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isActive: Bool {
        status != .done && status != .archived
    }

    public mutating func transition(to newStatus: ChoreStatus, at date: Date) {
        status = newStatus
        updatedAt = date
    }
}

public struct ChoreAssignment: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var choreID: String
    public var memberID: String
    public var assignedAt: Date
    public var dueDate: Date?
    public var status: ChoreStatus

    public init(
        id: String = UUID().uuidString,
        choreID: String,
        memberID: String,
        assignedAt: Date = Date(),
        dueDate: Date? = nil,
        status: ChoreStatus = .open
    ) {
        self.id = id
        self.choreID = choreID
        self.memberID = memberID
        self.assignedAt = assignedAt
        self.dueDate = dueDate
        self.status = status
    }
}

public struct ChoreMessage: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var authorMemberID: String
    public var body: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        authorMemberID: String,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.authorMemberID = authorMemberID
        self.body = body
        self.createdAt = createdAt
    }
}

public struct ReminderLog: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var choreID: String
    public var memberID: String
    public var channel: String
    public var scheduledAt: Date
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        choreID: String,
        memberID: String,
        channel: String,
        scheduledAt: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.choreID = choreID
        self.memberID = memberID
        self.channel = channel
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
    }
}

public struct ChoreSuggestion: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var sourceMessageID: String
    public var title: String
    public var assigneeID: String?
    public var dueDate: Date?
    public var urgency: SuggestionUrgency
    public var reminderCadence: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceMessageID: String,
        title: String,
        assigneeID: String? = nil,
        dueDate: Date? = nil,
        urgency: SuggestionUrgency = .normal,
        reminderCadence: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceMessageID = sourceMessageID
        self.title = title
        self.assigneeID = assigneeID
        self.dueDate = dueDate
        self.urgency = urgency
        self.reminderCadence = reminderCadence
        self.createdAt = createdAt
    }
}

public struct LocalSettings: Hashable, Codable, Sendable {
    public var hasCompletedOnboarding: Bool
    public var selectedMemberID: String?
    public var notificationsEnabled: Bool
    public var cloudKitEnabled: Bool

    public init(
        hasCompletedOnboarding: Bool = false,
        selectedMemberID: String? = nil,
        notificationsEnabled: Bool = false,
        cloudKitEnabled: Bool = true
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedMemberID = selectedMemberID
        self.notificationsEnabled = notificationsEnabled
        self.cloudKitEnabled = cloudKitEnabled
    }
}

public struct ChoreSnapshot: Hashable, Codable, Sendable {
    public var household: Household
    public var members: [Member]
    public var chores: [Chore]
    public var messages: [ChoreMessage]
    public var reminderLogs: [ReminderLog]
    public var suggestions: [ChoreSuggestion]
    public var settings: LocalSettings

    public init(
        household: Household,
        members: [Member],
        chores: [Chore] = [],
        messages: [ChoreMessage] = [],
        reminderLogs: [ReminderLog] = [],
        suggestions: [ChoreSuggestion] = [],
        settings: LocalSettings = LocalSettings()
    ) {
        self.household = household
        self.members = members
        self.chores = chores
        self.messages = messages
        self.reminderLogs = reminderLogs
        self.suggestions = suggestions
        self.settings = settings
    }

    public static func empty(now: Date = Date()) -> ChoreSnapshot {
        let member = Member(
            id: "member-current",
            displayName: "Me",
            isCurrentUser: true,
            createdAt: now
        )
        return ChoreSnapshot(
            household: Household(
                id: "household-default",
                name: "Our Household",
                createdAt: now,
                updatedAt: now
            ),
            members: [member],
            settings: LocalSettings(
                hasCompletedOnboarding: false,
                selectedMemberID: member.id,
                notificationsEnabled: false,
                cloudKitEnabled: true
            )
        )
    }

    public static func seededForUITests(now: Date = Date()) -> ChoreSnapshot {
        let current = Member(
            id: "member-peyton",
            displayName: "Peyton",
            phoneNumber: "5551230000",
            faceTimeHandle: "peyton@example.com",
            isCurrentUser: true,
            createdAt: now
        )
        let sam = Member(
            id: "member-sam",
            displayName: "Sam",
            phoneNumber: "5551231111",
            faceTimeHandle: "sam@example.com",
            createdAt: now
        )
        let chore = Chore(
            id: "chore-dishes",
            title: "Load dishwasher",
            notes: "Dinner plates and pans",
            createdByMemberID: current.id,
            assigneeID: sam.id,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now),
            status: .open,
            createdAt: now,
            updatedAt: now
        )
        return ChoreSnapshot(
            household: Household(
                id: "household-ui",
                name: "Pine House",
                createdAt: now,
                updatedAt: now
            ),
            members: [current, sam],
            chores: [chore],
            settings: LocalSettings(
                hasCompletedOnboarding: true,
                selectedMemberID: current.id,
                notificationsEnabled: false,
                cloudKitEnabled: true
            )
        )
    }
}
