import Foundation
import UserNotifications

/// Schedules and cancels local notifications for the dog's daily routine
/// (meals, walks, and play sessions). Uses the unified ScheduleItem model as its single source of truth.
@MainActor
final class ReminderManager {
    static let shared = ReminderManager()

    private let center       = UNUserNotificationCenter.current()
    private let idPrefix     = "com.smartkennel.routine."
    private let healthPrefix = "com.smartkennel.health."
    private let maxSlots     = 20   // upper bound on schedule items we'll ever schedule

    /// Hour of day (local time) to fire health reminders on their due date.
    private let healthFireHour = 9

    /// Days before the due date to fire a heads-up health reminder.
    private let healthLeadDays = 3

    private init() {}

    // MARK: - Public API

    /// Reschedules all notifications from the current profile — both daily routine
    /// (meal/walk/play) and health (vaccines, vet check-ups).
    /// Safe to call on every profile change — clears matching pending requests first.
    func scheduleAllReminders(profile: DogProfile) {
        Task {
            await scheduleRoutineReminders(items: profile.scheduleItems, profile: profile)
            await scheduleHealthReminders(profile: profile)
        }
    }

    /// Removes all PuppyCare routine notifications.
    func cancelAllReminders() {
        let ids = (0..<maxSlots).map { idPrefix + "\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        cancelAllHealthReminders()
    }

    /// Removes all pending health-reminder notifications.
    /// Uses the pending-requests query because health IDs are key-based, not slot-based.
    func cancelAllHealthReminders() {
        Task { [healthPrefix, center] in
            let pending   = await center.pendingNotificationRequests()
            let healthIds = pending.map(\.identifier).filter { $0.hasPrefix(healthPrefix) }
            if !healthIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: healthIds)
            }
        }
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

    // MARK: - Health reminders (vaccines, vet check-ups)

    /// Schedules a due-date notification (and 3-day heads-up) for every active,
    /// non-dismissed health reminder with a concrete dueDate. Past-due items are
    /// fired as an immediate notification so the user doesn't miss them.
    private func scheduleHealthReminders(profile: DogProfile) async {
        // Clear existing health-reminder requests first.
        let pending = await center.pendingNotificationRequests()
        let stale   = pending.map(\.identifier).filter { $0.hasPrefix(healthPrefix) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        guard let items = profile.derivedHealthReminders?.activeItems else { return }

        let dogName  = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        let nameText = dogName.isEmpty ? "your dog" : dogName
        let calendar = Calendar.current
        let now      = Date()

        for item in items {
            guard let dueDate = item.dueDate else { continue }

            // ── Due-date notification ──────────────────────────────────────────
            let dueContent = UNMutableNotificationContent()
            dueContent.sound = .default
            dueContent.title = "\(item.category.icon.isEmpty ? "🩺" : "🩺") \(item.title)"
            dueContent.body  = "\(nameText) is due today — \(item.detail)"

            if dueDate > now {
                var comps = calendar.dateComponents([.year, .month, .day], from: dueDate)
                comps.hour   = healthFireHour
                comps.minute = 0
                let trigger  = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request  = UNNotificationRequest(
                    identifier: healthPrefix + "due." + item.key,
                    content: dueContent,
                    trigger: trigger
                )
                try? await center.add(request)
            } else {
                // Past-due — fire in 10s so the user sees it immediately on next launch/profile save.
                dueContent.title = "🩺 \(item.title) — overdue"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                let request = UNNotificationRequest(
                    identifier: healthPrefix + "overdue." + item.key,
                    content: dueContent,
                    trigger: trigger
                )
                try? await center.add(request)
                continue   // skip lead-time for past-due items
            }

            // ── Heads-up notification (3 days before due date) ─────────────────
            guard let leadDate = calendar.date(byAdding: .day, value: -healthLeadDays, to: dueDate),
                  leadDate > now else { continue }

            let leadContent = UNMutableNotificationContent()
            leadContent.sound = .default
            leadContent.title = "🩺 Upcoming: \(item.title)"
            leadContent.body  = "\(nameText) is due in \(healthLeadDays) days — book the appointment."

            var leadComps = calendar.dateComponents([.year, .month, .day], from: leadDate)
            leadComps.hour   = healthFireHour
            leadComps.minute = 0
            let leadTrigger  = UNCalendarNotificationTrigger(dateMatching: leadComps, repeats: false)
            let leadRequest  = UNNotificationRequest(
                identifier: healthPrefix + "lead." + item.key,
                content: leadContent,
                trigger: leadTrigger
            )
            try? await center.add(leadRequest)
        }
    }
}
