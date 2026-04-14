import CloudKit
@testable import WeChore
import XCTest

final class WeChoreIntegrationTests: XCTestCase {
    func testCloudKitHouseholdStoreSavesHouseholdMembersChoresAndMessages() async throws {
        let database = FakeCloudKitDatabaseClient()
        let store = CloudKitHouseholdStore(database: database)
        var snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        snapshot.messages.append(ChoreMessage(
            id: "message-1",
            authorMemberID: "member-peyton",
            body: "Sam please load dishwasher tomorrow",
            createdAt: Date(timeIntervalSince1970: 124)
        ))

        try await store.save(snapshot: snapshot)
        let saved = await database.savedRecords

        XCTAssertNotNil(saved["Household.household-ui"])
        XCTAssertNotNil(saved["Member.member-sam"])
        XCTAssertNotNil(saved["Chore.chore-dishes"])
        XCTAssertNotNil(saved["ChoreMessage.message-1"])
    }

    func testCloudKitVoiceMessageRecordIncludesTranscriptMetadataAndAsset() throws {
        let audioURL = try VoiceMessageFiles.fileURL(for: "integration-voice.m4a")
        try Data("voice-asset".utf8).write(to: audioURL)
        var snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        snapshot.messages.append(ChoreMessage(
            id: "voice-message-1",
            authorMemberID: "member-peyton",
            body: "Sam please sweep the floor tomorrow",
            kind: .voice,
            voiceAttachment: VoiceAttachment(
                localAudioFilename: audioURL.lastPathComponent,
                duration: 2.4,
                transcriptConfidence: 0.98
            ),
            createdAt: Date(timeIntervalSince1970: 124)
        ))
        let store = CloudKitHouseholdStore(database: FakeCloudKitDatabaseClient())

        let record = store.records(for: snapshot)
            .first { $0.recordID.recordName == "ChoreMessage.voice-message-1" }

        XCTAssertEqual(record?["kind"] as? String, "voice")
        XCTAssertEqual(record?["body"] as? String, "Sam please sweep the floor tomorrow")
        XCTAssertEqual(record?["voiceDuration"] as? Double, 2.4)
        XCTAssertEqual(record?["transcriptConfidence"] as? Double, 0.98)
        XCTAssertNotNil(record?["voiceAudio"] as? CKAsset)
    }

    func testCloudKitShareUsesHouseholdName() {
        let snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        let store = CloudKitHouseholdStore(database: FakeCloudKitDatabaseClient())

        let share = store.share(for: snapshot)

        XCTAssertEqual(share[CKShare.SystemFieldKey.title] as? String, "Pine House")
    }

    @MainActor
    func testSyncedChoreCanScheduleLocalReminderThroughAppState() async {
        let scheduler = CapturingReminderScheduler()
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: Date(timeIntervalSince1970: 123)))
        let state = AppState(
            repository: repository,
            reminderScheduler: scheduler,
            clock: FixedClock(Date(timeIntervalSince1970: 123))
        )

        await state.scheduleReminder(for: state.chores[0])
        let plans = await scheduler.scheduledPlans

        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].identifier, "wechore.chore.chore-dishes")
    }

    @MainActor
    func testVoiceTranscriptSuggestionCanBeAcceptedIntoChores() async {
        let now = Date(timeIntervalSince1970: 123)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            voiceRecorder: FakeVoiceMessageRecorder(),
            voiceTranscriber: FakeVoiceMessageTranscriber(transcript: "Sam please sweep the floor tomorrow"),
            voicePlayer: FakeVoiceMessagePlayer(),
            clock: FixedClock(now)
        )

        await state.startVoiceMessageRecording()
        await state.finishVoiceMessageRecording()
        XCTAssertEqual(state.suggestions.count, 1)
        state.acceptSuggestion(state.suggestions[0])

        XCTAssertTrue(state.chores.contains { $0.title == "Sweep the floor" })
        XCTAssertTrue(state.suggestions.isEmpty)
    }
}
