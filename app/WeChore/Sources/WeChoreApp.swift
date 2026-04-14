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
                .tint(AppPalette.weChatGreen)
                .modifier(UITestDynamicTypeModifier())
                .onAppear {
                    if let preferredRoute = RuntimeEnvironment.preferredRoute {
                        router.selectedRoute = preferredRoute
                    }
                }
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
