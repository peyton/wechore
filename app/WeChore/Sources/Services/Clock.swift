import Foundation

public protocol ClockProviding: Sendable {
    func now() -> Date
}

public struct SystemClock: ClockProviding {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public struct FixedClock: ClockProviding {
    public let fixedDate: Date

    public init(_ fixedDate: Date) {
        self.fixedDate = fixedDate
    }

    public func now() -> Date {
        fixedDate
    }
}
