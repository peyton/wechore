import CloudKit
@testable import WeChore
import XCTest

final class WeChoreIntegrationTests: XCTestCase {
    func testCloudKitConversationStoreSavesThreadsParticipantsTasksMessagesActivitiesAndInvites() async throws {
        let database = FakeCloudKitDatabaseClient()
        let store = CloudKitConversationStore(database: database)
        var snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        snapshot.messages.append(ChoreMessage(
            id: "message-1",
            threadID: "thread-pine",
            authorMemberID: "participant-peyton",
            body: "Sam please load dishwasher tomorrow",
            createdAt: Date(timeIntervalSince1970: 124)
        ))
        snapshot.taskActivities.append(TaskActivity(
            id: "activity-1",
            threadID: "thread-pine",
            choreID: "task-dishes",
            actorParticipantID: "participant-peyton",
            kind: .assigned,
            body: "Sam was assigned Load dishwasher.",
            createdAt: Date(timeIntervalSince1970: 124)
        ))

        try await store.save(snapshot: snapshot)
        let saved = await database.savedRecords

        XCTAssertNotNil(saved["ChatThread.thread-pine"])
        XCTAssertNotNil(saved["ChatParticipant.participant-sam"])
        XCTAssertNotNil(saved["Chore.task-dishes"])
        XCTAssertNotNil(saved["ChoreMessage.message-1"])
        XCTAssertNotNil(saved["TaskActivity.activity-1"])
        XCTAssertNotNil(saved["ThreadInvite.invite-pine"])
    }

    func testCloudKitVoiceMessageRecordIncludesThreadTranscriptMetadataAndAsset() throws {
        let audioURL = try VoiceMessageFiles.fileURL(for: "integration-voice.m4a")
        try Data("voice-asset".utf8).write(to: audioURL)
        var snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        snapshot.messages.append(ChoreMessage(
            id: "voice-message-1",
            threadID: "thread-pine",
            authorMemberID: "participant-peyton",
            body: "Sam please sweep the floor tomorrow",
            kind: .voice,
            voiceAttachment: VoiceAttachment(
                localAudioFilename: audioURL.lastPathComponent,
                duration: 2.4,
                transcriptConfidence: 0.98
            ),
            createdAt: Date(timeIntervalSince1970: 124)
        ))
        let store = CloudKitConversationStore(database: FakeCloudKitDatabaseClient())

        let record = store.records(for: snapshot)
            .first { $0.recordID.recordName == "ChoreMessage.voice-message-1" }

        XCTAssertEqual(record?["threadID"] as? String, "thread-pine")
        XCTAssertEqual(record?["kind"] as? String, "voice")
        XCTAssertEqual(record?["body"] as? String, "Sam please sweep the floor tomorrow")
        XCTAssertEqual(record?["voiceDuration"] as? Double, 2.4)
        XCTAssertEqual(record?["transcriptConfidence"] as? Double, 0.98)
        XCTAssertNotNil(record?["voiceAudio"] as? CKAsset)
    }

    func testCloudKitShareUsesChatTitle() {
        let snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        let store = CloudKitConversationStore(database: FakeCloudKitDatabaseClient())

        let share = store.share(for: "thread-pine", in: snapshot)

        XCTAssertEqual(share?[CKShare.SystemFieldKey.title] as? String, "Pine Chat")
    }

    func testInviteCodeLookupResolvesUnexpiredInviteAndRejectsUnknownOrExpiredCodes() {
        var snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        snapshot.invites.append(ThreadInvite(
            id: "invite-expired",
            threadID: "thread-pine",
            inviterParticipantID: "participant-peyton",
            code: "OLD999",
            expiresAt: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 90)
        ))
        let store = CloudKitConversationStore(database: FakeCloudKitDatabaseClient())

        let payload = store.invitePayload(
            for: "PINE123",
            in: snapshot,
            now: Date(timeIntervalSince1970: 123)
        )

        XCTAssertEqual(payload?.threadID, "thread-pine")
        XCTAssertNil(store.invitePayload(for: "NOPE99", in: snapshot, now: Date(timeIntervalSince1970: 123)))
        XCTAssertNil(store.invitePayload(for: "OLD999", in: snapshot, now: Date(timeIntervalSince1970: 123)))
    }

    @MainActor
    func testSyncedTaskCanScheduleLocalReminderThroughAppState() async {
        let scheduler = CapturingReminderScheduler()
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: Date(timeIntervalSince1970: 123)))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            reminderScheduler: scheduler,
            clock: FixedClock(Date(timeIntervalSince1970: 123))
        )

        await state.scheduleReminder(for: state.chores[0])
        let plans = scheduler.scheduledPlans

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].identifier, "wechore.thread.thread-pine.task.task-dishes")
        XCTAssertEqual(state.snapshot.taskActivities.last?.kind, .reminded)
    }

    @MainActor
    func testVoiceTranscriptTaskCanBeCompletedFromTileState() async throws {
        let now = Date(timeIntervalSince1970: 123)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            voiceRecorder: FakeVoiceMessageRecorder(),
            voiceTranscriber: FakeVoiceMessageTranscriber(transcript: "Sam please sweep the floor tomorrow"),
            voicePlayer: FakeVoiceMessagePlayer(),
            clock: FixedClock(now)
        )

        await state.startVoiceMessageRecording(in: "thread-dm-sam")
        await state.finishVoiceMessageRecording()
        let chore = try XCTUnwrap(state.chores.first { $0.title == "Sweep the floor" })
        state.updateStatus(choreID: chore.id, status: .done)

        XCTAssertEqual(chore.assigneeID, "participant-sam")
        XCTAssertFalse(state.activeChores(in: "thread-dm-sam").contains { $0.id == chore.id })
        XCTAssertEqual(state.snapshot.taskActivities.last?.kind, .completed)
    }
}
