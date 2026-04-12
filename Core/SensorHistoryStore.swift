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
/// Records at most one sample every 5 minutes to avoid bloat.
/// Thread-safe via @MainActor — call from FirebaseService's main-actor Task blocks.
@MainActor
final class SensorHistoryStore: ObservableObject {
    static let shared = SensorHistoryStore()

    @Published private(set) var readings: [SensorReading] = []

    // One sample every 5 minutes, keep 48 h of data max
    private let recordInterval: TimeInterval = 300
    private let retentionHours: Double       = 48
    private let maxReadings                  = 576

    private var lastRecordDate: Date?

    private let saveURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("sensor_history.json")
    }()

    private let saveTrigger = PassthroughSubject<Void, Never>()
    private var cancellable: AnyCancellable?

    private init() {
        loadFromDisk()
        setupDebouncedSave()
    }

    // MARK: - Public API

    /// Call this every time a sensor update arrives. Internally throttled.
    func record(temperature: Double?, humidity: Double?) {
        guard temperature != nil || humidity != nil else { return }

        let now = Date()
        if let last = lastRecordDate, now.timeIntervalSince(last) < recordInterval { return }

        readings.append(SensorReading(temperature: temperature, humidity: humidity))
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
