import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        @Bindable var router = router
        Group {
            if appState.settings.hasCompletedOnboarding {
                if horizontalSizeClass == .regular {
                    IPadRootView()
                } else {
                    PhoneRootView()
                }
            } else {
                OnboardingView()
            }
        }
        .background(AppPalette.canvas)
        .sheet(item: $router.activeModal) { modal in
            switch modal {
            case .newChat:
                NewChatSheet()
            }
        }
    }
}

private struct PhoneRootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.phonePath) {
            ChatTreeView(
                open: { destination in router.openOnPhone(destination) },
                presentNewChat: { router.presentNewChat() }
            )
            .navigationTitle("Chats")
            .navigationDestination(for: ChatDestination.self) { destination in
                ChatDestinationView(destination: destination)
            }
        }
        .accessibilityIdentifier("root.phoneChatTree")
    }
}

private struct IPadRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ChatTreeView(
                open: { destination in router.selectOnIPad(destination) },
                presentNewChat: { router.presentNewChat() }
            )
            .navigationTitle("Chats")
            .accessibilityIdentifier("root.sidebar")
        } detail: {
            NavigationStack {
                ChatDestinationView(destination: selectedDestination)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .accessibilityIdentifier("root.ipadSplit")
    }

    private var selectedDestination: ChatDestination {
        if let selected = router.selectedDestination {
            return selected
        }
        if let first = appState.threads.first {
            return .thread(first.id)
        }
        if !appState.chores.isEmpty {
            return .taskInbox
        }
        return .settings
    }
}

private struct ChatDestinationView: View {
    let destination: ChatDestination

    var body: some View {
        switch destination {
        case let .thread(threadID):
            ConversationView(threadID: threadID)
        case .taskInbox:
            TaskInboxView()
        case .settings:
            SettingsView()
        }
    }
}

struct ChatTreeView: View {
    @Environment(AppState.self) private var appState
    let open: (ChatDestination) -> Void
    let presentNewChat: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.threads.isEmpty {
                ContentUnavailableView {
                    Label("No chats yet", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Start a chat to begin tracking todos with your people.")
                } actions: {
                    Button("New Chat", action: presentNewChat)
                        .buttonStyle(PrimaryActionButtonStyle())
                        .accessibilityIdentifier("chatTree.emptyNewChat")
                }
            }

            List {
                if !appState.groupThreads.isEmpty {
                    Section("Group chats") {
                        ForEach(appState.groupThreads) { thread in
                            ChatThreadRow(thread: thread) {
                                open(.thread(thread.id))
                            }
                        }
                    }
                }

                if !appState.dmThreads.isEmpty {
                    Section("DMs") {
                        ForEach(appState.dmThreads) { thread in
                            ChatThreadRow(thread: thread) {
                                open(.thread(thread.id))
                            }
                        }
                    }
                }

                Section {
                    Button {
                        open(.taskInbox)
                    } label: {
                        Label(taskInboxLabel, systemImage: "checklist.checked")
                    }
                    .accessibilityIdentifier("chatTree.taskInbox")

                    Button {
                        open(.settings)
                    } label: {
                        Label("Me", systemImage: "person.crop.circle.fill")
                    }
                    .accessibilityIdentifier("chatTree.me")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable {
                await appState.refresh()
            }
        }
        .background(AppPalette.canvas)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: presentNewChat) {
                    Label("New Chat", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("chatTree.newChat")
            }
        }
        .accessibilityIdentifier("chat.tree")
    }

    private var taskInboxLabel: String {
        let count = appState.activeChores.count
        return count == 0 ? "Task Inbox" : "Task Inbox (\(count))"
    }
}

private struct ChatThreadRow: View {
    @Environment(AppState.self) private var appState
    let thread: ChatThread
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                ThreadAvatar(thread: thread)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(thread.title)
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)
                            .lineLimit(1)
                        if appState.isThreadMuted(threadID: thread.id) {
                            Image(systemName: "bell.slash.fill")
                                .font(.caption2)
                                .foregroundStyle(AppPalette.muted)
                        }
                        Spacer()
                        Text(thread.lastActivityAt.weChoreShortDueText)
                            .font(.caption2)
                            .foregroundStyle(AppPalette.muted)
                    }
                    Text(appState.lastMessagePreview(for: thread))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                        .lineLimit(2)
                    if activeTaskCount > 0 {
                        Text(activeTaskCount == 1 ? "1 active task" : "\(activeTaskCount) active tasks")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.weChatGreen)
                    }
                }
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appState.toggleThreadMute(threadID: thread.id)
            } label: {
                Label(
                    appState.isThreadMuted(threadID: thread.id) ? "Unmute" : "Mute",
                    systemImage: appState.isThreadMuted(threadID: thread.id) ? "bell.fill" : "bell.slash.fill"
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens chat.")
        .accessibilityIdentifier("chat.thread.\(thread.id)")
    }

    private var activeTaskCount: Int {
        appState.activeChores(in: thread.id).count
    }

    private var accessibilityLabel: String {
        let taskText = activeTaskCount == 1 ? "1 active task" : "\(activeTaskCount) active tasks"
        return "\(thread.title), \(thread.kind.displayName), \(taskText)"
    }
}

private struct ThreadAvatar: View {
    @Environment(AppState.self) private var appState
    let thread: ChatThread

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(thread.kind == .group ? AppPalette.weChatGreen : AppPalette.surface)
            if let emoji = firstParticipantEmoji {
                Text(emoji)
                    .font(.title2)
            } else {
                Image(systemName: thread.kind == .group ? "person.2.fill" : "person.fill")
                    .font(.headline)
                    .foregroundStyle(thread.kind == .group ? AppPalette.onAccent : AppPalette.ink)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }

    private var firstParticipantEmoji: String? {
        appState.participants(in: thread.id)
            .first(where: { $0.avatarEmoji != nil })?.avatarEmoji
    }
}
