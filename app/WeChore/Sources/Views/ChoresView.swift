import SwiftUI
import UIKit

struct ChoresView: View {
    @Environment(AppState.self) private var appState
    @State private var title = ""
    @State private var selectedMemberID = ""
    @State private var duePreset: DuePreset = .tomorrow
    @State private var customDate = Date()
    @State private var scope: TaskScope = .all
    @State private var searchText = ""
    @State private var sortOrder: TaskSortOrder = .dueDate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderSummary(scope: scope)
                TaskScopePicker(scope: $scope)
                TaskSortPicker(sortOrder: $sortOrder)

                AddChorePanel(
                    title: $title,
                    selectedMemberID: $selectedMemberID,
                    duePreset: $duePreset,
                    customDate: $customDate,
                    canAdd: canAddChore,
                    add: addChore
                )

                TaskSections(sections: taskSections)
            }
            .padding(18)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(AppPalette.canvas)
        .searchable(text: $searchText, prompt: "Search tasks")
        .navigationTitle("Tasks")
        .safeAreaInset(edge: .bottom) {
            AppStatusBanner(allowsUndo: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .onAppear(perform: syncSelectedMember)
        .onChange(of: appState.members) { _, _ in
            syncSelectedMember()
        }
    }

    private var filteredChores: [Chore] {
        appState.chores.filter { chore in
            chore.status != .archived
                && (scope == .all || chore.assigneeID == appState.currentParticipant.id)
                && (searchText.isEmpty || chore.title.localizedCaseInsensitiveContains(searchText)
                    || chore.notes.localizedCaseInsensitiveContains(searchText)
                    || appState.assigneeName(for: chore).localizedCaseInsensitiveContains(searchText))
        }
    }

    private var taskSections: [TaskListSection] {
        let active = filteredChores.filter(\.isActive)
        let blocked = active.filter { $0.status == .blocked }
        let unblocked = active.filter { $0.status != .blocked }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let done = filteredChores.filter { $0.status == .done }

        let sections: [TaskListSection]
        switch sortOrder {
        case .dueDate:
            sections = [
                TaskListSection(title: "Blocked", chores: blocked, emptyText: nil),
                TaskListSection(
                    title: "Overdue",
                    chores: unblocked.filter { ($0.dueDate ?? .distantFuture) < today },
                    emptyText: nil
                ),
                TaskListSection(
                    title: "Today",
                    chores: unblocked.filter { chore in
                        chore.dueDate.map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false
                    },
                    emptyText: "Nothing due today. Send a message like \"Take out the trash tonight\" and WeChore will create the task."
                ),
                TaskListSection(
                    title: "Upcoming",
                    chores: unblocked.filter { ($0.dueDate ?? .distantPast) >= tomorrow },
                    emptyText: nil
                ),
                TaskListSection(
                    title: "No due date",
                    chores: unblocked.filter { $0.dueDate == nil },
                    emptyText: nil
                ),
                TaskListSection(title: "Done", chores: Array(done.prefix(6)), emptyText: nil),
            ]
        case .urgency:
            let urgencyOrder: (Chore) -> Int = { chore in
                switch chore.urgency {
                case .urgent: 0
                case .soon: 1
                case .normal: 2
                }
            }
            let sorted = unblocked.sorted { urgencyOrder($0) < urgencyOrder($1) }
            sections = [
                TaskListSection(title: "Blocked", chores: blocked, emptyText: nil),
                TaskListSection(title: "Active", chores: sorted, emptyText: "No active tasks."),
                TaskListSection(title: "Done", chores: Array(done.prefix(6)), emptyText: nil),
            ]
        case .title:
            let sorted = unblocked.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            sections = [
                TaskListSection(title: "Blocked", chores: blocked, emptyText: nil),
                TaskListSection(title: "Active", chores: sorted, emptyText: "No active tasks."),
                TaskListSection(title: "Done", chores: Array(done.prefix(6)), emptyText: nil),
            ]
        }
        return sections
    }

    private func addChore() {
        let didAdd = appState.addChore(
            title: title,
            assigneeID: selectedMemberID.isEmpty ? appState.currentMember.id : selectedMemberID,
            dueDate: duePreset.dueDate(customDate: customDate)
        )
        if didAdd {
            title = ""
        }
    }

    private func syncSelectedMember() {
        guard !appState.members.isEmpty else {
            selectedMemberID = ""
            return
        }
        if selectedMemberID.isEmpty || !appState.members.contains(where: { $0.id == selectedMemberID }) {
            selectedMemberID = appState.currentMember.id
        }
    }

    private var canAddChore: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && appState.members.contains(where: { $0.id == selectedMemberID })
    }
}

private enum TaskScope: String, CaseIterable, Identifiable {
    case all = "All"
    case mine = "Mine"

    var id: String { rawValue }
}

private enum TaskSortOrder: String, CaseIterable, Identifiable {
    case dueDate = "Due date"
    case urgency = "Urgency"
    case title = "Title"

    var id: String { rawValue }
}

private enum DuePreset: String, CaseIterable, Identifiable {
    case none = "No due date"
    case today = "Today"
    case tomorrow = "Tomorrow"
    case custom = "Pick date"

    var id: String { rawValue }

    func dueDate(customDate: Date = Date(), now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:
            return nil
        case .today:
            return calendar.endOfDay(afterAdding: 0, to: now)
        case .tomorrow:
            return calendar.endOfDay(afterAdding: 1, to: now)
        case .custom:
            return calendar.endOfDay(afterAdding: 0, to: customDate)
        }
    }
}

private struct TaskListSection: Identifiable {
    var title: String
    var chores: [Chore]
    var emptyText: String?

    var id: String { title }
}

private struct HeaderSummary: View {
    @Environment(AppState.self) private var appState
    let scope: TaskScope

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks")
                .font(.largeTitle.bold())
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("chores.title")
            Text(summaryText)
                .font(.headline)
                .foregroundStyle(AppPalette.muted)
                .accessibilityIdentifier("chores.assignmentSummary")
        }
    }

    private var summaryText: String {
        let active = scope == .all
            ? appState.activeChores.count
            : appState.currentMemberChores.filter(\.isActive).count
        let label = active == 1 ? "1 active task" : "\(active) active tasks"
        return scope == .all ? label : "\(label) assigned to \(appState.currentMember.displayName)"
    }
}

private struct TaskScopePicker: View {
    @Binding var scope: TaskScope

    var body: some View {
        Picker("Task scope", selection: $scope) {
            ForEach(TaskScope.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("tasks.scope")
    }
}

private struct TaskSortPicker: View {
    @Binding var sortOrder: TaskSortOrder

    var body: some View {
        Picker("Sort by", selection: $sortOrder) {
            ForEach(TaskSortOrder.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("tasks.sortOrder")
    }
}

private struct AddChorePanel: View {
    @Environment(AppState.self) private var appState
    @Binding var title: String
    @Binding var selectedMemberID: String
    @Binding var duePreset: DuePreset
    @Binding var customDate: Date
    let canAdd: Bool
    let add: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New task")
                .font(.headline)
            TextField("Take out trash", text: $title)
                .accessibilityIdentifier("chore.title")
                .textFieldStyle(.roundedBorder)
            Picker("Assign to", selection: $selectedMemberID) {
                ForEach(appState.members) { member in
                    Text(member.displayName).tag(member.id)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("chore.assignee")
            Picker("Due", selection: $duePreset) {
                ForEach(DuePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("chore.duePreset")
            if duePreset == .custom {
                DatePicker("Custom date", selection: $customDate, displayedComponents: .date)
                    .accessibilityIdentifier("chore.customDate")
            }
            Button("Add Task", action: add)
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!canAdd)
                .accessibilityIdentifier("chore.add")
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TaskSections: View {
    let sections: [TaskListSection]

    var body: some View {
        List {
            ForEach(sections) { section in
                if !section.chores.isEmpty || section.emptyText != nil {
                    Section {
                        if section.chores.isEmpty, let emptyText = section.emptyText {
                            EmptyState(text: emptyText)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(section.chores) { chore in
                                ChoreRow(chore: chore)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        Text(section.title)
                            .font(.title3.bold())
                            .foregroundStyle(AppPalette.ink)
                            .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .frame(minHeight: 200)
    }
}

private struct ChoreRow: View {
    @Environment(AppState.self) private var appState
    @State private var isEditorPresented = false
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chore.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("chore.row.\(chore.id).title")
                    Text("\(appState.assigneeName(for: chore)) • \(chore.status.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.muted)
                    if chore.urgency == .urgent {
                        Text("Urgent")
                            .font(.caption.bold())
                            .foregroundStyle(AppPalette.danger)
                    } else if chore.urgency == .soon {
                        Text("Soon")
                            .font(.caption.bold())
                            .foregroundStyle(AppPalette.warning)
                    }
                    if let dueDate = chore.dueDate {
                        Text("Due \(dueDate.weChoreShortDueText)")
                            .font(.footnote)
                            .foregroundStyle(chore.isActive ? AppPalette.warning : AppPalette.muted)
                    }
                    if chore.recurrence != nil {
                        Label(
                            chore.recurrence == "daily" ? "Daily" : "Weekly",
                            systemImage: "arrow.clockwise"
                        )
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                    }
                    if !chore.notes.isEmpty {
                        Text(chore.notes)
                            .font(.footnote)
                            .foregroundStyle(AppPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                StatusBadge(status: chore.status)
            }

            ChoreActionGroup(chore: chore, edit: { isEditorPresented = true })
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .swipeActions(edge: .leading) {
            Button {
                appState.updateStatus(choreID: chore.id, status: .done)
            } label: {
                Label("Done", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button {
                isEditorPresented = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            NavigationStack {
                TaskEditorSheet(chore: chore)
            }
        }
    }
}

private struct ChoreActionGroup: View {
    @Environment(AppState.self) private var appState
    @State private var showArchiveConfirmation = false
    let chore: Chore
    let edit: () -> Void

    private let gridColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                actionButtons
            }

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                actionButtons
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        ChoreControlButton(title: "Edit", identifier: "chore.edit.\(chore.id)", action: edit)
        if chore.status == .done {
            ChoreControlButton(title: "Reopen", identifier: "chore.reopen.\(chore.id)") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.updateStatus(choreID: chore.id, status: .open)
            }
            ChoreControlButton(title: "Archive", identifier: "chore.archive.\(chore.id)") {
                showArchiveConfirmation = true
            }
            .confirmationDialog("Archive this task?", isPresented: $showArchiveConfirmation) {
                Button("Archive", role: .destructive) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    appState.updateStatus(choreID: chore.id, status: .archived)
                }
            }
        } else {
            ChoreControlButton(title: "Start", identifier: "chore.start.\(chore.id)") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.updateStatus(choreID: chore.id, status: .inProgress)
            }
            ChoreControlButton(title: "Blocked", identifier: "chore.blocked.\(chore.id)") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.updateStatus(choreID: chore.id, status: .blocked)
            }
            ChoreControlButton(title: "Done", identifier: "chore.done.\(chore.id)") {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                appState.updateStatus(choreID: chore.id, status: .done)
            }
            ChoreControlButton(title: "Remind", identifier: "chore.remind.\(chore.id)") {
                Task { await appState.scheduleReminder(for: chore) }
            }
            ChoreControlButton(title: "Message", identifier: "chore.message.\(chore.id)") {
                appState.prepareTextReminder(for: chore)
            }
            ChoreControlButton(title: "Voice", identifier: "chore.voice.\(chore.id)") {
                Task { await appState.startVoiceHandoff(for: chore) }
            }
        }
    }
}

private struct TaskEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let chore: Chore

    @State private var title = ""
    @State private var selectedMemberID = ""
    @State private var notes = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var recurrence: String?
    @State private var status: ChoreStatus = .open
    @State private var originalUpdatedAt = Date()
    @State private var showConflictAlert = false

    var body: some View {
        Form {
            Section("Task") {
                TextField("Title", text: $title)
                    .accessibilityIdentifier("taskEditor.title")
                Picker("Assignee", selection: $selectedMemberID) {
                    ForEach(appState.members) { member in
                        Text(member.displayName).tag(member.id)
                    }
                }
                Toggle("Has due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Repeat") {
                Picker("Recurrence", selection: $recurrence) {
                    Text("Never").tag(String?.none)
                    Text("Daily").tag(String?.some("daily"))
                    Text("Weekly").tag(String?.some("weekly"))
                }
            }

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(ChoreStatus.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            }

            Section("Activity") {
                let activities = appState.activities(for: chore.id)
                if activities.isEmpty {
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                } else {
                    ForEach(activities) { activity in
                        HStack {
                            Text(activity.kind.rawValue.capitalized)
                                .font(.subheadline)
                            Spacer()
                            Text(activity.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(AppPalette.muted)
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Task")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
                    .accessibilityIdentifier("taskEditor.save")
            }
        }
        .onAppear(perform: load)
        .alert("Task was modified", isPresented: $showConflictAlert) {
            Button("Overwrite") { forceSave() }
            Button("Discard my changes", role: .cancel) { dismiss() }
        } message: {
            Text("Someone else changed this task while you were editing. Overwrite with your changes?")
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && appState.members.contains(where: { $0.id == selectedMemberID })
    }

    private func load() {
        originalUpdatedAt = chore.updatedAt
        title = chore.title
        selectedMemberID = chore.assigneeID
        notes = chore.notes
        hasDueDate = chore.dueDate != nil
        dueDate = chore.dueDate ?? Date()
        recurrence = chore.recurrence
        status = chore.status
    }

    private func save() {
        if let current = appState.chores.first(where: { $0.id == chore.id }),
           current.updatedAt > originalUpdatedAt {
            showConflictAlert = true
            return
        }
        forceSave()
    }

    private func forceSave() {
        guard appState.updateChore(
            choreID: chore.id,
            title: title,
            assigneeID: selectedMemberID,
            dueDate: hasDueDate ? dueDate : nil,
            notes: notes,
            recurrence: recurrence
        ) else {
            return
        }
        if status != chore.status {
            appState.updateStatus(choreID: chore.id, status: status)
        }
        dismiss()
    }
}

private struct ChoreControlButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .accessibilityIdentifier(identifier)
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

private extension Calendar {
    func endOfDay(afterAdding dayCount: Int, to date: Date) -> Date? {
        guard let targetDay = self.date(byAdding: .day, value: dayCount, to: startOfDay(for: date)),
              let nextDay = self.date(byAdding: .day, value: 1, to: targetDay) else {
            return nil
        }
        return self.date(byAdding: .second, value: -1, to: nextDay)
    }
}
