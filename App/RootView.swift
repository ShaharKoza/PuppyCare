import SwiftUI

struct RootView: View {
    @EnvironmentObject var profileStore: ProfileStore

    var body: some View {
        Group {
            if profileStore.profile.hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}
