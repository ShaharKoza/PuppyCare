import SwiftUI
import FirebaseCore

@main
struct PuppyCareApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var localization = Localization.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(localization)
                // Flip the entire UI to RTL when Hebrew is selected.
                // SwiftUI mirrors layouts, navigation chevrons, leading/trailing
                // alignment, swipe gestures, etc. automatically from this single hint.
                .environment(\.layoutDirection, localization.language.layoutDirection)
                .environment(\.locale, localization.language.locale)
                // Flush any in-flight debounced save the instant the app leaves the foreground.
                // This guarantees that the last edit is persisted even if the user force-quits
                // within the 500 ms debounce window.
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        FirebaseService.shared.startListening()
                    case .background, .inactive:
                        profileStore.saveImmediately()
                    default:
                        break
                    }
                }
                .task {
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
