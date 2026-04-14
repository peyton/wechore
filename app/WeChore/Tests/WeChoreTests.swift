import CloudKit
import SwiftData
@testable import WeChore
import XCTest

@MainActor
final class WeChoreTests: XCTestCase {
    func testAppRouterDefaultsToChats() {
        let router = AppRouter()

        XCTAssertEqual(router.selectedRoute, .messages)
        XCTAssertEqual(router.selectedRoute.title, "Chats")
    }

    func testChoreStatusTransitionUpdatesStatusAndTimestamp() {
        let created = Date(timeIntervalSince1970: 100)
        let updated = Date(timeIntervalSince1970: 200)
        var chore = Chore(
            title: "Take out trash",
            createdByMemberID: "a",
            assigneeID: "b",
            createdAt: created,
            updatedAt: created
        )

        chore.transition(to: .done, at: updated)

        XCTAssertEqual(chore.status, .done)
        XCTAssertEqual(chore.updatedAt, updated)
        XCTAssertFalse(chore.isActive)
    }

    func testReminderPlannerUsesDueDateAndSpecificCopy() {
        let now = Date(timeIntervalSince1970: 1_000)
        let due = Date(timeIntervalSince1970: 2_000)
        let chore = Chore(
            id: "chore-1",
            title: "Unload dishwasher",
            createdByMemberID: "member-1",
            assigneeID: "member-2",
            dueDate: due
        )
        let member = Member(id: "member-2", displayName: "Sam")

        let plan = ReminderPlanner.plan(chore: chore, assignee: member, now: now)

        XCTAssertEqual(plan.identifier, "wechore.chore.chore-1")
        XCTAssertEqual(plan.fireDate, due)
        XCTAssertEqual(plan.body, "Sam, check progress on Unload dishwasher.")
    }

    func testMessageSuggestionEngineExtractsAssigneeDueDateAndTitle() {
        let now = Date(timeIntervalSince1970: 1_000)
        let sam = Member(id: "sam", displayName: "Sam")
        let message = ChoreMessage(
            id: "message-1",
            authorMemberID: "me",
            body: "Sam please unload dishwasher tomorrow"
        )

        let suggestions = OnDeviceMessageSuggestionEngine().suggestions(
            from: message,
            members: [sam],
            now: now
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].assigneeID, "sam")
        XCTAssertEqual(suggestions[0].title, "Unload dishwasher")
        XCTAssertNotNil(suggestions[0].dueDate)
    }

    func testMessageSuggestionEngineHandlesDictatedPunctuation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let sam = Member(id: "sam", displayName: "Sam")
        let message = ChoreMessage(
            id: "message-1",
            authorMemberID: "me",
            body: "Sam, please unload the dishwasher tomorrow."
        )

        let suggestions = OnDeviceMessageSuggestionEngine().suggestions(
            from: message,
            members: [sam],
            now: now
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].assigneeID, "sam")
        XCTAssertEqual(suggestions[0].title, "Unload the dishwasher")
    }

    func testMessageSuggestionEngineDoesNotSuggestForPlainChat() {
        let message = ChoreMessage(
            id: "message-1",
            authorMemberID: "me",
            body: "That movie was good"
        )

        XCTAssertTrue(
            OnDeviceMessageSuggestionEngine()
                .suggestions(from: message, members: [], now: Date())
                .isEmpty
        )
    }

    func testCommunicationPrefersFaceTimeAudioThenPhone() {
        let opener = AppleSystemCommunicationOpener()
        let faceTime = Member(
            displayName: "Sam",
            phoneNumber: "5551231111",
            faceTimeHandle: "sam@example.com"
        )
        let phone = Member(displayName: "Lee", phoneNumber: "(555) 123-2222")

        XCTAssertEqual(
            opener.preferredVoiceURL(for: faceTime)?.absoluteString,
            "facetime-audio://sam@example.com"
        )
        XCTAssertEqual(
            opener.preferredVoiceURL(for: phone)?.absoluteString,
            "tel:5551232222"
        )
    }

    func testAppStateAcceptsMessageSuggestionIntoChores() {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(repository: repository, clock: FixedClock(now))

        state.postMessage("Sam please clean bathroom tomorrow")

        XCTAssertEqual(state.suggestions.count, 1)
        state.acceptSuggestion(state.suggestions[0])

        XCTAssertTrue(state.chores.contains { $0.title == "Clean bathroom" })
        XCTAssertTrue(state.suggestions.isEmpty)
    }

    func testVoiceMessageUsesSharedSuggestionPath() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            voiceRecorder: FakeVoiceMessageRecorder(duration: 3),
            voiceTranscriber: FakeVoiceMessageTranscriber(transcript: "Sam please sweep the floor tomorrow"),
            voicePlayer: FakeVoiceMessagePlayer(),
            clock: FixedClock(now)
        )

        await state.startVoiceMessageRecording()
        await state.finishVoiceMessageRecording()

        XCTAssertEqual(state.messages.last?.kind, .voice)
        XCTAssertEqual(state.messages.last?.body, "Sam please sweep the floor tomorrow")
        XCTAssertEqual(state.messages.last?.voiceAttachment?.duration, 3)
        XCTAssertEqual(state.suggestions.count, 1)
        XCTAssertEqual(state.suggestions[0].title, "Sweep the floor")
    }

    func testChoreMessageDecodesOldTextPayloadAsTextMessage() throws {
        let payload = Data("""
        {
          "id": "message-old",
          "authorMemberID": "member-peyton",
          "body": "Plain old message",
          "createdAt": "1970-01-01T00:00:00Z"
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let message = try decoder.decode(ChoreMessage.self, from: payload)

        XCTAssertEqual(message.kind, .text)
        XCTAssertNil(message.voiceAttachment)
    }

    func testVoiceAttachmentMetadataRoundTripsThroughSnapshot() throws {
        let now = Date(timeIntervalSince1970: 123)
        var snapshot = ChoreSnapshot.seededForUITests(now: now)
        snapshot.messages.append(ChoreMessage(
            id: "voice-1",
            authorMemberID: "member-peyton",
            body: "Sam please sweep the floor tomorrow",
            kind: .voice,
            voiceAttachment: VoiceAttachment(
                localAudioFilename: "voice-1.m4a",
                duration: 2.5,
                transcriptConfidence: 0.93
            ),
            createdAt: now
        ))
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(ChoreSnapshot.self, from: data)

        XCTAssertEqual(decoded.messages.last?.kind, .voice)
        XCTAssertEqual(decoded.messages.last?.voiceAttachment?.localAudioFilename, "voice-1.m4a")
        XCTAssertEqual(decoded.messages.last?.voiceAttachment?.duration, 2.5)
        XCTAssertEqual(decoded.messages.last?.voiceAttachment?.transcriptConfidence, 0.93)
    }

    func testVoiceStorageUsesAppLocalPathAndMissingAudioFails() throws {
        let storage = LocalVoiceMessageStorage()
        let recordingURL = try storage.makeRecordingURL()
        XCTAssertTrue(recordingURL.path.contains(VoiceMessageFiles.directoryName))
        let missing = storage.attachment(
            for: recordingURL,
            duration: 1,
            transcriptConfidence: nil
        )

        XCTAssertThrowsError(try storage.fileURL(for: missing)) { error in
            XCTAssertEqual(error as? VoiceMessageError, .missingAudioFile)
        }
    }

    func testSwiftDataRepositoryRoundTripsSnapshot() throws {
        let container = try WeChoreModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let repository = SwiftDataChoreRepository(context: ModelContext(container))
        let snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))

        try repository.saveSnapshot(snapshot)
        let loaded = try repository.loadSnapshot()

        XCTAssertEqual(loaded.household.name, "Pine House")
        XCTAssertEqual(loaded.members.count, 2)
        XCTAssertEqual(loaded.chores.first?.title, "Load dishwasher")
    }

    func testCloudKitRecordNamesAreDeterministic() {
        let snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        let store = CloudKitHouseholdStore(database: FakeCloudKitDatabaseClient())

        let names = store.records(for: snapshot).map(\.recordID.recordName)

        XCTAssertTrue(names.contains("Household.household-ui"))
        XCTAssertTrue(names.contains("Member.member-peyton"))
        XCTAssertTrue(names.contains("Chore.chore-dishes"))
    }

    func testThemeGreenMatchesBrandToken() {
        let uiColor = UIColor(AppPalette.weChatGreen)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        XCTAssertEqual(red, 0.027, accuracy: 0.01)
        XCTAssertEqual(green, 0.757, accuracy: 0.01)
        XCTAssertEqual(blue, 0.376, accuracy: 0.01)
        XCTAssertEqual(alpha, 1, accuracy: 0.01)
    }
}
