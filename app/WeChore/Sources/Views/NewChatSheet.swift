import SwiftUI

private enum NewChatMode: String, CaseIterable, Identifiable {
    case group = "Start Group"
    case dm = "Start DM"
    case join = "Join"

    var id: String { rawValue }
}

struct NewChatSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var mode: NewChatMode = .group
    @State private var groupTitle = ""
    @State private var dmName = ""
    @State private var dmContact = ""
    @State private var inviteCode = ""
    @State private var isDMContactPickerPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("New chat mode", selection: $mode) {
                        ForEach(NewChatMode.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("newChat.mode")

                    switch mode {
                    case .group:
                        groupSection
                    case .dm:
                        dmSection
                    case .join:
                        joinSection
                    }
                }
                .padding(18)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .background(AppPalette.canvas)
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        router.activeModal = nil
                    }
                }
            }
            .sheet(isPresented: $isDMContactPickerPresented) {
                ContactPicker { selection in
                    dmName = selection.displayName
                    dmContact = selection.contactValue
                    isDMContactPickerPresented = false
                } onCancel: {
                    isDMContactPickerPresented = false
                }
            }
        }
    }

    private var groupSection: some View {
        NewChatCard(title: "Start a group chat") {
            NewChatFieldLabel("Group name") {
                TextField("Family, roommates, weekend crew", text: $groupTitle)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("newChat.groupTitle")
            }

            Button("Start Group") {
                openThread(appState.createGroupChat(title: groupTitle))
                groupTitle = ""
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(groupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("newChat.startGroup")
        }
    }

    private var dmSection: some View {
        NewChatCard(title: "Start a DM") {
            NewChatFieldLabel("Name") {
                TextField("Name", text: $dmName)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("newChat.dmName")
            }

            NewChatFieldLabel("Phone or email") {
                TextField("Phone or email", text: $dmContact)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("newChat.dmContact")
            }

            Button {
                isDMContactPickerPresented = true
            } label: {
                Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityIdentifier("newChat.pickContact")

            Button("Start DM") {
                openThread(appState.startDM(
                    displayName: dmName,
                    phoneNumber: dmContact.contains("@") ? "" : dmContact,
                    faceTimeHandle: dmContact.contains("@") ? dmContact : ""
                ))
                dmName = ""
                dmContact = ""
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(dmName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("newChat.startDM")
        }
    }

    private var joinSection: some View {
        NewChatCard(title: "Join an existing chat") {
            NewChatFieldLabel("Invite code") {
                TextField("Invite code", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("newChat.inviteCode")
            }

            Button("Join with Code") {
                openThread(appState.acceptInviteCode(inviteCode))
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!inviteCode.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) })
            .accessibilityIdentifier("newChat.joinCode")

            Divider()

            Text("Scan a friend QR in Camera, then tap the WeChore join banner.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button("Simulate Nearby Join") {
                openThread(appState.simulateNearbyJoin())
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityIdentifier("newChat.nearby")
        }
    }

    private func openThread(_ threadID: String?) {
        guard let threadID else { return }
        router.openThread(threadID)
    }
}

private struct NewChatCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            content
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct NewChatFieldLabel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            content
        }
    }
}
