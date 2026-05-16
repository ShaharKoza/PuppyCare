import FirebaseMessaging
import UserNotifications
import UIKit
import Combine

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    /// Latest authorization status from `UNUserNotificationCenter`. Views
    /// observe this to surface a banner like "Notifications are off — open
    /// Settings" when the user has explicitly denied permission, otherwise
    /// the entire health-reminder feature silently fails for them.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() { super.init() }

    // Call once at app launch, before requesting permission.
    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    // Request user permission and register with APNs.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        guard granted else { return }
        // registerForRemoteNotifications() is synchronous — no await needed.
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Re-read the current status from iOS. Call after the user returns from
    /// Settings.app so the UI banner reflects a freshly-granted permission.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Convenience flag for views — true only if the user explicitly denied
    /// notifications. `.notDetermined` and `.authorized` both render normally.
    var isExplicitlyDenied: Bool {
        authorizationStatus == .denied
    }

    /// Deep-link into the app's own page in Settings.app so the user can
    /// toggle notifications back on without hunting for the row themselves.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - FCM Token

extension NotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { @MainActor in
            FirebaseService.shared.saveFCMToken(token)
        }
    }
}

// MARK: - Foreground presentation

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show banner + sound even when the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    // Clear badge when user taps the notification.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // iOS 16+ API — replaces the deprecated applicationIconBadgeNumber property.
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
