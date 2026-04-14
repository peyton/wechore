import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var displayName = ""
    @State private var householdName = ""
    @State private var contact = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    BrandLockup()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assign chores in the same place you talk about them.")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(
                            "WeChore uses CloudKit sharing, local reminders, and on-device suggestions. "
                                + "It never needs a WeChore server account."
                        )
                            .foregroundStyle(AppPalette.muted)
                    }

                    VStack(spacing: 14) {
                        TextField("Your name", text: $displayName)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("onboarding.name")
                            .textFieldStyle(.roundedBorder)

                        TextField("Household name", text: $householdName)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("onboarding.household")
                            .textFieldStyle(.roundedBorder)

                        TextField("FaceTime or phone", text: $contact)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("onboarding.contact")
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("Start WeChore") {
                        appState.completeOnboarding(
                            displayName: displayName,
                            householdName: householdName,
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
                Text("Household work, in sync.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
            }
        }
    }
}
