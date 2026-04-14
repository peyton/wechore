import Foundation

public enum SharedSnapshotStoreError: Error, Equatable {
    case missingAppGroupIdentifier
    case missingAppGroupContainer
    case missingSnapshot
}

public struct SharedSnapshotStore {
    public static let snapshotFilename = "wechore-widget-snapshot.json"

    private let appGroupIdentifier: String?
    private let fileManager: FileManager
    private let fallbackDirectory: URL?

    public init(
        appGroupIdentifier: String? = SharedSnapshotStore.bundleAppGroupIdentifier(),
        fileManager: FileManager = .default,
        fallbackDirectory: URL? = nil
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileManager = fileManager
        self.fallbackDirectory = fallbackDirectory
    }

    public static func bundleAppGroupIdentifier(bundle: Bundle = .main) -> String? {
        bundle.object(forInfoDictionaryKey: "WeChoreAppGroupID") as? String
    }

    public func loadSnapshot() throws -> ChoreSnapshot {
        let url = try snapshotURL()
        guard fileManager.fileExists(atPath: url.path) else {
            throw SharedSnapshotStoreError.missingSnapshot
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChoreSnapshot.self, from: data)
    }

    public func saveSnapshot(_ snapshot: ChoreSnapshot) throws {
        let url = try snapshotURL()
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }

    public func snapshotURL() throws -> URL {
        if let fallbackDirectory {
            return fallbackDirectory.appendingPathComponent(Self.snapshotFilename)
        }
        guard let appGroupIdentifier, !appGroupIdentifier.isEmpty else {
            throw SharedSnapshotStoreError.missingAppGroupIdentifier
        }
        guard let directory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw SharedSnapshotStoreError.missingAppGroupContainer
        }
        return directory.appendingPathComponent(Self.snapshotFilename)
    }
}

public struct WidgetTaskSummary: Identifiable, Hashable, Sendable {
    public var id: String
    public var threadID: String
    public var title: String
    public var assigneeName: String
    public var status: ChoreStatus
    public var dueDate: Date?
    public var statusLabel: String
    public var isOverdue: Bool
    public var isDueToday: Bool

    public init(
        id: String,
        threadID: String,
        title: String,
        assigneeName: String,
        status: ChoreStatus,
        dueDate: Date?,
        statusLabel: String,
        isOverdue: Bool,
        isDueToday: Bool
    ) {
        self.id = id
        self.threadID = threadID
        self.title = title
        self.assigneeName = assigneeName
        self.status = status
        self.dueDate = dueDate
        self.statusLabel = statusLabel
        self.isOverdue = isOverdue
        self.isDueToday = isDueToday
    }
}

public struct WidgetConversationSummary: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var kind: ChatThreadKind
    public var activeTaskCount: Int
    public var doneTaskCount: Int
    public var waitingForAssigneeCount: Int
    public var tasks: [WidgetTaskSummary]
    public var lastActivityAt: Date

    public init(
        id: String,
        title: String,
        kind: ChatThreadKind,
        activeTaskCount: Int,
        doneTaskCount: Int,
        waitingForAssigneeCount: Int,
        tasks: [WidgetTaskSummary],
        lastActivityAt: Date
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.activeTaskCount = activeTaskCount
        self.doneTaskCount = doneTaskCount
        self.waitingForAssigneeCount = waitingForAssigneeCount
        self.tasks = tasks
        self.lastActivityAt = lastActivityAt
    }

    public var statusText: String {
        if waitingForAssigneeCount > 0 {
            return "\(waitingForAssigneeCount) needs an assignee"
        }
        if activeTaskCount == 1 {
            return "1 active task"
        }
        return "\(activeTaskCount) active tasks"
    }
}

public enum WidgetProjection {
    public static func conversationSummaries(
        from snapshot: ChoreSnapshot,
        now: Date = Date()
    ) -> [WidgetConversationSummary] {
        snapshot.threads
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
            .map { conversationSummary(for: $0, in: snapshot, now: now) }
    }

    public static func favoriteConversationSummaries(
        from snapshot: ChoreSnapshot,
        now: Date = Date()
    ) -> [WidgetConversationSummary] {
        let summaries = conversationSummaries(from: snapshot, now: now)
        let favorites = snapshot.settings.widgetFavoriteThreadIDs
        guard !favorites.isEmpty else { return summaries }
        let byID = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        let orderedFavorites = favorites.compactMap { byID[$0] }
        let remaining = summaries.filter { !favorites.contains($0.id) }
        return orderedFavorites + remaining
    }

    public static func conversationSummary(
        for thread: ChatThread,
        in snapshot: ChoreSnapshot,
        now: Date = Date()
    ) -> WidgetConversationSummary {
        let threadChores = snapshot.chores.filter { $0.threadID == thread.id }
        let active = threadChores.filter(\.isActive)
        let done = threadChores.filter { $0.status == .done }
        let waiting = snapshot.suggestions.filter {
            $0.threadID == thread.id && $0.assignmentState == .needsAssignee
        }
        let tasks = active
            .sorted(by: Chore.widgetSort)
            .map { taskSummary(for: $0, in: snapshot, now: now) }
        return WidgetConversationSummary(
            id: thread.id,
            title: thread.title,
            kind: thread.kind,
            activeTaskCount: active.count,
            doneTaskCount: done.count,
            waitingForAssigneeCount: waiting.count,
            tasks: tasks,
            lastActivityAt: thread.lastActivityAt
        )
    }

    public static func taskSummary(
        for chore: Chore,
        in snapshot: ChoreSnapshot,
        now: Date = Date()
    ) -> WidgetTaskSummary {
        let calendar = Calendar.current
        let isOverdue = chore.dueDate.map { $0 < calendar.startOfDay(for: now) } ?? false
        let isDueToday = chore.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let statusLabel: String
        if chore.status == .blocked {
            statusLabel = "Blocked"
        } else if isOverdue {
            statusLabel = "Overdue"
        } else if isDueToday {
            statusLabel = "Due today"
        } else if chore.status == .done {
            statusLabel = "Done"
        } else {
            statusLabel = chore.dueDate.map { "Due \($0.weChoreSharedShortDateText)" } ?? chore.status.displayName
        }
        return WidgetTaskSummary(
            id: chore.id,
            threadID: chore.threadID,
            title: chore.title,
            assigneeName: snapshot.participants.first { $0.id == chore.assigneeID }?.displayName ?? "Unassigned",
            status: chore.status,
            dueDate: chore.dueDate,
            statusLabel: statusLabel,
            isOverdue: isOverdue,
            isDueToday: isDueToday
        )
    }
}

public enum WidgetSnapshotMutator {
    @discardableResult
    public static func markTaskDone(
        taskID: String,
        in snapshot: inout ChoreSnapshot,
        now: Date = Date()
    ) -> Bool {
        guard let index = snapshot.chores.firstIndex(where: { $0.id == taskID }),
              snapshot.chores[index].status != .done,
              snapshot.chores[index].status != .archived else {
            return false
        }
        snapshot.chores[index].transition(to: .done, at: now)
        let chore = snapshot.chores[index]
        let actorID = snapshot.settings.selectedParticipantID
            ?? snapshot.participants.first(where: \.isCurrentUser)?.id
            ?? chore.createdByMemberID
        let assignee = snapshot.participants.first(where: { $0.id == chore.assigneeID })?.displayName ?? "Someone"
        let body = "\(assignee) completed \(chore.title)."
        snapshot.taskActivities.append(TaskActivity(
            threadID: chore.threadID,
            choreID: chore.id,
            actorParticipantID: actorID,
            kind: .completed,
            body: body,
            createdAt: now
        ))
        snapshot.messages.append(ChoreMessage(
            threadID: chore.threadID,
            authorMemberID: actorID,
            body: body,
            kind: .system,
            createdAt: now
        ))
        snapshot.settings.recentlyCompletedTaskID = chore.id
        snapshot.normalizeConversationState()
        return true
    }
}

private extension Chore {
    static func widgetSort(lhs: Chore, rhs: Chore) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            if left != right { return left < right }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return lhs.updatedAt > rhs.updatedAt
    }
}

private extension Date {
    var weChoreSharedShortDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
