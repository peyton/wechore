import SwiftUI

struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String?
    @Environment(\.dismiss) private var dismiss

    private static let emojis = [
        "😊", "😎", "🤓", "🧑‍💻", "👩‍🍳", "🧹", "💪", "🌟",
        "🏠", "🐶", "🐱", "🌻", "🔥", "❄️", "🎯", "🎨",
        "🍕", "☕️", "🌈", "🦊", "🐻", "🌸", "⚡️", "🎵",
        "🧘", "🚀", "💜", "🌊", "🍀", "🦋",
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                        dismiss()
                    } label: {
                        Text(emoji)
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                selectedEmoji == emoji
                                    ? AppPalette.weChatGreen.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(emoji)
                }
            }
            .padding(18)
            .navigationTitle("Pick an avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if selectedEmoji != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Remove") {
                            selectedEmoji = nil
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
