import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profileStore: ProfileStore
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
            .tabItem { Label("Home", systemImage: "house.fill") }
            .badge(alertManager.unreadCount)
            .tag(0)

            // MARK: Daily Routine
            NavigationStack {
                DailyRoutineView()
                    .environmentObject(profileStore)
            }
            .tabItem { Label("Routine", systemImage: "list.bullet.clipboard.fill") }
            .tag(1)

            // MARK: Food Assistant
            NavigationStack {
                FoodAssistantView()
                    .environmentObject(profileStore)
            }
            .tabItem { Label("Assistant", systemImage: "sparkles") }
            .tag(2)

            // MARK: Training
            NavigationStack {
                TrainingView()
            }
            .tabItem { Label("Training", systemImage: "figure.walk.dog") }
            .tag(3)

            // MARK: Profile
            NavigationStack {
                ProfileView()
                    .environmentObject(profileStore)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(4)
        }
        .tint(AppTheme.accentBrown)
    }
}
