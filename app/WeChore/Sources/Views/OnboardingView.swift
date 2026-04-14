import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var displayName = ""
    @State private var firstChatName = ""
    @State private var contact = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    BrandLockup()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Make tasks where the conversation happens.")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(
                            "WeChore uses chats, DMs, local reminders, and on-device task extraction. "
                                + "It never needs a WeChore server account."
                        )
                            .foregroundStyle(AppPalette.muted)
                    }

                    VStack(spacing: 14) {
                        LabeledInput(title: "Your name") {
                            TextField("Your name", text: $displayName)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .accessibilityIdentifier("onboarding.name")
                                .textFieldStyle(.roundedBorder)
                        }

                        LabeledInput(title: "First group chat") {
                            TextField("First group chat", text: $firstChatName)
                                .textInputAutocapitalization(.words)
                                .accessibilityIdentifier("onboarding.chatName")
                                .textFieldStyle(.roundedBorder)
                        }

                        LabeledInput(title: "FaceTime or phone") {
                            TextField("FaceTime or phone", text: $contact)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .accessibilityIdentifier("onboarding.contact")
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Button("Start WeChore") {
                        appState.completeOnboarding(
                            displayName: displayName,
                            householdName: firstChatName,
                            contact: contact
                        )
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("onboarding.start")
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
            }
            .background(AppPalette.canvas)
        }
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppPalette.weChatGreen)
                Image(systemName: "checklist.checked")
                    .font(.title2.bold())
                    .foregroundStyle(AppPalette.onAccent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text("WeChore")
                    .font(.title.bold())
                    .foregroundStyle(AppPalette.ink)
                Text("Tasks inside chats.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
            }
        }
    }
}
