import FirebaseMessaging
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() { super.init() }

    // Call once at app launch, before requesting permission.
    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    // Request user permission and register with APNs.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        guard let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge]),
              granted
        else { return }
        // registerForRemoteNotifications() is synchronous — no await needed.
        UIApplication.shared.registerForRemoteNotifications()
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
