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
