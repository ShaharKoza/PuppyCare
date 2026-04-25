import Foundation
import Combine
import SwiftUI

// MARK: - Alert Models

enum AlertType: String, Codable, CaseIterable {
    case temperature, sound, motion, light

    var icon: String {
        switch self {
        case .temperature: return "thermometer.medium"
        case .sound:       return "waveform"
        case .motion:      return "figure.walk"
        case .light:       return "lightbulb.fill"
        }
    }

    var tint: Color {
        switch self {
        case .temperature: return .orange
        case .sound:       return .purple
        case .motion:      return .blue
        case .light:       return .yellow
        }
    }

    var displayName: String {
        switch self {
        case .temperature: return "Temperature"
        case .sound:       return "Sound"
        case .motion:      return "Motion"
        case .light:       return "Light"
        }
    }
}

enum AlertSeverity: String, Codable {
    case critical, warning, info

    var label: String {
        switch self {
        case .critical: return "Critical"
        case .warning:  return "Warning"
        case .info:     return "Info"
        }
    }

    var badgeColor: Color {
        switch self {
        case .critical: return .red
        case .warning:  return .orange
        case .info:     return .blue
        }
    }
}

struct AlertRecord: Codable, Identifiable {
    var id: UUID
    var type: AlertType
    var severity: AlertSeverity
    var title: String
    var detail: String
    var sensorValue: Double?
    var unit: String?
    var timestamp: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        type: AlertType,
        severity: AlertSeverity,
        title: String,
        detail: String,
        sensorValue: Double? = nil,
        unit: String? = nil,
        timestamp: Date = Date(),
        isRead: Bool = false
    ) {
        self.id          = id
        self.type        = type
        self.severity    = severity
        self.title       = title
        self.detail      = detail
        self.sensorValue = sensorValue
        self.unit        = unit
        self.timestamp   = timestamp
        self.isRead      = isRead
    }
}

// MARK: - Analytics Models

struct SensorSnapshot {
    var hour: Int
    var averageTemperature: Double?
    var totalBarks: Int
    var motionMinutes: Int
}

enum DaySummaryStatus {
    case good, someConcerns, needsAttention

    var label: String {
        switch self {
        case .good:           return "All Good"
        case .someConcerns:   return "Some Concerns"
        case .needsAttention: return "Needs Attention"
        }
    }

    var color: Color {
        switch self {
        case .good:           return .green
        case .someConcerns:   return .orange
        case .needsAttention: return .red
        }
    }

    var icon: String {
        switch self {
        case .good:           return "checkmark.circle.fill"
        case .someConcerns:   return "exclamationmark.circle.fill"
        case .needsAttention: return "xmark.circle.fill"
        }
    }
}

struct BehaviorInsight: Identifiable {
    let id    = UUID()
    let icon:  String
    let text:  String
    let color: Color
}

// MARK: - Analytics Engine

struct SensorAnalytics {
    let records: [AlertRecord]
    private static let calendar = Calendar.current

    var todayRecords: [AlertRecord] {
        let start = Self.calendar.startOfDay(for: Date())
        return records.filter { $0.timestamp >= start }
    }

    var barksByHour: [Int: Int] {
        var buckets = [Int: Int]()
        for record in records where record.type == .sound {
            let hour = Self.calendar.component(.hour, from: record.timestamp)
            buckets[hour, default: 0] += 1
        }
        return buckets
    }

    var totalBarksToday: Int { todayRecords.filter { $0.type == .sound }.count }

    var peakBarkHour: Int?  { barksByHour.max(by: { $0.value < $1.value })?.key }
    var peakBarkCount: Int  { barksByHour.values.max() ?? 0 }

    var activeHours: Set<Int> {
        Set(todayRecords.filter { $0.type == .motion }
            .map { Self.calendar.component(.hour, from: $0.timestamp) })
    }

    var totalActiveMinutesEstimate: Int { activeHours.count * 15 }

    var mostActiveHour: Int? {
        var counts = [Int: Int]()
        for record in todayRecords where record.type == .motion {
            let hour = Self.calendar.component(.hour, from: record.timestamp)
            counts[hour, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var minTempToday: Double? {
        todayRecords.filter { $0.type == .temperature }.compactMap { $0.sensorValue }.min()
    }
    var maxTempToday: Double? {
        todayRecords.filter { $0.type == .temperature }.compactMap { $0.sensorValue }.max()
    }

    var minutesOutsideSafeRange: Int { todayRecords.filter { $0.type == .temperature }.count * 5 }
    var safeTempPercent: Int {
        let unsafe = min(minutesOutsideSafeRange, 1440)
        return Int(((1440.0 - Double(unsafe)) / 1440.0) * 100)
    }

    var todayWarnings: Int  { todayRecords.filter { $0.severity == .warning  }.count }
    var todayCriticals: Int { todayRecords.filter { $0.severity == .critical }.count }

    var overallStatus: DaySummaryStatus {
        if todayCriticals > 0  { return .needsAttention }
        if todayWarnings  > 2  { return .someConcerns   }
        return .good
    }

    var behaviorInsights: [BehaviorInsight] {
        var insights = [BehaviorInsight]()

        if let peak = peakBarkHour, peakBarkCount >= 3 {
            insights.append(BehaviorInsight(
                icon:  "waveform",
                text:  "Peak barking at \(String(format: "%02d:00", peak)) — \(peakBarkCount) events",
                color: .purple
            ))
        }

        if let active = mostActiveHour {
            insights.append(BehaviorInsight(
                icon:  "figure.walk",
                text:  "Most active around \(String(format: "%02d:00", active))",
                color: .blue
            ))
        }

        if let max = maxTempToday, max > 28 {
            insights.append(BehaviorInsight(
                icon:  "thermometer.high",
                text:  String(format: "Temperature peaked at %.1f°C today", max),
                color: .orange
            ))
        }

        if let min = minTempToday, min < 12 {
            insights.append(BehaviorInsight(
                icon:  "thermometer.low",
                text:  String(format: "Temperature dropped to %.1f°C today", min),
                color: .cyan
            ))
        }

        if totalBarksToday == 0 && totalActiveMinutesEstimate > 0 {
            insights.append(BehaviorInsight(
                icon: "checkmark.seal.fill", text: "Quiet day — no barking recorded", color: .green
            ))
        }

        if insights.isEmpty {
            insights.append(BehaviorInsight(
                icon: "pawprint.fill", text: "Not enough data yet for insights", color: .secondary
            ))
        }

        return insights
    }

    var last12HoursBarksByHour: [(hour: Int, count: Int)] {
        let now         = Date()
        let currentHour = Self.calendar.component(.hour, from: now)
        return (0..<12).map { offset in
            let hour = (currentHour - 11 + offset + 24) % 24
            return (hour: hour, count: barksByHour[hour] ?? 0)
        }
    }
}

// MARK: - Alert Config
//
// Research sources:
//   • Merck Veterinary Manual — Neonatal care & thermoregulation
//   • AVMA — Animal housing temperature guidelines
//   • Brachycephalic Obstructive Airway Syndrome (BOAS) literature
//   • Canine geriatrics & pediatrics textbooks
//
// All thresholds are ambient kennel temperature (°C), not body temperature.

struct AlertConfig {

    // ── Temperature thresholds (°C) ──────────────────────────────────────────
    var tempWarnHigh:     Double = 28
    var tempCriticalHigh: Double = 32
    var tempWarnLow:      Double = 12
    var tempCriticalLow:  Double = 8

    // ── Sound behaviour ───────────────────────────────────────────────────────
    /// Sensitivity level drives re-alert cooldown (high = 30 s, standard = 60 s, low = 120 s).
    var soundSensitivity: SoundSensitivityLevel = .standard
    /// false → bark events alone do NOT trigger an alert; only sustainedSound does.
    /// Used for neonatal puppies (whimper/cry, not bark) and brachycephalics (breathing noise).
    var soundAsStandaloneTrigger: Bool = true

    // ── Motion & inactivity ───────────────────────────────────────────────────
    var motionSensitivity: MotionSensitivityLevel = .standard
    /// Seconds of no motion before an inactivity alert fires. 0 = disabled.
    /// Neonatal puppies sleep ~90 % of the day — inactivity is normal → disabled.
    var inactiveAlertAfterSeconds: Int = 3600   // 60 min default

    // ── Profile context (drives message wording) ──────────────────────────────
    var operationalProfile: OperationalDogProfile = .smallDog
    /// nil = not a puppy / age unknown; set for OperationalDogProfile.youngPuppy.
    var puppyAgeMonths: Double? = nil
}

// MARK: - Alert Manager

@MainActor
final class AlertManager: ObservableObject {
    static let shared = AlertManager()

    @Published private(set) var records: [AlertRecord] = []
    @Published private(set) var unreadCount: Int = 0

    private let maxRecords    = 500
    private let retentionDays = 30

    // Live config — fully updated by ProfileStore when profile changes.
    private var config = AlertConfig()

    private let saveURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("alert_history.json")
    }()

    private var cancellable: AnyCancellable?
    private let saveTrigger = PassthroughSubject<Void, Never>()

    private var isFirstUpdate = true

    // Per-type last-alert timestamps
    private var lastBarkAlertDate:       Date?
    private var lastMotionAlertDate:     Date?
    private var lastTempAlertDate:       Date?
    private var lastLightAlertDate:      Date?
    private var lastCombinedAlertDate:   Date?
    private var lastInactivityAlertDate: Date?
    /// When the last motion-off transition was observed. Used to measure inactivity
    /// duration without requiring the Pi to write a secondsSinceMotion field.
    private var lastMotionStoppedDate:   Date?

    // ── Co-occurrence tracking for the combined (motion+sound) critical alert ──
    /// Last time we saw a bark event in any sensor update.
    private var lastBarkObservedAt:   Date?
    /// Last time we saw a motion-onset edge in any sensor update.
    private var lastMotionObservedAt: Date?
    /// Window for "both happened" — if a bark and a motion edge fall inside this
    /// window, the situation is upgraded to a critical combined alert.
    private let combinedWindow: TimeInterval = 30

    // Fixed cooldowns that don't depend on sensitivity
    private let tempCooldown:       TimeInterval = 300
    private let motionCooldown:     TimeInterval = 300   // baseline; overridden by sensitivity
    private let lightCooldown:      TimeInterval = 300   // 5 min between light state-change alerts
    private let combinedCooldown:   TimeInterval = 120   // 2 min between combined critical alerts
    /// Minimum re-alert gap for inactivity — prevent flooding while dog stays asleep.
    private let inactivityAlertCooldown: TimeInterval = 1800  // 30 min

    // Edge-detection state
    private var prevMotionDetected: Bool?
    private var prevLightDetected:  Bool?

    private init() {
        loadFromDisk()
        setupDebouncedSave()
    }

    // MARK: - Public API

    /// Pipeline:
    ///   1. Temperature — independent of motion/sound, runs first.
    ///   2. Stamp current bark / motion-edge observations into the rolling window.
    ///   3. Combined alert — if bark + motion-edge fall inside the same window,
    ///      emit ONE critical record and suppress the individual sound/motion
    ///      alerts for this cycle (avoids three records from one event).
    ///   4. Otherwise: standalone sound alert (any bark) and standalone motion
    ///      alert (motion onset). Both are Warning level — the user wanted
    ///      immediate, visible alerts on either signal.
    ///   5. Light + inactivity housekeeping.
    func processSensorUpdate(_ sensor: SensorData) {
        defer { isFirstUpdate = false }

        if isFirstUpdate {
            prevMotionDetected = sensor.motionDetected
            prevLightDetected  = sensor.lightDetected
            return
        }

        let now         = Date()
        let motionEdge  = (prevMotionDetected == false) && (sensor.motionDetected == true)
        let barkEvent   = sensor.barkDetected
        if barkEvent  { lastBarkObservedAt   = now }
        if motionEdge { lastMotionObservedAt = now }

        checkTemperature(sensor)

        let combinedFired = checkCombinedAlert(sensor: sensor, now: now)

        if !combinedFired {
            if barkEvent  { checkSound(sensor) }
            if motionEdge { fireMotionAlert(sensor: sensor, now: now) }
        }

        // Update edge state and run motion-stopped tracking + inactivity check.
        updateMotionStateAndInactivity(sensor)

        checkLight(sensor)
    }

    // MARK: - Config update (called by ProfileStore)

    /// Full alert config update — called whenever the dog profile changes.
    /// Replaces the old updateThresholds(warnHigh:criticalHigh:warnLow:criticalLow:).
    func updateAlertConfig(
        // Temperature
        warnHigh:     Double,
        criticalHigh: Double,
        warnLow:      Double,
        criticalLow:  Double,
        // Sound
        soundSensitivity:         SoundSensitivityLevel,
        soundAsStandaloneTrigger: Bool,
        // Motion
        motionSensitivity:          MotionSensitivityLevel,
        inactiveAlertAfterMinutes:  Int,
        // Context
        operationalProfile: OperationalDogProfile,
        puppyAgeMonths:     Double?
    ) {
        config.tempWarnHigh     = warnHigh
        config.tempCriticalHigh = criticalHigh
        config.tempWarnLow      = warnLow
        config.tempCriticalLow  = criticalLow

        config.soundSensitivity         = soundSensitivity
        config.soundAsStandaloneTrigger = soundAsStandaloneTrigger

        config.motionSensitivity          = motionSensitivity
        // inactiveAlertAfterMinutes == 0 disables inactivity alerting (neonatal profile).
        config.inactiveAlertAfterSeconds  = inactiveAlertAfterMinutes * 60

        config.operationalProfile = operationalProfile
        config.puppyAgeMonths     = puppyAgeMonths
    }

    func markAllRead() {
        for index in records.indices { records[index].isRead = true }
        unreadCount = 0
        scheduleSave()
    }

    func deleteRecord(withID id: UUID) {
        records.removeAll { $0.id == id }
        recalcUnread()
        scheduleSave()
    }

    func clearAll() {
        records.removeAll()
        unreadCount = 0
        scheduleSave()
    }

    var analytics: SensorAnalytics { SensorAnalytics(records: records) }

    // MARK: - Computed cooldowns

    /// Bark re-alert cooldown scales with sound sensitivity.
    /// High sensitivity (brachycephalic / senior) → re-alert sooner.
    private var effectiveBarkCooldown: TimeInterval {
        switch config.soundSensitivity {
        case .high:     return 30
        case .standard: return 60
        case .low:      return 120
        }
    }

    /// Motion re-alert cooldown scales with motion sensitivity.
    private var effectiveMotionCooldown: TimeInterval {
        switch config.motionSensitivity {
        case .high:     return 120
        case .standard: return 300
        case .low:      return 600
        }
    }

    // MARK: - Threshold Checks

    // ── Temperature ────────────────────────────────────────────────────────────
    // Research: ambient kennel thresholds derived from Merck Veterinary Manual
    // and AVMA guidelines, sub-divided by operational profile in DogProfileEngine.
    private func checkTemperature(_ sensor: SensorData) {
        guard let temp = sensor.temperature else { return }

        let now = Date()
        if let last = lastTempAlertDate, now.timeIntervalSince(last) < tempCooldown { return }

        let record: AlertRecord?

        if temp > config.tempCriticalHigh {
            let detail = profileAwareTempDetail(temp: temp, high: true, critical: true)
            record = AlertRecord(
                type: .temperature, severity: .critical,
                title: "Kennel overheating",
                detail: detail,
                sensorValue: temp, unit: "°C"
            )
        } else if temp > config.tempWarnHigh {
            let detail = profileAwareTempDetail(temp: temp, high: true, critical: false)
            record = AlertRecord(
                type: .temperature, severity: .warning,
                title: "Kennel getting warm",
                detail: detail,
                sensorValue: temp, unit: "°C"
            )
        } else if temp < config.tempCriticalLow {
            let detail = profileAwareTempDetail(temp: temp, high: false, critical: true)
            record = AlertRecord(
                type: .temperature, severity: .critical,
                title: "Kennel too cold",
                detail: detail,
                sensorValue: temp, unit: "°C"
            )
        } else if temp < config.tempWarnLow {
            let detail = profileAwareTempDetail(temp: temp, high: false, critical: false)
            record = AlertRecord(
                type: .temperature, severity: .warning,
                title: "Kennel getting cold",
                detail: detail,
                sensorValue: temp, unit: "°C"
            )
        } else {
            record = nil
        }

        if let record {
            append(record)
            lastTempAlertDate = now
        }
    }

    /// Builds a profile-aware temperature detail string.
    private func profileAwareTempDetail(temp: Double, high: Bool, critical: Bool) -> String {
        let base = String(format: "%.1f°C", temp)

        switch config.operationalProfile {

        case .youngPuppy:
            let ageMonths = config.puppyAgeMonths ?? 2.0
            if ageMonths < 1 {
                // Neonatal: cannot thermoregulate at all (Merck Vet Manual)
                return high
                    ? "\(base) — Neonatal puppies cannot cool themselves. Remove heat source and cool kennel immediately."
                    : "\(base) — Neonatal puppies are highly vulnerable to hypothermia. Add warmth immediately; target 29–32°C."
            } else if ageMonths < 2 {
                return high
                    ? "\(base) — Puppy (4–8 weeks) is heat-sensitive. Reduce ambient temperature immediately."
                    : "\(base) — Puppy (4–8 weeks) needs warmth; target 23–28°C to prevent hypothermia."
            } else {
                return high
                    ? "\(base) — Puppy (2–4 months) is above comfortable range. Check ventilation."
                    : "\(base) — Puppy (2–4 months) is below comfortable range. Provide additional warmth."
            }

        case .brachycephalic:
            // BOAS dogs overheat rapidly and cannot pant efficiently
            return high
                ? "\(base) — Flat-faced breeds overheat rapidly and cannot pant efficiently. Act immediately."
                : "\(base) — Temperature below comfortable range for this breed."

        case .largeGiantDog:
            return high
                ? "\(base) — Large/giant dogs accumulate heat quickly. Check ventilation immediately."
                : "\(base) — Below comfortable range. Provide additional warmth."

        case .seniorSensitive:
            return high
                ? "\(base) — Senior dogs have reduced heat tolerance. Address immediately."
                : "\(base) — Senior dogs are cold-sensitive. Provide warmth to prevent stress."

        default:
            return high
                ? (critical
                   ? "\(base) — Critical level. Check ventilation immediately."
                   : "\(base) — Above comfortable range.")
                : (critical
                   ? "\(base) — Critical low. Provide warmth immediately."
                   : "\(base) — Below comfortable range.")
        }
    }

    // ── Sound ──────────────────────────────────────────────────────────────────
    // Research: neonatal puppies (0–4 weeks) vocalize by crying/whimpering —
    // they cannot bark. Sustained crying indicates cold, hunger, pain, or
    // separation distress (source: Merck Veterinary Manual, Neonatal Puppy Care).
    // Barking begins to develop around 3–4 weeks of age.
    // For brachycephalic dogs, breathing sounds (stridor/stertor) are clinically
    // relevant — the KY-038 microphone will pick these up as sound events.
    //
    // Gate logic:
    //   soundAsStandaloneTrigger = true  → require barkDetected (adult standard mode)
    //   soundAsStandaloneTrigger = false → sustainedSound OR barkDetected triggers the
    //     check; only sustained events produce an alert. This ensures that neonatal cries
    //     and brachycephalic respiratory sounds can alert even when bark_count_5s is low.
    /// Standalone sound alert.
    /// User intent: any bark in the kennel is a CRITICAL alert immediately —
    /// barking is never a low-priority event. Sustained barking gets stronger
    /// wording but the same severity. The combined (motion + bark) path is
    /// handled upstream; if it fired, this method is skipped for the cycle.
    private func checkSound(_ sensor: SensorData) {
        let hasBark      = sensor.barkDetected
        let hasSustained = sensor.sustainedSound
        guard hasBark || hasSustained else { return }

        let now = Date()
        if let last = lastBarkAlertDate, now.timeIntervalSince(last) < effectiveBarkCooldown { return }

        // ── Neonatal puppy (0–4 weeks): only sustained cries — brief whimpers normal ──
        if config.operationalProfile == .youngPuppy,
           let age = config.puppyAgeMonths, age < 1 {
            guard hasSustained else { return }
            append(AlertRecord(
                type: .sound, severity: .critical,
                title: "Puppy distress cry detected",
                detail: "Sustained crying in a neonatal puppy may indicate insufficient warmth (target 29–32°C), hunger, pain, or separation. Check immediately."
            ))
            lastBarkAlertDate = now
            return
        }

        // ── All other cases: bark or sustained sound → Critical ─────────────
        let title: String
        let detail: String

        if hasSustained {
            title = "Sustained barking in kennel"
            switch config.operationalProfile {
            case .brachycephalic:
                detail = "Sustained sound — flat-faced dogs may produce respiratory sounds (snoring/stertor). Verify breathing and check for overheating."
            case .seniorSensitive:
                detail = "Sustained barking — senior dogs may bark due to disorientation, pain, or anxiety. Check on your dog."
            default:
                detail = "Sustained barking detected — your dog needs attention."
            }
        } else {
            title  = "Barking in kennel"
            detail = sensor.barkCount5s >= 3
                ? "Repeated barking detected (\(sensor.barkCount5s) barks in 5 s) — check on your dog."
                : "Barking detected in the kennel — check on your dog."
        }

        append(AlertRecord(
            type: .sound, severity: .critical,
            title: title,
            detail: detail
        ))
        lastBarkAlertDate = now
    }

    // ── Combined: motion + bark within the same window → critical ───────────
    // Returns true if a combined record was emitted. The caller uses this to
    // suppress the individual sound/motion alerts for the current cycle so the
    // user sees ONE clear critical record instead of three competing ones.
    //
    // We also still respect the Pi's sustained streaks: if both streaks cross
    // their thresholds (≥ ~15 s of co-activity), that's an even stronger signal
    // and forces a combined alert even if neither edge fired this exact cycle.
    private let combinedMotionStreakThreshold = 3
    private let combinedSoundStreakThreshold  = 3

    @discardableResult
    private func checkCombinedAlert(sensor: SensorData, now: Date) -> Bool {
        // Path A: bark + motion-edge observed within combinedWindow.
        let barkRecent =
            lastBarkObservedAt.map   { now.timeIntervalSince($0) <= combinedWindow } ?? false
        let motionRecent =
            lastMotionObservedAt.map { now.timeIntervalSince($0) <= combinedWindow } ?? false
        let coOccurrence = barkRecent && motionRecent

        // Path B: Pi-side sustained streaks both above threshold (long co-activity).
        let sustainedCoActivity =
            sensor.motionStreak >= combinedMotionStreakThreshold &&
            sensor.soundStreak  >= combinedSoundStreakThreshold

        guard coOccurrence || sustainedCoActivity else { return false }

        if let last = lastCombinedAlertDate,
           now.timeIntervalSince(last) < combinedCooldown { return false }

        let detail: String
        switch config.operationalProfile {
        case .youngPuppy:
            let ageMonths = config.puppyAgeMonths ?? 2.0
            detail = ageMonths < 1
                ? "Neonatal puppy is moving and vocalising at the same time — possible distress (cold, hunger, pain). Check immediately."
                : "Puppy is moving and barking at the same time — may need attention. Check immediately."
        case .brachycephalic:
            detail = "Movement and barking at the same time — flat-faced breeds can become distressed quickly. Verify breathing and kennel temperature."
        case .seniorSensitive:
            detail = "Movement and barking together in a senior dog — may indicate disorientation, pain, or distress."
        default:
            detail = sustainedCoActivity
                ? "Sustained activity and barking detected — your dog may need urgent attention."
                : "Movement and barking detected together — your dog may need urgent attention."
        }

        append(AlertRecord(
            type: .sound, severity: .critical,
            title: "Activity + noise in kennel",
            detail: detail
        ))
        lastCombinedAlertDate = now
        // Note: we deliberately do NOT stamp lastBarkAlertDate here. The combined
        // event is logged as a sound record above, and the per-cycle suppression
        // (skipping checkSound / fireMotionAlert in processSensorUpdate) is enough
        // to avoid duplicate records for THIS update. Stamping the bark cooldown
        // here would silence real solo barks that arrive during the next 1-2 min,
        // which contradicts the "any bark = Critical" promise.
        lastMotionAlertDate = now
        return true
    }

    // ── Motion (edge-triggered, Warning level) ─────────────────────────────
    /// Fires the standalone "Motion in kennel" warning. Caller has already
    /// verified that this is a false→true edge AND that no combined alert
    /// fired this cycle.
    private func fireMotionAlert(sensor: SensorData, now: Date) {
        if let last = lastMotionAlertDate,
           now.timeIntervalSince(last) < effectiveMotionCooldown { return }

        let detail: String
        switch config.operationalProfile {
        case .seniorSensitive:
            detail = "Movement detected — senior dogs sometimes pace when uncomfortable. Check on your dog if this is unusual."
        case .brachycephalic:
            detail = "Movement detected — verify breathing quality and that the kennel is cool."
        default:
            detail = "Activity detected in the kennel."
        }

        append(AlertRecord(
            type: .motion, severity: .warning,
            title: "Motion in kennel",
            detail: detail
        ))
        lastMotionAlertDate = now
    }

    /// Tracks motion stop/start transitions for the inactivity clock and runs
    /// the inactivity threshold check. Always called once per update.
    private func updateMotionStateAndInactivity(_ sensor: SensorData) {
        let current = sensor.motionDetected
        if let prev = prevMotionDetected, prev != current {
            if current {
                lastMotionStoppedDate = nil           // moving again → reset clock
            } else {
                lastMotionStoppedDate = Date()        // stopped → begin counting
            }
        }
        checkInactivity(sensor)
        prevMotionDetected = current
    }

    // ── Light (edge-triggered) ─────────────────────────────────────────────────
    // Logs an info-level record on every light↔dark transition, with a 5-minute
    // cooldown between alerts to prevent flooding from a flickering bulb or
    // intermittent sunlight. Light changes are context, not safety — never push.
    private func checkLight(_ sensor: SensorData) {
        let current = sensor.lightDetected
        defer { prevLightDetected = current }

        guard current != prevLightDetected else { return }

        let now = Date()
        if let last = lastLightAlertDate, now.timeIntervalSince(last) < lightCooldown { return }

        let title  = current ? "Lights turned on"  : "Lights turned off"
        let detail = current
            ? "The kennel is now lit."
            : "The kennel is now dark — your dog may be settling in for sleep."

        append(AlertRecord(type: .light, severity: .info, title: title, detail: detail))
        lastLightAlertDate = now
    }

    // ── Inactivity ─────────────────────────────────────────────────────────────
    // Research basis:
    //   • Neonatal puppies sleep ~90 % of the day → inactivity is NORMAL; alerts disabled.
    //   • Puppies 4–12 weeks sleep 18–20 h/day → long naps are expected (high threshold).
    //   • Adult dogs sleep 12–14 h/day; extended inactivity during daytime warrants a check.
    //   • Brachycephalic dogs are at risk of BOAS during rest → lower threshold.
    //   • Senior dogs sleep more than adults; but sudden lethargy may signal illness.
    // (Sources: Merck Vet Manual; BOAS clinical studies; canine geriatric care guidelines)
    //
    // NOTE: secondsSinceMotion is measured on the iOS side by tracking when motionDetected
    // last transitioned false. This avoids requiring the Pi to write a separate counter field.
    private func checkInactivity(_ sensor: SensorData) {
        let threshold = config.inactiveAlertAfterSeconds
        guard threshold > 0 else { return }  // 0 = disabled (neonatal profile)

        // If dog is currently moving, no inactivity to report.
        if sensor.motionDetected {
            lastMotionStoppedDate = nil
            return
        }

        // If we've never observed a motion→still transition (e.g. app just launched
        // and dog was already still), start the clock conservatively from now.
        if lastMotionStoppedDate == nil {
            lastMotionStoppedDate = Date()
        }

        guard let stopped = lastMotionStoppedDate else { return }
        let secondsSince = Int(Date().timeIntervalSince(stopped))
        guard secondsSince >= threshold else { return }

        let now = Date()
        if let last = lastInactivityAlertDate,
           now.timeIntervalSince(last) < inactivityAlertCooldown { return }

        let minutes = secondsSince / 60
        let hours   = minutes / 60
        let timeStr = hours > 0
            ? "\(hours) h \(minutes % 60) min"
            : "\(minutes) min"

        let (title, detail, severity): (String, String, AlertSeverity)

        switch config.operationalProfile {

        case .youngPuppy:
            // Puppy 1–4 months: long sleep is normal but worth a gentle check.
            title    = "Extended rest period"
            detail   = "No movement for \(timeStr). Puppies sleep 18–20 h/day — verify your puppy is sleeping comfortably and breathing normally."
            severity = .info

        case .brachycephalic:
            // BOAS risk during prolonged rest: check breathing quality.
            title    = "Extended inactivity"
            detail   = "No movement for \(timeStr). Flat-faced dogs can experience respiratory difficulty during rest. Verify breathing is regular and the kennel is cool."
            severity = .warning

        case .seniorSensitive:
            // Senior dogs may experience sudden health deterioration.
            title    = "Extended inactivity"
            detail   = "No movement for \(timeStr). Senior dogs can show sudden health changes — consider checking on your dog, especially if this is unusual behaviour."
            severity = .warning

        default:
            title    = "Extended inactivity"
            detail   = "No movement detected for \(timeStr). Your dog may be resting — check in if this seems unusual."
            severity = .info
        }

        append(AlertRecord(type: .motion, severity: severity, title: title, detail: detail))
        lastInactivityAlertDate = now
    }

    // MARK: - Record Management

    private func append(_ record: AlertRecord) {
        records.insert(record, at: 0)
        pruneOldRecords()
        if records.count > maxRecords { records = Array(records.prefix(maxRecords)) }
        recalcUnread()
        scheduleSave()
    }

    private func pruneOldRecords() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        records.removeAll { $0.timestamp < cutoff }
    }

    private func recalcUnread() { unreadCount = records.filter { !$0.isRead }.count }

    // MARK: - Persistence

    private func setupDebouncedSave() {
        cancellable = saveTrigger
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.saveToDisk() }
    }

    private func scheduleSave() { saveTrigger.send() }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // First try the fast path — the entire array decodes cleanly.
        if let all = try? decoder.decode([AlertRecord].self, from: data) {
            records = all
            recalcUnread()
            return
        }

        // Fallback: decode element-by-element so a single bad record (e.g. a
        // legacy AlertType case from an older app version) does NOT wipe the
        // whole history. We re-parse the JSON as [Any] and try each entry.
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            records = []
            return
        }

        var recovered: [AlertRecord] = []
        for entry in raw {
            guard let entryData = try? JSONSerialization.data(withJSONObject: entry) else { continue }
            if let one = try? decoder.decode(AlertRecord.self, from: entryData) {
                recovered.append(one)
            }
        }
        records = recovered
        recalcUnread()
    }
}
