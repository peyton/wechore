import SwiftUI
import UIKit

enum AppPalette {
    static let weChatGreen = Color(red: 0.027, green: 0.757, blue: 0.376)
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.97, blue: 0.95, alpha: 1)
            : UIColor(red: 0.08, green: 0.10, blue: 0.09, alpha: 1)
    })
    static let muted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.66, green: 0.72, blue: 0.68, alpha: 1)
            : UIColor(red: 0.36, green: 0.42, blue: 0.38, alpha: 1)
    })
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.07, blue: 0.06, alpha: 1)
            : UIColor(red: 0.94, green: 0.98, blue: 0.95, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.13, blue: 0.11, alpha: 1)
            : UIColor.white
    })
    static let receivedBubble = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.19, blue: 0.17, alpha: 1)
            : UIColor(red: 0.90, green: 0.94, blue: 0.91, alpha: 1)
    })
    static let sentBubble = weChatGreen
    static let warning = Color(red: 0.94, green: 0.54, blue: 0.14)
    static let danger = Color(red: 0.86, green: 0.20, blue: 0.22)
    static let onAccent = Color(red: 0.02, green: 0.08, blue: 0.04)
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppPalette.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppPalette.weChatGreen.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppPalette.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(AppPalette.surface.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension Date {
    var weChoreShortDueText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
