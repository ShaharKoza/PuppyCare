import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var loc: Localization
    @ObservedObject private var alertManager = AlertManager.shared
    @State private var selectedTab: Int = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.pageBackground)
        appearance.shadowColor     = .clear
        appearance.shadowImage     = UIImage()

        let normalAttributes:   [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.secondaryLabel]
        let selectedAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor(AppTheme.accentBrown)]

        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            layout.normal.iconColor          = UIColor.secondaryLabel
            layout.normal.titleTextAttributes   = normalAttributes
            layout.selected.iconColor        = UIColor(AppTheme.accentBrown)
            layout.selected.titleTextAttributes = selectedAttributes
        }

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: Home
            NavigationStack {
                DashboardView(selectedTab: $selectedTab)
                    .environmentObject(profileStore)
            }
            .tabItem { Label(loc.t("Home"), systemImage: "house.fill") }
            .badge(alertManager.unreadCount)
            .tag(0)

            // MARK: Daily Routine
            NavigationStack {
                DailyRoutineView()
                    .environmentObject(profileStore)
            }
            .tabItem { Label(loc.t("Routine"), systemImage: "list.bullet.clipboard.fill") }
            .tag(1)

            // MARK: Food Assistant
            NavigationStack {
                FoodAssistantView()
                    .environmentObject(profileStore)
            }
            .tabItem { Label(loc.t("Assistant"), systemImage: "sparkles") }
            .tag(2)

            // MARK: Profile
            NavigationStack {
                ProfileView()
                    .environmentObject(profileStore)
            }
            .tabItem { Label(loc.t("Profile"), systemImage: "person.crop.circle") }
            .tag(3)
        }
        .tint(AppTheme.accentBrown)
        // Force the TabView to re-render when the language toggles —
        // tabItem labels are computed once on first render otherwise.
        .id(loc.language)
    }
}
