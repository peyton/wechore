import CloudKit
import Foundation

public protocol CloudKitDatabaseClient: Sendable {
    func save(_ record: CKRecord) async throws -> CKRecord
    func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?) async throws -> [CKRecord]
}

public protocol HouseholdSyncing: Sendable {
    func records(for snapshot: ChoreSnapshot) -> [CKRecord]
    func save(snapshot: ChoreSnapshot) async throws
    func share(for snapshot: ChoreSnapshot) -> CKShare
}

public struct CloudKitHouseholdStore: HouseholdSyncing {
    public enum RecordType {
        public static let household = "Household"
        public static let member = "Member"
        public static let chore = "Chore"
        public static let message = "ChoreMessage"
    }

    public let zoneID: CKRecordZone.ID
    private let database: CloudKitDatabaseClient

    public init(
        database: CloudKitDatabaseClient,
        zoneID: CKRecordZone.ID = CKRecordZone.ID(zoneName: "wechore-household", ownerName: CKCurrentUserDefaultName)
    ) {
        self.database = database
        self.zoneID = zoneID
    }

    public func records(for snapshot: ChoreSnapshot) -> [CKRecord] {
        var output: [CKRecord] = []
        let household = CKRecord(
            recordType: RecordType.household,
            recordID: recordID(recordType: RecordType.household, id: snapshot.household.id)
        )
        household["name"] = snapshot.household.name as CKRecordValue
        household["updatedAt"] = snapshot.household.updatedAt as CKRecordValue
        output.append(household)

        output.append(contentsOf: snapshot.members.map(memberRecord))
        output.append(contentsOf: snapshot.chores.map(choreRecord))
        output.append(contentsOf: snapshot.messages.map(messageRecord))
        return output
    }

    public func save(snapshot: ChoreSnapshot) async throws {
        for record in records(for: snapshot) {
            _ = try await database.save(record)
        }
    }

    public func share(for snapshot: ChoreSnapshot) -> CKShare {
        let root = records(for: snapshot)[0]
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = snapshot.household.name as CKRecordValue
        return share
    }

    private func recordID(recordType: String, id: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(recordType).\(id)", zoneID: zoneID)
    }

    private func memberRecord(_ member: Member) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.member,
            recordID: recordID(recordType: RecordType.member, id: member.id)
        )
        record["displayName"] = member.displayName as CKRecordValue
        record["isCurrentUser"] = (member.isCurrentUser ? 1 : 0) as CKRecordValue
        if let phoneNumber = member.phoneNumber {
            record["phoneNumber"] = phoneNumber as CKRecordValue
        }
        if let faceTimeHandle = member.faceTimeHandle {
            record["faceTimeHandle"] = faceTimeHandle as CKRecordValue
        }
        return record
    }

    private func choreRecord(_ chore: Chore) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.chore,
            recordID: recordID(recordType: RecordType.chore, id: chore.id)
        )
        record["title"] = chore.title as CKRecordValue
        record["notes"] = chore.notes as CKRecordValue
        record["createdByMemberID"] = chore.createdByMemberID as CKRecordValue
        record["assigneeID"] = chore.assigneeID as CKRecordValue
        record["status"] = chore.status.rawValue as CKRecordValue
        record["createdAt"] = chore.createdAt as CKRecordValue
        record["updatedAt"] = chore.updatedAt as CKRecordValue
        if let dueDate = chore.dueDate {
            record["dueDate"] = dueDate as CKRecordValue
        }
        return record
    }

    private func messageRecord(_ message: ChoreMessage) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.message,
            recordID: recordID(recordType: RecordType.message, id: message.id)
        )
        record["authorMemberID"] = message.authorMemberID as CKRecordValue
        record["body"] = message.body as CKRecordValue
        record["createdAt"] = message.createdAt as CKRecordValue
        return record
    }
}

public actor FakeCloudKitDatabaseClient: CloudKitDatabaseClient {
    public private(set) var savedRecords: [String: CKRecord] = [:]

    public init() {}

    public func save(_ record: CKRecord) async throws -> CKRecord {
        savedRecords[record.recordID.recordName] = record
        return record
    }

    public func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?) async throws -> [CKRecord] {
        Array(savedRecords.values)
    }
}
