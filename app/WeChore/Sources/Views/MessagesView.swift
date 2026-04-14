import SwiftUI

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    let threadID: String

    @State private var draft = ""
    @State private var isVoiceMode = false
    @State private var isActionPanelOpen = false
    @State private var invitePayload: InvitePayload?
    @FocusState private var isDraftFocused: Bool

    private let bottomID = "conversation.bottom"

    var body: some View {
        VStack(spacing: 0) {
            ConversationHeader(threadID: threadID, invitePayload: $invitePayload)
            FloatingTaskTile(threadID: threadID)
            ConversationScroll(threadID: threadID, bottomID: bottomID)
        }
        .background(AppPalette.chatCanvas)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                StatusToast()
                ChatComposer(
                    draft: $draft,
                    isVoiceMode: $isVoiceMode,
                    isActionPanelOpen: $isActionPanelOpen,
                    isDraftFocused: $isDraftFocused,
                    send: sendTextMessage,
                    startVoice: startVoiceRecording,
                    finishVoice: finishVoiceRecording
                )
                if isActionPanelOpen {
                    ConversationActionPanel(
                        invitePayload: invitePayload,
                        newTask: prepareNewTaskPrompt,
                        createInvite: createInvite
                    )
                }
            }
            .background(AppPalette.chrome)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(appState.thread(for: threadID)?.title ?? "Chat")
        .onAppear {
            if invitePayload == nil {
                invitePayload = appState.createInvite(for: threadID)
            }
        }
    }

    private func sendTextMessage() {
        let body = draft
        draft = ""
        isDraftFocused = false
        Task { await appState.postMessage(body, in: threadID) }
    }

    private func startVoiceRecording() {
        Task { await appState.startVoiceMessageRecording(in: threadID) }
    }

    private func finishVoiceRecording() {
        Task { await appState.finishVoiceMessageRecording() }
    }

    private func prepareNewTaskPrompt() {
        isVoiceMode = false
        isActionPanelOpen = false
        draft = "Please "
        isDraftFocused = true
    }

    private func createInvite() {
        invitePayload = appState.createInvite(for: threadID)
    }
}

private struct ConversationHeader: View {
    @Environment(AppState.self) private var appState
    let threadID: String
    @Binding var invitePayload: InvitePayload?

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
                ShareLink(item: payload.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 34, height: 34)
                }
                .accessibilityIdentifier("conversation.shareInvite")
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
                Image(systemName: activeTasks.isEmpty && drafts.isEmpty ? "checkmark.circle" : "bolt.fill")
                    .foregroundStyle(AppPalette.weChatGreen)
            }

            if drafts.isEmpty && activeTasks.isEmpty {
                Text("Nothing active. Send a request and WeChore will pull out the task.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(drafts) { draft in
                    DraftTaskRow(draft: draft)
                }
                ForEach(activeTasks.prefix(3)) { chore in
                    ActiveTaskRow(chore: chore)
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

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppPalette.weChatGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
            }
            Spacer(minLength: 8)
            Button {
                appState.confirmDraft(draft)
            } label: {
                Text("Add")
                    .accessibilityIdentifier("taskDraft.confirm.\(draft.id)")
            }
            .buttonStyle(TileMiniButtonStyle(isPrimary: true))
            .accessibilityIdentifier("taskDraft.confirm.\(draft.id)")
            Button {
                appState.dismissDraft(draft)
            } label: {
                Text("Skip")
                    .accessibilityIdentifier("taskDraft.skip.\(draft.id)")
            }
            .buttonStyle(TileMiniButtonStyle(isPrimary: false))
            .accessibilityIdentifier("taskDraft.skip.\(draft.id)")
        }
        .padding(10)
        .background(AppPalette.receivedBubble)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var detailText: String {
        let assignee = draft.assigneeID.flatMap { id in
            appState.participants.first(where: { $0.id == id })?.displayName
        } ?? "Choose assignee"
        let due = draft.dueDate.map { "Due \($0.weChoreShortDueText)" } ?? "No due date"
        return "\(assignee) • \(due)"
    }
}

private struct ActiveTaskRow: View {
    @Environment(AppState.self) private var appState
    let chore: Chore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: chore.status == .inProgress ? "clock.fill" : "checklist")
                .foregroundStyle(AppPalette.weChatGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(chore.dueDate == nil ? AppPalette.muted : AppPalette.warning)
            }
            Spacer(minLength: 8)
            Button {
                Task { await appState.scheduleReminder(for: chore) }
            } label: {
                Text("Remind")
                    .accessibilityIdentifier("taskTile.remind.\(chore.id)")
            }
            .buttonStyle(TileMiniButtonStyle(isPrimary: false))
            .accessibilityIdentifier("taskTile.remind.\(chore.id)")
            Button {
                appState.updateStatus(choreID: chore.id, status: .done)
            } label: {
                Text("Done")
                    .accessibilityIdentifier("taskTile.done.\(chore.id)")
            }
            .buttonStyle(TileMiniButtonStyle(isPrimary: true))
            .accessibilityIdentifier("taskTile.done.\(chore.id)")
        }
        .padding(10)
        .background(AppPalette.receivedBubble)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var detailText: String {
        let due = chore.dueDate.map { "Due \($0.weChoreShortDueText)" } ?? chore.status.displayName
        return "\(appState.assigneeName(for: chore)) • \(due)"
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
            Text(message.body)
                .font(.caption.weight(.semibold))
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

private struct StatusToast: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let message = appState.lastStatusMessage {
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppPalette.surface)
                .accessibilityIdentifier("status.message")
        }
    }
}

private struct ChatComposer: View {
    @Environment(AppState.self) private var appState
    @Binding var draft: String
    @Binding var isVoiceMode: Bool
    @Binding var isActionPanelOpen: Bool
    @FocusState.Binding var isDraftFocused: Bool
    let send: () -> Void
    let startVoice: () -> Void
    let finishVoice: () -> Void

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                isVoiceMode.toggle()
                isActionPanelOpen = false
                isDraftFocused = !isVoiceMode
            } label: {
                Image(systemName: isVoiceMode ? "keyboard" : "mic.fill")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("message.voiceMode")

            if isVoiceMode {
                VoiceRecordButton(
                    isRecording: appState.isRecordingVoiceMessage,
                    start: startVoice,
                    finish: finishVoice
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

            Button {
                isActionPanelOpen.toggle()
                isDraftFocused = false
            } label: {
                Image(systemName: isActionPanelOpen ? "xmark.circle.fill" : "plus.circle.fill")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("message.more")

            if !isVoiceMode {
                Button("Send", action: send)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(canSend ? AppPalette.onAccent : AppPalette.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(canSend ? AppPalette.weChatGreen : AppPalette.receivedBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(!canSend)
                    .accessibilityIdentifier("message.post")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct VoiceRecordButton: View {
    @State private var isPressing = false

    let isRecording: Bool
    let start: () -> Void
    let finish: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isRecording ? "waveform.circle.fill" : "waveform")
            Text(isRecording ? "Release to Send" : "Hold to Talk")
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .font(.headline)
        .foregroundStyle(AppPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 42)
        .padding(.horizontal, 10)
        .background(isRecording ? AppPalette.weChatGreen.opacity(0.45) : AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressing else { return }
                    isPressing = true
                    start()
                }
                .onEnded { _ in
                    guard isPressing else { return }
                    isPressing = false
                    finish()
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            isRecording ? finish() : start()
        }
        .accessibilityIdentifier("message.voiceHold")
    }
}

private struct ConversationActionPanel: View {
    let invitePayload: InvitePayload?
    let newTask: () -> Void
    let createInvite: () -> Void

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
                ShareLink(item: invitePayload.shareText) {
                    VStack(spacing: 8) {
                        Image(systemName: "airplayaudio")
                            .font(.title3)
                            .frame(width: 40, height: 40)
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
                    .frame(width: 40, height: 40)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Join or Start")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppPalette.ink)

                JoinStartPanel(title: "Start a group chat") {
                    TextField("Family, weekend crew, soccer carpool", text: $groupTitle)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("join.groupTitle")
                    Button("Start Group") {
                        openThread(appState.createGroupChat(title: groupTitle))
                        groupTitle = ""
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("join.startGroup")
                }

                JoinStartPanel(title: "Start a DM") {
                    TextField("Name", text: $dmName)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("join.dmName")
                    TextField("Phone or email", text: $dmContact)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("join.dmContact")
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
                    .accessibilityIdentifier("join.startDM")
                }

                JoinStartPanel(title: "Join with code") {
                    TextField("Invite code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("join.inviteCode")
                    Button("Join Code") {
                        if let threadID = appState.acceptInviteCode(inviteCode) {
                            openThread(threadID)
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
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
    }

    private func openThread(_ threadID: String) {
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

private struct TileMiniButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(isPrimary ? AppPalette.onAccent : AppPalette.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(isPrimary ? AppPalette.weChatGreen : AppPalette.surface)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
