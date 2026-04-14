import XCTest

final class WeChoreUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingCreatesHousehold() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_MODE"]
        app.launch()

        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Peyton")

        let household = app.textFields["onboarding.household"]
        household.tap()
        household.typeText("Pine House")

        let contact = app.textFields["onboarding.contact"]
        contact.tap()
        contact.typeText("peyton@example.com")

        app.buttons["onboarding.start"].tap()

        XCTAssertTrue(app.staticTexts["Pine House"].waitForExistence(timeout: 5))
    }

    func testCreateProgressAndReminderFlow() {
        let app = seededApp()

        let title = app.textFields["chore.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Take out trash")
        app.buttons["chore.add"].tap()

        XCTAssertTrue(app.staticTexts["Take out trash"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.start.")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "in progress")).firstMatch.waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.remind.")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Reminder scheduled for Sam."].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.done.")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "done")).firstMatch.waitForExistence(timeout: 5))
    }

    func testMessageSuggestionAcceptanceCreatesChore() {
        let app = seededApp(route: "messages")

        let input = app.textFields["message.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("Sam please unload dishwasher tomorrow")
        app.buttons["message.post"].tap()

        XCTAssertTrue(app.staticTexts["Unload dishwasher"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "suggestion.accept.")).firstMatch.tap()

        if app.tabBars.buttons["Chores"].exists {
            app.tabBars.buttons["Chores"].tap()
        } else {
            app.collectionViews.buttons["Chores"].tap()
        }
        XCTAssertTrue(app.staticTexts["Unload dishwasher"].waitForExistence(timeout: 5))
    }

    func testVoiceAndTextReminderActionsExposeSystemHandoffs() {
        let app = seededApp()

        XCTAssertTrue(app.staticTexts["Load dishwasher"].waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.voice.")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Opened voice handoff for Sam."].waitForExistence(timeout: 5))

        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.message.")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Prepared Messages reminder for Sam."].waitForExistence(timeout: 5))
    }

    func testHouseholdAndSettingsRoutesAreReachableOnPhoneAndIPad() {
        let app = seededApp(route: "household")

        XCTAssertTrue(
            app.staticTexts["Pine House"].waitForExistence(timeout: 10)
                || app.otherElements["root.sidebar"].waitForExistence(timeout: 10)
        )

        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
        } else {
            app.collectionViews.buttons["Settings"].tap()
        }

        XCTAssertTrue(app.staticTexts["Apple-only sync"].waitForExistence(timeout: 5))
    }

    private func seededApp(route: String = "chores") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_SEED_HOUSEHOLD",
            "UITEST_SEED_CHORES",
            "UITEST_DISABLE_CLOUDKIT",
            "UITEST_ROUTE=\(route)"
        ]
        app.launch()
        return app
    }
}
