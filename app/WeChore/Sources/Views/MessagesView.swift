import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    let threadID: String

    @State private var draft = ""
    @State private var searchText = ""
    @State private var isVoiceMode = false
    @State private var isActionPanelOpen = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var invitePayload: InvitePayload?
    @State private var isInviteSheetPresented = false
    @FocusState private var isDraftFocused: Bool

    private let bottomID = "conversation.bottom"

    var body: some View {
        VStack(spacing: 0) {
            ConversationHeader(
                threadID: threadID,
                invitePayload: $invitePayload,
                openInviteSheet: openInviteSheet
            )
            AppStatusBanner(allowsUndo: true)
            FloatingTaskTile(threadID: threadID)
            ConversationScroll(threadID: threadID, bottomID: bottomID, searchText: searchText)
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
                        threadID: threadID,
                        close: { isActionPanelOpen = false }
                    )
                }
            }
            .padding(.bottom, 34)
            .background(AppPalette.chrome)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(appState.thread(for: threadID)?.title ?? "Chat")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
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
        .sheet(isPresented: $isInviteSheetPresented) {
            if let invitePayload {
                NavigationStack {
                    ScrollView {
                        InviteQRCodeCard(
                            payload: invitePayload,
                            title: "Invite People",
                            detail: "Share this link, code, or QR to add someone to this chat."
                        )
                            .padding(18)
                    }
                    .background(AppPalette.canvas)
                    .navigationTitle("Invite")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isInviteSheetPresented = false
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

    private func openInviteSheet() {
        invitePayload = appState.createInvite(for: threadID) ?? appState.activeInvitePayload(for: threadID)
        isInviteSheetPresented = invitePayload != nil
    }

    private func sendPhotoMessage(_ data: Data) async {
        await appState.postImageMessage(imageData: data, in: threadID)
    }
}

private struct ConversationHeader: View {
    @Environment(AppState.self) private var appState
    let threadID: String
    @Binding var invitePayload: InvitePayload?
    let openInviteSheet: () -> Void

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
            Button(action: openInviteSheet) {
                Label("Invite", systemImage: invitePayload == nil ? "person.badge.plus" : "qrcode")
                    .labelStyle(.titleAndIcon)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("conversation.invite")
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

    private var recentlyDoneTasks: [Chore] {
        appState.chores
            .filter { $0.threadID == threadID && $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(2)
            .map { $0 }
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

            if drafts.isEmpty && activeTasks.isEmpty && recentlyDoneTasks.isEmpty {
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
                        router.openOnPhone(.taskInbox)
                        router.selectOnIPad(.taskInbox)
                    } label: {
                        Label("\(activeTasks.count - 3) more in Task Inbox", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(TaskActionButtonStyle(isPrimary: false))
                    .accessibilityIdentifier("taskTile.viewAll")
                }
                if !recentlyDoneTasks.isEmpty {
                    Divider()
                    ForEach(recentlyDoneTasks) { chore in
                        RecentlyDoneTaskRow(chore: chore)
                    }
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
        if drafts.isEmpty && activeTasks.isEmpty && recentlyDoneTasks.isEmpty {
            return "No open tasks"
        }
        let draftText = drafts.isEmpty ? nil : "\(drafts.count) to confirm"
        let activeText = activeTasks.isEmpty ? nil : "\(activeTasks.count) active"
        let doneText = recentlyDoneTasks.isEmpty ? nil : "\(recentlyDoneTasks.count) done"
        return [draftText, activeText, doneText].compactMap(\.self).joined(separator: " • ")
    }
}

private struct RecentlyDoneTaskRow: View {
    let chore: Chore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusIcon(systemName: "checkmark.circle.fill", color: AppPalette.weChatGreen)
            VStack(alignment: .leading, spacing: 3) {
                Text(chore.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text("Completed \(chore.updatedAt.weChoreShortDueText)")
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
            }
            Spacer()
        }
        .accessibilityIdentifier("taskTile.doneRecent.\(chore.id)")
    }
}

private struct DraftTaskRow: View {
    @Environment(AppState.self) private var appState
    let draft: TaskDraft
    let threadID: String
    @State private var hasAppeared = false

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
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        appState.confirmDraft(draft, assigneeID: participantID)
                    }
                }
            } else {
                ResponsiveTaskActions {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.weChatGreen.opacity(hasAppeared ? 0 : 0.6), lineWidth: 2)
                .animation(.easeOut(duration: 1.5).delay(0.5), value: hasAppeared)
        )
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.8)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                hasAppeared = true
            }
        }
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
    var searchText: String = ""

    private var filteredMessages: [ChoreMessage] {
        let all = appState.messages(in: threadID)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return all }
        return all.filter { $0.body.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredMessages.isEmpty {
                        if searchText.isEmpty {
                            EmptyConversationState()
                        } else {
                            Text("No messages matching \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.muted)
                                .padding(18)
                        }
                    }
                    ForEach(filteredMessages) { message in
                        MessageBubble(message: message, highlightText: searchText)
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
    var highlightText: String = ""

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
                        highlightedText(
                            message.kind == .voice ? "Transcript: \(message.body)" : message.body
                        )
                        .font(.body)
                        .foregroundStyle(isCurrentUser ? AppPalette.onAccent : AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                        ForEach(MessageLinkDetector.urls(in: message.body), id: \.absoluteString) { url in
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                    Text(url.absoluteString)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .font(.caption)
                                .foregroundStyle(isCurrentUser ? AppPalette.onAccent.opacity(0.85) : AppPalette.weChatGreen)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? AppPalette.sentBubble : AppPalette.receivedBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: 560, alignment: isCurrentUser ? .trailing : .leading)
                    .contextMenu {
                        ForEach(["👍", "❤️", "😂", "✅"], id: \.self) { emoji in
                            Button {
                                appState.toggleReaction(emoji: emoji, messageID: message.id)
                            } label: {
                                Text(emoji)
                            }
                        }
                        if isCurrentUser {
                            Button(role: .destructive) {
                                appState.deleteMessage(id: message.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if !message.reactions.isEmpty {
                        ReactionPills(reactions: message.reactions)
                    }

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

    @ViewBuilder
    private func highlightedText(_ text: String) -> some View {
        let query = highlightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            Text(text)
        } else {
            Text(Self.highlighted(text, matching: query))
        }
    }

    private static func highlighted(_ text: String, matching query: String) -> AttributedString {
        var result = AttributedString(text)
        let lowered = text.lowercased()
        let queryLowered = query.lowercased()
        var offset = lowered.startIndex
        while let range = lowered[offset...].range(of: queryLowered) {
            let startDist = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
            let endDist = lowered.distance(from: lowered.startIndex, to: range.upperBound)
            let attrStart = result.index(result.startIndex, offsetByCharacters: startDist)
            let attrEnd = result.index(result.startIndex, offsetByCharacters: endDist)
            result[attrStart ..< attrEnd].backgroundColor = .yellow.opacity(0.35)
            offset = range.upperBound
        }
        return result
    }
}

private struct ReactionPills: View {
    let reactions: [MessageReaction]

    private var grouped: [(emoji: String, count: Int)] {
        var counts: [(emoji: String, count: Int)] = []
        for reaction in reactions {
            if let idx = counts.firstIndex(where: { $0.emoji == reaction.emoji }) {
                counts[idx].count += 1
            } else {
                counts.append((emoji: reaction.emoji, count: 1))
            }
        }
        return counts
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(grouped, id: \.emoji) { item in
                HStack(spacing: 2) {
                    Text(item.emoji)
                    if item.count > 1 {
                        Text("\(item.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppPalette.muted)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(AppPalette.surface)
                .clipShape(Capsule())
            }
        }
    }
}

private enum MessageLinkDetector {
    static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
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
                .keyboardShortcut(.return, modifiers: .command)
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
    @Environment(AppState.self) private var appState
    let threadID: String
    let close: () -> Void

    @State private var title = ""
    @State private var selectedMemberID = ""
    @State private var duePreset: ManualDuePreset = .tomorrow

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && appState.members.contains(where: { $0.id == selectedMemberID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add task manually")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("chat.action.newTask")

            TextField("Task name", text: $title)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("chat.manualTask.title")

            Picker("Assign to", selection: $selectedMemberID) {
                ForEach(appState.members) { member in
                    Text(member.displayName).tag(member.id)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("chat.manualTask.assignee")

            Picker("Due", selection: $duePreset) {
                ForEach(ManualDuePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("chat.manualTask.duePreset")

            HStack(spacing: 8) {
                Button("Add Task", action: addTask)
                    .buttonStyle(TaskActionButtonStyle(isPrimary: true))
                    .disabled(!canAdd)
                    .accessibilityIdentifier("chat.manualTask.save")
                Button("Close", action: close)
                    .buttonStyle(TaskActionButtonStyle(isPrimary: false))
                    .accessibilityIdentifier("chat.manualTask.close")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .background(AppPalette.chrome)
        .onAppear {
            if selectedMemberID.isEmpty {
                selectedMemberID = appState.currentMember.id
            }
        }
    }

    private func addTask() {
        let didAdd = appState.addChore(
            title: title,
            assigneeID: selectedMemberID,
            dueDate: duePreset.dueDate(),
            threadID: threadID
        )
        guard didAdd else { return }
        title = ""
        close()
    }
}

private enum ManualDuePreset: String, CaseIterable, Identifiable {
    case none = "No due date"
    case today = "Today"
    case tomorrow = "Tomorrow"

    var id: String { rawValue }

    func dueDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .none: return nil
        case .today: return calendar.endOfDay(afterAdding: 0, to: now)
        case .tomorrow: return calendar.endOfDay(afterAdding: 1, to: now)
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

private extension Calendar {
    func endOfDay(afterAdding dayCount: Int, to date: Date) -> Date? {
        guard let targetDay = self.date(byAdding: .day, value: dayCount, to: startOfDay(for: date)),
              let nextDay = self.date(byAdding: .day, value: 1, to: targetDay) else {
            return nil
        }
        return self.date(byAdding: .second, value: -1, to: nextDay)
    }
}
