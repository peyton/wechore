import Foundation

enum ChatDestination: Hashable {
    case thread(String)
    case joinStart
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var phonePath: [ChatDestination] = []
    var selectedDestination: ChatDestination?

    func openOnPhone(_ destination: ChatDestination) {
        phonePath = [destination]
    }

    func selectOnIPad(_ destination: ChatDestination) {
        selectedDestination = destination
    }
}
