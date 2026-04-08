import Foundation
import UserNotifications

/// Schedules and cancels local notifications for the dog's daily routine
/// (meals, walks, and play sessions). Uses the unified ScheduleItem model as its single source of truth.
@MainActor
final class ReminderManager {
    static let shared = ReminderManager()

    private let center      = UNUserNotificationCenter.current()
    private let idPrefix    = "com.smartkennel.routine."
    private let maxSlots    = 20   // upper bound on schedule items we'll ever schedule

    private init() {}

    // MARK: - Public API

    /// Reschedules all notifications from the current profile's schedule items.
    /// Safe to call on every profile change — clears all existing routine notifications first.
    func scheduleAllReminders(profile: DogProfile) {
        Task {
            await scheduleRoutineReminders(items: profile.scheduleItems, profile: profile)
        }
    }

    /// Removes all PuppyCare routine notifications.
    func cancelAllReminders() {
        let ids = (0..<maxSlots).map { idPrefix + "\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Internal scheduling

    private func scheduleRoutineReminders(items: [ScheduleItem], profile: DogProfile) async {
        // Clear all existing routine slots
        cancelAllReminders()

        guard !items.isEmpty else { return }

        let dogName  = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let nameText = dogName.isEmpty ? "your dog" : dogName
        let food     = profile.foodName.trimmingCharacters(in: .whitespacesAndNewlines)

        let sorted = items.sorted { $0.time < $1.time }

        for (index, item) in sorted.prefix(maxSlots).enumerated() {
            let parts = item.time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { continue }

            let content = UNMutableNotificationContent()
            content.sound = .default

            switch item.type {
            case .meal:
                content.title = "\(item.type.notificationEmoji) \(item.label)"
                let gramsText = item.grams.map { "\($0) g" } ?? ""
                let detail    = [gramsText, food].filter { !$0.isEmpty }.joined(separator: " ")
                content.body  = detail.isEmpty
                    ? "Time to feed \(nameText)"
                    : "Time to feed \(nameText) — \(detail)"

            case .walk:
                content.title = "\(item.type.notificationEmoji) \(item.label)"
                content.body  = "Time for \(nameText)'s walk"

            case .play:
                content.title = "\(item.type.notificationEmoji) \(item.label)"
                let durText   = item.durationMinutes.map { "\($0) min" } ?? ""
                content.body  = durText.isEmpty
                    ? "Time for \(nameText)'s play session"
                    : "Time for \(nameText)'s play session — \(durText)"
            }

            var components    = DateComponents()
            components.hour   = parts[0]
            components.minute = parts[1]

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: idPrefix + "\(index)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
