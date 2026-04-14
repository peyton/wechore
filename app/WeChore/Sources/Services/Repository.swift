import Foundation
import SwiftData

@MainActor
public protocol ChoreRepository {
    func loadSnapshot() throws -> ChoreSnapshot
    func saveSnapshot(_ snapshot: ChoreSnapshot) throws
}

@MainActor
public final class InMemoryChoreRepository: ChoreRepository {
    private var snapshot: ChoreSnapshot

    public init(snapshot: ChoreSnapshot = .empty()) {
        self.snapshot = snapshot
    }

    public func loadSnapshot() throws -> ChoreSnapshot {
        snapshot
    }

    public func saveSnapshot(_ snapshot: ChoreSnapshot) throws {
        self.snapshot = snapshot
    }
}

@MainActor
public final class SwiftDataChoreRepository: ChoreRepository {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(context: ModelContext) {
        self.context = context
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func loadSnapshot() throws -> ChoreSnapshot {
        let descriptor = FetchDescriptor<StoredAppSnapshot>(
            predicate: #Predicate { $0.id == "default" }
        )
        if let stored = try context.fetch(descriptor).first {
            return try decoder.decode(ChoreSnapshot.self, from: stored.payload)
        }
        let snapshot = ChoreSnapshot.empty()
        try saveSnapshot(snapshot)
        return snapshot
    }

    public func saveSnapshot(_ snapshot: ChoreSnapshot) throws {
        let payload = try encoder.encode(snapshot)
        let descriptor = FetchDescriptor<StoredAppSnapshot>(
            predicate: #Predicate { $0.id == "default" }
        )
        if let stored = try context.fetch(descriptor).first {
            stored.payload = payload
            stored.updatedAt = Date()
        } else {
            context.insert(StoredAppSnapshot(payload: payload))
        }
        try context.save()
    }
}

@MainActor
public final class CompositeChoreRepository: ChoreRepository {
    private let primary: ChoreRepository
    private let sharedStore: SharedSnapshotStore

    public init(primary: ChoreRepository, sharedStore: SharedSnapshotStore = SharedSnapshotStore()) {
        self.primary = primary
        self.sharedStore = sharedStore
    }

    /// Loads from both app-local storage and shared widget storage, then mirrors
    /// the newest snapshot back to the stale side. The newest snapshot is chosen
    /// by the latest timestamp in the snapshot contents. This is deliberately a
    /// simple last-write-wins strategy; CloudKit is responsible for richer
    /// shared-conversation conflict handling.
    public func loadSnapshot() throws -> ChoreSnapshot {
        let primarySnapshot = try? primary.loadSnapshot()
        let sharedSnapshot = try loadSharedSnapshotIfPresent()

        switch (primarySnapshot, sharedSnapshot) {
        case let (storedPrimary?, shared?):
            let newest = Self.snapshotLastUpdatedAt(shared) > Self.snapshotLastUpdatedAt(storedPrimary)
                ? shared
                : storedPrimary
            if newest != storedPrimary {
                try primary.saveSnapshot(newest)
            }
            if newest != shared {
                try sharedStore.saveSnapshot(newest)
            }
            return newest
        case let (storedPrimary?, nil):
            try sharedStore.saveSnapshot(storedPrimary)
            return storedPrimary
        case let (nil, shared?):
            try primary.saveSnapshot(shared)
            return shared
        case (nil, nil):
            return try primary.loadSnapshot()
        }
    }

    public func saveSnapshot(_ snapshot: ChoreSnapshot) throws {
        try primary.saveSnapshot(snapshot)
        try sharedStore.saveSnapshot(snapshot)
    }

    private func loadSharedSnapshotIfPresent() throws -> ChoreSnapshot? {
        do {
            return try sharedStore.loadSnapshot()
        } catch SharedSnapshotStoreError.missingSnapshot {
            return nil
        }
    }

    private static func snapshotLastUpdatedAt(_ snapshot: ChoreSnapshot) -> Date {
        let householdDates = [snapshot.household.createdAt, snapshot.household.updatedAt]
        let participantDates = snapshot.participants.map(\.createdAt)
        let threadDates = snapshot.threads.flatMap { [$0.createdAt, $0.updatedAt, $0.lastActivityAt] }
        let choreDates = snapshot.chores.flatMap { [$0.createdAt, $0.updatedAt] }
        let messageDates = snapshot.messages.map(\.createdAt)
        let reminderDates = snapshot.reminderLogs.map(\.createdAt)
        let suggestionDates = snapshot.suggestions.map(\.createdAt)
        let activityDates = snapshot.taskActivities.map(\.createdAt)
        let inviteDates = snapshot.invites.map(\.createdAt)
        return (
            householdDates
                + participantDates
                + threadDates
                + choreDates
                + messageDates
                + reminderDates
                + suggestionDates
                + activityDates
                + inviteDates
        ).max() ?? .distantPast
    }
}
