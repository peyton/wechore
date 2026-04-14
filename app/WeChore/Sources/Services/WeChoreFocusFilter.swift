import AppIntents

@available(iOS 16.0, *)
struct WeChoreFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "WeChore Focus"
    static let description: IntentDescription = "Configure WeChore notifications during Focus."

    @Parameter(title: "Show notifications", default: true)
    var showNotifications: Bool

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(showNotifications, forKey: "focusFilterShowNotifications")
        return .result()
    }
}
