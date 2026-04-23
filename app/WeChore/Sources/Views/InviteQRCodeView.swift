import SwiftUI
import UIKit

struct InviteQRCodeCard: View {
    let payload: InvitePayload
    var title: String = "Scan to join"
    var detail: String = "Open Camera, point it at this code, then tap the WeChore join banner."
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                BrandMark(size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Text(payload.threadTitle)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                }
            }

            QRCodeImage(text: payload.universalURL.absoluteString)
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("invite.qr")

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text("Expires \(payload.expiresAt.weChoreShortDueText)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
                .accessibilityIdentifier("invite.expires")

            HStack(spacing: 10) {
                Text("Code \(payload.code)")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(AppPalette.receivedBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("invite.qrCodeText")
                Spacer()
                Button {
                    UIPasteboard.general.string = payload.shareText
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("invite.copyLink")
                ShareLink(item: payload.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("invite.qrShare")
            }
        }
        .padding(14)
        .background(AppPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct QRCodeImage: View {
    let text: String

    var body: some View {
        if let image = QRCodeRenderer.makeImage(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("QR code")
        } else {
            ContentUnavailableView("QR code unavailable", systemImage: "qrcode")
                .frame(minHeight: 220)
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppPalette.weChatGreen)
            Image(systemName: "checklist.checked")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(AppPalette.onAccent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
