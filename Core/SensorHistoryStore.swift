import Foundation
import Combine

// MARK: - Model

struct SensorReading: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let temperature: Double?
    let humidity: Double?

    init(temperature: Double?, humidity: Double?) {
        self.id          = UUID()
        self.timestamp   = Date()
        self.temperature = temperature
        self.humidity    = humidity
    }
}

// MARK: - Store

/// Accumulates timestamped sensor readings for the last 48 hours.
///
/// Design:
/// - Records at most one sample per minute. This gives a usable chart after
///   just 2–3 minutes of foreground use, instead of the 10–15 minutes the
///   previous 5-minute throttle required.
/// - Keeps up to 48 h of samples (2880 points) — still trivial on disk/memory.
/// - Uses an internal "last-good" cache for temperature and humidity, so a
///   transient `null` from the Pi (e.g. during a DHT retry) does NOT create
///   holes in the chart. Both fields of every stored SensorReading are either
///   the freshest real value or nil only when we have truly never seen one.
///
/// Thread-safe via @MainActor — call from FirebaseService's main-actor Task blocks.
@MainActor
final class SensorHistoryStore: ObservableObject {
    static let shared = SensorHistoryStore()

    @Published private(set) var readings: [SensorReading] = []

    // One sample per minute, keep 48 h of data max.
    private let recordInterval: TimeInterval = 60
    private let retentionHours: Double       = 48
    private let maxReadings                  = 2880

    private var lastRecordDate: Date?

    // Sticky last-good values. Protect the chart from per-tick nulls.
    private var lastGoodTemperature: Double?
    private var lastGoodHumidity:    Double?

    private let saveURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("sensor_history.json")
    }()

    private let saveTrigger = PassthroughSubject<Void, Never>()
    private var cancellable: AnyCancellable?

    private init() {
        loadFromDisk()
        // Seed the sticky cache from the most recent persisted reading so that
        // a fresh app launch doesn't start from nil for a minute.
        if let last = readings.last {
            lastGoodTemperature = last.temperature ?? lastGoodTemperature
            lastGoodHumidity    = last.humidity    ?? lastGoodHumidity
        }
        setupDebouncedSave()
    }

    // MARK: - Public API

    /// Call this every time a sensor update arrives. Internally throttled
    /// to one sample per `recordInterval`, and backfills nil fields from the
    /// sticky last-good cache so the chart never has spurious gaps.
    func record(temperature: Double?, humidity: Double?) {
        // Update sticky cache whenever we get a real value.
        if let temperature { lastGoodTemperature = temperature }
        if let humidity    { lastGoodHumidity    = humidity    }

        // Nothing has ever been good? Nothing to record.
        guard lastGoodTemperature != nil || lastGoodHumidity != nil else { return }

        let now = Date()
        if let last = lastRecordDate, now.timeIntervalSince(last) < recordInterval { return }

        readings.append(
            SensorReading(
                temperature: temperature ?? lastGoodTemperature,
                humidity:    humidity    ?? lastGoodHumidity
            )
        )
        lastRecordDate = now
        pruneOldReadings()
        saveTrigger.send()
    }

    var last24HoursReadings: [SensorReading] {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        return readings.filter { $0.timestamp >= cutoff }
    }

    // MARK: - Pruning

    private func pruneOldReadings() {
        let cutoff = Date().addingTimeInterval(-retentionHours * 3600)
        readings.removeAll { $0.timestamp < cutoff }
        if readings.count > maxReadings {
            readings = Array(readings.suffix(maxReadings))
        }
    }

    // MARK: - Persistence

    private func setupDebouncedSave() {
        cancellable = saveTrigger
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.saveToDisk() }
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(readings) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        readings = (try? decoder.decode([SensorReading].self, from: data)) ?? []
    }
}
