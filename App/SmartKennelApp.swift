import SwiftUI
import FirebaseCore

@main
struct PuppyCareApp: App {
    @StateObject private var profileStore = ProfileStore()
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
