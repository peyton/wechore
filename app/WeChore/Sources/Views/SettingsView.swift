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

                SettingsProfileSection()
                SettingsQRCodeSection()
                WidgetFavoritesSection()
                SettingsDiagnosticsSection()

                Link("Support", destination: SettingsLinks.support)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("settings.support")
                Link("Privacy", destination: SettingsLinks.privacy)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("settings.privacy")
            }
            .padding(18)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(AppPalette.canvas)
        .safeAreaInset(edge: .bottom) {
            AppStatusBanner()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }
}

private enum SettingsLinks {
    static let support = URL(string: "https://wechore.peyton.app/support/")
        ?? URL(fileURLWithPath: "/support")
    static let privacy = URL(string: "https://wechore.peyton.app/privacy/")
        ?? URL(fileURLWithPath: "/privacy")
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
                Button(invitePayload == nil ? "Create QR" : "Refresh") {
                    createOrRefreshInvite()
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
                loadExistingInvite()
            }
        }
    }

    private func loadExistingInvite() {
        guard let threadID = appState.groupThreads.first?.id ?? appState.threads.first?.id else {
            invitePayload = nil
            return
        }
        invitePayload = appState.activeInvitePayload(for: threadID)
    }

    private func createOrRefreshInvite() {
        guard let threadID = appState.groupThreads.first?.id ?? appState.threads.first?.id else {
            invitePayload = nil
            return
        }
        invitePayload = appState.createInvite(for: threadID)
    }
}

private struct SettingsProfileSection: View {
    @Environment(AppState.self) private var appState
    @State private var displayName = ""
    @State private var contact = ""
    @State private var selectedEmoji: String?
    @State private var isEmojiPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Button {
                isEmojiPickerPresented = true
            } label: {
                HStack {
                    Text(selectedEmoji ?? "😊")
                        .font(.largeTitle)
                    Text("Change avatar")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.profile.avatar")
            TextField("Name", text: $displayName)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("settings.profile.name")
            TextField("Phone or email", text: $contact)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("settings.profile.contact")
            Button("Save Profile") {
                _ = appState.updateCurrentParticipant(
                    displayName: displayName,
                    contact: contact,
                    avatarEmoji: selectedEmoji
                )
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("settings.profile.save")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear(perform: load)
        .onChange(of: appState.currentParticipant) { _, _ in
            load()
        }
        .sheet(isPresented: $isEmojiPickerPresented) {
            EmojiPickerSheet(selectedEmoji: $selectedEmoji)
        }
    }

    private func load() {
        displayName = appState.currentParticipant.displayName
        contact = appState.currentParticipant.faceTimeHandle ?? appState.currentParticipant.phoneNumber ?? ""
        selectedEmoji = appState.currentParticipant.avatarEmoji
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

private struct SettingsDiagnosticsSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            diagnosticLine("Chats", value: appState.threads.count)
            diagnosticLine("Active tasks", value: appState.activeChores.count)
            diagnosticLine("Drafts waiting", value: appState.suggestions.count)
            Text("No ads. No third-party server. WeChore only extracts tasks from messages recorded inside WeChore.")
                .font(.caption)
                .foregroundStyle(AppPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func diagnosticLine(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .font(.body.monospacedDigit().weight(.semibold))
        }
        .font(.subheadline)
        .foregroundStyle(AppPalette.ink)
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
