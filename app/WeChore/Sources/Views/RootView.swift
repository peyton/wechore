import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if appState.settings.hasCompletedOnboarding {
                if horizontalSizeClass == .regular {
                    IPadRootView()
                } else {
                    PhoneRootView()
                }
            } else {
                OnboardingView()
            }
        }
        .background(AppPalette.canvas)
    }
}

private struct PhoneRootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedRoute) {
            ForEach(AppRoute.allCases) { route in
                NavigationStack {
                    destination(for: route)
                        .navigationTitle(route.title)
                }
                .tabItem {
                    Label(route.title, systemImage: route.systemImage)
                }
                .tag(route)
            }
        }
        .accessibilityIdentifier("root.phoneTabs")
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .chores:
            ChoresView()
        case .messages:
            MessagesView()
        case .household:
            HouseholdView()
        case .settings:
            SettingsView()
        }
    }
}

private struct IPadRootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(AppRoute.allCases) { route in
                    Button {
                        router.selectedRoute = route
                    } label: {
                        Label(route.title, systemImage: route.systemImage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sidebar.\(route.rawValue)")
                }
            }
            .navigationTitle("WeChore")
            .accessibilityIdentifier("root.sidebar")
        } detail: {
            NavigationStack {
                destination(for: router.selectedRoute)
                    .navigationTitle(router.selectedRoute.title)
            }
        }
        .accessibilityIdentifier("root.ipadSplit")
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .chores:
            ChoresView()
        case .messages:
            MessagesView()
        case .household:
            HouseholdView()
        case .settings:
            SettingsView()
        }
    }
}
