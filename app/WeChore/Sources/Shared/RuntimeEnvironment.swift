import SwiftUI

enum RuntimeEnvironment {
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }

    static var preferredRoute: AppRoute? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("UITEST_ROUTE=") }) else {
            return nil
        }
        return AppRoute(rawValue: String(argument.dropFirst("UITEST_ROUTE=".count)))
    }

    static var shouldCompleteOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_COMPLETE_ONBOARDING")
    }

    static var shouldSeedHousehold: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SEED_HOUSEHOLD")
    }

    static var shouldSeedChores: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_SEED_CHORES")
    }

    static var shouldDisableCloudKit: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_DISABLE_CLOUDKIT")
    }

    static var requestedMemberName: String? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("UITEST_MEMBER=") }) else {
            return nil
        }
        return String(argument.dropFirst("UITEST_MEMBER=".count))
    }
}
