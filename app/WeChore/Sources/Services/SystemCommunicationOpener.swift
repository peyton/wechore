import Foundation
import MessageUI
import SwiftUI
import UIKit

public enum CommunicationChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case faceTimeAudio
    case phone
    case message

    public var id: String { rawValue }
}

public protocol SystemCommunicationOpening: Sendable {
    func preferredVoiceURL(for member: Member) -> URL?
    @MainActor func openVoice(for member: Member) async -> Bool
}

public struct AppleSystemCommunicationOpener: SystemCommunicationOpening {
    public init() {}

    public func preferredVoiceURL(for member: Member) -> URL? {
        if let faceTimeHandle = member.faceTimeHandle, !faceTimeHandle.isEmpty {
            return URL(string: "facetime-audio://\(faceTimeHandle)")
        }
        if let phoneNumber = member.phoneNumber, !phoneNumber.isEmpty {
            let digits = phoneNumber.filter(\.isNumber)
            return URL(string: "tel:\(digits)")
        }
        return nil
    }

    @MainActor
    public func openVoice(for member: Member) async -> Bool {
        guard let url = preferredVoiceURL(for: member) else { return false }
        if RuntimeEnvironment.isRunningUITests {
            return true
        }
        return await UIApplication.shared.open(url)
    }
}

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, @preconcurrency MFMessageComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        @MainActor
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onFinish()
        }
    }
}
