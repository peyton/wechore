import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var step: OnboardingStep = .chat
    @State private var displayName = ""
    @State private var firstChatName = ""
    @State private var contact = ""
    @State private var selectedDiscovery: OnboardingDiscovery?
    @State private var selectedContact: ContactSelection?
    @State private var selectedEmoji: String?
    @State private var isContactPickerPresented = false
    @State private var isEmojiPickerPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    OnboardingPage(step: .chat) {
                        VStack(alignment: .leading, spacing: 14) {
                            BrandLockup()
                            Text("Chats first. Tasks follow.")
                                .font(.largeTitle.bold())
                                .foregroundStyle(AppPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Talk like you already do. WeChore keeps the request, assignee, and reminder beside the conversation.")
                                .font(.body)
                                .foregroundStyle(AppPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tag(OnboardingStep.chat)

                    OnboardingPage(step: .connect) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Find your people.")
                                .font(.largeTitle.bold())
                                .foregroundStyle(AppPalette.ink)
                            Text("Start with a nearby chat, choose someone from Contacts, or scan a friend code.")
                                .font(.body)
                                .foregroundStyle(AppPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(spacing: 10) {
                                DiscoveryOptionButton(
                                    title: "Find nearby chat",
                                    detail: "Bring phones together to join or start a chat.",
                                    systemImage: "dot.radiowaves.left.and.right",
                                    isSelected: selectedDiscovery == .nearby
                                ) {
                                    selectedDiscovery = .nearby
                                    step = .profile
                                }
                                .accessibilityIdentifier("onboarding.option.nearby")

                                DiscoveryOptionButton(
                                    title: "Use Contacts",
                                    detail: "Pick a person to start a DM or invite after setup.",
                                    systemImage: "person.crop.circle.badge.plus",
                                    isSelected: selectedDiscovery == .contacts
                                ) {
                                    selectedDiscovery = .contacts
                                    isContactPickerPresented = true
                                }
                                .accessibilityIdentifier("onboarding.option.contacts")

                                DiscoveryOptionButton(
                                    title: "Scan QR code",
                                    detail: "Camera can scan a WeChore QR and open the join link.",
                                    systemImage: "qrcode.viewfinder",
                                    isSelected: selectedDiscovery == .qr
                                ) {
                                    selectedDiscovery = .qr
                                    step = .profile
                                }
                                .accessibilityIdentifier("onboarding.option.qr")
                            }
                        }
                    }
                    .tag(OnboardingStep.connect)

                    OnboardingPage(step: .profile) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Open your first chat.")
                                .font(.largeTitle.bold())
                                .foregroundStyle(AppPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(profileDetail)
                                .font(.body)
                                .foregroundStyle(AppPalette.muted)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(spacing: 14) {
                                Button {
                                    isEmojiPickerPresented = true
                                } label: {
                                    HStack {
                                        Text(selectedEmoji ?? "😊")
                                            .font(.largeTitle)
                                        Text("Pick your avatar")
                                            .font(.subheadline)
                                            .foregroundStyle(AppPalette.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("onboarding.avatar")

                                LabeledInput(title: "Your name") {
                                    TextField("Your name", text: $displayName)
                                        .textContentType(.name)
                                        .textInputAutocapitalization(.words)
                                        .accessibilityIdentifier("onboarding.name")
                                        .textFieldStyle(.roundedBorder)
                                }

                                LabeledInput(title: "First chat") {
                                    TextField("Family, roommates, weekend crew", text: $firstChatName)
                                        .textInputAutocapitalization(.words)
                                        .accessibilityIdentifier("onboarding.chatName")
                                        .textFieldStyle(.roundedBorder)
                                }

                                LabeledInput(title: "Phone or email, optional") {
                                    TextField("Phone or email", text: $contact)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .accessibilityIdentifier("onboarding.contact")
                                        .textFieldStyle(.roundedBorder)
                                }

                                Button {
                                    selectedDiscovery = .contacts
                                    isContactPickerPresented = true
                                } label: {
                                    Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                                .accessibilityIdentifier("onboarding.contacts")
                            }
                        }
                    }
                    .tag(OnboardingStep.profile)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                OnboardingFooter(
                    step: step,
                    canStart: canCompleteProfile,
                    validationMessage: profileValidationMessage,
                    next: advance,
                    back: goBack,
                    start: completeOnboarding
                )
            }
            .background(AppPalette.canvas)
            .sheet(isPresented: $isContactPickerPresented) {
                ContactPicker { selection in
                    selectedContact = selection
                    selectedDiscovery = .contacts
                    step = .profile
                    isContactPickerPresented = false
                } onCancel: {
                    isContactPickerPresented = false
                }
            }
            .sheet(isPresented: $isEmojiPickerPresented) {
                EmojiPickerSheet(selectedEmoji: $selectedEmoji)
            }
        }
    }

    private var profileDetail: String {
        switch selectedDiscovery {
        case .nearby:
            return "We will take you to nearby join options after setup. This first chat keeps WeChore ready if nobody is nearby yet."
        case .contacts:
            if let selectedContact {
                return "Add your name now. We will open a DM with \(selectedContact.displayName) after setup."
            }
            return "Add your name now. Contacts stay optional and can start a DM after setup."
        case .qr:
            return "Your own QR code will be available from the chat list. Friends can scan it with Camera."
        case nil:
            return "This creates the chat WeChore opens first. You can add people by QR, nearby join, or Contacts anytime."
        }
    }

    private var canCompleteProfile: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !firstChatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var profileValidationMessage: String? {
        guard step == .profile, !canCompleteProfile else { return nil }
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Add your name to open the first chat."
        }
        return "Name the first chat to continue."
    }

    private func advance() {
        guard let next = step.next else { return }
        step = next
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    private func completeOnboarding() {
        guard canCompleteProfile else { return }
        appState.completeOnboarding(
            displayName: displayName,
            householdName: firstChatName,
            contact: contact,
            avatarEmoji: selectedEmoji
        )
        if let selectedContact {
            let contactValue = selectedContact.contactValue
            guard let threadID = appState.startDM(
                displayName: selectedContact.displayName,
                phoneNumber: contactValue.contains("@") ? "" : contactValue,
                faceTimeHandle: contactValue.contains("@") ? contactValue : ""
            ) else { return }
            let destination = ChatDestination.thread(threadID)
            router.phonePath = [destination]
            router.selectedDestination = destination
            return
        }
        if selectedDiscovery != nil {
            router.phonePath = [.joinStart]
            router.selectedDestination = .joinStart
        }
    }
}

private enum OnboardingStep: Int, CaseIterable, Hashable {
    case chat
    case connect
    case profile

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

private enum OnboardingDiscovery {
    case nearby
    case contacts
    case qr
}

private struct OnboardingPage<Content: View>: View {
    let step: OnboardingStep
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingHeroArt(step: step)
                    .frame(height: 230)
                    .accessibilityHidden(true)
                content
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct OnboardingHeroArt: View {
    let step: OnboardingStep

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppPalette.receivedBubble)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.weChatGreen.opacity(0.26), lineWidth: 1)

            switch step {
            case .chat:
                ChatHero()
            case .connect:
                ConnectHero()
            case .profile:
                QRHero()
            }
        }
    }
}

private struct ChatHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeroBubble(text: "Can someone start laundry?", icon: "bubble.left.fill", isAccent: false)
                .frame(maxWidth: 270, alignment: .leading)
            HStack {
                Spacer(minLength: 40)
                HeroBubble(text: "I can do it after dinner.", icon: "checkmark.circle.fill", isAccent: true)
                    .frame(maxWidth: 250, alignment: .trailing)
            }
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.clipboard.fill")
                    .foregroundStyle(AppPalette.weChatGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Laundry")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Text("Assigned from chat")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }
                Spacer()
                Text("Tonight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.weChatGreen)
            }
            .padding(12)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(18)
    }
}

private struct ConnectHero: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppPalette.weChatGreen.opacity(0.28), lineWidth: 18)
                .frame(width: 150, height: 150)
            Circle()
                .stroke(AppPalette.weChatGreen.opacity(0.18), lineWidth: 12)
                .frame(width: 210, height: 210)
            HStack(spacing: 16) {
                HeroIcon(systemName: "person.crop.circle.badge.plus")
                HeroIcon(systemName: "dot.radiowaves.left.and.right", isAccent: true)
                HeroIcon(systemName: "qrcode.viewfinder")
            }
        }
        .padding(18)
    }
}

private struct QRHero: View {
    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                BrandMark(size: 54)
                Text("My QR")
                    .font(.title.bold())
                    .foregroundStyle(AppPalette.ink)
                Text("Always one tap from the chat list.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            QRSketch()
                .frame(width: 128, height: 128)
        }
        .padding(18)
    }
}

private struct HeroBubble: View {
    let text: String
    let icon: String
    let isAccent: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(isAccent ? AppPalette.onAccent : AppPalette.weChatGreen)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isAccent ? AppPalette.onAccent : AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(isAccent ? AppPalette.weChatGreen : AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HeroIcon: View {
    let systemName: String
    var isAccent = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(isAccent ? AppPalette.onAccent : AppPalette.ink)
            .frame(width: 66, height: 66)
            .background(isAccent ? AppPalette.weChatGreen : AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct QRSketch: View {
    private let cells: [[Bool]] = [
        [true, true, true, false, true, false, true],
        [true, false, true, false, false, true, false],
        [true, true, true, false, true, false, true],
        [false, false, false, true, false, true, false],
        [true, false, true, false, true, true, true],
        [false, true, false, true, true, false, true],
        [true, false, true, false, true, true, false]
    ]

    var body: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(cells.indices, id: \.self) { row in
                GridRow {
                    ForEach(cells[row].indices, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(cells[row][column] ? AppPalette.ink : Color.white)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DiscoveryOptionButton: View {
    let title: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? AppPalette.onAccent : AppPalette.weChatGreen)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? AppPalette.weChatGreen : AppPalette.receivedBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingFooter: View {
    let step: OnboardingStep
    let canStart: Bool
    let validationMessage: String?
    let next: () -> Void
    let back: () -> Void
    let start: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if step == .profile {
                Button("Open Chat", action: start)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canStart)
                    .accessibilityIdentifier("onboarding.start")
                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppPalette.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("onboarding.validation")
                }
            } else {
                Button(step == .chat ? "Next" : "Set Up Profile", action: next)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("onboarding.next")
            }

            if step.previous != nil {
                Button("Back", action: back)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("onboarding.back")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(AppPalette.canvas)
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
            BrandMark()

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
