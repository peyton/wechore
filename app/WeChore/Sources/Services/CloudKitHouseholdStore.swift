import CloudKit
import Foundation

public protocol CloudKitDatabaseClient: Sendable {
    func save(_ record: CKRecord) async throws -> CKRecord
    func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?) async throws -> [CKRecord]
}

public protocol ConversationSyncing: Sendable {
    func records(for snapshot: ChoreSnapshot) -> [CKRecord]
    func save(snapshot: ChoreSnapshot) async throws
    func share(for threadID: String, in snapshot: ChoreSnapshot) -> CKShare?
    func invitePayload(for code: String, in snapshot: ChoreSnapshot, now: Date) -> InvitePayload?
}

public typealias HouseholdSyncing = ConversationSyncing

public struct CloudKitConversationStore: ConversationSyncing {
    public enum RecordType {
        public static let thread = "ChatThread"
        public static let participant = "ChatParticipant"
        public static let chore = "Chore"
        public static let message = "ChoreMessage"
        public static let taskActivity = "TaskActivity"
        public static let invite = "ThreadInvite"
    }

    public let zoneID: CKRecordZone.ID
    private let database: CloudKitDatabaseClient

    public init(
        database: CloudKitDatabaseClient,
        zoneID: CKRecordZone.ID = CKRecordZone.ID(
            zoneName: "wechore-conversations",
            ownerName: CKCurrentUserDefaultName
        )
    ) {
        self.database = database
        self.zoneID = zoneID
    }

    public func records(for snapshot: ChoreSnapshot) -> [CKRecord] {
        snapshot.threads.map(threadRecord)
            + snapshot.participants.map(participantRecord)
            + snapshot.chores.map(choreRecord)
            + snapshot.messages.map(messageRecord)
            + snapshot.taskActivities.map(taskActivityRecord)
            + snapshot.invites.map(inviteRecord)
    }

    public func save(snapshot: ChoreSnapshot) async throws {
        for record in records(for: snapshot) {
            _ = try await database.save(record)
        }
    }

    public func share(for threadID: String, in snapshot: ChoreSnapshot) -> CKShare? {
        guard let thread = snapshot.threads.first(where: { $0.id == threadID }) else { return nil }
        let root = threadRecord(thread)
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = thread.title as CKRecordValue
        return share
    }

    public func invitePayload(for code: String, in snapshot: ChoreSnapshot, now: Date) -> InvitePayload? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let invite = snapshot.invites.first(where: {
            $0.code == normalized && $0.expiresAt >= now
        }), let thread = snapshot.threads.first(where: { $0.id == invite.threadID }) else {
            return nil
        }
        return InvitePayload(
            inviteID: invite.id,
            threadID: thread.id,
            threadTitle: thread.title,
            inviterParticipantID: invite.inviterParticipantID,
            code: invite.code,
            expiresAt: invite.expiresAt
        )
    }

    private func recordID(recordType: String, id: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(recordType).\(id)", zoneID: zoneID)
    }

    private func threadRecord(_ thread: ChatThread) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.thread,
            recordID: recordID(recordType: RecordType.thread, id: thread.id)
        )
        record["kind"] = thread.kind.rawValue as CKRecordValue
        record["title"] = thread.title as CKRecordValue
        record["participantIDs"] = thread.participantIDs as CKRecordValue
        record["pinnedTaskIDs"] = thread.pinnedTaskIDs as CKRecordValue
        record["unreadCount"] = thread.unreadCount as CKRecordValue
        record["createdAt"] = thread.createdAt as CKRecordValue
        record["updatedAt"] = thread.updatedAt as CKRecordValue
        record["lastActivityAt"] = thread.lastActivityAt as CKRecordValue
        return record
    }

    private func participantRecord(_ participant: ChatParticipant) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.participant,
            recordID: recordID(recordType: RecordType.participant, id: participant.id)
        )
        record["displayName"] = participant.displayName as CKRecordValue
        record["isCurrentUser"] = (participant.isCurrentUser ? 1 : 0) as CKRecordValue
        record["createdAt"] = participant.createdAt as CKRecordValue
        if let phoneNumber = participant.phoneNumber {
            record["phoneNumber"] = phoneNumber as CKRecordValue
        }
        if let faceTimeHandle = participant.faceTimeHandle {
            record["faceTimeHandle"] = faceTimeHandle as CKRecordValue
        }
        return record
    }

    private func choreRecord(_ chore: Chore) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.chore,
            recordID: recordID(recordType: RecordType.chore, id: chore.id)
        )
        record["threadID"] = chore.threadID as CKRecordValue
        record["title"] = chore.title as CKRecordValue
        record["notes"] = chore.notes as CKRecordValue
        record["createdByMemberID"] = chore.createdByMemberID as CKRecordValue
        record["assigneeID"] = chore.assigneeID as CKRecordValue
        record["status"] = chore.status.rawValue as CKRecordValue
        record["reminderPolicy"] = chore.reminderPolicy.rawValue as CKRecordValue
        record["notificationState"] = chore.notificationState.rawValue as CKRecordValue
        record["createdAt"] = chore.createdAt as CKRecordValue
        record["updatedAt"] = chore.updatedAt as CKRecordValue
        if let sourceMessageID = chore.sourceMessageID {
            record["sourceMessageID"] = sourceMessageID as CKRecordValue
        }
        if let dueDate = chore.dueDate {
            record["dueDate"] = dueDate as CKRecordValue
        }
        if let lastReminderAt = chore.lastReminderAt {
            record["lastReminderAt"] = lastReminderAt as CKRecordValue
        }
        return record
    }

    private func messageRecord(_ message: ChoreMessage) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.message,
            recordID: recordID(recordType: RecordType.message, id: message.id)
        )
        record["threadID"] = message.threadID as CKRecordValue
        record["authorMemberID"] = message.authorMemberID as CKRecordValue
        record["body"] = message.body as CKRecordValue
        record["kind"] = message.kind.rawValue as CKRecordValue
        record["createdAt"] = message.createdAt as CKRecordValue
        if let attachment = message.voiceAttachment {
            record["voiceDuration"] = attachment.duration as CKRecordValue
            if let confidence = attachment.transcriptConfidence {
                record["transcriptConfidence"] = confidence as CKRecordValue
            }
            if let audioURL = try? VoiceMessageFiles.fileURL(for: attachment.localAudioFilename),
               FileManager.default.fileExists(atPath: audioURL.path) {
                record["voiceAudio"] = CKAsset(fileURL: audioURL)
            }
        }
        return record
    }

    private func taskActivityRecord(_ activity: TaskActivity) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.taskActivity,
            recordID: recordID(recordType: RecordType.taskActivity, id: activity.id)
        )
        record["threadID"] = activity.threadID as CKRecordValue
        record["choreID"] = activity.choreID as CKRecordValue
        record["actorParticipantID"] = activity.actorParticipantID as CKRecordValue
        record["kind"] = activity.kind.rawValue as CKRecordValue
        record["body"] = activity.body as CKRecordValue
        record["createdAt"] = activity.createdAt as CKRecordValue
        return record
    }

    private func inviteRecord(_ invite: ThreadInvite) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.invite,
            recordID: recordID(recordType: RecordType.invite, id: invite.id)
        )
        record["threadID"] = invite.threadID as CKRecordValue
        record["inviterParticipantID"] = invite.inviterParticipantID as CKRecordValue
        record["code"] = invite.code as CKRecordValue
        record["expiresAt"] = invite.expiresAt as CKRecordValue
        record["createdAt"] = invite.createdAt as CKRecordValue
        return record
    }
}

public typealias CloudKitHouseholdStore = CloudKitConversationStore

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
