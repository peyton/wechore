import SwiftData
import SwiftUI

@main
struct WeChoreApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
        let repository = CompositeChoreRepository(primary: SwiftDataChoreRepository(context: context))
        let extractionEngine: any TaskExtractionEngine = RuntimeEnvironment.isRunningUITests
            ? RuleBasedTaskExtractionEngine()
            : TaskExtractionEngineFactory.live()
        let reminderScheduler: ReminderScheduling = RuntimeEnvironment.isRunningUITests
            ? CapturingReminderScheduler()
            : LocalReminderScheduler()
        let voiceRecorder: VoiceMessageRecording = RuntimeEnvironment.isRunningUITests
            ? FakeVoiceMessageRecorder()
            : AppleVoiceMessageRecorder()
        let voiceTranscriber: VoiceMessageTranscribing = RuntimeEnvironment.isRunningUITests
            ? FakeVoiceMessageTranscriber(transcript: RuntimeEnvironment.fakeVoiceTranscript)
            : AppleSpeechVoiceMessageTranscriber()
        let voicePlayer: VoiceMessagePlaying = RuntimeEnvironment.isRunningUITests
            ? FakeVoiceMessagePlayer()
            : AppleVoiceMessagePlayer()
        _appState = State(initialValue: AppState(
            repository: repository,
            extractionEngine: extractionEngine,
            reminderScheduler: reminderScheduler,
            voiceRecorder: voiceRecorder,
            voiceTranscriber: voiceTranscriber,
            voicePlayer: voicePlayer
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
                .modelContainer(container)
                .preferredColorScheme(colorScheme)
                .tint(AppPalette.weChatGreen)
                .modifier(UITestDynamicTypeModifier())
                .onAppear {
                    if let preferredDestination = RuntimeEnvironment.preferredDestination {
                        router.selectedDestination = preferredDestination
                        router.phonePath = [preferredDestination]
                    }
                    if let preferredModal = RuntimeEnvironment.preferredModal {
                        router.activeModal = preferredModal
                    }
                }
                .onOpenURL { url in
                    if let destination = route(for: url) {
                        router.selectedDestination = destination
                        router.phonePath = [destination]
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    appState.refreshFromSharedState()
                    appState.clearBadge()
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appState.settings.themePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func route(for url: URL) -> ChatDestination? {
        guard let deepLink = WeChoreDeepLink(url: url) else { return nil }
        switch deepLink {
        case let .thread(threadID):
            guard appState.thread(for: threadID) != nil else {
                appState.lastStatusMessage = "That chat is not on this device."
                return nil
            }
            return .thread(threadID)
        case let .task(taskID):
            guard let threadID = appState.threadID(forTaskID: taskID) else {
                appState.lastStatusMessage = "That task is not on this device."
                return nil
            }
            return .thread(threadID)
        case let .join(payload):
            guard let threadID = appState.acceptInvite(payload) else { return nil }
            return .thread(threadID)
        }
    }
}

private struct UITestDynamicTypeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if RuntimeEnvironment.shouldUseLargeText {
            content.dynamicTypeSize(.accessibility3)
        } else {
            content
        }
    }
}
