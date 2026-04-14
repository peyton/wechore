import Foundation

enum AppRoute: String, CaseIterable, Identifiable {
    case chores
    case messages
    case household
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chores: "Chores"
        case .messages: "Messages"
        case .household: "Household"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chores: "checklist"
        case .messages: "bubble.left.and.bubble.right.fill"
        case .household: "person.2.fill"
        case .settings: "gearshape.fill"
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedRoute: AppRoute = .chores
}
