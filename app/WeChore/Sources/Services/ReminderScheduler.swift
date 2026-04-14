import Foundation
@preconcurrency import UserNotifications

public struct ReminderPlan: Equatable, Sendable {
    public var identifier: String
    public var title: String
    public var body: String
    public var fireDate: Date

    public init(identifier: String, title: String, body: String, fireDate: Date) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.fireDate = fireDate
    }
}

public enum ReminderPlanner {
    public static func plan(
        chore: Chore,
        assignee: Member,
        now: Date,
        calendar: Calendar = .current
    ) -> ReminderPlan {
        let fallback = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let fireDate = chore.dueDate.map { max($0, now) } ?? fallback
        return ReminderPlan(
            identifier: "wechore.thread.\(chore.threadID).task.\(chore.id)",
            title: "WeChore task",
            body: "\(assignee.displayName), check \(chore.title).",
            fireDate: fireDate
        )
    }
}

@MainActor
public protocol ReminderScheduling {
    func requestAuthorization() async throws -> Bool
    func schedule(plan: ReminderPlan) async throws
}

public struct LocalReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func schedule(plan: ReminderPlan) async throws {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default

        let interval = max(plan.fireDate.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [plan.identifier])
        try await center.add(request)
    }
}

public final class CapturingReminderScheduler: ReminderScheduling {
    public private(set) var requestedAuthorization = false
    public private(set) var scheduledPlans: [ReminderPlan] = []

    public init() {}

    public func requestAuthorization() async throws -> Bool {
        requestedAuthorization = true
        return true
    }

    public func schedule(plan: ReminderPlan) async throws {
        scheduledPlans.removeAll { $0.identifier == plan.identifier }
        scheduledPlans.append(plan)
    }
}
