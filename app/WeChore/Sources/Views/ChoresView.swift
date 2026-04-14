import SwiftUI

struct ChoresView: View {
    @Environment(AppState.self) private var appState
    @State private var title = ""
    @State private var selectedMemberID = ""
    @State private var duePreset: DuePreset = .tomorrow
    @State private var scope: TaskScope = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderSummary(scope: scope)
                TaskScopePicker(scope: $scope)

                AddChorePanel(
                    title: $title,
                    selectedMemberID: $selectedMemberID,
                    duePreset: $duePreset,
                    canAdd: canAddChore,
                    add: addChore
                )

                TaskSections(sections: taskSections)
            }
            .padding(18)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(AppPalette.canvas)
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
        }
    }

    private var taskSections: [TaskListSection] {
        let active = filteredChores.filter(\.isActive)
        let blocked = active.filter { $0.status == .blocked }
        let unblocked = active.filter { $0.status != .blocked }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let done = filteredChores.filter { $0.status == .done }

        return [
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
                emptyText: "Nothing due today."
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
            TaskListSection(title: "Done", chores: Array(done.prefix(6)), emptyText: nil)
        ]
    }

    private func addChore() {
        let didAdd = appState.addChore(
            title: title,
            assigneeID: selectedMemberID.isEmpty ? appState.currentMember.id : selectedMemberID,
            dueDate: duePreset.dueDate()
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

private enum DuePreset: String, CaseIterable, Identifiable {
    case none = "No due date"
    case today = "Today"
    case tomorrow = "Tomorrow"

    var id: String { rawValue }

    func dueDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:
            return nil
        case .today:
            return calendar.endOfDay(afterAdding: 0, to: now)
        case .tomorrow:
            return calendar.endOfDay(afterAdding: 1, to: now)
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

private struct AddChorePanel: View {
    @Environment(AppState.self) private var appState
    @Binding var title: String
    @Binding var selectedMemberID: String
    @Binding var duePreset: DuePreset
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
            Button("Add Task", action: add)
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
        VStack(alignment: .leading, spacing: 18) {
            ForEach(sections) { section in
                if !section.chores.isEmpty || section.emptyText != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.title3.bold())
                            .foregroundStyle(AppPalette.ink)
                        if section.chores.isEmpty, let emptyText = section.emptyText {
                            EmptyState(text: emptyText)
                        } else {
                            ForEach(section.chores) { chore in
                                ChoreRow(chore: chore)
                            }
                        }
                    }
                }
            }
        }
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
                    if let dueDate = chore.dueDate {
                        Text("Due \(dueDate.weChoreShortDueText)")
                            .font(.footnote)
                            .foregroundStyle(chore.isActive ? AppPalette.warning : AppPalette.muted)
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
        .sheet(isPresented: $isEditorPresented) {
            NavigationStack {
                TaskEditorSheet(chore: chore)
            }
        }
    }
}

private struct ChoreActionGroup: View {
    @Environment(AppState.self) private var appState
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
                appState.updateStatus(choreID: chore.id, status: .open)
            }
            ChoreControlButton(title: "Archive", identifier: "chore.archive.\(chore.id)") {
                appState.updateStatus(choreID: chore.id, status: .archived)
            }
        } else {
            ChoreControlButton(title: "Start", identifier: "chore.start.\(chore.id)") {
                appState.updateStatus(choreID: chore.id, status: .inProgress)
            }
            ChoreControlButton(title: "Blocked", identifier: "chore.blocked.\(chore.id)") {
                appState.updateStatus(choreID: chore.id, status: .blocked)
            }
            ChoreControlButton(title: "Done", identifier: "chore.done.\(chore.id)") {
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
    @State private var status: ChoreStatus = .open

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

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(ChoreStatus.allCases) { option in
                        Text(option.displayName).tag(option)
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
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && appState.members.contains(where: { $0.id == selectedMemberID })
    }

    private func load() {
        title = chore.title
        selectedMemberID = chore.assigneeID
        notes = chore.notes
        hasDueDate = chore.dueDate != nil
        dueDate = chore.dueDate ?? Date()
        status = chore.status
    }

    private func save() {
        guard appState.updateChore(
            choreID: chore.id,
            title: title,
            assigneeID: selectedMemberID,
            dueDate: hasDueDate ? dueDate : nil,
            notes: notes
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
