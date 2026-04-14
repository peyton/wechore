import Contacts
import ContactsUI
import SwiftUI

struct ContactSelection: Equatable {
    var displayName: String
    var contactValue: String
}

struct ContactPicker: UIViewControllerRepresentable {
    let onSelect: (ContactSelection) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onSelect: (ContactSelection) -> Void
        private let onCancel: () -> Void

        init(onSelect: @escaping (ContactSelection) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func contactPicker(_: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(ContactSelection(
                displayName: contact.weChoreDisplayName,
                contactValue: contact.weChorePreferredContactValue
            ))
            onCancel()
        }

        func contactPickerDidCancel(_: CNContactPickerViewController) {
            onCancel()
        }
    }
}

private extension CNContact {
    var weChoreDisplayName: String {
        let formatted = CNContactFormatter.string(from: self, style: .fullName) ?? ""
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Contact" : trimmed
    }

    var weChorePreferredContactValue: String {
        if let email = emailAddresses.first?.value {
            return String(email)
        }
        if let phone = phoneNumbers.first?.value.stringValue {
            return phone
        }
        return ""
    }
}
