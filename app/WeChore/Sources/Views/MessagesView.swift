import SwiftUI

struct MessagesView: View {
    @Environment(AppState.self) private var appState
    @State private var message = ""
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Household messages")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppPalette.ink)
                    Text("Suggestions only come from messages typed here.")
                        .font(.headline)
                        .foregroundStyle(AppPalette.muted)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Sam please unload dishwasher tomorrow", text: $message, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("message.input")
                        .textFieldStyle(.roundedBorder)
                        .focused($isMessageFocused)
                    Button("Post Message") {
                        appState.postMessage(message)
                        message = ""
                        isMessageFocused = false
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("message.post")
                }
                .padding(14)
                .background(AppPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                SuggestionList()
                MessageList()
            }
            .padding(18)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(AppPalette.canvas)
    }
}

private struct SuggestionList: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested chores")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.ink)
            if appState.suggestions.isEmpty {
                EmptyState(text: "No suggestions yet. Try asking someone to clean, unload, wash, or take out something.")
                    .accessibilityIdentifier("suggestions.empty")
            } else {
                ForEach(appState.suggestions) { suggestion in
                    Button {
                        appState.acceptSuggestion(suggestion)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.title)
                                    .font(.headline)
                                Text(suggestion.dueDate.map { "Due \($0.weChoreShortDueText)" } ?? "No due date")
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.muted)
                            }
                            Spacer()
                            Text("Add")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppPalette.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppPalette.receivedBubble)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(14)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggestion.accept.\(suggestion.id)")
                }
            }
        }
    }
}

private struct MessageList: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thread")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.ink)
            if appState.messages.isEmpty {
                EmptyState(text: "No household messages yet.")
                    .accessibilityIdentifier("messages.empty")
            } else {
                ForEach(appState.messages) { message in
                    let isCurrentUser = message.authorMemberID == appState.currentMember.id
                    Text(message.body)
                        .font(.body)
                        .foregroundStyle(isCurrentUser ? AppPalette.onAccent : AppPalette.ink)
                        .padding(12)
                        .frame(maxWidth: 520, alignment: isCurrentUser ? .trailing : .leading)
                        .background(isCurrentUser ? AppPalette.sentBubble : AppPalette.receivedBubble)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                        .accessibilityIdentifier("message.row.\(message.id)")
                }
            }
        }
    }
}
