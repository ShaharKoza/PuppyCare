import SwiftUI

struct RootView: View {
    @EnvironmentObject var profileStore: ProfileStore

    var body: some View {
        Group {
            if !profileStore.profile.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(profileStore)
            } else if !profileStore.profile.hasCompletedProfileSetup {
                DogProfileSetupView()
                    .environmentObject(profileStore)
            } else {
                ContentView()
                    .environmentObject(profileStore)
            }
        }
    }
}
