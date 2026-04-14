import SwiftUI

struct MessagesView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var draft = ""
    @State private var isVoiceMode = false
    @State private var isActionPanelOpen = false
    @FocusState private var isDraftFocused: Bool

    private let bottomID = "chat.bottom"

    var body: some View {
        VStack(spacing: 0) {
            ChatRoomHeader()
            AssignedChoreStrip()
            ConversationScroll(bottomID: bottomID)
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
                    ChatActionPanel(
                        newChore: prepareNewChorePrompt,
                        openAssigned: openAssignedChores,
                        openHousehold: openHousehold,
                        openSettings: openSettings
                    )
                }
            }
            .background(AppPalette.chrome)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendTextMessage() {
        appState.postMessage(draft)
        draft = ""
        isDraftFocused = false
    }

    private func startVoiceRecording() {
        Task { await appState.startVoiceMessageRecording() }
    }

    private func finishVoiceRecording() {
        Task { await appState.finishVoiceMessageRecording() }
    }

    private func prepareNewChorePrompt() {
        isVoiceMode = false
        isActionPanelOpen = false
        draft = "Please assign "
        isDraftFocused = true
    }

    private func openAssignedChores() {
        router.selectedRoute = .chores
    }

    private func openHousehold() {
        router.selectedRoute = .household
    }

    private func openSettings() {
        router.selectedRoute = .settings
    }
}

private struct ChatRoomHeader: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(AppPalette.weChatGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.household.name)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("chat.householdName")
                Text("\(appState.members.count) members")
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(AppPalette.chrome)
    }
}

private struct AssignedChoreStrip: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    private var assignedChores: [Chore] {
        appState.currentMemberChores.filter(\.isActive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Assigned to you")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }
                Spacer(minLength: 12)
                Button("All chores") {
                    router.selectedRoute = .chores
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.weChatGreen)
                .accessibilityIdentifier("chat.assignedChores.open")
            }

            if assignedChores.isEmpty {
                Button {
                    router.selectedRoute = .chores
                } label: {
                    Label("Open the chore list", systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chat.assignedChores.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(assignedChores) { chore in
                            AssignedChoreCard(chore: chore)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppPalette.chrome)
    }

    private var summaryText: String {
        if assignedChores.isEmpty {
            return "\(appState.activeChores.count) active household chores"
        }
        if assignedChores.count == 1 {
            return "1 active chore for \(appState.currentMember.displayName)"
        }
        return "\(assignedChores.count) active chores for \(appState.currentMember.displayName)"
    }
}

private struct AssignedChoreCard: View {
    @Environment(AppState.self) private var appState
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chore.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(chore.dueDate.map { "Due \($0.weChoreShortDueText)" } ?? chore.status.displayName)
                .font(.caption)
                .foregroundStyle(chore.dueDate == nil ? AppPalette.muted : AppPalette.warning)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done") {
                appState.updateStatus(choreID: chore.id, status: .done)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(AppPalette.onAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppPalette.weChatGreen)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityIdentifier("chat.assignedChore.done.\(chore.id)")
        }
        .frame(width: 188, alignment: .leading)
        .padding(12)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ConversationScroll: View {
    @Environment(AppState.self) private var appState
    let bottomID: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if appState.messages.isEmpty {
                        EmptyChatState()
                    }
                    ForEach(appState.messages) { message in
                        MessageBubble(message: message)
                    }
                    SuggestionInlineList()
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
            .onChange(of: appState.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: appState.suggestions.count) { _, _ in
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

private struct EmptyChatState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title2)
                .foregroundStyle(AppPalette.weChatGreen)
            Text("Start with a household message.")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Text("Type or record a chore request, then accept the suggestion that appears here.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .accessibilityIdentifier("messages.empty")
    }
}

private struct MessageBubble: View {
    @Environment(AppState.self) private var appState
    let message: ChoreMessage

    private var isCurrentUser: Bool {
        message.authorMemberID == appState.currentMember.id
    }

    var body: some View {
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
                Avatar(name: appState.currentMember.displayName, isCurrentUser: true)
            } else {
                Spacer(minLength: 42)
            }
        }
    }

    private var authorName: String {
        appState.members.first(where: { $0.id == message.authorMemberID })?.displayName ?? "Household"
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

private struct SuggestionInlineList: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Chore suggestions")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.muted)
                    .textCase(.uppercase)
                ForEach(appState.suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SuggestionCard: View {
    @Environment(AppState.self) private var appState
    let suggestion: ChoreSuggestion

    var body: some View {
        Button {
            appState.acceptSuggestion(suggestion)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppPalette.weChatGreen)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detailText)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("Add")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.onAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppPalette.weChatGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(12)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("suggestion.accept.\(suggestion.id)")
    }

    private var detailText: String {
        let assignee = suggestion.assigneeID.flatMap { id in
            appState.members.first(where: { $0.id == id })?.displayName
        } ?? appState.currentMember.displayName
        let due = suggestion.dueDate.map { "Due \($0.weChoreShortDueText)" } ?? "No due date"
        return "\(assignee) • \(due)"
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
                TextField("Message WeChore", text: $draft, axis: .vertical)
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

private struct ChatActionPanel: View {
    let newChore: () -> Void
    let openAssigned: () -> Void
    let openHousehold: () -> Void
    let openSettings: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 116), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ChatActionButton(title: "New chore", systemImage: "square.and.pencil", action: newChore)
                .accessibilityIdentifier("chat.action.newChore")
            ChatActionButton(title: "Assigned chores", systemImage: "checklist", action: openAssigned)
                .accessibilityIdentifier("chat.action.assigned")
            ChatActionButton(title: "Household", systemImage: "person.2.fill", action: openHousehold)
                .accessibilityIdentifier("chat.action.household")
            ChatActionButton(title: "Me", systemImage: "person.crop.circle.fill", action: openSettings)
                .accessibilityIdentifier("chat.action.settings")
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
