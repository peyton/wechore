import XCTest

@MainActor
final class WeChoreUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSingleScreenOnboardingStartsChatAndLandsInConversation() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_MODE"]
        app.launch()

        let name = app.textFields["onboarding.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Peyton")

        let chatName = app.textFields["onboarding.chatName"]
        XCTAssertTrue(chatName.waitForExistence(timeout: 5))
        chatName.tap()
        chatName.typeText("Pine Chat")

        element("onboarding.startChat", in: app).tap()

        XCTAssertTrue(waitForConversation(in: app, timeout: 8))
        XCTAssertTrue(element("conversation.title", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testChatTreeShowsOnlyCoreDestinations() {
        let app = seededApp()

        XCTAssertTrue(waitForChatTree(in: app, timeout: 10))
        XCTAssertTrue(chatTreeAction("chatTree.taskInbox", title: "Task Inbox", in: app).exists)
        XCTAssertTrue(chatTreeAction("chatTree.me", title: "Me", in: app).exists)
        XCTAssertTrue(element("chatTree.newChat", in: app).exists)
        XCTAssertFalse(chatTreeAction("chatTree.joinStart", title: "Join or Start", in: app).exists)
        XCTAssertFalse(chatTreeAction("chatTree.myQR", title: "My QR", in: app).exists)
    }

    func testNewChatModalCanStartGroupDMAndJoinCode() {
        let groupApp = seededApp(route: "join")
        XCTAssertTrue(groupApp.staticTexts["New Chat"].waitForExistence(timeout: 10))
        let groupTitle = element("newChat.groupTitle", in: groupApp)
        XCTAssertTrue(groupTitle.waitForExistence(timeout: 5))
        groupTitle.tap()
        groupTitle.typeText("Soccer Carpool")
        element("newChat.startGroup", in: groupApp).tap()
        XCTAssertTrue(waitForConversation(in: groupApp, timeout: 8))
        XCTAssertTrue(groupApp.staticTexts["Soccer Carpool"].waitForExistence(timeout: 5))

        let dmApp = seededApp(route: "join")
        XCTAssertTrue(dmApp.staticTexts["New Chat"].waitForExistence(timeout: 10))
        selectNewChatMode("Start DM", in: dmApp)
        let dmName = element("newChat.dmName", in: dmApp)
        XCTAssertTrue(dmName.waitForExistence(timeout: 5))
        dmName.tap()
        dmName.typeText("Taylor")
        let dmContact = element("newChat.dmContact", in: dmApp)
        dmContact.tap()
        dmContact.typeText("taylor@example.com")
        element("newChat.startDM", in: dmApp).tap()
        XCTAssertTrue(waitForConversation(in: dmApp, timeout: 8))
        XCTAssertTrue(dmApp.staticTexts["Taylor"].waitForExistence(timeout: 5))

        let joinApp = seededApp(route: "join")
        XCTAssertTrue(joinApp.staticTexts["New Chat"].waitForExistence(timeout: 10))
        selectNewChatMode("Join", in: joinApp)
        let inviteCode = element("newChat.inviteCode", in: joinApp)
        XCTAssertTrue(inviteCode.waitForExistence(timeout: 5))
        inviteCode.tap()
        inviteCode.typeText("PINE123")
        element("newChat.joinCode", in: joinApp).tap()
        XCTAssertTrue(waitForConversation(in: joinApp, timeout: 8))
        XCTAssertTrue(joinApp.staticTexts["Pine Chat"].waitForExistence(timeout: 5))
    }

    func testTypingClearAndAmbiguousRequestsPopulateTaskRail() {
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
    }

    func testTaskInboxDeepLinksToSourceChat() {
        let app = seededApp(route: "tasks")

        XCTAssertTrue(element("taskInbox.title", in: app).waitForExistence(timeout: 10))
        guard let taskRow = findTaskInboxTask(title: "Load dishwasher", id: "task-dishes", in: app, timeout: 6) else {
            XCTFail("Expected seeded task to appear in Task Inbox")
            return
        }
        taskRow.tap()

        XCTAssertTrue(waitForConversation(in: app, timeout: 8))
        XCTAssertTrue(app.staticTexts["Pine Chat"].waitForExistence(timeout: 5))
    }

    func testTaskCompletionInConversationUpdatesTaskInbox() {
        let app = seededApp(route: "group")
        XCTAssertTrue(waitForConversation(in: app, timeout: 10))

        let done = element("taskTile.done.task-dishes", in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.staticTexts["Load dishwasher is done."].waitForExistence(timeout: 5))

        returnToChatTree(in: app)
        chatTreeAction("chatTree.taskInbox", title: "Task Inbox", in: app).tap()

        let summary = element("taskInbox.summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("1 done"))
        XCTAssertNotNil(findTaskInboxTask(title: "Load dishwasher", id: "task-dishes", in: app, timeout: 6))
    }

    func testInviteFlowIsHeaderOnlyAndShowsSingleSheet() {
        let app = seededApp(route: "group")
        XCTAssertTrue(waitForConversation(in: app, timeout: 10))

        XCTAssertTrue(element("conversation.invite", in: app).waitForExistence(timeout: 5))

        element("message.more", in: app).tap()
        XCTAssertTrue(element("chat.action.newTask", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("chat.action.invite", in: app).exists)
        element("message.more", in: app).tap()

        element("conversation.invite", in: app).tap()
        XCTAssertTrue(element("invite.qr", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("invite.qrCodeText", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("invite.qrShare", in: app).waitForExistence(timeout: 5))
    }

    func testManualTaskEntryFromComposerAddsTaskToRail() {
        let app = seededApp(route: "group")
        XCTAssertTrue(waitForConversation(in: app, timeout: 10))

        element("message.more", in: app).tap()
        let title = element("chat.manualTask.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Mop floor")

        element("chat.manualTask.save", in: app).tap()

        XCTAssertTrue(app.staticTexts["Mop floor"].waitForExistence(timeout: 5))
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

    private func selectNewChatMode(_ mode: String, in app: XCUIApplication) {
        let button = app.segmentedControls.buttons[mode]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func returnToChatTree(in app: XCUIApplication) {
        let explicitBack = app.navigationBars.buttons["Chats"]
        if explicitBack.waitForExistence(timeout: 2) {
            explicitBack.tap()
        }
    }

    private func waitForChatTree(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let taskInbox = chatTreeAction("chatTree.taskInbox", title: "Task Inbox", in: app)
            let me = chatTreeAction("chatTree.me", title: "Me", in: app)
            if element("chat.tree", in: app).exists || (taskInbox.exists && me.exists) {
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

    private func findTaskInboxTask(
        title: String,
        id: String,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let row = element("taskInbox.row.\(id)", in: app)
            if row.exists {
                return row
            }
            let rowTitle = element("taskInbox.row.\(id).title", in: app)
            if rowTitle.exists {
                return rowTitle
            }
            let titleText = app.staticTexts[title]
            if titleText.exists {
                return titleText
            }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return nil
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func chatTreeAction(_ identifier: String, title: String, in app: XCUIApplication) -> XCUIElement {
        let identified = element(identifier, in: app)
        if identified.exists {
            return identified
        }
        let button = app.buttons[title]
        return button.exists ? button : app.staticTexts.matching(identifier: title).firstMatch
    }
}
