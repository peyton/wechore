import Foundation

@MainActor
@Observable
final class AppState {
    private let repository: ChoreRepository
    private let suggestionEngine: MessageSuggestionGenerating
    private let reminderScheduler: ReminderScheduling
    private let communicationOpener: SystemCommunicationOpening
    private let clock: ClockProviding
    private let voiceRecorder: VoiceMessageRecording
    private let voiceTranscriber: VoiceMessageTranscribing
    private let voiceStorage: VoiceMessageStorage
    private let voicePlayer: VoiceMessagePlaying

    private(set) var snapshot: ChoreSnapshot
    var lastStatusMessage: String?
    var preparedMessageMember: Member?
    var preparedMessageBody = ""
    var shouldPresentMessageComposer = false
    var isRecordingVoiceMessage = false
    private var currentVoiceRecordingURL: URL?

    init(
        repository: ChoreRepository,
        suggestionEngine: MessageSuggestionGenerating = OnDeviceMessageSuggestionEngine(),
        reminderScheduler: ReminderScheduling = LocalReminderScheduler(),
        communicationOpener: SystemCommunicationOpening = AppleSystemCommunicationOpener(),
        voiceRecorder: VoiceMessageRecording = AppleVoiceMessageRecorder(),
        voiceTranscriber: VoiceMessageTranscribing = AppleSpeechVoiceMessageTranscriber(),
        voiceStorage: VoiceMessageStorage = LocalVoiceMessageStorage(),
        voicePlayer: VoiceMessagePlaying = AppleVoiceMessagePlayer(),
        clock: ClockProviding = SystemClock()
    ) {
        self.repository = repository
        self.suggestionEngine = suggestionEngine
        self.reminderScheduler = reminderScheduler
        self.communicationOpener = communicationOpener
        self.voiceRecorder = voiceRecorder
        self.voiceTranscriber = voiceTranscriber
        self.voiceStorage = voiceStorage
        self.voicePlayer = voicePlayer
        self.clock = clock
        do {
            snapshot = try repository.loadSnapshot()
        } catch {
            snapshot = .empty(now: clock.now())
            lastStatusMessage = "WeChore started with a fresh local cache."
        }
        applyLaunchConfigurationIfNeeded()
    }

    var household: Household { snapshot.household }
    var members: [Member] { snapshot.members }
    var chores: [Chore] { snapshot.chores.sorted(by: Self.choreSort) }
    var activeChores: [Chore] { chores.filter(\.isActive) }
    var messages: [ChoreMessage] { snapshot.messages.sorted { $0.createdAt < $1.createdAt } }
    var suggestions: [ChoreSuggestion] { snapshot.suggestions.sorted { $0.createdAt < $1.createdAt } }
    var settings: LocalSettings { snapshot.settings }

    var currentMember: Member {
        if let selected = settings.selectedMemberID,
           let member = members.first(where: { $0.id == selected }) {
            return member
        }
        return members.first ?? Member(displayName: "Me", isCurrentUser: true)
    }

    var currentMemberChores: [Chore] {
        chores.filter { $0.assigneeID == currentMember.id && $0.status != .archived }
    }

    func completeOnboarding(displayName: String, householdName: String, contact: String) {
        let now = clock.now()
        var member = currentMember
        member.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Me" : displayName
        if contact.contains("@") {
            member.faceTimeHandle = contact
        } else if !contact.isEmpty {
            member.phoneNumber = contact
        }
        member.isCurrentUser = true

        snapshot.household.name = householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Our Household" : householdName
        snapshot.household.updatedAt = now
        snapshot.members = [member, Member(displayName: "Sam", phoneNumber: "5551231111", faceTimeHandle: "sam@example.com")]
        snapshot.settings.hasCompletedOnboarding = true
        snapshot.settings.selectedMemberID = member.id
        save("Household ready.")
    }

    func addMember(displayName: String, phoneNumber: String = "", faceTimeHandle: String = "") {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        snapshot.members.append(Member(
            displayName: trimmed,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            faceTimeHandle: faceTimeHandle.isEmpty ? nil : faceTimeHandle
        ))
        save("Added \(trimmed).")
    }

    func addChore(title: String, assigneeID: String, dueDate: Date?, notes: String = "") {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = clock.now()
        snapshot.chores.append(Chore(
            title: trimmed,
            notes: notes,
            createdByMemberID: currentMember.id,
            assigneeID: assigneeID,
            dueDate: dueDate,
            createdAt: now,
            updatedAt: now
        ))
        save("Added \(trimmed).")
    }

    func updateStatus(choreID: String, status: ChoreStatus) {
        guard let index = snapshot.chores.firstIndex(where: { $0.id == choreID }) else { return }
        snapshot.chores[index].transition(to: status, at: clock.now())
        save("\(snapshot.chores[index].title) is \(status.displayName.lowercased()).")
    }

    func postMessage(
        _ body: String,
        kind: ChoreMessageKind = .text,
        voiceAttachment: VoiceAttachment? = nil
    ) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = ChoreMessage(
            authorMemberID: currentMember.id,
            body: trimmed,
            kind: kind,
            voiceAttachment: voiceAttachment,
            createdAt: clock.now()
        )
        snapshot.messages.append(message)
        let newSuggestions = suggestionEngine.suggestions(from: message, members: members, now: clock.now())
        snapshot.suggestions.append(contentsOf: newSuggestions)
        save(newSuggestions.isEmpty ? "Message posted." : "Suggested \(newSuggestions[0].title).")
    }

    func postVoiceMessage(transcript: String, attachment: VoiceAttachment) {
        postMessage(transcript, kind: .voice, voiceAttachment: attachment)
    }

    func startVoiceMessageRecording() async {
        guard !isRecordingVoiceMessage else { return }
        do {
            let url = try voiceStorage.makeRecordingURL()
            currentVoiceRecordingURL = url
            try await voiceRecorder.startRecording(to: url)
            isRecordingVoiceMessage = true
            lastStatusMessage = "Recording voice message."
        } catch {
            currentVoiceRecordingURL = nil
            isRecordingVoiceMessage = false
            lastStatusMessage = "Voice recording could not start."
        }
    }

    func finishVoiceMessageRecording() async {
        guard isRecordingVoiceMessage, let url = currentVoiceRecordingURL else {
            lastStatusMessage = "No voice message is recording."
            return
        }

        do {
            let duration = try await voiceRecorder.stopRecording()
            isRecordingVoiceMessage = false
            currentVoiceRecordingURL = nil
            let transcript = try await voiceTranscriber.transcript(for: url)
            let attachment = voiceStorage.attachment(
                for: url,
                duration: duration,
                transcriptConfidence: transcript.confidence
            )
            postVoiceMessage(transcript: transcript.text, attachment: attachment)
        } catch {
            voiceRecorder.cancelRecording()
            isRecordingVoiceMessage = false
            currentVoiceRecordingURL = nil
            lastStatusMessage = "Voice message could not be posted."
        }
    }

    func cancelVoiceMessageRecording() {
        guard isRecordingVoiceMessage else { return }
        voiceRecorder.cancelRecording()
        isRecordingVoiceMessage = false
        currentVoiceRecordingURL = nil
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
        let assigneeID = suggestion.assigneeID ?? currentMember.id
        addChore(
            title: suggestion.title,
            assigneeID: assigneeID,
            dueDate: suggestion.dueDate,
            notes: "Suggested from household messages."
        )
        snapshot.suggestions.removeAll { $0.id == suggestion.id }
        save("Accepted \(suggestion.title).")
    }

    func scheduleReminder(for chore: Chore) async {
        guard let assignee = members.first(where: { $0.id == chore.assigneeID }) else { return }
        do {
            let allowed = try await reminderScheduler.requestAuthorization()
            snapshot.settings.notificationsEnabled = allowed
            let plan = ReminderPlanner.plan(chore: chore, assignee: assignee, now: clock.now())
            try await reminderScheduler.schedule(plan: plan)
            snapshot.reminderLogs.append(ReminderLog(
                choreID: chore.id,
                memberID: assignee.id,
                channel: "local-notification",
                scheduledAt: plan.fireDate,
                createdAt: clock.now()
            ))
            save("Reminder scheduled for \(assignee.displayName).")
        } catch {
            lastStatusMessage = "Reminder could not be scheduled."
        }
    }

    func prepareTextReminder(for chore: Chore) {
        guard let assignee = members.first(where: { $0.id == chore.assigneeID }) else { return }
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
        guard let assignee = members.first(where: { $0.id == chore.assigneeID }) else { return }
        let opened = await communicationOpener.openVoice(for: assignee)
        lastStatusMessage = opened ? "Opened voice handoff for \(assignee.displayName)." : "No voice handle for \(assignee.displayName)."
    }

    func preferredVoiceURL(for member: Member) -> URL? {
        communicationOpener.preferredVoiceURL(for: member)
    }

    func assigneeName(for chore: Chore) -> String {
        members.first(where: { $0.id == chore.assigneeID })?.displayName ?? "Unassigned"
    }

    private func applyLaunchConfigurationIfNeeded() {
        guard RuntimeEnvironment.isRunningUITests else { return }
        if RuntimeEnvironment.shouldCompleteOnboarding || RuntimeEnvironment.shouldSeedHousehold || RuntimeEnvironment.shouldSeedChores {
            snapshot = .seededForUITests(now: clock.now())
        }
        if let memberName = RuntimeEnvironment.requestedMemberName,
           let member = snapshot.members.first(where: { $0.displayName == memberName }) {
            snapshot.settings.selectedMemberID = member.id
        }
        if RuntimeEnvironment.shouldDisableCloudKit {
            snapshot.settings.cloudKitEnabled = false
        }
        try? repository.saveSnapshot(snapshot)
    }

    private func save(_ message: String) {
        do {
            try repository.saveSnapshot(snapshot)
            lastStatusMessage = message
        } catch {
            lastStatusMessage = "WeChore could not save the latest change."
        }
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
        return "\(seconds)s"
    }
}
