import Foundation
import SwiftData

@Model
final class StoredAppSnapshot {
    var id: String = "default"
    @Attribute(.externalStorage) var payload: Data = Data()
    var updatedAt: Date = Date()

    init(id: String = "default", payload: Data, updatedAt: Date = Date()) {
        self.id = id
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

enum WeChoreModelContainerFactory {
    static func makeSharedContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let schema = Schema([
            StoredAppSnapshot.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
