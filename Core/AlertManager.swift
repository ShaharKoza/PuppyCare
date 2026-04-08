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
        case .light:       return "sun.max"
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
    var lightLevel: Double?
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

// MARK: - Alert Thresholds

struct AlertThresholds {
    var warnHigh:     Double = 28
    var criticalHigh: Double = 32
    var warnLow:      Double = 12
    var criticalLow:  Double = 8
}

// MARK: - Alert Manager

@MainActor
final class AlertManager: ObservableObject {
    static let shared = AlertManager()

    @Published private(set) var records: [AlertRecord] = []
    @Published private(set) var unreadCount: Int = 0

    private let maxRecords   = 500
    private let retentionDays = 30

    // Live thresholds — updated by ProfileStore when profile changes
    private var thresholds = AlertThresholds()

    private let saveURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("alert_history.json")
    }()

    private var cancellable: AnyCancellable?
    private let saveTrigger = PassthroughSubject<Void, Never>()

    private var isFirstUpdate = true

    private var lastBarkAlertDate:   Date?
    private var lastMotionAlertDate: Date?
    private var lastLightAlertDate:  Date?
    private var lastTempAlertDate:   Date?

    private let barkCooldown:   TimeInterval = 60
    private let motionCooldown: TimeInterval = 300
    private let lightCooldown:  TimeInterval = 300
    private let tempCooldown:   TimeInterval = 300

    private var prevMotionDetected: Bool?
    private var prevLightDetected:  Bool?

    private init() {
        loadFromDisk()
        setupDebouncedSave()
    }

    // MARK: - Public API

    func processSensorUpdate(_ sensor: SensorData) {
        defer { isFirstUpdate = false }

        if isFirstUpdate {
            prevMotionDetected = sensor.motionDetected
            prevLightDetected  = sensor.lightDetected
            return
        }

        checkTemperature(sensor)
        checkSound(sensor)
        checkMotion(sensor)
        checkLight(sensor)
    }

    /// Called by ProfileStore when the user changes temperature threshold settings.
    func updateThresholds(warnHigh: Double, criticalHigh: Double, warnLow: Double, criticalLow: Double) {
        thresholds.warnHigh     = warnHigh
        thresholds.criticalHigh = criticalHigh
        thresholds.warnLow      = warnLow
        thresholds.criticalLow  = criticalLow
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

    // MARK: - Threshold Checks

    private func checkTemperature(_ sensor: SensorData) {
        guard let temp = sensor.temperature, temp != 0 else { return }

        let now = Date()
        if let last = lastTempAlertDate, now.timeIntervalSince(last) < tempCooldown { return }

        let record: AlertRecord?

        if temp > thresholds.criticalHigh {
            record = AlertRecord(
                type: .temperature, severity: .critical,
                title: "Kennel overheating",
                detail: String(format: "Temperature is %.1f°C — critical level. Check ventilation immediately.", temp),
                sensorValue: temp, unit: "°C"
            )
        } else if temp > thresholds.warnHigh {
            record = AlertRecord(
                type: .temperature, severity: .warning,
                title: "Kennel getting warm",
                detail: String(format: "Temperature is %.1f°C — above comfortable range.", temp),
                sensorValue: temp, unit: "°C"
            )
        } else if temp < thresholds.criticalLow {
            record = AlertRecord(
                type: .temperature, severity: .critical,
                title: "Kennel too cold",
                detail: String(format: "Temperature is %.1f°C — critical low. Provide warmth immediately.", temp),
                sensorValue: temp, unit: "°C"
            )
        } else if temp < thresholds.warnLow {
            record = AlertRecord(
                type: .temperature, severity: .warning,
                title: "Kennel getting cold",
                detail: String(format: "Temperature is %.1f°C — below comfortable range.", temp),
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

    private func checkSound(_ sensor: SensorData) {
        guard sensor.barkDetected else { return }

        let now = Date()
        if let last = lastBarkAlertDate, now.timeIntervalSince(last) < barkCooldown { return }

        let severity: AlertSeverity = sensor.sustainedSound ? .warning : .info
        let detail: String
        if sensor.sustainedSound {
            detail = "Sustained barking detected — your dog may need attention."
        } else if sensor.barkCount5s >= 3 {
            detail = "Repeated barking detected (\(sensor.barkCount5s) barks in 5 s)."
        } else {
            detail = "Bark event detected."
        }

        append(AlertRecord(type: .sound, severity: severity, title: "Barking detected", detail: detail))
        lastBarkAlertDate = now
    }

    private func checkMotion(_ sensor: SensorData) {
        let current = sensor.motionDetected
        defer { prevMotionDetected = current }

        guard current != prevMotionDetected, current else { return }

        let now = Date()
        if let last = lastMotionAlertDate, now.timeIntervalSince(last) < motionCooldown { return }

        append(AlertRecord(
            type: .motion, severity: .info,
            title: "Motion detected", detail: "Movement detected in the kennel area."
        ))
        lastMotionAlertDate = now
    }

    private func checkLight(_ sensor: SensorData) {
        let current = sensor.lightDetected
        defer { prevLightDetected = current }

        guard current != prevLightDetected else { return }

        let now = Date()
        if let last = lastLightAlertDate, now.timeIntervalSince(last) < lightCooldown { return }

        let title  = current ? "Light turned on"         : "Light turned off"
        let detail = current ? "Light is now on in the kennel." : "Light is now off in the kennel."

        append(AlertRecord(type: .light, severity: .info, title: title, detail: detail))
        lastLightAlertDate = now
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
        records = (try? decoder.decode([AlertRecord].self, from: data)) ?? []
        recalcUnread()
    }
}
