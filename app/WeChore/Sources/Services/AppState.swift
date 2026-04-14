import Foundation
import UserNotifications

@MainActor
@Observable
final class AppState {
    private let repository: ChoreRepository
    private let extractionEngine: any TaskExtractionEngine
    private let reminderScheduler: ReminderScheduling
    private let communicationOpener: SystemCommunicationOpening
    private let clock: ClockProviding
    private let voiceRecorder: VoiceMessageRecording
    private let voiceTranscriber: VoiceMessageTranscribing
    private let voiceStorage: VoiceMessageStorage
    private let voicePlayer: VoiceMessagePlaying
    private let widgetTimelineReloader: WidgetTimelineReloading

    private(set) var snapshot: ChoreSnapshot
    var lastStatusMessage: String?
    var recentlyCompletedTaskID: String?
    var preparedMessageMember: Member?
    var preparedMessageBody = ""
    var shouldPresentMessageComposer = false
    var isRecordingVoiceMessage = false
    var latestInvitePayload: InvitePayload?

    private var currentVoiceRecordingURL: URL?
    private var currentVoiceThreadID: String?

    init(
        repository: ChoreRepository,
        extractionEngine: any TaskExtractionEngine = TaskExtractionEngineFactory.live(),
        reminderScheduler: ReminderScheduling = LocalReminderScheduler(),
        communicationOpener: SystemCommunicationOpening = AppleSystemCommunicationOpener(),
        voiceRecorder: VoiceMessageRecording = AppleVoiceMessageRecorder(),
        voiceTranscriber: VoiceMessageTranscribing = AppleSpeechVoiceMessageTranscriber(),
        voiceStorage: VoiceMessageStorage = LocalVoiceMessageStorage(),
        voicePlayer: VoiceMessagePlaying = AppleVoiceMessagePlayer(),
        widgetTimelineReloader: WidgetTimelineReloading = LiveWidgetTimelineReloader(),
        clock: ClockProviding = SystemClock()
    ) {
        self.repository = repository
        self.extractionEngine = extractionEngine
        self.reminderScheduler = reminderScheduler
        self.communicationOpener = communicationOpener
        self.voiceRecorder = voiceRecorder
        self.voiceTranscriber = voiceTranscriber
        self.voiceStorage = voiceStorage
        self.voicePlayer = voicePlayer
        self.widgetTimelineReloader = widgetTimelineReloader
        self.clock = clock
        do {
            snapshot = try repository.loadSnapshot()
            applyLoadedSnapshot(snapshot, shouldAnnounceRecentCompletion: true)
        } catch {
            snapshot = .empty(now: clock.now())
            lastStatusMessage = "WeChore started with a fresh local cache."
        }
        applyLaunchConfigurationIfNeeded()
    }

    var participants: [ChatParticipant] { snapshot.participants }
    var members: [Member] { snapshot.participants }
    var household: Household { snapshot.household }
    var threads: [ChatThread] { snapshot.threads.sorted(by: threadSort) }
    var groupThreads: [ChatThread] { threads.filter { $0.kind == .group } }
    var dmThreads: [ChatThread] { threads.filter { $0.kind == .dm } }
    var chores: [Chore] { snapshot.chores.sorted(by: Self.choreSort) }
    var activeChores: [Chore] { chores.filter(\.isActive) }
    var messages: [ChoreMessage] { snapshot.messages.sorted { $0.createdAt < $1.createdAt } }
    var suggestions: [TaskDraft] { snapshot.suggestions.sorted { $0.createdAt < $1.createdAt } }
    var settings: LocalSettings { snapshot.settings }

    var currentParticipant: ChatParticipant {
        if let selected = settings.selectedParticipantID,
           let participant = participants.first(where: { $0.id == selected }) {
            return participant
        }
        return participants.first ?? ChatParticipant(displayName: "Me", isCurrentUser: true)
    }

    var currentMember: Member { currentParticipant }

    var defaultThreadID: String {
        threads.first?.id ?? ChatThread.legacyDefaultID
    }

    var currentMemberChores: [Chore] {
        chores.filter { $0.assigneeID == currentParticipant.id && $0.status != .archived }
    }

    func completeOnboarding(displayName: String, householdName: String, contact: String, avatarEmoji: String? = nil) {
        let now = clock.now()
        var participant = currentParticipant
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        participant.displayName = trimmedName.isEmpty ? "Me" : trimmedName
        if trimmedContact.contains("@") {
            participant.faceTimeHandle = trimmedContact
        } else if !trimmedContact.isEmpty {
            participant.phoneNumber = Self.normalizedPhoneNumber(trimmedContact)
        }
        participant.avatarEmoji = avatarEmoji
        participant.isCurrentUser = true

        let trimmedChatTitle = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatTitle = trimmedChatTitle.isEmpty
            ? "Family Chat"
            : trimmedChatTitle
        let thread = ChatThread(
            id: ChatThread.legacyDefaultID,
            kind: .group,
            title: chatTitle,
            participantIDs: [participant.id],
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        )

        snapshot.household.name = chatTitle
        snapshot.household.updatedAt = now
        snapshot.participants = [participant]
        snapshot.threads = [thread]
        snapshot.settings.hasCompletedOnboarding = true
        snapshot.settings.selectedParticipantID = participant.id
        save("Chat ready.")
    }

    @discardableResult
    func addParticipant(displayName: String, phoneNumber: String = "", faceTimeHandle: String = "") -> ChatParticipant? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhoneNumber = Self.normalizedPhoneNumber(phoneNumber)
        let normalizedFaceTimeHandle = faceTimeHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = participants.first(where: { $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let participant = ChatParticipant(
            displayName: trimmed,
            phoneNumber: normalizedPhoneNumber.isEmpty ? nil : normalizedPhoneNumber,
            faceTimeHandle: normalizedFaceTimeHandle.isEmpty ? nil : normalizedFaceTimeHandle
        )
        snapshot.participants.append(participant)
        return save("Added \(trimmed).") ? participant : nil
    }

    func addMember(displayName: String, phoneNumber: String = "", faceTimeHandle: String = "") {
        _ = addParticipant(displayName: displayName, phoneNumber: phoneNumber, faceTimeHandle: faceTimeHandle)
    }

    @discardableResult
    func createGroupChat(title: String, participantIDs: [String] = []) -> String? {
        let now = clock.now()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastStatusMessage = "Name the group chat first."
            return nil
        }
        if let existing = snapshot.threads.first(where: {
            $0.kind == .group && $0.title.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            lastStatusMessage = "Opened \(existing.title)."
            return existing.id
        }
        let ids = Self.uniqueOrderedIDs(([currentParticipant.id] + participantIDs).filter { !$0.isEmpty })
        let thread = ChatThread(
            kind: .group,
            title: trimmed,
            participantIDs: ids,
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        )
        snapshot.threads.append(thread)
        return save("Started \(thread.title).") ? thread.id : nil
    }

    @discardableResult
    func startDM(displayName: String, phoneNumber: String = "", faceTimeHandle: String = "") -> String? {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let participant = addParticipant(
            displayName: trimmedDisplayName,
            phoneNumber: phoneNumber,
            faceTimeHandle: faceTimeHandle
        ) else {
            if trimmedDisplayName.isEmpty {
                lastStatusMessage = "Add a name before starting a DM."
            }
            return nil
        }
        if let existing = snapshot.threads.first(where: { thread in
            thread.kind == .dm
                && Set(thread.participantIDs) == Set([currentParticipant.id, participant.id])
        }) {
            lastStatusMessage = "Opened \(existing.title)."
            return existing.id
        }

        let now = clock.now()
        let thread = ChatThread(
            kind: .dm,
            title: participant.displayName,
            participantIDs: [currentParticipant.id, participant.id],
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        )
        snapshot.threads.append(thread)
        return save("Started DM with \(participant.displayName).") ? thread.id : nil
    }

    func thread(for id: String) -> ChatThread? {
        snapshot.threads.first { $0.id == id }
    }

    func participants(in threadID: String) -> [ChatParticipant] {
        guard let thread = thread(for: threadID) else { return [] }
        return participants.filter { thread.participantIDs.contains($0.id) }
    }

    func messages(in threadID: String) -> [ChoreMessage] {
        messages.filter { $0.threadID == threadID }
    }

    func activeChores(in threadID: String) -> [Chore] {
        chores.filter { $0.threadID == threadID && $0.isActive }
    }

    func taskDrafts(in threadID: String) -> [TaskDraft] {
        suggestions.filter { $0.threadID == threadID }
    }

    func lastMessagePreview(for thread: ChatThread) -> String {
        if let message = messages(in: thread.id).last {
            return message.kind == .system ? message.body : "\(participantName(for: message.authorMemberID)): \(message.body)"
        }
        let count = activeChores(in: thread.id).count
        return count == 1 ? "1 active task" : "\(count) active tasks"
    }

    @discardableResult
    func postMessage(
        _ body: String,
        in threadID: String? = nil,
        kind: ChoreMessageKind = .text,
        voiceAttachment: VoiceAttachment? = nil
    ) async -> Bool {
        let resolvedThreadID = threadID ?? defaultThreadID
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let now = clock.now()
        let message = ChoreMessage(
            threadID: resolvedThreadID,
            authorMemberID: currentParticipant.id,
            body: trimmed,
            kind: kind,
            voiceAttachment: voiceAttachment,
            createdAt: now
        )
        snapshot.messages.append(message)
        touchThread(resolvedThreadID, at: now)

        var createdTasks: [Chore] = []
        var draftTasks: [TaskDraft] = []
        var duplicateTaskTitles: [String] = []
        if kind != .system {
            let thread = thread(for: resolvedThreadID)
            let extracted = await extractionEngine.extractTasks(
                from: message,
                participants: participants(in: resolvedThreadID),
                now: now
            )
            for originalDraft in extracted {
                let draft = draftForAssignment(originalDraft, in: thread, sourceMessage: message)
                switch draft.assignmentState {
                case .needsAssignee:
                    snapshot.suggestions.append(draft)
                    draftTasks.append(draft)
                case .ready:
                    if draft.needsConfirmation {
                        snapshot.suggestions.append(draft)
                        draftTasks.append(draft)
                    } else {
                        if let task = createTask(from: draft, sourceMessage: message, at: now) {
                            createdTasks.append(task)
                        } else {
                            duplicateTaskTitles.append(draft.title)
                        }
                    }
                }
            }
        }

        if let first = createdTasks.first {
            return save("Added task: \(first.title).")
        } else if let first = draftTasks.first {
            return save("Draft task ready: \(first.title).")
        } else if let first = duplicateTaskTitles.first {
            return save("\(first) is already active.")
        } else {
            return save("Message posted.")
        }
    }

    @discardableResult
    func postVoiceMessage(transcript: String, attachment: VoiceAttachment, in threadID: String? = nil) async -> Bool {
        await postMessage(transcript, in: threadID, kind: .voice, voiceAttachment: attachment)
    }

    func postImageMessage(imageData: Data, in threadID: String) async -> Bool {
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try imageData.write(to: url)
        } catch {
            lastStatusMessage = "Could not save image."
            return false
        }
        let now = clock.now()
        let message = ChoreMessage(
            threadID: threadID,
            authorMemberID: currentParticipant.id,
            body: "\u{1f4f7} Photo",
            imageFilename: filename,
            createdAt: now
        )
        snapshot.messages.append(message)
        touchThread(threadID, at: now)
        return save("Photo sent.")
    }

    @discardableResult
    func addChore(
        title: String,
        assigneeID: String,
        dueDate: Date?,
        notes: String = "",
        threadID: String? = nil,
        sourceMessageID: String? = nil
    ) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let now = clock.now()
        let resolvedThreadID = threadID ?? defaultThreadID
        guard snapshot.threads.contains(where: { $0.id == resolvedThreadID }) else {
            lastStatusMessage = "Choose a valid chat before adding a task."
            return false
        }
        guard snapshot.participants.contains(where: { $0.id == assigneeID }) else {
            lastStatusMessage = "Choose a valid assignee before adding a task."
            return false
        }
        guard !hasActiveDuplicateTask(title: trimmed, assigneeID: assigneeID, threadID: resolvedThreadID) else {
            lastStatusMessage = "\(trimmed) is already active for \(assigneeName(for: assigneeID))."
            return false
        }
        let chore = Chore(
            threadID: resolvedThreadID,
            title: trimmed,
            notes: notes,
            createdByMemberID: currentParticipant.id,
            assigneeID: assigneeID,
            sourceMessageID: sourceMessageID,
            dueDate: dueDate,
            createdAt: now,
            updatedAt: now
        )
        snapshot.chores.append(chore)
        recordActivity(for: chore, kind: .assigned, at: now)
        return save("Added \(trimmed).")
    }

    func confirmDraft(_ draft: TaskDraft, assigneeID: String? = nil) {
        var confirmedDraft = draft
        if let assigneeID {
            confirmedDraft.assigneeID = assigneeID
        }
        if confirmedDraft.assignmentState == .needsAssignee && confirmedDraft.assigneeID == nil {
            lastStatusMessage = "Choose who should do this."
            return
        }
        confirmedDraft.assignmentState = .ready
        confirmedDraft.needsConfirmation = false
        let now = clock.now()
        let fallbackMessage = ChoreMessage(
            id: confirmedDraft.sourceMessageID,
            threadID: confirmedDraft.threadID,
            authorMemberID: currentParticipant.id,
            body: confirmedDraft.title,
            createdAt: confirmedDraft.createdAt
        )
        snapshot.suggestions.removeAll { $0.id == confirmedDraft.id }
        if let chore = createTask(from: confirmedDraft, sourceMessage: fallbackMessage, at: now) {
            save("Added task: \(chore.title).")
        } else {
            save("\(confirmedDraft.title) is already active for this person.")
        }
    }

    func dismissDraft(_ draft: TaskDraft) {
        snapshot.suggestions.removeAll { $0.id == draft.id }
        save("Draft removed.")
    }

    func deleteMessage(id: String) {
        snapshot.messages.removeAll { $0.id == id }
        save("Message deleted.")
    }

    func updateStatus(choreID: String, status: ChoreStatus) {
        guard let index = snapshot.chores.firstIndex(where: { $0.id == choreID }) else { return }
        guard snapshot.chores[index].status != status else { return }
        let now = clock.now()
        snapshot.chores[index].transition(to: status, at: now)
        let chore = snapshot.chores[index]
        let activityKind: TaskActivityKind = switch status {
        case .open: .reopened
        case .inProgress: .started
        case .blocked: .blocked
        case .done: .completed
        case .archived: .completed
        }
        recordActivity(for: chore, kind: activityKind, at: now)
        if status == .done {
            recentlyCompletedTaskID = chore.id
            snapshot.settings.recentlyCompletedTaskID = chore.id
        } else if recentlyCompletedTaskID == chore.id {
            recentlyCompletedTaskID = nil
            snapshot.settings.recentlyCompletedTaskID = nil
        }
        save("\(chore.title) is \(status.displayName.lowercased()).")
    }

    func updateChore(
        choreID: String,
        title: String,
        assigneeID: String,
        dueDate: Date?,
        notes: String
    ) -> Bool {
        guard let index = snapshot.chores.firstIndex(where: { $0.id == choreID }) else {
            lastStatusMessage = "Task not found."
            return false
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            lastStatusMessage = "Add a task title first."
            return false
        }
        guard snapshot.participants.contains(where: { $0.id == assigneeID }) else {
            lastStatusMessage = "Choose a valid assignee before saving."
            return false
        }
        let chore = snapshot.chores[index]
        if hasActiveDuplicateTask(
            title: trimmedTitle,
            assigneeID: assigneeID,
            threadID: chore.threadID,
            excluding: chore.id
        ) {
            lastStatusMessage = "\(trimmedTitle) is already active for \(assigneeName(for: assigneeID))."
            return false
        }

        snapshot.chores[index].title = trimmedTitle
        snapshot.chores[index].assigneeID = assigneeID
        snapshot.chores[index].dueDate = dueDate
        snapshot.chores[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.chores[index].updatedAt = clock.now()
        return save("Updated \(trimmedTitle).")
    }

    func updateCurrentParticipant(displayName: String, contact: String, avatarEmoji: String? = nil) -> Bool {
        guard let index = snapshot.participants.firstIndex(where: { $0.id == currentParticipant.id }) else {
            lastStatusMessage = "Profile could not be updated."
            return false
        }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastStatusMessage = "Add your name before saving."
            return false
        }
        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.participants[index].displayName = trimmedName
        snapshot.participants[index].isCurrentUser = true
        snapshot.participants[index].avatarEmoji = avatarEmoji
        if trimmedContact.contains("@") {
            snapshot.participants[index].faceTimeHandle = trimmedContact
            snapshot.participants[index].phoneNumber = nil
        } else {
            let phoneNumber = Self.normalizedPhoneNumber(trimmedContact)
            snapshot.participants[index].phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
            snapshot.participants[index].faceTimeHandle = nil
        }
        return save("Profile updated.")
    }

    func reopenRecentlyCompletedTask() {
        guard let recentlyCompletedTaskID else { return }
        updateStatus(choreID: recentlyCompletedTaskID, status: .open)
    }

    func dismissStatusMessage() {
        lastStatusMessage = nil
        recentlyCompletedTaskID = nil
        snapshot.settings.recentlyCompletedTaskID = nil
        do {
            snapshot.normalizeConversationState(now: clock.now())
            try repository.saveSnapshot(snapshot)
            widgetTimelineReloader.reloadAllTimelines()
        } catch {
            lastStatusMessage = "WeChore could not save the latest change."
        }
    }

    func refreshFromSharedState() {
        do {
            let loaded = try repository.loadSnapshot()
            applyLoadedSnapshot(loaded, shouldAnnounceRecentCompletion: true)
        } catch {
            lastStatusMessage = "WeChore could not refresh the latest changes."
        }
    }

    func refresh() async {
        do {
            let refreshed = try repository.loadSnapshot()
            applyLoadedSnapshot(refreshed, shouldAnnounceRecentCompletion: false)
        } catch {
            lastStatusMessage = "Could not refresh."
        }
    }

    func scheduleReminder(for chore: Chore) async {
        guard chore.isActive else {
            lastStatusMessage = "Only active tasks can be reminded."
            return
        }
        guard let assignee = participants.first(where: { $0.id == chore.assigneeID }) else { return }
        do {
            let allowed = try await reminderScheduler.requestAuthorization()
            snapshot.settings.notificationsEnabled = allowed
            guard allowed else {
                if let index = snapshot.chores.firstIndex(where: { $0.id == chore.id }) {
                    snapshot.chores[index].notificationState = .failed
                }
                save("Notifications are not allowed yet.")
                return
            }
            let plan = ReminderPlanner.plan(chore: chore, assignee: assignee, now: clock.now())
            try await reminderScheduler.schedule(plan: plan)
            if let index = snapshot.chores.firstIndex(where: { $0.id == chore.id }) {
                snapshot.chores[index].notificationState = .scheduled
                snapshot.chores[index].lastReminderAt = plan.fireDate
            }
            snapshot.reminderLogs.append(ReminderLog(
                threadID: chore.threadID,
                choreID: chore.id,
                memberID: assignee.id,
                channel: "local-notification",
                scheduledAt: plan.fireDate,
                createdAt: clock.now()
            ))
            recordActivity(for: chore, kind: .reminded, at: clock.now())
            save("Reminder scheduled for \(assignee.displayName).")
        } catch {
            if let index = snapshot.chores.firstIndex(where: { $0.id == chore.id }) {
                snapshot.chores[index].notificationState = .failed
            }
            lastStatusMessage = "Reminder could not be scheduled."
        }
    }

    func prepareTextReminder(for chore: Chore) {
        guard let assignee = participants.first(where: { $0.id == chore.assigneeID }) else { return }
        preparedMessageMember = assignee
        preparedMessageBody = "Reminder from WeChore: please check progress on \(chore.title)."
        if RuntimeEnvironment.isRunningUITests {
            lastStatusMessage = "Prepared Messages reminder for \(assignee.displayName)."
        } else {
            shouldPresentMessageComposer = true
        }
    }

    func messageRecipients(for member: Member) -> [String] {
        if let phoneNumber = member.phoneNumber, !phoneNumber.isEmpty {
            return [phoneNumber]
        }
        if let handle = member.faceTimeHandle, !handle.isEmpty {
            return [handle]
        }
        return []
    }

    func startVoiceHandoff(for chore: Chore) async {
        guard let assignee = participants.first(where: { $0.id == chore.assigneeID }) else { return }
        let opened = await communicationOpener.openVoice(for: assignee)
        lastStatusMessage = opened ? "Opened voice handoff for \(assignee.displayName)." : "No voice handle for \(assignee.displayName)."
    }

    func preferredVoiceURL(for member: Member) -> URL? {
        communicationOpener.preferredVoiceURL(for: member)
    }

    func assigneeName(for chore: Chore) -> String {
        assigneeName(for: chore.assigneeID)
    }

    func assigneeName(for assigneeID: String) -> String {
        participants.first(where: { $0.id == assigneeID })?.displayName ?? "Unassigned"
    }

    func participantName(for id: String) -> String {
        participants.first(where: { $0.id == id })?.displayName ?? "Someone"
    }

    func activeInvitePayload(for threadID: String) -> InvitePayload? {
        pruneExpiredInvites()
        guard let invite = snapshot.invites
            .filter({ $0.threadID == threadID && $0.expiresAt >= clock.now() })
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first,
            let thread = thread(for: invite.threadID) else {
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

    func createInvite(for threadID: String) -> InvitePayload? {
        pruneExpiredInvites()
        guard let thread = thread(for: threadID) else { return nil }
        if let existing = activeInvitePayload(for: threadID) {
            latestInvitePayload = existing
            lastStatusMessage = "Invite ready for \(thread.title)."
            return existing
        }
        let now = clock.now()
        let code = makeInviteCode()
        let invite = ThreadInvite(
            threadID: threadID,
            inviterParticipantID: currentParticipant.id,
            code: code,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now,
            createdAt: now
        )
        snapshot.invites.append(invite)
        let payload = InvitePayload(
            inviteID: invite.id,
            threadID: thread.id,
            threadTitle: thread.title,
            inviterParticipantID: invite.inviterParticipantID,
            code: invite.code,
            expiresAt: invite.expiresAt
        )
        latestInvitePayload = payload
        return save("Invite ready for \(thread.title).") ? payload : nil
    }

    @discardableResult
    func acceptInviteURL(_ url: URL) -> String? {
        guard let payload = InvitePayload(url: url) else {
            lastStatusMessage = "That invite link could not be opened."
            return nil
        }
        return acceptInvite(payload)
    }

    @discardableResult
    func acceptInviteCode(_ code: String) -> String? {
        pruneExpiredInvites()
        let normalized = Self.normalizedInviteCode(code)
        guard !normalized.isEmpty else {
            lastStatusMessage = "Enter an invite code first."
            return nil
        }
        guard let invite = snapshot.invites.first(where: {
            Self.normalizedInviteCode($0.code) == normalized && $0.expiresAt >= clock.now()
        }), let thread = thread(for: invite.threadID) else {
            lastStatusMessage = "Invite code not found."
            return nil
        }
        let payload = InvitePayload(
            inviteID: invite.id,
            threadID: thread.id,
            threadTitle: thread.title,
            inviterParticipantID: invite.inviterParticipantID,
            code: invite.code,
            expiresAt: invite.expiresAt
        )
        return acceptInvite(payload)
    }

    @discardableResult
    func acceptInvite(_ payload: InvitePayload) -> String? {
        pruneExpiredInvites()
        guard payload.expiresAt >= clock.now() else {
            lastStatusMessage = "That invite has expired."
            return nil
        }
        if snapshot.threads.contains(where: { $0.id == payload.threadID }) {
            lastStatusMessage = "Opened \(payload.threadTitle)."
            return payload.threadID
        }
        let now = clock.now()
        snapshot.threads.append(ChatThread(
            id: payload.threadID,
            kind: .group,
            title: payload.threadTitle,
            participantIDs: [currentParticipant.id],
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        ))
        return save("Joined \(payload.threadTitle).") ? payload.threadID : nil
    }

    @discardableResult
    func simulateNearbyJoin() -> String {
        let threadID = createGroupChat(title: "Nearby Chat") ?? defaultThreadID
        lastStatusMessage = "Nearby invite accepted."
        return threadID
    }

    func startVoiceMessageRecording(in threadID: String? = nil) async {
        guard !isRecordingVoiceMessage else { return }
        do {
            let url = try voiceStorage.makeRecordingURL()
            currentVoiceRecordingURL = url
            currentVoiceThreadID = threadID ?? defaultThreadID
            try await voiceRecorder.startRecording(to: url)
            isRecordingVoiceMessage = true
            lastStatusMessage = "Recording voice message."
        } catch {
            currentVoiceRecordingURL = nil
            currentVoiceThreadID = nil
            isRecordingVoiceMessage = false
            lastStatusMessage = "Voice recording could not start."
        }
    }

    func finishVoiceMessageRecording() async {
        guard isRecordingVoiceMessage,
              let url = currentVoiceRecordingURL,
              let threadID = currentVoiceThreadID else {
            lastStatusMessage = "No voice message is recording."
            return
        }

        do {
            let duration = try await voiceRecorder.stopRecording()
            isRecordingVoiceMessage = false
            currentVoiceRecordingURL = nil
            currentVoiceThreadID = nil
            let transcript = try await voiceTranscriber.transcript(for: url)
            guard !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw VoiceMessageError.emptyTranscript
            }
            let attachment = voiceStorage.attachment(
                for: url,
                duration: duration,
                transcriptConfidence: transcript.confidence
            )
            await postVoiceMessage(transcript: transcript.text, attachment: attachment, in: threadID)
        } catch let error as VoiceMessageError {
            voiceRecorder.cancelRecording()
            isRecordingVoiceMessage = false
            currentVoiceRecordingURL = nil
            currentVoiceThreadID = nil
            lastStatusMessage = error.localizedDescription
        } catch {
            voiceRecorder.cancelRecording()
            isRecordingVoiceMessage = false
            currentVoiceRecordingURL = nil
            currentVoiceThreadID = nil
            lastStatusMessage = "Voice message could not be posted."
        }
    }

    func cancelVoiceMessageRecording() {
        guard isRecordingVoiceMessage else { return }
        voiceRecorder.cancelRecording()
        isRecordingVoiceMessage = false
        currentVoiceRecordingURL = nil
        currentVoiceThreadID = nil
        lastStatusMessage = "Voice message canceled."
    }

    func playVoiceMessage(_ message: ChoreMessage) {
        guard let attachment = message.voiceAttachment else {
            lastStatusMessage = "Voice message audio is unavailable."
            return
        }

        do {
            let url = try voiceStorage.fileURL(for: attachment)
            let duration = try voicePlayer.play(url: url)
            lastStatusMessage = "Playing voice message (\(Self.voiceDurationText(duration)))."
        } catch {
            lastStatusMessage = "Voice message audio is unavailable."
        }
    }

    func acceptSuggestion(_ suggestion: ChoreSuggestion) {
        confirmDraft(suggestion)
    }

    func threadID(forTaskID taskID: String) -> String? {
        snapshot.chores.first { $0.id == taskID }?.threadID
    }

    func isWidgetFavorite(threadID: String) -> Bool {
        snapshot.settings.widgetFavoriteThreadIDs.contains(threadID)
    }

    func setWidgetFavorite(threadID: String, isFavorite: Bool) {
        if isFavorite {
            guard snapshot.threads.contains(where: { $0.id == threadID }) else { return }
            if !snapshot.settings.widgetFavoriteThreadIDs.contains(threadID) {
                snapshot.settings.widgetFavoriteThreadIDs.append(threadID)
            }
            save("Widget favorite added.")
        } else {
            snapshot.settings.widgetFavoriteThreadIDs.removeAll { $0 == threadID }
            save("Widget favorite removed.")
        }
    }

    private func createTask(from draft: TaskDraft, sourceMessage: ChoreMessage, at now: Date) -> Chore? {
        let assigneeID = draft.assigneeID ?? currentParticipant.id
        guard !hasActiveDuplicateTask(title: draft.title, assigneeID: assigneeID, threadID: draft.threadID) else {
            return nil
        }
        let chore = Chore(
            threadID: draft.threadID,
            title: draft.title,
            notes: "Created from chat.",
            createdByMemberID: sourceMessage.authorMemberID,
            assigneeID: assigneeID,
            sourceMessageID: sourceMessage.id,
            dueDate: draft.dueDate,
            status: .open,
            urgency: draft.urgency,
            reminderPolicy: draft.dueDate == nil ? .smart : .dueDate,
            createdAt: now,
            updatedAt: now
        )
        snapshot.chores.append(chore)
        recordActivity(for: chore, kind: .assigned, at: now)
        return chore
    }

    private func hasActiveDuplicateTask(
        title: String,
        assigneeID: String,
        threadID: String,
        excluding excludedChoreID: String? = nil
    ) -> Bool {
        let normalizedTitle = Self.normalizedTaskTitle(title)
        return snapshot.chores.contains { chore in
            chore.isActive
                && chore.threadID == threadID
                && chore.assigneeID == assigneeID
                && chore.id != excludedChoreID
                && Self.normalizedTaskTitle(chore.title) == normalizedTitle
        }
    }

    private static func normalizedTaskTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func pruneExpiredInvites() {
        snapshot.normalizeConversationState(now: clock.now())
    }

    private func draftForAssignment(
        _ draft: TaskDraft,
        in thread: ChatThread?,
        sourceMessage message: ChoreMessage
    ) -> TaskDraft {
        var assignedDraft = draft
        guard let thread else { return assignedDraft }

        switch thread.kind {
        case .dm:
            let recipientID = thread.participantIDs.first { $0 != message.authorMemberID }
            assignedDraft.assigneeID = assignedDraft.assigneeID ?? recipientID
            assignedDraft.needsConfirmation = false
            assignedDraft.assignmentState = .ready
        case .group:
            assignedDraft.needsConfirmation = true
            assignedDraft.assignmentState = .needsAssignee
        }

        return assignedDraft
    }

    private func recordActivity(for chore: Chore, kind: TaskActivityKind, at date: Date) {
        let body = activityBody(for: chore, kind: kind)
        snapshot.taskActivities.append(TaskActivity(
            threadID: chore.threadID,
            choreID: chore.id,
            actorParticipantID: currentParticipant.id,
            kind: kind,
            body: body,
            createdAt: date
        ))
        snapshot.messages.append(ChoreMessage(
            threadID: chore.threadID,
            authorMemberID: currentParticipant.id,
            body: body,
            kind: .system,
            createdAt: date
        ))
        touchThread(chore.threadID, at: date)
    }

    private func activityBody(for chore: Chore, kind: TaskActivityKind) -> String {
        switch kind {
        case .assigned:
            "\(assigneeName(for: chore)) was assigned \(chore.title)."
        case .reminded:
            "Reminder scheduled for \(assigneeName(for: chore)): \(chore.title)."
        case .started:
            "\(assigneeName(for: chore)) started \(chore.title)."
        case .blocked:
            "\(chore.title) is blocked."
        case .completed:
            "\(assigneeName(for: chore)) completed \(chore.title)."
        case .reopened:
            "\(chore.title) was reopened."
        }
    }

    private func touchThread(_ threadID: String, at date: Date) {
        guard let index = snapshot.threads.firstIndex(where: { $0.id == threadID }) else { return }
        snapshot.threads[index].updatedAt = date
        snapshot.threads[index].lastActivityAt = date
    }

    private func applyLaunchConfigurationIfNeeded() {
        guard RuntimeEnvironment.isRunningUITests else { return }
        if RuntimeEnvironment.shouldCompleteOnboarding
            || RuntimeEnvironment.shouldSeedConversation
            || RuntimeEnvironment.shouldSeedChores {
            snapshot = .seededForUITests(now: clock.now())
        }
        if let participantName = RuntimeEnvironment.requestedParticipantName,
           let participant = snapshot.participants.first(where: { $0.displayName == participantName }) {
            snapshot.settings.selectedParticipantID = participant.id
        }
        if RuntimeEnvironment.shouldDisableCloudKit {
            snapshot.settings.cloudKitEnabled = false
        }
        try? repository.saveSnapshot(snapshot)
    }

    private func applyLoadedSnapshot(
        _ loadedSnapshot: ChoreSnapshot,
        shouldAnnounceRecentCompletion: Bool
    ) {
        snapshot = loadedSnapshot
        snapshot.normalizeConversationState(now: clock.now())
        recentlyCompletedTaskID = snapshot.settings.recentlyCompletedTaskID
        guard shouldAnnounceRecentCompletion,
              let recentlyCompletedTaskID,
              let chore = snapshot.chores.first(where: {
                $0.id == recentlyCompletedTaskID && $0.status == .done
              }) else {
            return
        }
        lastStatusMessage = "\(chore.title) is done."
    }

    @discardableResult
    private func save(_ message: String) -> Bool {
        do {
            snapshot.normalizeConversationState(now: clock.now())
            try repository.saveSnapshot(snapshot)
            lastStatusMessage = message
            widgetTimelineReloader.reloadAllTimelines()
            updateBadgeCount()
            return true
        } catch {
            if let loaded = try? repository.loadSnapshot() {
                applyLoadedSnapshot(loaded, shouldAnnounceRecentCompletion: false)
            }
            lastStatusMessage = "WeChore could not save the latest change."
            return false
        }
    }

    private func updateBadgeCount() {
        let overdue = chores.filter { chore in
            chore.isActive && (chore.dueDate ?? .distantFuture) < clock.now()
        }.count
        let unread = threads.reduce(0) { $0 + $1.unreadCount }
        let total = overdue + unread
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(total)
        }
    }

    func clearBadge() {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    private func threadSort(lhs: ChatThread, rhs: ChatThread) -> Bool {
        lhs.lastActivityAt > rhs.lastActivityAt
    }

    private func makeInviteCode() -> String {
        let activeCodes = Set(snapshot.invites.map { Self.normalizedInviteCode($0.code) })
        for _ in 0..<20 {
            let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
            if !activeCodes.contains(code) {
                return code
            }
        }
        return String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }

    private static func choreSort(lhs: Chore, rhs: Chore) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            if left != right { return left < right }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    static func voiceDurationText(_ duration: TimeInterval) -> String {
        let seconds = max(1, Int(duration.rounded()))
        guard seconds >= 60 else { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }

    private static func normalizedInviteCode(_ code: String) -> String {
        String(code.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func normalizedPhoneNumber(_ phoneNumber: String) -> String {
        phoneNumber.filter { $0.isNumber || $0 == "+" }
    }

    private static func uniqueOrderedIDs(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
