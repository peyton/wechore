import Foundation

enum AppRoute: String, CaseIterable, Identifiable {
    case messages
    case chores
    case household
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .messages: "Chats"
        case .chores: "Chores"
        case .household: "Household"
        case .settings: "Me"
        }
    }

    var systemImage: String {
        switch self {
        case .messages: "bubble.left.and.bubble.right.fill"
        case .chores: "checklist"
        case .household: "person.2.fill"
        case .settings: "person.crop.circle.fill"
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedRoute: AppRoute = .messages
}
