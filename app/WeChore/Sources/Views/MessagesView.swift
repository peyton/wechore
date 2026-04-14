import Foundation
import PhotosUI
import SwiftUI

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    let threadID: String

    @State private var draft = ""
    @State private var isVoiceMode = false
    @State private var isActionPanelOpen = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var invitePayload: InvitePayload?
    @State private var isInviteQRPresented = false
    @FocusState private var isDraftFocused: Bool

    private let bottomID = "conversation.bottom"

    var body: some View {
        VStack(spacing: 0) {
            ConversationHeader(
                threadID: threadID,
                invitePayload: $invitePayload,
                createInvite: createInvite,
                showInviteQR: showInviteQR
            )
            AppStatusBanner(allowsUndo: true)
            FloatingTaskTile(threadID: threadID)
            ConversationScroll(threadID: threadID, bottomID: bottomID)
        }
        .background(AppPalette.chatCanvas)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                ChatComposer(
                    draft: $draft,
                    isVoiceMode: $isVoiceMode,
                    isActionPanelOpen: $isActionPanelOpen,
                    selectedPhoto: $selectedPhoto,
                    isDraftFocused: $isDraftFocused,
                    send: sendTextMessage,
                    startVoice: startVoiceRecording,
                    finishVoice: finishVoiceRecording,
                    cancelVoice: cancelVoiceRecording
                )
                if isActionPanelOpen {
                    ConversationActionPanel(
                        invitePayload: invitePayload,
                        newTask: prepareNewTaskPrompt,
                        createInvite: createInvite,
                        showInviteQR: showInviteQR
                    )
                }
            }
            .padding(.bottom, 34)
            .background(AppPalette.chrome)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(appState.thread(for: threadID)?.title ?? "Chat")
        .onDisappear {
            if appState.isRecordingVoiceMessage {
                appState.cancelVoiceMessageRecording()
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await sendPhotoMessage(data)
                }
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $isInviteQRPresented) {
            if let invitePayload {
                NavigationStack {
                    ScrollView {
                        InviteQRCodeCard(payload: invitePayload)
                            .padding(18)
                    }
                    .background(AppPalette.canvas)
                    .navigationTitle("Invite QR")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isInviteQRPresented = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func sendTextMessage() {
        isDraftFocused = false
        let body = draft
        draft = ""
        Task {
            let posted = await appState.postMessage(body, in: threadID)
            if !posted {
                await MainActor.run {
                    draft = body
                }
            }
        }
    }

    private func startVoiceRecording() {
        Task { await appState.startVoiceMessageRecording(in: threadID) }
    }

    private func finishVoiceRecording() {
        Task { await appState.finishVoiceMessageRecording() }
    }

    private func cancelVoiceRecording() {
        appState.cancelVoiceMessageRecording()
    }

    private func prepareNewTaskPrompt() {
        isVoiceMode = false
        isActionPanelOpen = false
        draft = "Please "
        isDraftFocused = true
    }

    private func createInvite() {
        invitePayload = appState.createInvite(for: threadID)
        isActionPanelOpen = false
    }

    private func showInviteQR() {
        if invitePayload == nil {
            createInvite()
        }
        isActionPanelOpen = false
        isInviteQRPresented = invitePayload != nil
    }

    private func sendPhotoMessage(_ data: Data) async {
        await appState.postImageMessage(imageData: data, in: threadID)
    }
}

private struct ConversationHeader: View {
    @Environment(AppState.self) private var appState
    let threadID: String
    @Binding var invitePayload: InvitePayload?
    let createInvite: () -> Void
    let showInviteQR: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: thread?.kind == .dm ? "person.fill" : "person.2.fill")
                .foregroundStyle(AppPalette.weChatGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(thread?.title ?? "Chat")
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("conversation.title")
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
            }
            Spacer()
            if let payload = invitePayload {
                HStack(spacing: 2) {
                    Button(action: showInviteQR) {
                        Label("Show QR", systemImage: "qrcode")
                            .labelStyle(.iconOnly)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("conversation.showInviteQR")

                    ShareLink(item: payload.shareText) {
                        Label("Share invite", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("conversation.shareInvite")
                }
            } else {
                Button(action: createInvite) {
                    Label("Invite", systemImage: "person.badge.plus")
                        .labelStyle(.titleAndIcon)
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("conversation.createInvite")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(AppPalette.chrome)
    }

    private var thread: ChatThread? {
        appState.thread(for: threadID)
    }

    private var subtitle: String {
        let participantCount = appState.participants(in: threadID).count
        let tasks = appState.activeChores(in: threadID).count
        let participantText = participantCount == 1 ? "1 person" : "\(participantCount) people"
        let taskText = tasks == 1 ? "1 active task" : "\(tasks) active tasks"
        return "\(participantText) • \(taskText)"
    }
}

private struct FloatingTaskTile: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    let threadID: String

    private var activeTasks: [Chore] {
        appState.activeChores(in: threadID)
    }

    private var drafts: [TaskDraft] {
        appState.taskDrafts(in: threadID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tasks")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("taskTile")
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }
                Spacer()
                Image(systemName: activeTasks.isEmpty && drafts.isEmpty ? "checkmark.circle" : "list.bullet.clipboard")
                    .foregroundStyle(AppPalette.weChatGreen)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            if drafts.isEmpty && activeTasks.isEmpty {
                Text("Nothing active. Send a request and WeChore will pull out the task.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(drafts) { draft in
                    DraftTaskRow(draft: draft, threadID: threadID)
                }
                ForEach(activeTasks.prefix(3)) { chore in
                    ActiveTaskRow(chore: chore)
                }
                if activeTasks.count > 3 {
                    Button {
                        router.openOnPhone(.tasks)
                        router.selectOnIPad(.tasks)
                    } label: {
                        Label("\(activeTasks.count - 3) more in Tasks", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(TaskActionButtonStyle(isPrimary: false))
                    .accessibilityIdentifier("taskTile.viewAll")
                }
            }
        }
        .padding(12)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(AppPalette.chatCanvas)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tasks, \(summary)")
    }

    private var summary: String {
        if drafts.isEmpty && activeTasks.isEmpty {
            return "No open tasks"
        }
        let draftText = drafts.isEmpty ? nil : "\(drafts.count) to confirm"
        let activeText = activeTasks.isEmpty ? nil : "\(activeTasks.count) active"
        return [draftText, activeText].compactMap(\.self).joined(separator: " • ")
    }
}

private struct DraftTaskRow: View {
    @Environment(AppState.self) private var appState
    let draft: TaskDraft
    let threadID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                StatusIcon(systemName: "person.crop.circle.badge.questionmark", color: AppPalette.warning)
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if draft.assignmentState == .needsAssignee {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who should do this?")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    FlexibleAssigneeChips(
                        participants: appState.participants(in: threadID),
                        selectedID: draft.assigneeID
                    ) { participantID in
                        appState.confirmDraft(draft, assigneeID: participantID)
                    }
                }
            } else {
                ResponsiveTaskActions {
                    Button {
                        appState.confirmDraft(draft)
                    } label: {
                        Label("Add task", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(TaskActionButtonStyle(isPrimary: true))
                    .accessibilityHint("Creates this chore.")
                    .accessibilityIdentifier("taskDraft.confirm.\(draft.id)")

                    Button {
                        appState.dismissDraft(draft)
                    } label: {
                        Label("Skip", systemImage: "xmark.circle")
                    }
                    .buttonStyle(TaskActionButtonStyle(isPrimary: false))
                    .accessibilityHint("Removes this suggestion.")
                    .accessibilityIdentifier("taskDraft.skip.\(draft.id)")
                }
            }
            Button {
                appState.dismissDraft(draft)
            } label: {
                Label("Dismiss suggestion", systemImage: "xmark")
            }
            .buttonStyle(TaskActionButtonStyle(isPrimary: false))
            .accessibilityIdentifier("taskDraft.dismiss.\(draft.id)")
        }
        .padding(12)
        .background(AppPalette.receivedBubble)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var detailText: String {
        let assignee = draft.assigneeID.flatMap { id in
            appState.participants.first(where: { $0.id == id })?.displayName
        } ?? "Waiting for assignee"
        let due = draft.dueDate.map { "Due \($0.weChoreShortDueText)" } ?? "No due date"
        return "\(assignee) • \(due)"
    }
}

private struct FlexibleAssigneeChips: View {
    let participants: [ChatParticipant]
    let selectedID: String?
    let choose: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 116), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(participants) { participant in
                Button {
                    choose(participant.id)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: selectedID == participant.id ? "checkmark.circle.fill" : "person.fill")
                        Text(participant.displayName)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(TaskActionButtonStyle(isPrimary: selectedID == participant.id))
                .accessibilityHint("Assigns this chore to \(participant.displayName).")
                .accessibilityIdentifier("taskDraft.assignee.\(participant.id)")
            }
        }
    }
}

private struct ActiveTaskRow: View {
    @Environment(AppState.self) private var appState
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                StatusIcon(systemName: statusIconName, color: statusColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(chore.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            ResponsiveTaskActions {
                Button {
                    Task { await appState.scheduleReminder(for: chore) }
                } label: {
                    Label("Remind", systemImage: "bell.fill")
                }
                .buttonStyle(TaskActionButtonStyle(isPrimary: false))
                .accessibilityHint("Schedules a reminder for \(appState.assigneeName(for: chore)).")
                .accessibilityIdentifier("taskTile.remind.\(chore.id)")

                Button {
                    appState.updateStatus(choreID: chore.id, status: .blocked)
                } label: {
                    Label("Blocked", systemImage: "exclamationmark.octagon.fill")
                }
                .buttonStyle(TaskActionButtonStyle(isPrimary: false))
                .accessibilityHint("Marks this chore as blocked.")
                .accessibilityIdentifier("taskTile.blocked.\(chore.id)")

                Button {
                    appState.updateStatus(choreID: chore.id, status: .done)
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(TaskActionButtonStyle(isPrimary: true))
                .accessibilityHint("Marks this chore complete. You can undo from the status message.")
                .accessibilityIdentifier("taskTile.done.\(chore.id)")
            }
        }
        .padding(12)
        .background(AppPalette.receivedBubble)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Done") {
            appState.updateStatus(choreID: chore.id, status: .done)
        }
        .accessibilityAction(named: "Remind") {
            Task { await appState.scheduleReminder(for: chore) }
        }
    }

    private var detailText: String {
        let due = statusLabel
        return "\(appState.assigneeName(for: chore)) • \(due)"
    }

    private var statusLabel: String {
        if chore.status == .blocked { return "Blocked" }
        guard let dueDate = chore.dueDate else { return chore.status.displayName }
        if Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: Date()) {
            return "Overdue"
        }
        if Calendar.current.isDateInToday(dueDate) {
            return "Due today"
        }
        return "Due \(dueDate.weChoreShortDueText)"
    }

    private var statusIconName: String {
        switch chore.status {
        case .blocked: "exclamationmark.octagon.fill"
        case .done: "checkmark.circle.fill"
        case .inProgress: "clock.fill"
        case .open, .archived:
            chore.dueDate == nil ? "checklist" : "calendar"
        }
    }

    private var statusColor: Color {
        if chore.status == .blocked { return AppPalette.warning }
        if statusLabel == "Overdue" || statusLabel == "Due today" { return AppPalette.warning }
        return AppPalette.muted
    }
}

private struct ResponsiveTaskActions<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                content
            }
            VStack(alignment: .leading, spacing: 2) {
                content
            }
        }
    }
}

private struct StatusIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.headline)
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ConversationScroll: View {
    @Environment(AppState.self) private var appState
    let threadID: String
    let bottomID: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if appState.messages(in: threadID).isEmpty {
                        EmptyConversationState()
                    }
                    ForEach(appState.messages(in: threadID)) { message in
                        MessageBubble(message: message)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .onAppear {
                scrollToBottom(proxy)
            }
            .onChange(of: appState.messages(in: threadID).count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: appState.activeChores(in: threadID).count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
}

private struct EmptyConversationState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title2)
                .foregroundStyle(AppPalette.weChatGreen)
            Text("Say what needs doing.")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Text("Try: Sam, please unload the dishwasher tonight.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .accessibilityIdentifier("conversation.empty")
    }
}

private struct MessageBubble: View {
    @Environment(AppState.self) private var appState
    let message: ChoreMessage

    private var isCurrentUser: Bool {
        message.authorMemberID == appState.currentParticipant.id
    }

    var body: some View {
        if message.kind == .system {
            VStack(spacing: 3) {
                Text(message.body)
                    .font(.caption.weight(.semibold))
                Text(message.createdAt.weChoreShortTimeText)
                    .font(.caption2)
            }
            .foregroundStyle(AppPalette.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppPalette.chrome)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if isCurrentUser {
                    Spacer(minLength: 42)
                } else {
                    Avatar(name: authorName)
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                    if !isCurrentUser {
                        Text(authorName)
                            .font(.caption)
                            .foregroundStyle(AppPalette.muted)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        if let filename = message.imageFilename,
                           let image = UIImage(
                               contentsOfFile: FileManager.default.temporaryDirectory
                                   .appendingPathComponent(filename).path
                           ) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        if message.kind == .voice {
                            VoicePlaybackButton(message: message)
                        }
                        Text(message.kind == .voice ? "Transcript: \(message.body)" : message.body)
                            .font(.body)
                            .foregroundStyle(isCurrentUser ? AppPalette.onAccent : AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? AppPalette.sentBubble : AppPalette.receivedBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: 560, alignment: isCurrentUser ? .trailing : .leading)
                    Text(message.createdAt.weChoreShortTimeText)
                        .font(.caption2)
                        .foregroundStyle(AppPalette.muted)
                }
                .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)

                if isCurrentUser {
                    Avatar(name: appState.currentParticipant.displayName, isCurrentUser: true)
                } else {
                    Spacer(minLength: 42)
                }
            }
        }
    }

    private var authorName: String {
        appState.participantName(for: message.authorMemberID)
    }
}

private struct VoicePlaybackButton: View {
    @Environment(AppState.self) private var appState
    let message: ChoreMessage

    var body: some View {
        Button {
            appState.playVoiceMessage(message)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                Text("Voice message")
                Text(durationText)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(AppPalette.surface.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("voice.play.\(message.id)")
    }

    private var durationText: String {
        AppState.voiceDurationText(message.voiceAttachment?.duration ?? 1)
    }
}

private struct Avatar: View {
    let name: String
    var isCurrentUser = false

    var body: some View {
        Text(initial)
            .font(.caption.weight(.bold))
            .foregroundStyle(isCurrentUser ? AppPalette.onAccent : AppPalette.ink)
            .frame(width: 34, height: 34)
            .background(isCurrentUser ? AppPalette.weChatGreen : AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }

    private var initial: String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}

private struct ChatComposer: View {
    @Environment(AppState.self) private var appState
    @Binding var draft: String
    @Binding var isVoiceMode: Bool
    @Binding var isActionPanelOpen: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    @FocusState.Binding var isDraftFocused: Bool
    let send: () -> Void
    let startVoice: () -> Void
    let finishVoice: () -> Void
    let cancelVoice: () -> Void

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                if appState.isRecordingVoiceMessage {
                    cancelVoice()
                    isVoiceMode = false
                } else {
                    isVoiceMode.toggle()
                }
                isActionPanelOpen = false
                isDraftFocused = !isVoiceMode
            } label: {
                Label(isVoiceMode ? "Keyboard" : "Voice", systemImage: isVoiceMode ? "keyboard" : "mic.fill")
                    .labelStyle(.iconOnly)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityIdentifier("message.voiceMode")

            if isVoiceMode {
                VoiceRecordButton(
                    isRecording: appState.isRecordingVoiceMessage,
                    start: startVoice,
                    finish: finishVoice,
                    cancel: cancelVoice
                )
            } else {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .focused($isDraftFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("message.input")
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Photo", systemImage: "photo")
                    .labelStyle(.iconOnly)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityIdentifier("message.photo")

            Button {
                isActionPanelOpen.toggle()
                isDraftFocused = false
            } label: {
                Label(
                    isActionPanelOpen ? "Close actions" : "More actions",
                    systemImage: isActionPanelOpen ? "xmark.circle.fill" : "plus.circle.fill"
                )
                .labelStyle(.iconOnly)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityIdentifier("message.more")

            if !isVoiceMode {
                Button {
                    guard canSend else { return }
                    isDraftFocused = false
                    Task { @MainActor in
                        await Task.yield()
                        send()
                    }
                } label: {
                    Text("Send")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canSend ? AppPalette.onAccent : AppPalette.muted)
                        .frame(minWidth: 58, minHeight: 44)
                        .padding(.horizontal, 4)
                        .background(canSend ? AppPalette.weChatGreen : AppPalette.receivedBubble)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .accessibilityIdentifier("message.post")
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct VoiceRecordButton: View {
    @State private var isHoldRecording = false

    let isRecording: Bool
    let start: () -> Void
    let finish: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording ? finish() : start()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: isRecording ? "waveform.circle.fill" : "waveform")
                    Text(isRecording ? "Tap to Send" : "Tap to Record")
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(isRecording ? AppPalette.weChatGreen.opacity(0.45) : AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(isRecording ? "Sends this voice message." : "Starts recording a voice message.")
            .accessibilityAction {
                isRecording ? finish() : start()
            }
            .accessibilityIdentifier("message.voiceRecord")
            if !isRecording {
                HoldVoiceShortcutButton(
                    isHoldRecording: $isHoldRecording,
                    start: start,
                    finish: finish
                )
            }
            if isRecording {
                Button {
                    isHoldRecording = false
                    cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(TaskActionButtonStyle(isPrimary: false))
                .accessibilityHint("Deletes this voice recording.")
                .accessibilityIdentifier("message.voiceCancel")
            }
        }
    }
}

private struct HoldVoiceShortcutButton: View {
    @Binding var isHoldRecording: Bool
    let start: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "hand.tap.fill")
            Text("Hold")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppPalette.ink)
        .frame(width: 50, height: 54)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onLongPressGesture(
            minimumDuration: 0.25,
            maximumDistance: 48,
            perform: {},
            onPressingChanged: { pressing in
                if pressing, !isHoldRecording {
                    isHoldRecording = true
                    start()
                } else if !pressing, isHoldRecording {
                    isHoldRecording = false
                    finish()
                }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Hold to record")
        .accessibilityHint("Hold down to record, then lift to send.")
        .accessibilityIdentifier("message.voiceHold")
    }
}

private struct ConversationActionPanel: View {
    let invitePayload: InvitePayload?
    let newTask: () -> Void
    let createInvite: () -> Void
    let showInviteQR: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 116), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ChatActionButton(title: "New task", systemImage: "square.and.pencil", action: newTask)
                .accessibilityIdentifier("chat.action.newTask")
            ChatActionButton(title: "Invite", systemImage: "person.badge.plus", action: createInvite)
                .accessibilityIdentifier("chat.action.invite")
            if let invitePayload {
                ChatActionButton(title: "QR code", systemImage: "qrcode", action: showInviteQR)
                    .accessibilityIdentifier("chat.action.qr")
                ShareLink(item: invitePayload.shareText) {
                    VStack(spacing: 8) {
                        Image(systemName: "airplayaudio")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(AppPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Share")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .accessibilityIdentifier("chat.action.share")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .background(AppPalette.chrome)
    }
}

private struct ChatActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 68)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct JoinStartView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var groupTitle = ""
    @State private var dmName = ""
    @State private var dmContact = ""
    @State private var inviteCode = ""
    @State private var isDMContactPickerPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Join or Start")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppPalette.ink)

                JoinStartPanel(title: "Scan a QR code") {
                    Text(
                        "Ask your friend to open My QR. Open the iPhone Camera app, "
                            + "point it at their WeChore QR, then tap the join banner."
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .foregroundStyle(AppPalette.weChatGreen)
                        Text("Camera scanning works with WeChore invite links.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                    }
                    .accessibilityIdentifier("join.scanQR")
                }

                JoinStartPanel(title: "Start a group chat") {
                    VisibleFieldLabel("Group chat name") {
                        TextField("Family, weekend crew, soccer carpool", text: $groupTitle)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("join.groupTitle")
                    }
                    Button("Start Group") {
                        openThread(appState.createGroupChat(title: groupTitle))
                        groupTitle = ""
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canStartGroup)
                    .accessibilityIdentifier("join.startGroup")
                }

                JoinStartPanel(title: "Start a DM") {
                    VisibleFieldLabel("Name") {
                        TextField("Name", text: $dmName)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("join.dmName")
                    }
                    VisibleFieldLabel("Phone or email") {
                        TextField("Phone or email", text: $dmContact)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("join.dmContact")
                    }
                    Button {
                        isDMContactPickerPresented = true
                    } label: {
                        Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("join.pickContact")

                    Button("Start DM") {
                        openThread(appState.startDM(
                            displayName: dmName,
                            phoneNumber: dmContact.contains("@") ? "" : dmContact,
                            faceTimeHandle: dmContact.contains("@") ? dmContact : ""
                        ))
                        dmName = ""
                        dmContact = ""
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canStartDM)
                    .accessibilityIdentifier("join.startDM")
                }

                JoinStartPanel(title: "Join with code") {
                    VisibleFieldLabel("Invite code") {
                        TextField("Invite code", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("join.inviteCode")
                    }
                    Button("Join Code") {
                        if let threadID = appState.acceptInviteCode(inviteCode) {
                            openThread(threadID)
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canJoinCode)
                    .accessibilityIdentifier("join.code")
                }

                JoinStartPanel(title: "Bring phones together") {
                    Text("WeChore uses nearby Apple device discovery when available, then falls back to matching codes.")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Simulate Nearby Join") {
                        openThread(appState.simulateNearbyJoin())
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("join.nearby")
                }
            }
            .padding(18)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(AppPalette.canvas)
        .navigationTitle("Join or Start")
        .safeAreaInset(edge: .bottom) {
            AppStatusBanner()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $isDMContactPickerPresented) {
            ContactPicker { selection in
                dmName = selection.displayName
                dmContact = selection.contactValue
                isDMContactPickerPresented = false
            } onCancel: {
                isDMContactPickerPresented = false
            }
        }
    }

    private var canStartGroup: Bool {
        !groupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canStartDM: Bool {
        !dmName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canJoinCode: Bool {
        inviteCode.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    private func openThread(_ threadID: String?) {
        guard let threadID else { return }
        let destination = ChatDestination.thread(threadID)
        router.phonePath = [destination]
        router.selectedDestination = destination
    }
}

private struct JoinStartPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            content
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct VisibleFieldLabel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            content
        }
    }
}

private struct TaskActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(isPrimary ? AppPalette.onAccent : AppPalette.ink)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(isPrimary ? AppPalette.weChatGreen : AppPalette.surface)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
