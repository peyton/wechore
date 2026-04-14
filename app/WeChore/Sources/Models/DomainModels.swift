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

public enum ChoreMessageKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case voice
    case system

    public var id: String { rawValue }
}

public enum ChatThreadKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case group
    case dm

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .group: "Group chat"
        case .dm: "DM"
        }
    }
}

public enum TaskReminderPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case dueDate
    case smart

    public var id: String { rawValue }
}

public enum TaskNotificationState: String, Codable, CaseIterable, Identifiable, Sendable {
    case notScheduled
    case scheduled
    case delivered
    case failed

    public var id: String { rawValue }
}

public enum TaskActivityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case assigned
    case reminded
    case started
    case blocked
    case completed
    case reopened

    public var id: String { rawValue }
}

public struct VoiceAttachment: Hashable, Codable, Sendable {
    public var localAudioFilename: String
    public var duration: TimeInterval
    public var transcriptConfidence: Double?

    public init(
        localAudioFilename: String,
        duration: TimeInterval,
        transcriptConfidence: Double? = nil
    ) {
        self.localAudioFilename = localAudioFilename
        self.duration = duration
        self.transcriptConfidence = transcriptConfidence
    }
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

public struct ChatParticipant: Identifiable, Hashable, Codable, Sendable {
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

public typealias Member = ChatParticipant

public struct ChatThread: Identifiable, Hashable, Codable, Sendable {
    public static let legacyDefaultID = "thread-family"

    public var id: String
    public var kind: ChatThreadKind
    public var title: String
    public var participantIDs: [String]
    public var pinnedTaskIDs: [String]
    public var unreadCount: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var lastActivityAt: Date

    public init(
        id: String = UUID().uuidString,
        kind: ChatThreadKind,
        title: String,
        participantIDs: [String],
        pinnedTaskIDs: [String] = [],
        unreadCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastActivityAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.participantIDs = participantIDs
        self.pinnedTaskIDs = pinnedTaskIDs
        self.unreadCount = unreadCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastActivityAt = lastActivityAt
    }
}

public struct InvitePayload: Hashable, Codable, Sendable {
    public var inviteID: String
    public var threadID: String
    public var threadTitle: String
    public var inviterParticipantID: String
    public var code: String
    public var expiresAt: Date

    public init(
        inviteID: String,
        threadID: String,
        threadTitle: String,
        inviterParticipantID: String,
        code: String,
        expiresAt: Date
    ) {
        self.inviteID = inviteID
        self.threadID = threadID
        self.threadTitle = threadTitle
        self.inviterParticipantID = inviterParticipantID
        self.code = code
        self.expiresAt = expiresAt
    }

    public var shareText: String {
        "Join \(threadTitle) on WeChore with code \(code): \(universalURL.absoluteString)"
    }

    public var universalURL: URL {
        url(scheme: "https", host: "wechore.peyton.app", path: "/join")
    }

    public func appURL(scheme: String = "wechore") -> URL {
        url(scheme: scheme, host: "join", path: "")
    }

    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let pathLooksJoin = components.path == "/join" || components.host == "join"
        guard pathLooksJoin else { return nil }

        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        guard let inviteID = values["invite"],
              let threadID = values["thread"],
              let threadTitle = values["title"]?.removingPercentEncoding,
              let inviterParticipantID = values["inviter"],
              let code = values["code"],
              let expires = values["expires"].flatMap(Double.init) else {
            return nil
        }
        self.init(
            inviteID: inviteID,
            threadID: threadID,
            threadTitle: threadTitle,
            inviterParticipantID: inviterParticipantID,
            code: code,
            expiresAt: Date(timeIntervalSince1970: expires)
        )
    }

    private func url(scheme: String, host: String, path: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "invite", value: inviteID),
            URLQueryItem(name: "thread", value: threadID),
            URLQueryItem(name: "title", value: threadTitle),
            URLQueryItem(name: "inviter", value: inviterParticipantID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "expires", value: String(Int(expiresAt.timeIntervalSince1970)))
        ]
        return components.url ?? URL(string: "wechore://join")!
    }
}

public struct ThreadInvite: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var threadID: String
    public var inviterParticipantID: String
    public var code: String
    public var expiresAt: Date
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        threadID: String,
        inviterParticipantID: String,
        code: String,
        expiresAt: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.inviterParticipantID = inviterParticipantID
        self.code = code
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

public struct Chore: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var threadID: String
    public var title: String
    public var notes: String
    public var createdByMemberID: String
    public var assigneeID: String
    public var sourceMessageID: String?
    public var dueDate: Date?
    public var status: ChoreStatus
    public var reminderPolicy: TaskReminderPolicy
    public var notificationState: TaskNotificationState
    public var lastReminderAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        threadID: String = ChatThread.legacyDefaultID,
        title: String,
        notes: String = "",
        createdByMemberID: String,
        assigneeID: String,
        sourceMessageID: String? = nil,
        dueDate: Date? = nil,
        status: ChoreStatus = .open,
        reminderPolicy: TaskReminderPolicy = .smart,
        notificationState: TaskNotificationState = .notScheduled,
        lastReminderAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.title = title
        self.notes = notes
        self.createdByMemberID = createdByMemberID
        self.assigneeID = assigneeID
        self.sourceMessageID = sourceMessageID
        self.dueDate = dueDate
        self.status = status
        self.reminderPolicy = reminderPolicy
        self.notificationState = notificationState
        self.lastReminderAt = lastReminderAt
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

    private enum CodingKeys: String, CodingKey {
        case id
        case threadID
        case title
        case notes
        case createdByMemberID
        case assigneeID
        case sourceMessageID
        case dueDate
        case status
        case reminderPolicy
        case notificationState
        case lastReminderAt
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        threadID = try container.decodeIfPresent(String.self, forKey: .threadID) ?? ChatThread.legacyDefaultID
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdByMemberID = try container.decode(String.self, forKey: .createdByMemberID)
        assigneeID = try container.decode(String.self, forKey: .assigneeID)
        sourceMessageID = try container.decodeIfPresent(String.self, forKey: .sourceMessageID)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        status = try container.decodeIfPresent(ChoreStatus.self, forKey: .status) ?? .open
        reminderPolicy = try container.decodeIfPresent(TaskReminderPolicy.self, forKey: .reminderPolicy) ?? .smart
        notificationState = try container.decodeIfPresent(
            TaskNotificationState.self,
            forKey: .notificationState
        ) ?? .notScheduled
        lastReminderAt = try container.decodeIfPresent(Date.self, forKey: .lastReminderAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
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
    public var threadID: String
    public var authorMemberID: String
    public var body: String
    public var kind: ChoreMessageKind
    public var voiceAttachment: VoiceAttachment?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        threadID: String = ChatThread.legacyDefaultID,
        authorMemberID: String,
        body: String,
        kind: ChoreMessageKind = .text,
        voiceAttachment: VoiceAttachment? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.authorMemberID = authorMemberID
        self.body = body
        self.kind = kind
        self.voiceAttachment = voiceAttachment
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case threadID
        case authorMemberID
        case body
        case kind
        case voiceAttachment
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        threadID = try container.decodeIfPresent(String.self, forKey: .threadID) ?? ChatThread.legacyDefaultID
        authorMemberID = try container.decode(String.self, forKey: .authorMemberID)
        body = try container.decode(String.self, forKey: .body)
        kind = try container.decodeIfPresent(ChoreMessageKind.self, forKey: .kind) ?? .text
        voiceAttachment = try container.decodeIfPresent(VoiceAttachment.self, forKey: .voiceAttachment)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

public struct ReminderLog: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var threadID: String
    public var choreID: String
    public var memberID: String
    public var channel: String
    public var scheduledAt: Date
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        threadID: String = ChatThread.legacyDefaultID,
        choreID: String,
        memberID: String,
        channel: String,
        scheduledAt: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.choreID = choreID
        self.memberID = memberID
        self.channel = channel
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case threadID
        case choreID
        case memberID
        case channel
        case scheduledAt
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        threadID = try container.decodeIfPresent(String.self, forKey: .threadID) ?? ChatThread.legacyDefaultID
        choreID = try container.decode(String.self, forKey: .choreID)
        memberID = try container.decode(String.self, forKey: .memberID)
        channel = try container.decode(String.self, forKey: .channel)
        scheduledAt = try container.decode(Date.self, forKey: .scheduledAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

public struct TaskDraft: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var threadID: String
    public var sourceMessageID: String
    public var title: String
    public var assigneeID: String?
    public var dueDate: Date?
    public var urgency: SuggestionUrgency
    public var reminderCadence: String?
    public var confidence: Double
    public var needsConfirmation: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        threadID: String = ChatThread.legacyDefaultID,
        sourceMessageID: String,
        title: String,
        assigneeID: String? = nil,
        dueDate: Date? = nil,
        urgency: SuggestionUrgency = .normal,
        reminderCadence: String? = nil,
        confidence: Double = 1,
        needsConfirmation: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.sourceMessageID = sourceMessageID
        self.title = title
        self.assigneeID = assigneeID
        self.dueDate = dueDate
        self.urgency = urgency
        self.reminderCadence = reminderCadence
        self.confidence = confidence
        self.needsConfirmation = needsConfirmation
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case threadID
        case sourceMessageID
        case title
        case assigneeID
        case dueDate
        case urgency
        case reminderCadence
        case confidence
        case needsConfirmation
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        threadID = try container.decodeIfPresent(String.self, forKey: .threadID) ?? ChatThread.legacyDefaultID
        sourceMessageID = try container.decode(String.self, forKey: .sourceMessageID)
        title = try container.decode(String.self, forKey: .title)
        assigneeID = try container.decodeIfPresent(String.self, forKey: .assigneeID)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        urgency = try container.decodeIfPresent(SuggestionUrgency.self, forKey: .urgency) ?? .normal
        reminderCadence = try container.decodeIfPresent(String.self, forKey: .reminderCadence)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1
        needsConfirmation = try container.decodeIfPresent(Bool.self, forKey: .needsConfirmation) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

public typealias ChoreSuggestion = TaskDraft

public struct TaskActivity: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var threadID: String
    public var choreID: String
    public var actorParticipantID: String
    public var kind: TaskActivityKind
    public var body: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        threadID: String,
        choreID: String,
        actorParticipantID: String,
        kind: TaskActivityKind,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.choreID = choreID
        self.actorParticipantID = actorParticipantID
        self.kind = kind
        self.body = body
        self.createdAt = createdAt
    }
}

public struct LocalSettings: Hashable, Codable, Sendable {
    public var hasCompletedOnboarding: Bool
    public var selectedParticipantID: String?
    public var notificationsEnabled: Bool
    public var cloudKitEnabled: Bool

    public init(
        hasCompletedOnboarding: Bool = false,
        selectedParticipantID: String? = nil,
        notificationsEnabled: Bool = false,
        cloudKitEnabled: Bool = true
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedParticipantID = selectedParticipantID
        self.notificationsEnabled = notificationsEnabled
        self.cloudKitEnabled = cloudKitEnabled
    }

    public var selectedMemberID: String? {
        get { selectedParticipantID }
        set { selectedParticipantID = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding
        case selectedParticipantID
        case selectedMemberID
        case notificationsEnabled
        case cloudKitEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        selectedParticipantID = try container.decodeIfPresent(
            String.self,
            forKey: .selectedParticipantID
        ) ?? container.decodeIfPresent(String.self, forKey: .selectedMemberID)
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        cloudKitEnabled = try container.decodeIfPresent(Bool.self, forKey: .cloudKitEnabled) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encodeIfPresent(selectedParticipantID, forKey: .selectedParticipantID)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(cloudKitEnabled, forKey: .cloudKitEnabled)
    }
}

public struct ChoreSnapshot: Hashable, Codable, Sendable {
    public var household: Household
    public var participants: [ChatParticipant]
    public var threads: [ChatThread]
    public var chores: [Chore]
    public var messages: [ChoreMessage]
    public var reminderLogs: [ReminderLog]
    public var suggestions: [TaskDraft]
    public var taskActivities: [TaskActivity]
    public var invites: [ThreadInvite]
    public var settings: LocalSettings

    public var members: [ChatParticipant] {
        get { participants }
        set { participants = newValue }
    }

    public init(
        household: Household,
        participants: [ChatParticipant],
        threads: [ChatThread] = [],
        chores: [Chore] = [],
        messages: [ChoreMessage] = [],
        reminderLogs: [ReminderLog] = [],
        suggestions: [TaskDraft] = [],
        taskActivities: [TaskActivity] = [],
        invites: [ThreadInvite] = [],
        settings: LocalSettings = LocalSettings()
    ) {
        self.household = household
        self.participants = participants
        self.threads = threads
        self.chores = chores
        self.messages = messages
        self.reminderLogs = reminderLogs
        self.suggestions = suggestions
        self.taskActivities = taskActivities
        self.invites = invites
        self.settings = settings
        normalizeConversationState()
    }

    public init(
        household: Household,
        members: [Member],
        chores: [Chore] = [],
        messages: [ChoreMessage] = [],
        reminderLogs: [ReminderLog] = [],
        suggestions: [TaskDraft] = [],
        settings: LocalSettings = LocalSettings()
    ) {
        self.init(
            household: household,
            participants: members,
            chores: chores,
            messages: messages,
            reminderLogs: reminderLogs,
            suggestions: suggestions,
            settings: settings
        )
    }

    private enum CodingKeys: String, CodingKey {
        case household
        case participants
        case members
        case threads
        case chores
        case messages
        case reminderLogs
        case suggestions
        case taskActivities
        case invites
        case settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        household = try container.decodeIfPresent(
            Household.self,
            forKey: .household
        ) ?? Household(name: "Family Chat")
        participants = try container.decodeIfPresent(
            [ChatParticipant].self,
            forKey: .participants
        ) ?? container.decodeIfPresent([ChatParticipant].self, forKey: .members) ?? []
        threads = try container.decodeIfPresent([ChatThread].self, forKey: .threads) ?? []
        chores = try container.decodeIfPresent([Chore].self, forKey: .chores) ?? []
        messages = try container.decodeIfPresent([ChoreMessage].self, forKey: .messages) ?? []
        reminderLogs = try container.decodeIfPresent([ReminderLog].self, forKey: .reminderLogs) ?? []
        suggestions = try container.decodeIfPresent([TaskDraft].self, forKey: .suggestions) ?? []
        taskActivities = try container.decodeIfPresent([TaskActivity].self, forKey: .taskActivities) ?? []
        invites = try container.decodeIfPresent([ThreadInvite].self, forKey: .invites) ?? []
        settings = try container.decodeIfPresent(LocalSettings.self, forKey: .settings) ?? LocalSettings()
        normalizeConversationState()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(household, forKey: .household)
        try container.encode(participants, forKey: .participants)
        try container.encode(threads, forKey: .threads)
        try container.encode(chores, forKey: .chores)
        try container.encode(messages, forKey: .messages)
        try container.encode(reminderLogs, forKey: .reminderLogs)
        try container.encode(suggestions, forKey: .suggestions)
        try container.encode(taskActivities, forKey: .taskActivities)
        try container.encode(invites, forKey: .invites)
        try container.encode(settings, forKey: .settings)
    }

    public static func empty(now: Date = Date()) -> ChoreSnapshot {
        let participant = ChatParticipant(
            id: "participant-current",
            displayName: "Me",
            isCurrentUser: true,
            createdAt: now
        )
        let thread = ChatThread(
            id: ChatThread.legacyDefaultID,
            kind: .group,
            title: "Family Chat",
            participantIDs: [participant.id],
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        )
        return ChoreSnapshot(
            household: Household(
                id: "legacy-household-default",
                name: thread.title,
                createdAt: now,
                updatedAt: now
            ),
            participants: [participant],
            threads: [thread],
            settings: LocalSettings(
                hasCompletedOnboarding: false,
                selectedParticipantID: participant.id,
                notificationsEnabled: false,
                cloudKitEnabled: true
            )
        )
    }

    public static func seededForUITests(now: Date = Date()) -> ChoreSnapshot {
        let current = ChatParticipant(
            id: "participant-peyton",
            displayName: "Peyton",
            phoneNumber: "5551230000",
            faceTimeHandle: "peyton@example.com",
            isCurrentUser: true,
            createdAt: now
        )
        let sam = ChatParticipant(
            id: "participant-sam",
            displayName: "Sam",
            phoneNumber: "5551231111",
            faceTimeHandle: "sam@example.com",
            createdAt: now
        )
        let group = ChatThread(
            id: "thread-pine",
            kind: .group,
            title: "Pine Chat",
            participantIDs: [current.id, sam.id],
            pinnedTaskIDs: ["task-dishes"],
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        )
        let dm = ChatThread(
            id: "thread-dm-sam",
            kind: .dm,
            title: "Sam",
            participantIDs: [current.id, sam.id],
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        )
        let chore = Chore(
            id: "task-dishes",
            threadID: group.id,
            title: "Load dishwasher",
            notes: "Dinner plates and pans",
            createdByMemberID: current.id,
            assigneeID: sam.id,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now),
            status: .open,
            createdAt: now,
            updatedAt: now
        )
        let invite = ThreadInvite(
            id: "invite-pine",
            threadID: group.id,
            inviterParticipantID: current.id,
            code: "PINE123",
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now,
            createdAt: now
        )
        return ChoreSnapshot(
            household: Household(
                id: "legacy-household-ui",
                name: group.title,
                createdAt: now,
                updatedAt: now
            ),
            participants: [current, sam],
            threads: [group, dm],
            chores: [chore],
            invites: [invite],
            settings: LocalSettings(
                hasCompletedOnboarding: true,
                selectedParticipantID: current.id,
                notificationsEnabled: false,
                cloudKitEnabled: true
            )
        )
    }

    public mutating func normalizeConversationState() {
        if participants.isEmpty {
            let participant = ChatParticipant(id: "participant-current", displayName: "Me", isCurrentUser: true)
            participants = [participant]
            settings.selectedParticipantID = participant.id
        }

        if settings.selectedParticipantID == nil {
            settings.selectedParticipantID = participants.first(where: \.isCurrentUser)?.id ?? participants.first?.id
        }

        if threads.isEmpty {
            threads = [Self.legacyThread(from: household, participants: participants, now: household.createdAt)]
        }

        let fallbackThreadID = threads.first?.id ?? ChatThread.legacyDefaultID
        for index in chores.indices where chores[index].threadID == ChatThread.legacyDefaultID {
            chores[index].threadID = fallbackThreadID
        }
        for index in messages.indices where messages[index].threadID == ChatThread.legacyDefaultID {
            messages[index].threadID = fallbackThreadID
        }
        for index in reminderLogs.indices where reminderLogs[index].threadID == ChatThread.legacyDefaultID {
            reminderLogs[index].threadID = fallbackThreadID
        }
        for index in suggestions.indices where suggestions[index].threadID == ChatThread.legacyDefaultID {
            suggestions[index].threadID = fallbackThreadID
        }

        for index in threads.indices {
            let activeIDs = chores
                .filter { $0.threadID == threads[index].id && $0.isActive }
                .map(\.id)
            threads[index].pinnedTaskIDs = activeIDs
            let threadMessages = messages
                .filter { $0.threadID == threads[index].id }
                .map(\.createdAt)
            let threadChores = chores
                .filter { $0.threadID == threads[index].id }
                .map(\.updatedAt)
            threads[index].lastActivityAt = (threadMessages + threadChores + [threads[index].updatedAt]).max()
                ?? threads[index].updatedAt
        }
    }

    private static func legacyThread(
        from household: Household,
        participants: [ChatParticipant],
        now: Date
    ) -> ChatThread {
        ChatThread(
            id: ChatThread.legacyDefaultID,
            kind: .group,
            title: household.name.isEmpty ? "Family Chat" : household.name,
            participantIDs: participants.map(\.id),
            createdAt: household.createdAt,
            updatedAt: household.updatedAt,
            lastActivityAt: now
        )
    }
}
