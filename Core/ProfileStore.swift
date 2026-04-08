import Foundation
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile: DogProfile

    private let storageKey   = "smart_kennel_dog_profile"
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let data    = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(DogProfile.self, from: data)
        {
            self.profile = decoded
        } else {
            self.profile = .empty
        }

        setupAutoSave()
        setupKennelSessionTracking()
        setupThresholdSync()
        normalizeProfileIfNeeded()

        // Push current thresholds and schedule to singletons immediately on launch.
        syncThresholds(profile: profile)
        ReminderManager.shared.scheduleAllReminders(profile: profile)
    }

    // MARK: - Auto-save

    private func setupAutoSave() {
        $profile
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] updatedProfile in
                self?.saveImmediately()
                ReminderManager.shared.scheduleAllReminders(profile: updatedProfile)
            }
            .store(in: &cancellables)
    }

    func saveImmediately() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Kennel session tracking

    private func setupKennelSessionTracking() {
        $profile
            .map(\.isInKennel)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] inKennel in
                guard let self else { return }
                // Always stamp a fresh start when entering; always clear when leaving.
                // No == nil guard: if a stale kennelSessionStart survived from a previous
                // session we must overwrite it, not reuse it.
                self.profile.kennelSessionStart = inKennel ? Date() : nil
            }
            .store(in: &cancellables)
    }

    // MARK: - Threshold sync

    private func setupThresholdSync() {
        $profile
            .map { ($0.tempWarnHigh, $0.tempCriticalHigh, $0.tempWarnLow, $0.tempCriticalLow) }
            .removeDuplicates { $0 == $1 }
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.syncThresholds(profile: self.profile)
            }
            .store(in: &cancellables)
    }

    private func syncThresholds(profile: DogProfile) {
        AlertManager.shared.updateThresholds(
            warnHigh:     profile.tempWarnHigh,
            criticalHigh: profile.tempCriticalHigh,
            warnLow:      profile.tempWarnLow,
            criticalLow:  profile.tempCriticalLow
        )
    }

    // MARK: - Normalisation + one-time migration

    private func normalizeProfileIfNeeded() {
        var updated = profile
        var changed = false

        // String field defaults
        if updated.foodCaloriesPer100g.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.foodCaloriesPer100g = "380"; changed = true
        }
        if updated.morningMealTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.morningMealTime = "07:00"; changed = true
        }
        if updated.secondMealTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.secondMealTime = "11:00"; changed = true
        }
        if updated.thirdMealTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.thirdMealTime = "15:00"; changed = true
        }
        if updated.eveningMealTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.eveningMealTime = "19:00"; changed = true
        }

        // Kennel session — ensure state is consistent on every launch.
        if updated.isInKennel {
            // Start a fresh timer if none exists (e.g. first launch with kennel already on).
            if updated.kennelSessionStart == nil {
                updated.kennelSessionStart = Date(); changed = true
            }
        } else {
            // Clear any stale start time that survived a crash or debounce race.
            if updated.kennelSessionStart != nil {
                updated.kennelSessionStart = nil; changed = true
            }
        }

        // ── One-time migration from legacy meal + walkTimes → scheduleItems ──────────
        // Runs only if scheduleItems is empty AND legacy data exists.
        if updated.scheduleItems.isEmpty {
            var migrated: [ScheduleItem] = []

            // Migrate meals
            if updated.mealsPerDay > 0 {
                let times = legacyMealTimes(
                    firstTimeString: updated.morningMealTime,
                    mealsCount: updated.mealsPerDay
                )
                for t in times {
                    let timeStr = timeString(from: t)
                    migrated.append(ScheduleItem(
                        type:  .meal,
                        time:  timeStr,
                        label: ScheduleItem.autoLabel(type: .meal, timeString: timeStr),
                        grams: updated.gramsPerMeal > 0 ? updated.gramsPerMeal : nil
                    ))
                }
            }

            // Migrate walk times
            for walkTime in updated.walkTimes {
                migrated.append(ScheduleItem(
                    type:  .walk,
                    time:  walkTime,
                    label: ScheduleItem.autoLabel(type: .walk, timeString: walkTime)
                ))
            }

            if !migrated.isEmpty {
                updated.scheduleItems = migrated.sorted { $0.time < $1.time }
                changed = true
            }
        }

        if changed { profile = updated }
    }

    // MARK: - Public API

    func resetProfile() {
        ReminderManager.shared.cancelAllReminders()
        profile = .empty
        saveImmediately()
    }

    /// Called by DogProfileSetupView after the user completes the setup flow.
    /// Applies auto-derived sensor thresholds and health reminders to the live profile.
    /// Existing manual overrides are preserved if manualOverridesEnabled is true.
    func applyDerivedConfiguration(_ config: DogProfileEngine.DerivedConfiguration) {
        // Sensor thresholds — only apply if the user has not manually overridden them
        if !profile.manualOverridesEnabled {
            profile.tempWarnHigh     = config.sensorDefaults.tempWarnHigh
            profile.tempCriticalHigh = config.sensorDefaults.tempCriticalHigh
            profile.tempWarnLow      = config.sensorDefaults.tempWarnLow
            profile.tempCriticalLow  = config.sensorDefaults.tempCriticalLow
        }
        // Always update operational profile, reminders, and completion flag
        profile.selectedOperationalProfile = config.operationalProfile
        profile.derivedHealthReminders     = config.healthReminders
        profile.hasCompletedProfileSetup   = true

        syncThresholds(profile: profile)
        saveImmediately()
    }

    // MARK: - Legacy meal-time calculation (used only for migration)

    private func legacyMealTimes(firstTimeString: String, mealsCount: Int) -> [Date] {
        guard mealsCount > 0 else { return [] }
        let lastMealLimitMinutes = 20 * 60

        let parts  = firstTimeString.split(separator: ":").compactMap { Int($0) }
        let h      = parts.count >= 1 ? parts[0] : 7
        let m      = parts.count >= 2 ? parts[1] : 0
        let cal    = Calendar.current
        let first  = cal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()

        guard mealsCount > 1 else { return [first] }

        let firstMinutes = h * 60 + m
        let totalSpan    = lastMealLimitMinutes - firstMinutes
        guard totalSpan > 0 else { return Array(repeating: first, count: mealsCount) }

        let interval = Double(totalSpan) / Double(mealsCount - 1)
        return (0..<mealsCount).map { i in
            let rawMinutes = Double(firstMinutes) + Double(i) * interval
            let rounded    = Int((rawMinutes / 5).rounded()) * 5
            let hour       = min(rounded / 60, 23)
            let minute     = rounded % 60
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private func timeString(from date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

// MARK: - Tuple Equatable helper

private func == (
    lhs: (Double, Double, Double, Double),
    rhs: (Double, Double, Double, Double)
) -> Bool {
    lhs.0 == rhs.0 && lhs.1 == rhs.1 && lhs.2 == rhs.2 && lhs.3 == rhs.3
}
