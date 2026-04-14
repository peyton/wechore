import AppIntents
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import WidgetKit

private enum WeChoreWidgetPalette {
    static let green = Color(red: 0.027, green: 0.757, blue: 0.376)
    static let ink = dynamicColor(
        light: UIColor(red: 0.075, green: 0.094, blue: 0.118, alpha: 1),
        dark: UIColor(red: 0.940, green: 0.970, blue: 0.950, alpha: 1)
    )
    static let muted = dynamicColor(
        light: UIColor(red: 0.404, green: 0.455, blue: 0.506, alpha: 1),
        dark: UIColor(red: 0.660, green: 0.720, blue: 0.680, alpha: 1)
    )
    static let surface = dynamicColor(
        light: UIColor(red: 0.965, green: 0.973, blue: 0.969, alpha: 1),
        dark: UIColor(red: 0.100, green: 0.130, blue: 0.110, alpha: 1)
    )
    static let background = dynamicColor(
        light: UIColor.white,
        dark: UIColor(red: 0.050, green: 0.070, blue: 0.060, alpha: 1)
    )
    static let warning = Color(red: 0.788, green: 0.180, blue: 0.080)
    static let blocked = Color(red: 0.596, green: 0.290, blue: 0.725)
    static let done = Color(red: 0.165, green: 0.580, blue: 0.392)

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

private enum WeChoreWidgetEnvironment {
    static var urlScheme: String {
        Bundle.main.object(forInfoDictionaryKey: "WeChoreURLScheme") as? String ?? "wechore"
    }
}

struct ConversationEntity: AppEntity, Identifiable, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Conversation")
    static let defaultQuery = ConversationEntityQuery()

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init() {
        id = ""
        title = "Conversation"
    }

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    init(summary: WidgetConversationSummary) {
        id = summary.id
        title = summary.title
    }
}

struct ConversationEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [ConversationEntity.ID]) async throws -> [ConversationEntity] {
        try loadConversations().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ConversationEntity] {
        try loadConversations()
    }

    func allEntities() async throws -> [ConversationEntity] {
        try loadConversations()
    }

    private func loadConversations() throws -> [ConversationEntity] {
        let snapshot = try? SharedSnapshotStore().loadSnapshot()
        return WidgetProjection.favoriteConversationSummaries(from: snapshot ?? .previewForWidgets)
            .map(ConversationEntity.init(summary:))
    }
}

struct TaskEntity: AppEntity, Identifiable, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task")
    static let defaultQuery = TaskEntityQuery()

    var id: String
    var threadID: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init() {
        id = ""
        threadID = ""
        title = "Task"
    }

    init(id: String, threadID: String, title: String) {
        self.id = id
        self.threadID = threadID
        self.title = title
    }

    init(summary: WidgetTaskSummary) {
        id = summary.id
        threadID = summary.threadID
        title = summary.title
    }
}

struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [TaskEntity.ID]) async throws -> [TaskEntity] {
        let snapshot = try? SharedSnapshotStore().loadSnapshot()
        let summaries = WidgetProjection.conversationSummaries(from: snapshot ?? .previewForWidgets)
            .flatMap(\.tasks)
        return summaries
            .filter { identifiers.contains($0.id) }
            .map(TaskEntity.init(summary:))
    }
}

struct ConversationWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "WeChore Conversation"
    static let description = IntentDescription("Choose the conversation this widget opens and summarizes.")

    @Parameter(title: "Conversation")
    var conversation: ConversationEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$conversation)")
    }

    init() {}

    init(conversation: ConversationEntity?) {
        self.conversation = conversation
    }
}

struct MarkTaskDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Task Done"
    static let description = IntentDescription("Completes a WeChore task from a widget.")
    static let openAppWhenRun = false

    @Parameter(title: "Task")
    var task: TaskEntity

    init() {
        task = TaskEntity()
    }

    init(task: TaskEntity) {
        self.task = task
    }

    func perform() async throws -> some IntentResult {
        var snapshot = try SharedSnapshotStore().loadSnapshot()
        guard WidgetSnapshotMutator.markTaskDone(taskID: task.id, in: &snapshot) else {
            throw WeChoreWidgetIntentError.taskUnavailable
        }
        try SharedSnapshotStore().saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

private enum WeChoreWidgetIntentError: LocalizedError {
    case taskUnavailable

    var errorDescription: String? {
        switch self {
        case .taskUnavailable:
            "This task is no longer active."
        }
    }
}

struct OpenConversationIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Conversation"
    static let description = IntentDescription("Opens a WeChore conversation.")

    @Parameter(title: "Conversation")
    var conversation: ConversationEntity

    init() {
        conversation = ConversationEntity()
    }

    init(conversation: ConversationEntity) {
        self.conversation = conversation
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(
            WeChoreDeepLink.thread(conversation.id).url(scheme: WeChoreWidgetEnvironment.urlScheme)
        ))
    }
}

struct OpenTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Task"
    static let description = IntentDescription("Opens the WeChore conversation for a task.")

    @Parameter(title: "Task")
    var task: TaskEntity

    init() {
        task = TaskEntity()
    }

    init(task: TaskEntity) {
        self.task = task
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(
            WeChoreDeepLink.task(task.id).url(scheme: WeChoreWidgetEnvironment.urlScheme)
        ))
    }
}

struct ConversationWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConversationWidgetIntent
    let summaries: [WidgetConversationSummary]
    let selected: WidgetConversationSummary
}

struct ConversationWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConversationWidgetEntry {
        entry(for: ConversationWidgetIntent(), at: Date(), snapshot: .previewForWidgets)
    }

    func snapshot(for configuration: ConversationWidgetIntent, in context: Context) async -> ConversationWidgetEntry {
        entry(for: configuration, at: Date(), snapshot: context.isPreview ? .previewForWidgets : loadSnapshot())
    }

    func timeline(for configuration: ConversationWidgetIntent, in context: Context) async -> Timeline<ConversationWidgetEntry> {
        let now = Date()
        let entry = entry(for: configuration, at: now, snapshot: loadSnapshot())
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60)))
    }

    private func entry(
        for configuration: ConversationWidgetIntent,
        at date: Date,
        snapshot: ChoreSnapshot
    ) -> ConversationWidgetEntry {
        let summaries = WidgetProjection.favoriteConversationSummaries(from: snapshot, now: date)
        let selected = summaries.first { $0.id == configuration.conversation?.id }
            ?? summaries.first
            ?? WidgetProjection.conversationSummary(for: ChoreSnapshot.previewThread, in: .previewForWidgets, now: date)
        return ConversationWidgetEntry(
            date: date,
            configuration: configuration,
            summaries: summaries,
            selected: selected
        )
    }

    private func loadSnapshot() -> ChoreSnapshot {
        (try? SharedSnapshotStore().loadSnapshot()) ?? .previewForWidgets
    }
}

struct ConversationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConversationWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallConversationWidget(summary: entry.selected)
            case .systemMedium:
                MediumConversationWidget(summary: entry.selected)
            case .systemLarge:
                LargeConversationWidget(summary: entry.selected)
            case .systemExtraLarge:
                ExtraLargeConversationWidget(summaries: Array(entry.summaries.prefix(4)))
            case .accessoryInline:
                InlineConversationWidget(summary: entry.selected)
            case .accessoryCircular:
                CircularConversationWidget(summary: entry.selected)
            case .accessoryRectangular:
                RectangularConversationWidget(summary: entry.selected)
            default:
                SmallConversationWidget(summary: entry.selected)
            }
        }
        .widgetURL(WeChoreDeepLink.thread(entry.selected.id).url(scheme: WeChoreWidgetEnvironment.urlScheme))
    }
}

private struct SmallConversationWidget: View {
    let summary: WidgetConversationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: summary.title, status: summary.statusText)
            Spacer(minLength: 2)
            if let task = summary.tasks.first {
                TaskStatusPill(task: task)
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(WeChoreWidgetPalette.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                Text(task.assigneeName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeChoreWidgetPalette.muted)
            } else {
                Text("All caught up")
                    .font(.headline)
                    .foregroundStyle(WeChoreWidgetPalette.done)
            }
        }
        .padding()
    }
}

private struct MediumConversationWidget: View {
    let summary: WidgetConversationSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: summary.title, status: summary.statusText)
                CountRow(summary: summary)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.tasks.prefix(2)) { task in
                    WidgetTaskRow(task: task, allowsDone: task.id == summary.tasks.first?.id)
                }
                if summary.tasks.isEmpty {
                    Text("No open tasks")
                        .font(.headline)
                        .foregroundStyle(WeChoreWidgetPalette.done)
                }
            }
        }
        .padding()
    }
}

private struct LargeConversationWidget: View {
    let summary: WidgetConversationSummary

    private var overdueTasks: [WidgetTaskSummary] {
        summary.tasks.filter(\.isOverdue)
    }

    private var todayTasks: [WidgetTaskSummary] {
        summary.tasks.filter(\.isDueToday)
    }

    private var otherTasks: [WidgetTaskSummary] {
        summary.tasks.filter { !$0.isOverdue && !$0.isDueToday }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: summary.title, status: summary.statusText)
            CountRow(summary: summary)
            SectionedTasks(title: "Overdue", tasks: Array(overdueTasks.prefix(2)), allowsDone: true)
            SectionedTasks(title: "Today", tasks: Array(todayTasks.prefix(2)), allowsDone: true)
            SectionedTasks(title: "Next", tasks: Array(otherTasks.prefix(3)), allowsDone: true)
            Spacer(minLength: 0)
        }
        .padding()
    }
}

private struct ExtraLargeConversationWidget: View {
    let summaries: [WidgetConversationSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WeChore")
                .font(.title3.bold())
                .foregroundStyle(WeChoreWidgetPalette.ink)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(summaries) { summary in
                    Link(destination: WeChoreDeepLink.thread(summary.id).url(scheme: WeChoreWidgetEnvironment.urlScheme)) {
                        VStack(alignment: .leading, spacing: 8) {
                            WidgetHeader(title: summary.title, status: summary.statusText)
                            CountRow(summary: summary)
                            if let task = summary.tasks.first {
                                TaskStatusPill(task: task)
                                Text(task.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(WeChoreWidgetPalette.ink)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                        .padding(12)
                        .background(WeChoreWidgetPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .padding()
    }
}

private struct InlineConversationWidget: View {
    let summary: WidgetConversationSummary

    var body: some View {
        Text("\(summary.title): \(summary.statusText)")
    }
}

private struct CircularConversationWidget: View {
    let summary: WidgetConversationSummary

    var body: some View {
        Gauge(value: Double(summary.doneTaskCount), in: 0...Double(max(1, summary.doneTaskCount + summary.activeTaskCount))) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            Text("\(summary.activeTaskCount)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

private struct RectangularConversationWidget: View {
    let summary: WidgetConversationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title)
                .font(.headline)
            Text(summary.statusText)
                .font(.caption)
            if let task = summary.tasks.first {
                HStack {
                    Text(task.title)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button(intent: MarkTaskDoneIntent(task: TaskEntity(summary: task))) {
                        Text("Done")
                    }
                    .font(.caption2.bold())
                }
            }
        }
    }
}

private struct WidgetHeader: View {
    let title: String
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(WeChoreWidgetPalette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeChoreWidgetPalette.muted)
                .lineLimit(2)
        }
    }
}

private struct CountRow: View {
    let summary: WidgetConversationSummary

    var body: some View {
        HStack(spacing: 8) {
            CountPill(label: "Open", value: summary.activeTaskCount, color: WeChoreWidgetPalette.green)
            CountPill(label: "Done", value: summary.doneTaskCount, color: WeChoreWidgetPalette.done)
            if summary.waitingForAssigneeCount > 0 {
                CountPill(label: "Needs person", value: summary.waitingForAssigneeCount, color: WeChoreWidgetPalette.warning)
            }
        }
    }
}

private struct CountPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.headline.bold())
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
    }
}

private struct SectionedTasks: View {
    let title: String
    let tasks: [WidgetTaskSummary]
    let allowsDone: Bool

    var body: some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WeChoreWidgetPalette.muted)
                ForEach(tasks) { task in
                    WidgetTaskRow(task: task, allowsDone: allowsDone)
                }
            }
        }
    }
}

private struct WidgetTaskRow: View {
    let task: WidgetTaskSummary
    let allowsDone: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TaskStatusPill(task: task)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeChoreWidgetPalette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(task.assigneeName) • \(task.statusLabel)")
                    .font(.caption2)
                    .foregroundStyle(WeChoreWidgetPalette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if allowsDone {
                Button(intent: MarkTaskDoneIntent(task: TaskEntity(summary: task))) {
                    Text("Done")
                }
                .font(.caption.weight(.bold))
                .buttonStyle(.borderedProminent)
                Link(destination: WeChoreDeepLink.task(task.id).url(scheme: WeChoreWidgetEnvironment.urlScheme)) {
                    Text("Open")
                }
                .font(.caption.weight(.bold))
            }
        }
    }
}

private struct TaskStatusPill: View {
    let task: WidgetTaskSummary

    var body: some View {
        Label(task.statusLabel, systemImage: iconName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .labelStyle(.iconOnly)
            .accessibilityLabel(task.statusLabel)
    }

    private var iconName: String {
        if task.status == .blocked { return "exclamationmark.octagon.fill" }
        if task.status == .done { return "checkmark.circle.fill" }
        if task.isOverdue { return "calendar.badge.exclamationmark" }
        if task.isDueToday { return "calendar" }
        return "circle"
    }

    private var color: Color {
        if task.status == .blocked { return WeChoreWidgetPalette.blocked }
        if task.status == .done { return WeChoreWidgetPalette.done }
        if task.isOverdue { return WeChoreWidgetPalette.warning }
        return WeChoreWidgetPalette.green
    }
}

struct WeChoreConversationWidget: Widget {
    private let kind = "WeChoreConversationWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConversationWidgetIntent.self,
            provider: ConversationWidgetProvider()
        ) { entry in
            ConversationWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WeChoreWidgetPalette.background
                }
        }
        .configurationDisplayName("WeChore Conversation")
        .description("Open a chosen conversation, check chore status, and mark safe tasks done.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

@main
struct WeChoreWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WeChoreConversationWidget()
    }
}

private extension ChoreSnapshot {
    static var previewThread: ChatThread {
        previewForWidgets.threads[0]
    }

    static var previewForWidgets: ChoreSnapshot {
        let now = Date()
        let peyton = ChatParticipant(id: "participant-peyton", displayName: "Peyton", isCurrentUser: true, createdAt: now)
        let sam = ChatParticipant(id: "participant-sam", displayName: "Sam", createdAt: now)
        let thread = ChatThread(
            id: "thread-pine",
            kind: .group,
            title: "Pine Chat",
            participantIDs: [peyton.id, sam.id],
            createdAt: now,
            updatedAt: now,
            lastActivityAt: now
        )
        let chore = Chore(
            id: "task-dishes",
            threadID: thread.id,
            title: "Load dishwasher",
            createdByMemberID: peyton.id,
            assigneeID: sam.id,
            dueDate: now,
            createdAt: now,
            updatedAt: now
        )
        let waiting = TaskDraft(
            threadID: thread.id,
            sourceMessageID: "message-1",
            title: "Water plants",
            needsConfirmation: true,
            assignmentState: .needsAssignee,
            createdAt: now
        )
        return ChoreSnapshot(
            household: Household(name: "Pine Chat", createdAt: now, updatedAt: now),
            participants: [peyton, sam],
            threads: [thread],
            chores: [chore],
            suggestions: [waiting],
            settings: LocalSettings(
                hasCompletedOnboarding: true,
                selectedParticipantID: peyton.id,
                widgetFavoriteThreadIDs: [thread.id]
            )
        )
    }
}
