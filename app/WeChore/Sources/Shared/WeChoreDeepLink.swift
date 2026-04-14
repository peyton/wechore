import Foundation

public enum WeChoreDeepLink: Equatable, Sendable {
    case thread(String)
    case task(String)
    case join(InvitePayload)

    public init?(url: URL) {
        if let payload = InvitePayload(url: url) {
            self = .join(payload)
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let host = components.host?.lowercased()
        let pathID = components.path
            .split(separator: "/")
            .last
            .map(String.init)
        let queryID = components.queryItems?.first(where: { $0.name == "id" })?.value
        let id = pathID ?? queryID

        switch host {
        case "thread":
            guard let id, !id.isEmpty else { return nil }
            self = .thread(id)
        case "task":
            guard let id, !id.isEmpty else { return nil }
            self = .task(id)
        default:
            return nil
        }
    }

    public func url(scheme: String = "wechore") -> URL {
        var components = URLComponents()
        components.scheme = scheme
        switch self {
        case let .thread(id):
            components.host = "thread"
            components.path = "/\(id)"
        case let .task(id):
            components.host = "task"
            components.path = "/\(id)"
        case let .join(payload):
            return payload.appURL(scheme: scheme)
        }
        return components.url ?? fallbackURL(scheme: scheme)
    }

    private func fallbackURL(scheme: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "thread"
        return components.url ?? URL(fileURLWithPath: "/thread")
    }
}
