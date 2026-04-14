import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppPalette.ink)

                SettingsRow(
                    title: "Apple-only sync",
                    detail: appState.settings.cloudKitEnabled ? "CloudKit sharing enabled" : "CloudKit disabled for testing"
                )
                SettingsRow(
                    title: "Notifications",
                    detail: appState.settings.notificationsEnabled ? "Allowed" : "Request when scheduling reminders"
                )
                SettingsRow(
                    title: "Message intelligence",
                    detail: "On-device parsing from WeChore messages only"
                )
                SettingsRow(
                    title: "Voice handoff",
                    detail: "FaceTime Audio first, Phone fallback"
                )

                Link("Support", destination: URL(string: "https://wechore.peyton.app/support/")!)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("settings.support")
                Link("Privacy", destination: URL(string: "https://wechore.peyton.app/privacy/")!)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("settings.privacy")
            }
            .padding(18)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(AppPalette.canvas)
    }
}

private struct SettingsRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
