import SwiftUI

struct HouseholdView: View {
    @Environment(AppState.self) private var appState
    @State private var memberName = ""
    @State private var phone = ""
    @State private var handle = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.household.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppPalette.ink)
                    Text("CloudKit sharing keeps household records on Apple infrastructure tied to each member's iCloud account.")
                        .foregroundStyle(AppPalette.muted)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Members")
                        .font(.title2.bold())
                    ForEach(appState.members) { member in
                        HStack {
                            Image(systemName: member.isCurrentUser ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                                .foregroundStyle(AppPalette.weChatGreen)
                            VStack(alignment: .leading) {
                                Text(member.displayName)
                                    .font(.headline)
                                if let url = appState.preferredVoiceURL(for: member) {
                                    Text(url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(AppPalette.muted)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(AppPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityIdentifier("member.row.\(member.id)")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Add member")
                        .font(.headline)
                    TextField("Display name", text: $memberName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("member.name")
                    TextField("Phone", text: $phone)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("member.phone")
                    TextField("FaceTime handle", text: $handle)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("member.facetime")
                    Button("Add Member") {
                        appState.addMember(displayName: memberName, phoneNumber: phone, faceTimeHandle: handle)
                        memberName = ""
                        phone = ""
                        handle = ""
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("member.add")
                }
                .padding(14)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("iCloud sharing")
                        .font(.title2.bold())
                    Text(
                        appState.settings.cloudKitEnabled
                            ? "Ready for CKShare invitation flow in signed builds."
                            : "CloudKit disabled for this run."
                    )
                        .foregroundStyle(AppPalette.muted)
                    Button("Prepare iCloud Share") {
                        appState.lastStatusMessage = "CloudKit share metadata prepared for \(appState.household.name)."
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("cloudkit.prepareShare")
                }
                .padding(14)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(18)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(AppPalette.canvas)
    }
}
