import SwiftData
import SwiftUI

@main
struct WeChoreApp: App {
    @State private var appState: AppState
    @State private var router = AppRouter()
    private let container: ModelContainer

    init() {
        do {
            container = try WeChoreModelContainerFactory.makeSharedContainer(
                isStoredInMemoryOnly: RuntimeEnvironment.isRunningUITests
            )
        } catch {
            assertionFailure("Failed to create ModelContainer: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
        let context = ModelContext(container)
        let repository = SwiftDataChoreRepository(context: context)
        let reminderScheduler: ReminderScheduling = RuntimeEnvironment.isRunningUITests
            ? CapturingReminderScheduler()
            : LocalReminderScheduler()
        _appState = State(initialValue: AppState(repository: repository, reminderScheduler: reminderScheduler))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
                .modelContainer(container)
                .tint(AppPalette.weChatGreen)
                .onAppear {
                    if let preferredRoute = RuntimeEnvironment.preferredRoute {
                        router.selectedRoute = preferredRoute
                    }
                }
        }
    }
}
