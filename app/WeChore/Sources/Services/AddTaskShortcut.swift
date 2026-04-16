import AppIntents
import WidgetKit

struct AddTaskShortcut: AppIntent {
    static let title: LocalizedStringResource = "Add WeChore Task"
    static let description = IntentDescription("Creates a new task in WeChore.")
    static let openAppWhenRun = false

    @Parameter(title: "Task title")
    var taskTitle: String

    @Parameter(title: "Due date", default: nil)
    var dueDate: Date?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var snapshot = try SharedSnapshotStore().loadSnapshot()
        let participant = snapshot.participants.first(where: { $0.isCurrentUser })
            ?? snapshot.participants.first!
        let threadID = snapshot.threads.first?.id ?? "thread-family"
        let now = Date()
        let chore = Chore(
            threadID: threadID,
            title: taskTitle,
            createdByMemberID: participant.id,
            assigneeID: participant.id,
            dueDate: dueDate,
            createdAt: now,
            updatedAt: now
        )
        snapshot.chores.append(chore)
        try SharedSnapshotStore().saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Added \"\(taskTitle)\" to WeChore.")
    }
}

struct WeChoreShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskShortcut(),
            phrases: [
                "Create a task in \(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "checklist.checked"
        )
    }
}
