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

        XCTAssertTrue(waitForChats(in: app, timeout: 5))
        XCTAssertTrue(app.staticTexts["Pine House"].waitForExistence(timeout: 5))
    }

    func testFreshSeededLaunchOpensChats() {
        let app = seededApp()

        XCTAssertTrue(waitForChats(in: app, timeout: 10))
        XCTAssertTrue(element("message.more", in: app).exists)
    }

    func testCreateProgressAndReminderFlow() {
        let app = seededApp(route: "chores")

        let title = app.textFields["chore.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Take out trash")
        app.buttons["chore.add"].tap()

        XCTAssertTrue(app.staticTexts["Take out trash"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.start.")).firstMatch.tap()
        let inProgressStatus = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "in progress")
        ).firstMatch
        XCTAssertTrue(inProgressStatus.waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.remind.")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Reminder scheduled for Sam."].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chore.done.")).firstMatch.tap()
        let doneStatus = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "done")
        ).firstMatch
        XCTAssertTrue(doneStatus.waitForExistence(timeout: 5))
    }

    func testChatMessageSuggestionAcceptanceCreatesChore() {
        let app = seededApp()

        let input = element("message.input", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("Sam please unload dishwasher tomorrow")
        element("message.post", in: app).tap()

        XCTAssertTrue(app.staticTexts["Unload dishwasher"].waitForExistence(timeout: 5))
        element(matchingIdentifierPrefix: "suggestion.accept.", in: app).tap()

        openRoute("Chores", in: app)
        XCTAssertTrue(app.staticTexts["Unload dishwasher"].waitForExistence(timeout: 5))
    }

    func testFakeVoiceRecordingCreatesPlayableSuggestion() {
        let app = seededApp(fakeVoiceTranscript: "Sam please sweep the floor tomorrow")

        XCTAssertTrue(waitForChats(in: app, timeout: 10))
        element("message.voiceMode", in: app).tap()
        let voiceHold = element("message.voiceHold", in: app)
        XCTAssertTrue(voiceHold.waitForExistence(timeout: 5))

        voiceHold.press(forDuration: 0.6)

        let playButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "voice.play.")
        ).firstMatch
        let transcript = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Transcript: Sam please sweep")
        ).firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        XCTAssertTrue(transcript.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sweep the floor"].waitForExistence(timeout: 5))
        element(matchingIdentifierPrefix: "suggestion.accept.", in: app).tap()

        openRoute("Chores", in: app)
        XCTAssertTrue(app.staticTexts["Sweep the floor"].waitForExistence(timeout: 5))
    }

    func testAssignedChoresAreReachableFromChat() {
        let app = seededApp(member: "Sam")

        XCTAssertTrue(waitForChats(in: app, timeout: 10))
        XCTAssertTrue(app.staticTexts["Load dishwasher"].waitForExistence(timeout: 5))
        element("chat.assignedChores.open", in: app).tap()

        XCTAssertTrue(app.staticTexts["Load dishwasher"].waitForExistence(timeout: 5))
    }

    func testVoiceAndTextReminderActionsExposeSystemHandoffs() {
        let app = seededApp(route: "chores")

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

        openRoute("Me", in: app)

        XCTAssertTrue(app.staticTexts["Apple-only sync"].waitForExistence(timeout: 5))
    }

    func testLargeTextKeepsChoreActionsReachable() {
        let app = seededApp(route: "chores", member: "Sam", largeText: true)

        XCTAssertTrue(app.staticTexts["Load dishwasher"].waitForExistence(timeout: 10))
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(element(matchingIdentifierPrefix: "chore.start.", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(matchingIdentifierPrefix: "chore.message.", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(matchingIdentifierPrefix: "chore.voice.", in: app).waitForExistence(timeout: 5))
    }

    private func seededApp(
        route: String? = nil,
        member: String? = nil,
        largeText: Bool = false,
        fakeVoiceTranscript: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_SEED_HOUSEHOLD",
            "UITEST_SEED_CHORES",
            "UITEST_DISABLE_CLOUDKIT"
        ]
        if let route {
            arguments.append("UITEST_ROUTE=\(route)")
        }
        if let member {
            arguments.append("UITEST_MEMBER=\(member)")
        }
        if largeText {
            arguments.append("UITEST_LARGE_TEXT")
        }
        if let fakeVoiceTranscript {
            arguments.append("UITEST_FAKE_VOICE_TRANSCRIPT=\(fakeVoiceTranscript)")
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func openRoute(_ title: String, in app: XCUIApplication) {
        if app.tabBars.buttons[title].exists {
            app.tabBars.buttons[title].tap()
        } else if app.collectionViews.buttons[title].exists {
            app.collectionViews.buttons[title].tap()
        } else {
            app.buttons[title].tap()
        }
    }

    private func waitForChats(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        element("message.voiceMode", in: app).waitForExistence(timeout: timeout)
            && app.staticTexts["Pine House"].waitForExistence(timeout: 2)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func element(matchingIdentifierPrefix prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

}
