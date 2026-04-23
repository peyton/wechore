import SwiftUI

struct TaskInboxView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                TaskInboxSections(sections: sections, openThread: openThread)
            }
            .padding(18)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(AppPalette.canvas)
        .searchable(text: $searchText, prompt: "Search tasks")
        .navigationTitle("Task Inbox")
        .safeAreaInset(edge: .bottom) {
            AppStatusBanner(allowsUndo: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Inbox")
                .font(.largeTitle.bold())
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("taskInbox.title")
            Text(summaryText)
                .font(.headline)
                .foregroundStyle(AppPalette.muted)
                .accessibilityIdentifier("taskInbox.summary")
        }
    }

    private var summaryText: String {
        let activeCount = filteredTasks.filter(\.isActive).count
        let doneCount = filteredTasks.filter { $0.status == .done }.count
        if activeCount == 0 && doneCount == 0 {
            return "No tasks yet. Start from chat and tasks appear here automatically."
        }
        return "\(activeCount) active • \(doneCount) done"
    }

    private var filteredTasks: [Chore] {
        appState.chores.filter { chore in
            chore.status != .archived
                && (searchText.isEmpty
                    || chore.title.localizedCaseInsensitiveContains(searchText)
                    || chore.notes.localizedCaseInsensitiveContains(searchText)
                    || appState.assigneeName(for: chore).localizedCaseInsensitiveContains(searchText)
                    || (appState.thread(for: chore.threadID)?.title.localizedCaseInsensitiveContains(searchText) ?? false))
        }
    }

    private var sections: [TaskInboxSection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let active = filteredTasks.filter(\.isActive)
        let doneRecent = filteredTasks
            .filter { $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }

        return [
            TaskInboxSection(
                id: "overdue",
                title: "Overdue",
                chores: active
                    .filter { ($0.dueDate ?? .distantFuture) < today }
                    .sorted(by: Self.dueDateSort),
                emptyText: nil
            ),
            TaskInboxSection(
                id: "today",
                title: "Today",
                chores: active
                    .filter { chore in
                        chore.dueDate.map { calendar.isDate($0, inSameDayAs: today) } ?? false
                    }
                    .sorted(by: Self.dueDateSort),
                emptyText: nil
            ),
            TaskInboxSection(
                id: "upcoming",
                title: "Upcoming",
                chores: active
                    .filter { chore in
                        guard let due = chore.dueDate else { return true }
                        return due >= tomorrow
                    }
                    .sorted(by: Self.dueDateSort),
                emptyText: "Nothing upcoming. Add tasks by messaging in a chat."
            ),
            TaskInboxSection(
                id: "done",
                title: "Done (recent)",
                chores: Array(doneRecent.prefix(8)),
                emptyText: nil
            )
        ]
    }

    private static func dueDateSort(lhs: Chore, rhs: Chore) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func openThread(_ threadID: String) {
        router.openOnPhone(.thread(threadID))
        router.selectOnIPad(.thread(threadID))
    }
}

private struct TaskInboxSection: Identifiable {
    let id: String
    let title: String
    let chores: [Chore]
    let emptyText: String?
}

private struct TaskInboxSections: View {
    @Environment(AppState.self) private var appState
    let sections: [TaskInboxSection]
    let openThread: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(sections) { section in
                if !section.chores.isEmpty || section.emptyText != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.title3.bold())
                            .foregroundStyle(AppPalette.ink)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("taskInbox.section.\(section.id)")

                        if section.chores.isEmpty, let emptyText = section.emptyText {
                            EmptyState(text: emptyText)
                        } else {
                            ForEach(section.chores) { chore in
                                TaskInboxRow(
                                    chore: chore,
                                    threadTitle: appState.thread(for: chore.threadID)?.title ?? "Chat",
                                    assigneeName: appState.assigneeName(for: chore),
                                    openThread: openThread
                                )
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("taskInbox.sections")
    }
}

private struct TaskInboxRow: View {
    let chore: Chore
    let threadTitle: String
    let assigneeName: String
    let openThread: (String) -> Void

    var body: some View {
        Button {
            openThread(chore.threadID)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                StatusBadge(status: chore.status)

                VStack(alignment: .leading, spacing: 4) {
                    Text(chore.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("taskInbox.row.\(chore.id).title")
                    Text("\(assigneeName) • \(threadTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.muted)
                    if let dueDate = chore.dueDate {
                        Text("Due \(dueDate.weChoreShortDueText)")
                            .font(.footnote)
                            .foregroundStyle(chore.isActive ? AppPalette.warning : AppPalette.muted)
                    } else {
                        Text("No due date")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.muted)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(AppPalette.weChatGreen)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the source chat.")
        .accessibilityIdentifier("taskInbox.row.\(chore.id)")
    }
}

private struct StatusBadge: View {
    let status: ChoreStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(status == .done ? AppPalette.onAccent : AppPalette.ink)
            .background(status == .done ? AppPalette.weChatGreen : AppPalette.receivedBubble)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct EmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppPalette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
