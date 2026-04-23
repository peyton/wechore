import Foundation

enum ChatDestination: Hashable {
    case thread(String)
    case taskInbox
    case settings
}

enum ChatModal: String, Identifiable {
    case newChat

    var id: String { rawValue }
}

@MainActor
@Observable
final class AppRouter {
    var phonePath: [ChatDestination] = []
    var selectedDestination: ChatDestination?
    var activeModal: ChatModal?

    func openOnPhone(_ destination: ChatDestination) {
        phonePath = [destination]
    }

    func selectOnIPad(_ destination: ChatDestination) {
        selectedDestination = destination
    }

    func openThread(_ threadID: String) {
        let destination = ChatDestination.thread(threadID)
        openOnPhone(destination)
        selectOnIPad(destination)
        activeModal = nil
    }

    func presentNewChat() {
        activeModal = .newChat
    }
}
