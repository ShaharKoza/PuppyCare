import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct PuppyCareApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var localization = Localization.shared
    @StateObject private var notifications = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Sign in anonymously so the RTDB security rules (auth != null) accept
        // every write the iOS client makes — primarily the FCM token. The
        // server-side Cloud Function uses the Admin SDK and bypasses rules,
        // so it's unaffected. Anonymous Auth is free, requires no UI, and
        // creates a stable per-install identity that survives app restarts.
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { _, error in
                if let error {
                    print("[Auth] Anonymous sign-in failed: \(error.localizedDescription)")
                }
            }
        }
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(localization)
                .environmentObject(notifications)
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
                        // Re-derive the dog's operational profile + health
                        // reminders against the CURRENT calendar — a dog that
                        // aged past the puppy threshold while the app was
                        // backgrounded would otherwise keep using puppy alert
                        // rules, and the rabies due date would never roll to
                        // the next anniversary.
                        profileStore.recomputeDerivedConfiguration()
                        // Re-check notifications permission — the user may
                        // have toggled it from Settings.app while we were
                        // backgrounded.
                        Task { await notifications.refreshAuthorizationStatus() }
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
