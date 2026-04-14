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
}
