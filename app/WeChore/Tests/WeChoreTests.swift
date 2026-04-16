import CloudKit
import SwiftData
@testable import WeChore
import XCTest

@MainActor
final class WeChoreTests: XCTestCase {
    func testAppRouterStartsAtChatTree() {
        let router = AppRouter()

        XCTAssertTrue(router.phonePath.isEmpty)
        XCTAssertNil(router.selectedDestination)
    }

    func testChoreStatusTransitionUpdatesStatusAndTimestamp() {
        let created = Date(timeIntervalSince1970: 100)
        let updated = Date(timeIntervalSince1970: 200)
        var chore = Chore(
            threadID: "thread-1",
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

    func testReminderPlannerUsesThreadScopedIdentifier() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let now = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 1, day: 1, hour: 11, minute: 43, second: 20)
        ))
        let due = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))
        let chore = Chore(
            id: "task-1",
            threadID: "thread-family",
            title: "Unload dishwasher",
            createdByMemberID: "participant-1",
            assigneeID: "participant-2",
            dueDate: due
        )
        let participant = ChatParticipant(id: "participant-2", displayName: "Sam")

        let plan = ReminderPlanner.plan(chore: chore, assignee: participant, now: now, calendar: calendar)

        XCTAssertEqual(plan.identifier, "wechore.thread.thread-family.task.task-1")
        XCTAssertEqual(plan.fireDate, due)
        XCTAssertEqual(plan.body, "Sam, check Unload dishwasher.")
    }

    func testRuleBasedExtractionCreatesClearTaskDraft() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let sam = ChatParticipant(id: "participant-sam", displayName: "Sam")
        let message = ChoreMessage(
            id: "message-1",
            threadID: "thread-1",
            authorMemberID: "participant-me",
            body: "Sam please unload dishwasher tomorrow"
        )

        let drafts = await RuleBasedTaskExtractionEngine().extractTasks(
            from: message,
            participants: [sam],
            now: now
        )

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].threadID, "thread-1")
        XCTAssertEqual(drafts[0].assigneeID, "participant-sam")
        XCTAssertEqual(drafts[0].title, "Unload dishwasher")
        XCTAssertNotNil(drafts[0].dueDate)
        XCTAssertFalse(drafts[0].needsConfirmation)
    }

    func testRuleBasedExtractionKeepsAmbiguousRequestAsDraft() async {
        let message = ChoreMessage(
            id: "message-1",
            threadID: "thread-1",
            authorMemberID: "participant-me",
            body: "Please clean the bathroom tomorrow."
        )

        let drafts = await RuleBasedTaskExtractionEngine().extractTasks(
            from: message,
            participants: [],
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].title, "Clean the bathroom")
        XCTAssertNil(drafts[0].assigneeID)
        XCTAssertTrue(drafts[0].needsConfirmation)
    }

    func testPlainChatDoesNotExtractTask() async {
        let message = ChoreMessage(
            id: "message-1",
            threadID: "thread-1",
            authorMemberID: "participant-me",
            body: "That movie was good"
        )

        let drafts = await RuleBasedTaskExtractionEngine().extractTasks(
            from: message,
            participants: [],
            now: Date()
        )

        XCTAssertTrue(drafts.isEmpty)
    }

    func testSnapshotMigrationCreatesOneGroupChatFromOldPayload() throws {
        let payload = Data("""
        {
          "household": {
            "id": "household-old",
            "name": "Pine House",
            "createdAt": "1970-01-01T00:00:00Z",
            "updatedAt": "1970-01-01T00:00:00Z"
          },
          "members": [
            {
              "id": "participant-peyton",
              "displayName": "Peyton",
              "isCurrentUser": true,
              "createdAt": "1970-01-01T00:00:00Z"
            },
            {
              "id": "participant-sam",
              "displayName": "Sam",
              "isCurrentUser": false,
              "createdAt": "1970-01-01T00:00:00Z"
            }
          ],
          "chores": [
            {
              "id": "task-old",
              "title": "Load dishwasher",
              "notes": "",
              "createdByMemberID": "participant-peyton",
              "assigneeID": "participant-sam",
              "status": "open",
              "createdAt": "1970-01-01T00:00:00Z",
              "updatedAt": "1970-01-01T00:00:00Z"
            }
          ],
          "messages": [
            {
              "id": "message-old",
              "authorMemberID": "participant-peyton",
              "body": "Sam please load dishwasher",
              "createdAt": "1970-01-01T00:00:00Z"
            }
          ],
          "reminderLogs": [],
          "suggestions": [],
          "settings": {
            "hasCompletedOnboarding": true,
            "selectedMemberID": "participant-peyton",
            "notificationsEnabled": false,
            "cloudKitEnabled": true
          }
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(ChoreSnapshot.self, from: payload)

        XCTAssertEqual(snapshot.threads.count, 1)
        XCTAssertEqual(snapshot.threads[0].title, "Pine House")
        XCTAssertEqual(snapshot.chores[0].threadID, snapshot.threads[0].id)
        XCTAssertEqual(snapshot.messages[0].threadID, snapshot.threads[0].id)
        XCTAssertEqual(snapshot.settings.selectedParticipantID, "participant-peyton")
    }

    func testInvitePayloadRoundTripsThroughAppURL() {
        let payload = InvitePayload(
            inviteID: "invite-1",
            threadID: "thread-1",
            threadTitle: "Pine Chat",
            inviterParticipantID: "participant-peyton",
            code: "PINE123",
            expiresAt: Date(timeIntervalSince1970: 2_000)
        )

        let decoded = InvitePayload(url: payload.appURL())

        XCTAssertEqual(decoded, payload)
        XCTAssertTrue(payload.shareText.contains("PINE123"))
    }

    func testDeepLinkURLConstructionDoesNotRequireForceUnwrapFallback() {
        let url = WeChoreDeepLink.thread("thread-pine").url()

        XCTAssertEqual(url.scheme, "wechore")
        XCTAssertEqual(url.host, "thread")
        XCTAssertEqual(url.path, "/thread-pine")
    }

    func testExpiredInvitesArePrunedDuringNormalization() {
        let now = Date(timeIntervalSince1970: 2_000)
        var snapshot = ChoreSnapshot.seededForUITests(now: now)
        snapshot.invites.append(ThreadInvite(
            id: "invite-expired",
            threadID: "thread-pine",
            inviterParticipantID: "participant-peyton",
            code: "OLD123",
            expiresAt: Date(timeIntervalSince1970: 1_000),
            createdAt: Date(timeIntervalSince1970: 900)
        ))

        snapshot.normalizeConversationState(now: now)

        XCTAssertFalse(snapshot.invites.contains { $0.id == "invite-expired" })
        XCTAssertTrue(snapshot.invites.contains { $0.id == "invite-pine" })
    }

    func testQRCodeRendererCreatesImageForInviteURL() {
        let payload = InvitePayload(
            inviteID: "invite-1",
            threadID: "thread-1",
            threadTitle: "Pine Chat",
            inviterParticipantID: "participant-peyton",
            code: "PINE123",
            expiresAt: Date(timeIntervalSince1970: 2_000)
        )

        let image = QRCodeRenderer.makeImage(from: payload.universalURL.absoluteString)

        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
        XCTAssertGreaterThan(image?.size.height ?? 0, 0)
    }

    func testDMChoreIsAssignedToRecipientWithoutMention() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let widgetReloader = CapturingWidgetTimelineReloader()
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            widgetTimelineReloader: widgetReloader,
            clock: FixedClock(now)
        )

        await state.postMessage("Please clean bathroom tomorrow", in: "thread-dm-sam")

        let chore = state.chores.first { $0.title == "Clean bathroom" && $0.threadID == "thread-dm-sam" }
        XCTAssertEqual(chore?.assigneeID, "participant-sam")
        XCTAssertTrue(state.suggestions.isEmpty)
        XCTAssertTrue(state.messages(in: "thread-dm-sam").contains { $0.kind == .system })
        XCTAssertGreaterThan(widgetReloader.reloadCount, 0)
    }

    func testGroupTaskUsesAssigneeDraftBubbleEvenWhenNameDetected() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        await state.postMessage("Sam please clean bathroom tomorrow", in: "thread-pine")

        let draft = state.taskDrafts(in: "thread-pine").first
        XCTAssertEqual(draft?.title, "Clean bathroom")
        XCTAssertEqual(draft?.assigneeID, "participant-sam")
        XCTAssertEqual(draft?.assignmentState, .needsAssignee)
        XCTAssertFalse(state.chores.contains { $0.title == "Clean bathroom" && $0.threadID == "thread-pine" })

        state.confirmDraft(try XCTUnwrap(draft), assigneeID: "participant-sam")

        XCTAssertTrue(state.chores.contains {
            $0.title == "Clean bathroom" && $0.threadID == "thread-pine" && $0.assigneeID == "participant-sam"
        })
        XCTAssertTrue(state.taskDrafts(in: "thread-pine").isEmpty)
    }

    func testAppStateKeepsAmbiguousTaskAsConfirmableDraft() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        await state.postMessage("Please clean bathroom tomorrow", in: "thread-pine")

        XCTAssertEqual(state.taskDrafts(in: "thread-pine").count, 1)
        XCTAssertEqual(state.taskDrafts(in: "thread-pine")[0].assignmentState, .needsAssignee)
        state.confirmDraft(state.taskDrafts(in: "thread-pine")[0])
        XCTAssertEqual(state.lastStatusMessage, "Choose who should do this.")

        state.confirmDraft(state.taskDrafts(in: "thread-pine")[0], assigneeID: "participant-sam")

        XCTAssertTrue(state.chores.contains {
            $0.title == "Clean bathroom" && $0.threadID == "thread-pine" && $0.assigneeID == "participant-sam"
        })
    }

    func testFakeExtractionEngineNormalizesThreadAndMessage() async {
        let engine = FakeTaskExtractionEngine(drafts: [
            TaskDraft(sourceMessageID: "placeholder", title: "Take out trash")
        ])
        let message = ChoreMessage(
            id: "message-real",
            threadID: "thread-real",
            authorMemberID: "me",
            body: "anything"
        )

        let drafts = await engine.extractTasks(from: message, participants: [], now: Date(timeIntervalSince1970: 44))

        XCTAssertEqual(drafts[0].threadID, "thread-real")
        XCTAssertEqual(drafts[0].sourceMessageID, "message-real")
        XCTAssertEqual(drafts[0].createdAt, Date(timeIntervalSince1970: 44))
    }

    func testVoiceMessageUsesSharedExtractionPath() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            voiceRecorder: FakeVoiceMessageRecorder(duration: 3),
            voiceTranscriber: FakeVoiceMessageTranscriber(transcript: "Sam please sweep the floor tomorrow"),
            voicePlayer: FakeVoiceMessagePlayer(),
            clock: FixedClock(now)
        )

        await state.startVoiceMessageRecording(in: "thread-dm-sam")
        await state.finishVoiceMessageRecording()

        XCTAssertEqual(
            state.messages(in: "thread-dm-sam").last(where: { $0.kind == .voice })?.body,
            "Sam please sweep the floor tomorrow"
        )
        XCTAssertTrue(state.chores.contains {
            $0.title == "Sweep the floor" && $0.threadID == "thread-dm-sam" && $0.assigneeID == "participant-sam"
        })
    }

    func testVoiceAttachmentMetadataRoundTripsThroughSnapshot() throws {
        let now = Date(timeIntervalSince1970: 123)
        var snapshot = ChoreSnapshot.seededForUITests(now: now)
        snapshot.messages.append(ChoreMessage(
            id: "voice-1",
            threadID: "thread-pine",
            authorMemberID: "participant-peyton",
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

    func testEmptyVoiceTranscriptReportsClearStatus() async {
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: .seededForUITests()),
            extractionEngine: RuleBasedTaskExtractionEngine(),
            voiceRecorder: FakeVoiceMessageRecorder(duration: 3),
            voiceTranscriber: FakeVoiceMessageTranscriber(transcript: "   "),
            voicePlayer: FakeVoiceMessagePlayer()
        )

        await state.startVoiceMessageRecording(in: "thread-dm-sam")
        await state.finishVoiceMessageRecording()

        XCTAssertFalse(state.messages(in: "thread-dm-sam").contains { $0.kind == .voice })
        XCTAssertEqual(state.lastStatusMessage, VoiceMessageError.emptyTranscript.localizedDescription)
    }

    func testVoiceDurationTextUsesMinutesWhenNeeded() {
        XCTAssertEqual(AppState.voiceDurationText(3), "3s")
        XCTAssertEqual(AppState.voiceDurationText(75), "1m 15s")
    }

    func testSwiftDataRepositoryRoundTripsConversationSnapshot() throws {
        let container = try WeChoreModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let repository = SwiftDataChoreRepository(context: ModelContext(container))
        let snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))

        try repository.saveSnapshot(snapshot)
        let loaded = try repository.loadSnapshot()

        XCTAssertEqual(loaded.threads.first?.title, "Pine Chat")
        XCTAssertEqual(loaded.participants.count, 2)
        XCTAssertEqual(loaded.chores.first?.threadID, "thread-pine")
    }

    func testSharedSnapshotStoreRoundTripsAndMigratesDraftAssignmentState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SharedSnapshotStore(appGroupIdentifier: nil, fallbackDirectory: directory)
        var snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        snapshot.suggestions.append(TaskDraft(
            threadID: "thread-pine",
            sourceMessageID: "message-draft",
            title: "Water plants",
            needsConfirmation: true,
            assignmentState: .needsAssignee,
            createdAt: Date(timeIntervalSince1970: 124)
        ))

        try store.saveSnapshot(snapshot)
        let loaded = try store.loadSnapshot()

        XCTAssertEqual(loaded.threads.count, 2)
        XCTAssertEqual(loaded.suggestions.first?.assignmentState, .needsAssignee)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.snapshotURL().path))
    }

    func testWidgetSnapshotMutatorCompletesTaskAndKeepsUndoMarker() {
        let now = Date(timeIntervalSince1970: 123)
        var snapshot = ChoreSnapshot.seededForUITests(now: now)

        let changed = WidgetSnapshotMutator.markTaskDone(
            taskID: "task-dishes",
            in: &snapshot,
            now: Date(timeIntervalSince1970: 200)
        )
        let summary = WidgetProjection.conversationSummaries(
            from: snapshot,
            now: Date(timeIntervalSince1970: 200)
        ).first { $0.id == "thread-pine" }

        XCTAssertTrue(changed)
        XCTAssertEqual(snapshot.chores.first { $0.id == "task-dishes" }?.status, .done)
        XCTAssertEqual(snapshot.taskActivities.last?.kind, .completed)
        XCTAssertEqual(snapshot.settings.recentlyCompletedTaskID, "task-dishes")
        XCTAssertEqual(summary?.activeTaskCount, 0)
        XCTAssertEqual(summary?.doneTaskCount, 1)
    }

    func testAppStateRefreshImportsWidgetCompletionFromSharedSnapshot() throws {
        let initial = Date(timeIntervalSince1970: 100)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sharedStore = SharedSnapshotStore(appGroupIdentifier: nil, fallbackDirectory: directory)
        let primary = InMemoryChoreRepository(snapshot: .seededForUITests(now: initial))
        let repository = CompositeChoreRepository(primary: primary, sharedStore: sharedStore)
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(initial)
        )
        var widgetSnapshot = ChoreSnapshot.seededForUITests(now: initial)
        WidgetSnapshotMutator.markTaskDone(
            taskID: "task-dishes",
            in: &widgetSnapshot,
            now: Date(timeIntervalSince1970: 250)
        )
        try sharedStore.saveSnapshot(widgetSnapshot)

        state.refreshFromSharedState()

        XCTAssertEqual(state.snapshot.chores.first { $0.id == "task-dishes" }?.status, .done)
        XCTAssertEqual(state.recentlyCompletedTaskID, "task-dishes")
        XCTAssertEqual(state.lastStatusMessage, "Load dishwasher is done.")
    }

    func testDeepLinksParseThreadsTasksAndExistingInvites() throws {
        XCTAssertEqual(
            WeChoreDeepLink(url: WeChoreDeepLink.thread("thread-pine").url(scheme: "wechore-dev")),
            .thread("thread-pine")
        )
        XCTAssertEqual(
            WeChoreDeepLink(url: WeChoreDeepLink.task("task-dishes").url()),
            .task("task-dishes")
        )
        let invite = InvitePayload(
            inviteID: "invite-1",
            threadID: "thread-pine",
            threadTitle: "Pine Chat",
            inviterParticipantID: "participant-peyton",
            code: "PINE123",
            expiresAt: Date(timeIntervalSince1970: 2_000)
        )
        XCTAssertEqual(WeChoreDeepLink(url: invite.appURL()), .join(invite))
    }

    func testUndoReopensRecentlyCompletedTask() {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        state.updateStatus(choreID: "task-dishes", status: .done)
        XCTAssertEqual(state.recentlyCompletedTaskID, "task-dishes")
        XCTAssertFalse(state.activeChores(in: "thread-pine").contains { $0.id == "task-dishes" })

        state.reopenRecentlyCompletedTask()

        XCTAssertNil(state.recentlyCompletedTaskID)
        XCTAssertTrue(state.activeChores(in: "thread-pine").contains { $0.id == "task-dishes" })
        XCTAssertEqual(state.snapshot.chores.first { $0.id == "task-dishes" }?.status, .open)
    }

    func testAddChoreRejectsInvalidThreadAndAssigneeIDs() {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        XCTAssertFalse(state.addChore(
            title: "Clean sink",
            assigneeID: "participant-missing",
            dueDate: nil,
            threadID: "thread-pine"
        ))
        XCTAssertFalse(state.addChore(
            title: "Clean sink",
            assigneeID: "participant-sam",
            dueDate: nil,
            threadID: "thread-missing"
        ))

        XCTAssertFalse(state.chores.contains { $0.title == "Clean sink" })
    }

    func testAddChoreRejectsDuplicateActiveTaskForSameThreadAndAssignee() {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        XCTAssertTrue(state.addChore(
            title: "Clean sink",
            assigneeID: "participant-sam",
            dueDate: nil,
            threadID: "thread-pine"
        ))
        XCTAssertFalse(state.addChore(
            title: "  clean   sink  ",
            assigneeID: "participant-sam",
            dueDate: nil,
            threadID: "thread-pine"
        ))

        XCTAssertEqual(state.chores.filter { $0.title == "Clean sink" }.count, 1)
    }

    func testExpiredInvitePayloadDoesNotOpenThread() {
        let now = Date(timeIntervalSince1970: 2_000)
        let repository = InMemoryChoreRepository(snapshot: .seededForUITests(now: now))
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )
        let expired = InvitePayload(
            inviteID: "invite-expired",
            threadID: "thread-new",
            threadTitle: "Old Chat",
            inviterParticipantID: "participant-peyton",
            code: "OLD123",
            expiresAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertNil(state.acceptInvite(expired))
        XCTAssertFalse(state.threads.contains { $0.id == "thread-new" })
        XCTAssertEqual(state.lastStatusMessage, "That invite has expired.")
    }

    func testCompositeRepositoryPropagatesSharedStoreSaveFailures() throws {
        let blockedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        _ = FileManager.default.createFile(atPath: blockedDirectory.path, contents: Data())
        let repository = CompositeChoreRepository(
            primary: InMemoryChoreRepository(snapshot: .seededForUITests()),
            sharedStore: SharedSnapshotStore(
                appGroupIdentifier: nil,
                fallbackDirectory: blockedDirectory
            )
        )

        XCTAssertThrowsError(try repository.saveSnapshot(.seededForUITests()))
    }

    func testCapturingReminderSchedulerReplacesDuplicatePlan() async throws {
        let scheduler = CapturingReminderScheduler()
        let first = ReminderPlan(
            identifier: "wechore.thread.thread-pine.task.task-1",
            title: "WeChore task",
            body: "Sam, check dishes.",
            fireDate: Date(timeIntervalSince1970: 1_000)
        )
        let second = ReminderPlan(
            identifier: first.identifier,
            title: first.title,
            body: "Sam, check dishes later.",
            fireDate: Date(timeIntervalSince1970: 2_000)
        )

        try await scheduler.schedule(plan: first)
        try await scheduler.schedule(plan: second)

        XCTAssertEqual(scheduler.scheduledPlans, [second])
    }

    func testBlankGroupAndDMCreationAreRejected() {
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: .seededForUITests()),
            extractionEngine: RuleBasedTaskExtractionEngine()
        )

        XCTAssertNil(state.createGroupChat(title: "   "))
        XCTAssertNil(state.startDM(displayName: "   "))

        XCTAssertFalse(state.threads.contains { $0.title == "New Group" })
        XCTAssertFalse(state.threads.contains { $0.kind == .dm && $0.participantIDs.count == 1 })
        XCTAssertEqual(state.lastStatusMessage, "Add a name before starting a DM.")
    }

    func testCreateGroupChatPreservesParticipantOrderAndReusesDuplicateTitle() {
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: .seededForUITests()),
            extractionEngine: RuleBasedTaskExtractionEngine()
        )

        let threadID = state.createGroupChat(title: "School", participantIDs: [
            "participant-sam",
            "participant-peyton",
            "participant-sam"
        ])
        let duplicateID = state.createGroupChat(title: "school")
        let thread = state.thread(for: threadID ?? "")

        XCTAssertEqual(thread?.participantIDs, ["participant-peyton", "participant-sam"])
        XCTAssertEqual(duplicateID, threadID)
    }

    func testInviteCodeAcceptsPastedSeparatorsAndCreateInviteReusesActiveInvite() {
        let now = Date(timeIntervalSince1970: 1_000)
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: .seededForUITests(now: now)),
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        let first = state.createInvite(for: "thread-pine")
        let second = state.createInvite(for: "thread-pine")
        let opened = state.acceptInviteCode(" pine-123 ")

        XCTAssertEqual(first, second)
        XCTAssertEqual(opened, "thread-pine")
        XCTAssertEqual(state.snapshot.invites.filter { $0.threadID == "thread-pine" }.count, 1)
    }

    func testDuplicateExtractedDMTaskDoesNotCreateSecondChore() async {
        let now = Date(timeIntervalSince1970: 1_000)
        var snapshot = ChoreSnapshot.seededForUITests(now: now)
        snapshot.chores.append(Chore(
            id: "task-dm-clean",
            threadID: "thread-dm-sam",
            title: "Clean bathroom",
            createdByMemberID: "participant-peyton",
            assigneeID: "participant-sam",
            createdAt: now,
            updatedAt: now
        ))
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: snapshot),
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        await state.postMessage("Please clean bathroom tomorrow", in: "thread-dm-sam")

        XCTAssertEqual(
            state.chores.filter { $0.threadID == "thread-dm-sam" && $0.title == "Clean bathroom" }.count,
            1
        )
        XCTAssertEqual(state.lastStatusMessage, "Clean bathroom is already active.")
    }

    func testSelfAssignmentInDMStaysAssignedToCurrentParticipant() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: .seededForUITests(now: now)),
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        await state.postMessage("I'll clean bathroom tomorrow", in: "thread-dm-sam")

        let chore = state.chores.first { $0.threadID == "thread-dm-sam" && $0.title == "Clean bathroom" }
        XCTAssertEqual(chore?.assigneeID, "participant-peyton")
    }

    func testRelativeDueDatesResolveToEndOfDay() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let calendar = Calendar.current
        let sam = ChatParticipant(id: "participant-sam", displayName: "Sam")
        let message = ChoreMessage(
            id: "message-1",
            threadID: "thread-1",
            authorMemberID: "participant-me",
            body: "Sam please unload dishwasher today"
        )

        let drafts = await RuleBasedTaskExtractionEngine().extractTasks(
            from: message,
            participants: [sam],
            now: now
        )
        let draft = try XCTUnwrap(drafts.first)
        let expected = try XCTUnwrap(calendar.date(
            byAdding: .second,
            value: -1,
            to: try XCTUnwrap(calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ))
        ))

        XCTAssertEqual(draft.dueDate, expected)
    }

    func testReminderIsNotScheduledForCompletedTask() async {
        let scheduler = CapturingReminderScheduler()
        var snapshot = ChoreSnapshot.seededForUITests()
        snapshot.chores[0].status = .done
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: snapshot),
            extractionEngine: RuleBasedTaskExtractionEngine(),
            reminderScheduler: scheduler
        )

        await state.scheduleReminder(for: state.chores[0])

        XCTAssertTrue(scheduler.scheduledPlans.isEmpty)
        XCTAssertEqual(state.lastStatusMessage, "Only active tasks can be reminded.")
    }

    func testDeniedReminderAuthorizationMarksTaskFailed() async {
        let scheduler = DenyingReminderScheduler()
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: .seededForUITests()),
            extractionEngine: RuleBasedTaskExtractionEngine(),
            reminderScheduler: scheduler
        )

        await state.scheduleReminder(for: state.chores[0])

        XCTAssertTrue(scheduler.scheduledPlans.isEmpty)
        XCTAssertEqual(state.snapshot.chores[0].notificationState, .failed)
        XCTAssertEqual(state.lastStatusMessage, "Notifications are not allowed yet.")
    }

    func testCurrentParticipantProfileCanBeUpdated() {
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: .seededForUITests()),
            extractionEngine: RuleBasedTaskExtractionEngine()
        )

        XCTAssertTrue(state.updateCurrentParticipant(displayName: "Peyton R", contact: "(555) 123-9999"))

        XCTAssertEqual(state.currentParticipant.displayName, "Peyton R")
        XCTAssertEqual(state.currentParticipant.phoneNumber, "5551239999")
        XCTAssertNil(state.currentParticipant.faceTimeHandle)
    }

    func testTaskDetailsCanBeUpdatedWithoutCreatingDuplicateActiveTask() {
        let now = Date(timeIntervalSince1970: 1_000)
        var snapshot = ChoreSnapshot.seededForUITests(now: now)
        snapshot.chores.append(Chore(
            id: "task-clean",
            threadID: "thread-pine",
            title: "Clean sink",
            createdByMemberID: "participant-peyton",
            assigneeID: "participant-sam",
            createdAt: now,
            updatedAt: now
        ))
        let state = AppState(
            repository: InMemoryChoreRepository(snapshot: snapshot),
            extractionEngine: RuleBasedTaskExtractionEngine(),
            clock: FixedClock(now)
        )

        XCTAssertFalse(state.updateChore(
            choreID: "task-clean",
            title: "Load dishwasher",
            assigneeID: "participant-sam",
            dueDate: nil,
            notes: "duplicate"
        ))
        XCTAssertTrue(state.updateChore(
            choreID: "task-clean",
            title: "Clean sink",
            assigneeID: "participant-peyton",
            dueDate: Date(timeIntervalSince1970: 2_000),
            notes: "Use the small brush"
        ))

        let updated = state.snapshot.chores.first { $0.id == "task-clean" }
        XCTAssertEqual(updated?.assigneeID, "participant-peyton")
        XCTAssertEqual(updated?.notes, "Use the small brush")
        XCTAssertEqual(updated?.dueDate, Date(timeIntervalSince1970: 2_000))
    }

    func testSaveFailureRestoresPersistedSnapshotAndReportsFailure() {
        let repository = FailingSaveRepository(snapshot: .seededForUITests())
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine()
        )

        XCTAssertFalse(state.addChore(
            title: "Clean sink",
            assigneeID: "participant-sam",
            dueDate: nil,
            threadID: "thread-pine"
        ))

        XCTAssertFalse(state.chores.contains { $0.title == "Clean sink" })
        XCTAssertEqual(state.lastStatusMessage, "WeChore could not save the latest change.")
    }

    func testStartDMStopsWhenNewParticipantCannotBeSaved() {
        let snapshot = ChoreSnapshot.seededForUITests()
        let repository = FailingSaveRepository(snapshot: snapshot)
        let state = AppState(
            repository: repository,
            extractionEngine: RuleBasedTaskExtractionEngine()
        )

        XCTAssertNil(state.startDM(displayName: "Jordan"))

        XCTAssertEqual(state.snapshot.participants, snapshot.participants)
        XCTAssertEqual(state.snapshot.threads, snapshot.threads)
        XCTAssertEqual(state.lastStatusMessage, "WeChore could not save the latest change.")
    }

    func testSnapshotNormalizationRepairsOrphanReferences() {
        var snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        snapshot.settings.selectedParticipantID = "missing"
        snapshot.threads[0].participantIDs = ["participant-sam", "missing", "participant-sam"]
        snapshot.chores[0].threadID = "missing-thread"
        snapshot.chores[0].assigneeID = "missing-person"
        snapshot.messages.append(ChoreMessage(
            threadID: "missing-thread",
            authorMemberID: "missing-person",
            body: "hello"
        ))
        snapshot.suggestions.append(TaskDraft(
            threadID: "missing-thread",
            sourceMessageID: "message-1",
            title: "Water plants",
            assigneeID: "missing-person"
        ))

        snapshot.normalizeConversationState(now: Date(timeIntervalSince1970: 123))

        XCTAssertEqual(snapshot.settings.selectedParticipantID, "participant-peyton")
        XCTAssertEqual(snapshot.threads[0].participantIDs, ["participant-peyton", "participant-sam"])
        XCTAssertEqual(snapshot.chores[0].threadID, "thread-pine")
        XCTAssertEqual(snapshot.chores[0].assigneeID, "participant-peyton")
        XCTAssertEqual(snapshot.messages.last?.threadID, "thread-pine")
        XCTAssertEqual(snapshot.messages.last?.authorMemberID, "participant-peyton")
        XCTAssertNil(snapshot.suggestions.last?.assigneeID)
        XCTAssertEqual(snapshot.suggestions.last?.assignmentState, .needsAssignee)
    }

    func testWidgetMetadataDeclaresTargetsFamiliesAndAppIntents() throws {
        let appRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(
            contentsOf: appRoot.appendingPathComponent("Project.swift"),
            encoding: .utf8
        )
        let widgetSource = try String(
            contentsOf: appRoot.appendingPathComponent("WidgetExtension/Sources/WeChoreWidgets.swift"),
            encoding: .utf8
        )
        let entitlements = try String(
            contentsOf: appRoot.appendingPathComponent("WidgetExtension/WeChoreWidget.entitlements"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("WeChoreWidgetsExtension"))
        XCTAssertTrue(project.contains("WeChoreDevWidgetsExtension"))
        XCTAssertTrue(project.contains("product: .appExtension"))
        XCTAssertTrue(project.contains("WidgetExtension/WeChoreWidget.entitlements"))
        XCTAssertTrue(entitlements.contains("$(WECHORE_APP_GROUP_ID)"))
        XCTAssertTrue(widgetSource.contains("import WidgetKit"))
        XCTAssertTrue(widgetSource.contains("import AppIntents"))
        XCTAssertTrue(widgetSource.contains("MarkTaskDoneIntent"))
        XCTAssertTrue(widgetSource.contains("OpenConversationIntent"))
        XCTAssertTrue(widgetSource.contains("OpenTaskIntent"))
        for family in [
            ".systemSmall",
            ".systemMedium",
            ".systemLarge",
            ".systemExtraLarge",
            ".accessoryInline",
            ".accessoryCircular",
            ".accessoryRectangular"
        ] {
            XCTAssertTrue(widgetSource.contains(family), "Missing widget family \(family)")
        }
    }

    func testCloudKitRecordNamesAreDeterministicForConversations() {
        let snapshot = ChoreSnapshot.seededForUITests(now: Date(timeIntervalSince1970: 123))
        let store = CloudKitConversationStore(database: FakeCloudKitDatabaseClient())

        let names = store.records(for: snapshot).map(\.recordID.recordName)

        XCTAssertTrue(names.contains("ChatThread.thread-pine"))
        XCTAssertTrue(names.contains("ChatParticipant.participant-peyton"))
        XCTAssertTrue(names.contains("Chore.task-dishes"))
        XCTAssertTrue(names.contains("ThreadInvite.invite-pine"))
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

@MainActor
private final class DenyingReminderScheduler: ReminderScheduling {
    private(set) var scheduledPlans: [ReminderPlan] = []

    func requestAuthorization() async throws -> Bool {
        false
    }

    func schedule(plan: ReminderPlan) async throws {
        scheduledPlans.append(plan)
    }
}

@MainActor
private final class FailingSaveRepository: ChoreRepository {
    private let snapshot: ChoreSnapshot

    init(snapshot: ChoreSnapshot) {
        self.snapshot = snapshot
    }

    func loadSnapshot() throws -> ChoreSnapshot {
        snapshot
    }

    func saveSnapshot(_ snapshot: ChoreSnapshot) throws {
        throw NSError(domain: "FailingSaveRepository", code: 1)
    }
}
