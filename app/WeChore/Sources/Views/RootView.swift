import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
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
    }
}

private struct PhoneRootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.phonePath) {
            ChatTreeView { destination in
                router.openOnPhone(destination)
            }
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
            ChatTreeView { destination in
                router.selectOnIPad(destination)
            }
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
        return .joinStart
    }
}

private struct ChatDestinationView: View {
    let destination: ChatDestination

    var body: some View {
        switch destination {
        case let .thread(threadID):
            ConversationView(threadID: threadID)
        case .tasks:
            ChoresView()
        case .joinStart:
            JoinStartView()
        case .myQRCode:
            MyQRCodeView()
        case .settings:
            SettingsView()
        }
    }
}

struct ChatTreeView: View {
    @Environment(AppState.self) private var appState
    let open: (ChatDestination) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.threads.isEmpty {
                ContentUnavailableView {
                    Label("No chats yet", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Start a chat to begin tracking chores with your household.")
                } actions: {
                    Button("Start a Chat") { open(.joinStart) }
                        .buttonStyle(PrimaryActionButtonStyle())
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
                        open(.tasks)
                    } label: {
                        Label(tasksLabel, systemImage: "checklist.checked")
                    }
                    .accessibilityIdentifier("chatTree.tasks")

                    Button {
                        open(.joinStart)
                    } label: {
                        Label("Join or Start", systemImage: "plus.bubble.fill")
                    }
                    .accessibilityIdentifier("chatTree.joinStart")

                    Button {
                        open(.myQRCode)
                    } label: {
                        Label("My QR", systemImage: "qrcode")
                    }
                    .accessibilityIdentifier("chatTree.myQR")

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
                Button {
                    open(.tasks)
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("chatTree.newTask")
            }
        }
        .accessibilityIdentifier("chat.tree")
    }

    private var tasksLabel: String {
        let count = appState.activeChores.count
        return count == 0 ? "Tasks" : "Tasks (\(count))"
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
    let thread: ChatThread

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(thread.kind == .group ? AppPalette.weChatGreen : AppPalette.surface)
            Image(systemName: thread.kind == .group ? "person.2.fill" : "person.fill")
                .font(.headline)
                .foregroundStyle(thread.kind == .group ? AppPalette.onAccent : AppPalette.ink)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
