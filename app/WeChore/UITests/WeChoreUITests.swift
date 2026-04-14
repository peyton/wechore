import XCTest

@MainActor
final class WeChoreUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingCreatesFirstGroupChat() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_MODE"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Chats first. Tasks follow."].waitForExistence(timeout: 10))
        element("onboarding.next", in: app).tap()
        XCTAssertTrue(element("onboarding.option.nearby", in: app).waitForExistence(timeout: 5))
        element("onboarding.next", in: app).tap()

        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Peyton")

        let chatName = app.textFields["onboarding.chatName"]
        chatName.tap()
        chatName.typeText("Pine Chat")

        let contact = app.textFields["onboarding.contact"]
        contact.tap()
        contact.typeText("peyton@example.com")

        app.buttons["onboarding.start"].tap()

        XCTAssertTrue(waitForChatTree(in: app, timeout: 5))
        XCTAssertTrue(chatTreeLabel("Pine Chat", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testFreshSeededLaunchOpensChatTreeWithoutTabBar() {
        let app = seededApp()

        XCTAssertTrue(waitForChatTree(in: app, timeout: 10))
        XCTAssertTrue(chatTreeThread("thread-pine", title: "Pine Chat", in: app).exists)
        XCTAssertTrue(chatTreeAction("chatTree.tasks", title: "Tasks", in: app).exists)
        XCTAssertTrue(chatTreeAction("chatTree.joinStart", title: "Join or Start", in: app).exists)
        XCTAssertTrue(chatTreeAction("chatTree.myQR", title: "My QR", in: app).exists)
        XCTAssertTrue(chatTreeAction("chatTree.me", title: "Me", in: app).exists)
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testStartGroupChatDMInviteCodeAndNearbyJoinReachConversation() {
        let groupApp = seededApp(route: "join")
        XCTAssertTrue(element("join.scanQR", in: groupApp).waitForExistence(timeout: 10))
        XCTAssertTrue(startGroupChat(in: groupApp, title: "Soccer Carpool"))
        XCTAssertTrue(groupApp.staticTexts["Soccer Carpool"].waitForExistence(timeout: 5))

        let dmApp = seededApp(route: "join")
        XCTAssertTrue(startDM(in: dmApp, name: "Taylor", contact: "taylor@example.com"))
        XCTAssertTrue(dmApp.staticTexts["Taylor"].waitForExistence(timeout: 5))

        let codeApp = seededApp(route: "join")
        XCTAssertTrue(joinByCode(in: codeApp, code: "PINE123"))
        XCTAssertTrue(codeApp.staticTexts["Pine Chat"].waitForExistence(timeout: 5))

        let nearbyApp = seededApp(route: "join")
        let nearby = element("join.nearby", in: nearbyApp)
        XCTAssertTrue(nearby.waitForExistence(timeout: 10))
        nearby.tap()
        XCTAssertTrue(nearbyApp.staticTexts["Nearby Chat"].waitForExistence(timeout: 5))
    }

    func testMyQRCodeIsReachableFromChatTree() {
        let app = seededApp()
        XCTAssertTrue(waitForChatTree(in: app, timeout: 10))

        chatTreeAction("chatTree.myQR", title: "My QR", in: app).tap()

        XCTAssertTrue(app.staticTexts["My QR"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("invite.qr", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("invite.qrShare", in: app).exists)
    }

    func testTypingClearAndAmbiguousRequestsPopulateTaskTile() {
        let app = seededApp(route: "group")
        XCTAssertTrue(waitForConversation(in: app, timeout: 10))

        sendMessage("Sam please unload dishwasher tomorrow", in: app)
        XCTAssertTrue(app.staticTexts["Unload dishwasher"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Who should do this?"].waitForExistence(timeout: 5))
        element("taskDraft.assignee.participant-sam", in: app).tap()
        XCTAssertTrue(app.staticTexts["Sam was assigned Unload dishwasher."].waitForExistence(timeout: 5))

        sendMessage("Please clean bathroom tomorrow", in: app)
        XCTAssertTrue(app.staticTexts["Clean bathroom"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Who should do this?"].waitForExistence(timeout: 5))
        element("taskDraft.assignee.participant-sam", in: app).tap()
        XCTAssertTrue(app.staticTexts["Sam was assigned Clean bathroom."].waitForExistence(timeout: 5))
    }

    func testDMSendsTaskToRecipientWithoutNamingThem() {
        let app = seededApp(route: "dm")
        XCTAssertTrue(waitForConversation(in: app, timeout: 10))

        sendMessage("Please clean bathroom tomorrow", in: app)

        XCTAssertTrue(app.staticTexts["Clean bathroom"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sam was assigned Clean bathroom."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Who should do this?"].exists)
    }

    func testFakeVoiceTranscriptCreatesTaskInFloatingTile() {
        let app = seededApp(
            route: "dm",
            fakeVoiceTranscript: "Sam please sweep the floor tomorrow"
        )
        XCTAssertTrue(waitForConversation(in: app, timeout: 10))

        element("message.voiceMode", in: app).tap()
        let voiceRecord = element("message.voiceRecord", in: app)
        XCTAssertTrue(voiceRecord.waitForExistence(timeout: 5))
        voiceRecord.tap()
        XCTAssertTrue(element("message.voiceCancel", in: app).waitForExistence(timeout: 5))
        voiceRecord.tap()

        XCTAssertTrue(element(matchingIdentifierPrefix: "voice.play.", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sweep the floor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Transcript: Sam please sweep")
        ).firstMatch.waitForExistence(timeout: 5))
    }

    func testMarkingTileTaskDonePostsThreadActivity() {
        let app = seededApp(route: "group")
        XCTAssertTrue(waitForConversation(in: app, timeout: 10))

        let done = element("taskTile.done.task-dishes", in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        XCTAssertTrue(app.staticTexts["Load dishwasher is done."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sam completed Load dishwasher."].waitForExistence(timeout: 5))
        XCTAssertTrue(element("status.undo", in: app).waitForExistence(timeout: 5))
    }

    func testMeAndSettingsAreReachableFromTree() {
        let app = seededApp()
        XCTAssertTrue(waitForChatTree(in: app, timeout: 10))

        chatTreeAction("chatTree.me", title: "Me", in: app).tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Apple-only sync"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My QR"].exists)
        XCTAssertTrue(app.staticTexts["Widget Favorites"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.widgetFavorite.thread-pine", in: app).exists)
    }

    func testTasksViewIsReachableFromTree() {
        let app = seededApp()
        XCTAssertTrue(waitForChatTree(in: app, timeout: 10))

        chatTreeAction("chatTree.tasks", title: "Tasks", in: app).tap()

        XCTAssertTrue(app.staticTexts["Tasks"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("chore.row.task-dishes.title", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("tasks.scope", in: app).exists)
    }

    func testLargeTextKeepsTaskTileComposerAndJoinActionsUsable() {
        let app = seededApp(route: "group", participant: "Sam", largeText: true)

        XCTAssertTrue(waitForConversation(in: app, timeout: 10))
        XCTAssertTrue(element("taskTile", in: app).exists)
        XCTAssertTrue(element("message.input", in: app).exists)
        XCTAssertTrue(element("message.more", in: app).exists)
        XCTAssertTrue(app.buttons["Remind"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertTrue(element("taskTile.done.task-dishes", in: app).waitForExistence(timeout: 5))
    }

    func testOpeningConversationDoesNotCreateInviteToast() {
        let app = seededApp(route: "group")

        XCTAssertTrue(waitForConversation(in: app, timeout: 10))
        XCTAssertFalse(app.staticTexts["Invite ready for Pine Chat."].exists)
        XCTAssertTrue(element("conversation.createInvite", in: app).waitForExistence(timeout: 5))

        element("conversation.createInvite", in: app).tap()

        XCTAssertTrue(app.staticTexts["Invite ready for Pine Chat."].waitForExistence(timeout: 5))
        XCTAssertTrue(element("conversation.shareInvite", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("conversation.showInviteQR", in: app).waitForExistence(timeout: 5))
        element("conversation.showInviteQR", in: app).tap()
        XCTAssertTrue(element("invite.qr", in: app).waitForExistence(timeout: 5))
    }

    private func seededApp(
        route: String? = nil,
        participant: String? = nil,
        largeText: Bool = false,
        fakeVoiceTranscript: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_SEED_CONVERSATION",
            "UITEST_SEED_CHORES",
            "UITEST_DISABLE_CLOUDKIT"
        ]
        if let route {
            arguments.append("UITEST_ROUTE=\(route)")
        }
        if let participant {
            arguments.append("UITEST_PARTICIPANT=\(participant)")
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

    private func sendMessage(_ message: String, in app: XCUIApplication) {
        let input = element("message.input", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(message)
        element("message.post", in: app).tap()
    }

    private func startGroupChat(in app: XCUIApplication, title: String) -> Bool {
        let field = app.textFields["join.groupTitle"]
        guard field.waitForExistence(timeout: 10) else { return false }
        field.tap()
        field.typeText(title)
        element("join.startGroup", in: app).tap()
        return waitForConversation(in: app, timeout: 5)
    }

    private func startDM(in app: XCUIApplication, name: String, contact: String) -> Bool {
        let nameField = app.textFields["join.dmName"]
        guard nameField.waitForExistence(timeout: 10) else { return false }
        nameField.tap()
        nameField.typeText(name)
        let contactField = app.textFields["join.dmContact"]
        contactField.tap()
        contactField.typeText(contact)
        element("join.startDM", in: app).tap()
        return waitForConversation(in: app, timeout: 5)
    }

    private func joinByCode(in app: XCUIApplication, code: String) -> Bool {
        let field = app.textFields["join.inviteCode"]
        guard field.waitForExistence(timeout: 10) else { return false }
        field.tap()
        field.typeText(code)
        element("join.code", in: app).tap()
        return waitForConversation(in: app, timeout: 5)
    }

    private func waitForChatTree(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let join = chatTreeAction("chatTree.joinStart", title: "Join or Start", in: app)
            let me = chatTreeAction("chatTree.me", title: "Me", in: app)
            if element("chat.tree", in: app).exists || (join.exists && me.exists) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    private func waitForConversation(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        element("taskTile", in: app).waitForExistence(timeout: timeout)
            && element("message.input", in: app).waitForExistence(timeout: 2)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func element(matchingIdentifierPrefix prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    private func chatTreeThread(_ identifier: String, title: String, in app: XCUIApplication) -> XCUIElement {
        let identified = element("chat.thread.\(identifier)", in: app)
        return identified.exists ? identified : chatTreeLabel(title, in: app)
    }

    private func chatTreeAction(_ identifier: String, title: String, in app: XCUIApplication) -> XCUIElement {
        let identified = element(identifier, in: app)
        if identified.exists {
            return identified
        }
        let button = app.buttons[title]
        return button.exists ? button : chatTreeLabel(title, in: app)
    }

    private func chatTreeLabel(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(identifier: title).firstMatch
    }
}
