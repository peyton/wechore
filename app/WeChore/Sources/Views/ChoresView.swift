import SwiftUI

struct ChoresView: View {
    @Environment(AppState.self) private var appState
    @State private var title = ""
    @State private var selectedMemberID = ""
    @State private var dueTomorrow = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderSummary()

                AddChorePanel(
                    title: $title,
                    selectedMemberID: $selectedMemberID,
                    dueTomorrow: $dueTomorrow,
                    add: addChore
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Active chores")
                        .font(.title2.bold())
                        .foregroundStyle(AppPalette.ink)
                    if appState.activeChores.isEmpty {
                        EmptyState(text: "No active chores. Add one or accept a message suggestion.")
                    } else {
                        ForEach(appState.activeChores) { chore in
                            ChoreRow(chore: chore)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(AppPalette.canvas)
        .safeAreaInset(edge: .bottom) {
            if let message = appState.lastStatusMessage {
                Text(message)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("status.message")
            }
        }
        .onAppear {
            if selectedMemberID.isEmpty {
                selectedMemberID = appState.members.first?.id ?? ""
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.shouldPresentMessageComposer },
            set: { _ in appState.shouldPresentMessageComposer = false }
        )) {
            if let member = appState.preparedMessageMember {
                MessageComposeView(
                    recipients: appState.messageRecipients(for: member),
                    body: appState.preparedMessageBody,
                    onFinish: { appState.shouldPresentMessageComposer = false }
                )
            }
        }
    }

    private func addChore() {
        let dueDate = dueTomorrow ? Calendar.current.date(byAdding: .day, value: 1, to: Date()) : nil
        appState.addChore(
            title: title,
            assigneeID: selectedMemberID.isEmpty ? appState.currentMember.id : selectedMemberID,
            dueDate: dueDate
        )
        title = ""
    }
}

private struct HeaderSummary: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.household.name)
                .font(.largeTitle.bold())
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("chores.householdName")
            Text("\(appState.currentMemberChores.filter(\.isActive).count) chores assigned to \(appState.currentMember.displayName)")
                .font(.headline)
                .foregroundStyle(AppPalette.muted)
                .accessibilityIdentifier("chores.assignmentSummary")
        }
    }
}

private struct AddChorePanel: View {
    @Environment(AppState.self) private var appState
    @Binding var title: String
    @Binding var selectedMemberID: String
    @Binding var dueTomorrow: Bool
    let add: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New chore")
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
            Toggle("Due tomorrow", isOn: $dueTomorrow)
                .accessibilityIdentifier("chore.dueTomorrow")
            Button("Add Chore", action: add)
                .buttonStyle(PrimaryActionButtonStyle())
                .accessibilityIdentifier("chore.add")
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ChoreRow: View {
    @Environment(AppState.self) private var appState
    let chore: Chore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chore.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("chore.row.\(chore.id).title")
                    Text("\(appState.assigneeName(for: chore)) · \(chore.status.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.muted)
                    if let dueDate = chore.dueDate {
                        Text("Due \(dueDate.weChoreShortDueText)")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.warning)
                    }
                }
                Spacer()
                StatusBadge(status: chore.status)
            }

            ChoreActionGroup(chore: chore)
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ChoreActionGroup: View {
    @Environment(AppState.self) private var appState
    let chore: Chore

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
        ChoreControlButton(title: "Start", identifier: "chore.start.\(chore.id)") {
            appState.updateStatus(choreID: chore.id, status: .inProgress)
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
