import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var displayName = ""
    @State private var firstChatName = ""
    @State private var inviteCode = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BrandLockup()

                    Text("Combined chat + todo. Nothing extra.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Start a chat or join one, then track todos directly in conversation.")
                        .font(.body)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    onboardingCard

                    AppStatusBanner()
                }
                .padding(18)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .background(AppPalette.canvas)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledInput(title: "Your name") {
                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.name")
            }

            LabeledInput(title: "First chat name") {
                TextField("Family, roommates, weekend crew", text: $firstChatName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.chatName")
            }

            Button("Start New Chat") {
                completeOnboardingAndOpenFirstChat()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!canStart)
            .accessibilityIdentifier("onboarding.startChat")

            Divider()

            LabeledInput(title: "Have an invite code?") {
                TextField("Invite code", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.inviteCode")
            }

            Button("Join with Code") {
                completeOnboardingAndJoinCode()
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(!canJoinWithCode)
            .accessibilityIdentifier("onboarding.joinWithCode")
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var canStart: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canJoinWithCode: Bool {
        canStart && inviteCode.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    private func completeOnboardingAndOpenFirstChat() {
        appState.completeOnboarding(
            displayName: displayName,
            householdName: firstChatName,
            contact: ""
        )
        if let firstThreadID = appState.threads.first?.id {
            router.openThread(firstThreadID)
        }
    }

    private func completeOnboardingAndJoinCode() {
        appState.completeOnboarding(
            displayName: displayName,
            householdName: firstChatName.isEmpty ? "Home Chat" : firstChatName,
            contact: ""
        )
        let joinedThreadID = appState.acceptInviteCode(inviteCode) ?? appState.defaultThreadID
        router.openThread(joinedThreadID)
    }
}

private struct LabeledInput<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            content
        }
    }
}

private struct BrandLockup: View {
    var body: some View {
        HStack(spacing: 10) {
            BrandMark(size: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text("WeChore")
                    .font(.title3.bold())
                    .foregroundStyle(AppPalette.ink)
                Text("Chat first. Todos in context.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
            }
        }
    }
}
