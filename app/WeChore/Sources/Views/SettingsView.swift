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
                    detail: appState.settings.cloudKitEnabled ? "CloudKit conversation sharing enabled" : "CloudKit disabled for testing"
                )
                SettingsRow(
                    title: "Notifications",
                    detail: appState.settings.notificationsEnabled ? "Allowed" : "Request when scheduling reminders"
                )
                SettingsRow(
                    title: "Message intelligence",
                    detail: "Task extraction runs on device from WeChore chats only"
                )
                SettingsRow(
                    title: "Invites",
                    detail: "QR codes, Camera scanning, share links, AirDrop, and nearby join"
                )

                SettingsQRCodeSection()
                WidgetFavoritesSection()

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

private struct SettingsQRCodeSection: View {
    @Environment(AppState.self) private var appState
    @State private var invitePayload: InvitePayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("My QR")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Text("Friends can scan this with Camera to join your first chat.")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Refresh") {
                    refreshInvite()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("settings.myQR.refresh")
            }

            if let invitePayload {
                InviteQRCodeCard(payload: invitePayload, title: "My WeChore QR")
            } else {
                Text("Start a chat first, then your QR code appears here.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            if invitePayload == nil {
                refreshInvite()
            }
        }
    }

    private func refreshInvite() {
        guard let threadID = appState.groupThreads.first?.id ?? appState.threads.first?.id else {
            invitePayload = nil
            return
        }
        invitePayload = appState.createInvite(for: threadID)
    }
}

private struct WidgetFavoritesSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Widget Favorites")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Text("Choose the chats widgets show first. You can still pick any conversation when adding a configurable widget.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(appState.threads) { thread in
                Toggle(isOn: Binding(
                    get: { appState.isWidgetFavorite(threadID: thread.id) },
                    set: { appState.setWidgetFavorite(threadID: thread.id, isFavorite: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(thread.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                        Text(thread.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(AppPalette.muted)
                    }
                }
                .toggleStyle(.switch)
                .frame(minHeight: 44)
                .accessibilityIdentifier("settings.widgetFavorite.\(thread.id)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
