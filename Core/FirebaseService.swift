import Foundation
import FirebaseDatabase
import Combine

@MainActor
final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published var sensorData = SensorData()
    @Published var isConnected = false
    @Published var cameraImageURL: URL?
    @Published var cameraImageUpdatedAt: Date?

    @Published var lastValidTempDate: Date?
    @Published var lastHeartbeatDate: Date?

    /// True when the Pi unit hasn't written a heartbeat in > 60 s — UI surfaces
    /// an "offline" banner so the user knows the values may be stale.
    var isPiOffline: Bool {
        guard let date = lastHeartbeatDate else { return false }
        return Date().timeIntervalSince(date) > 60
    }

    var isTempStale: Bool {
        guard let date = lastValidTempDate else { return sensorData.temperature == nil }
        return Date().timeIntervalSince(date) > 300
    }

    var tempLastSeenMinutesAgo: Int? {
        guard let date = lastValidTempDate else { return nil }
        return max(0, Int(Date().timeIntervalSince(date)) / 60)
    }

    private let rootRef = Database.database().reference()

    private var connectionHandle:  DatabaseHandle?
    private var sensorsHandle:     DatabaseHandle?
    private var soundHandle:       DatabaseHandle?
    private var alertHandle:       DatabaseHandle?
    private var cameraHandle:      DatabaseHandle?
    private var heartbeatHandle:   DatabaseHandle?

    private init() {}

    func startListening() {
        removeAllHandles()
        listenToConnection()
        listenToSensors()
        listenToSound()
        listenToAlert()
        listenToCamera()
        listenToHeartbeat()
    }

    func stopListening() {
        removeAllHandles()
        isConnected = false
    }

    private func removeAllHandles() {
        if let h = connectionHandle {
            Database.database().reference(withPath: ".info/connected").removeObserver(withHandle: h)
            connectionHandle = nil
        }
        if let h = sensorsHandle {
            rootRef.child("kennel/sensors").removeObserver(withHandle: h)
            sensorsHandle = nil
        }
        if let h = soundHandle {
            rootRef.child("kennel/sound").removeObserver(withHandle: h)
            soundHandle = nil
        }
        if let h = alertHandle {
            rootRef.child("kennel/alert").removeObserver(withHandle: h)
            alertHandle = nil
        }
        if let h = cameraHandle {
            rootRef.child("kennel/camera").removeObserver(withHandle: h)
            cameraHandle = nil
        }
        if let h = heartbeatHandle {
            rootRef.child("kennel/heartbeat").removeObserver(withHandle: h)
            heartbeatHandle = nil
        }
    }

    func saveFCMToken(_ token: String) {
        rootRef.child("kennel/fcm_token").setValue(token)
    }

    func clearFCMToken() {
        rootRef.child("kennel/fcm_token").removeValue()
    }

    private func listenToConnection() {
        connectionHandle = Database.database()
            .reference(withPath: ".info/connected")
            .observe(.value) { [weak self] snapshot in
                let connected = snapshot.value as? Bool ?? false
                Task { @MainActor [weak self] in
                    self?.isConnected = connected
                }
            }
    }

    private func listenToSensors() {
        sensorsHandle = rootRef.child("kennel/sensors").observe(
            .value,
            with: { [weak self] snapshot in
                guard let self else { return }
                guard snapshot.exists() else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let temperature   = FirebaseService.toDouble(dict["temperature"])
                let humidity      = FirebaseService.toDouble(dict["humidity"])
                let motion        = FirebaseService.toBool(dict["motion"])
                let sleeping      = FirebaseService.toBool(dict["sleeping"])
                let lightDetected = FirebaseService.lightStringToBool(dict["light"])
                let motionStreak  = FirebaseService.toInt(dict["motion_streak"])
                let soundStreak   = FirebaseService.toInt(dict["sound_streak"])
                let timestamp     = dict["timestamp"] as? String

                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let temperature {
                        self.sensorData.temperature = temperature
                        self.lastValidTempDate = Date()
                    }
                    if let humidity      { self.sensorData.humidity       = humidity      }
                    if let motion        { self.sensorData.motionDetected  = motion        }
                    if let sleeping      { self.sensorData.sleeping        = sleeping      }
                    if let lightDetected { self.sensorData.lightDetected   = lightDetected }
                    if let motionStreak  { self.sensorData.motionStreak    = motionStreak  }
                    if let soundStreak   { self.sensorData.soundStreak     = soundStreak   }
                    if let timestamp     { self.sensorData.timestamp       = timestamp     }

                    // Record into history from the sticky sensorData cache —
                    // NOT from the per-tick local parsed values. This way a
                    // transient `null` from the Pi never leaves a hole in the
                    // chart: we always record the freshest known-good reading.
                    SensorHistoryStore.shared.record(
                        temperature: self.sensorData.temperature,
                        humidity:    self.sensorData.humidity
                    )
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                }
            },
            withCancel: { _ in }
        )
    }

    private func listenToSound() {
        soundHandle = rootRef.child("kennel/sound").observe(
            .value,
            with: { [weak self] snapshot in
                guard let self else { return }
                guard snapshot.exists() else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let soundActive = FirebaseService.toBool(dict["sound_active"])
                let barkDetected = FirebaseService.toBool(dict["bark_detected"])
                let barkCount = FirebaseService.toInt(dict["bark_count_5s"])
                let sustainedSound = FirebaseService.toBool(dict["sustained_sound"])

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let soundActive { self.sensorData.soundActive = soundActive }
                    if let barkDetected { self.sensorData.barkDetected = barkDetected }
                    if let barkCount { self.sensorData.barkCount5s = barkCount }
                    if let sustainedSound { self.sensorData.sustainedSound = sustainedSound }
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                }
            },
            withCancel: { _ in }
        )
    }

    private func listenToAlert() {
        alertHandle = rootRef.child("kennel/alert").observe(
            .value,
            with: { [weak self] snapshot in
                guard let self else { return }
                guard snapshot.exists() else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let alertLevel = dict["level"] as? String
                let sleeping = FirebaseService.toBool(dict["sleeping"])
                let puppyMode = FirebaseService.toBool(dict["puppy_mode"])
                let puppyAge = dict["puppy_age"] as? String ?? ""
                let timestamp = dict["timestamp"] as? String

                let reasons: [String]
                if let arr = dict["reasons"] as? [String] {
                    reasons = arr
                } else if let arr = dict["reasons"] as? [Any] {
                    reasons = arr.compactMap { $0 as? String }
                } else {
                    reasons = []
                }

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let alertLevel { self.sensorData.alertLevel = alertLevel }
                    if let sleeping { self.sensorData.sleeping = sleeping }
                    if let puppyMode { self.sensorData.puppyMode = puppyMode }
                    self.sensorData.puppyAge = puppyAge
                    self.sensorData.alertReasons = reasons
                    if let timestamp { self.sensorData.timestamp = timestamp }
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                }
            },
            withCancel: { _ in }
        )
    }

    private func listenToCamera() {
        cameraHandle = rootRef.child("kennel/camera").observe(
            .value,
            with: { [weak self] snapshot in
                guard let self else { return }

                let imageURLString: String? =
                    (snapshot.value as? String) ??
                    (snapshot.childSnapshot(forPath: "url").value as? String) ??
                    (snapshot.childSnapshot(forPath: "image_url").value as? String)

                let timestampString =
                    snapshot.childSnapshot(forPath: "timestamp").value as? String

                Task { @MainActor [weak self] in
                    guard let self else { return }

                    let newURL: URL?
                    if let imageURLString, let url = URL(string: imageURLString) {
                        newURL = url
                    } else {
                        newURL = nil
                    }
                    self.cameraImageURL = newURL

                    if let timestampString,
                       let parsedDate = ISO8601DateFormatter().date(from: timestampString) {
                        self.cameraImageUpdatedAt = parsedDate
                    } else if newURL == nil {
                        self.cameraImageUpdatedAt = nil
                    }
                    // Otherwise keep the existing updatedAt — don't fake "just now"
                    // on a snapshot whose true timestamp we don't know.
                }
            },
            withCancel: { _ in }
        )
    }

    private func listenToHeartbeat() {
        heartbeatHandle = rootRef.child("kennel/heartbeat").observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil else { return }
                guard snapshot.exists() else { return }

                // Accept either a dict { timestamp, epoch_ms } or a raw ISO string.
                var resolved: Date?
                if let dict = snapshot.value as? [String: Any] {
                    if let epochMs = FirebaseService.toDouble(dict["epoch_ms"]) {
                        resolved = Date(timeIntervalSince1970: epochMs / 1000.0)
                    } else if let ts = dict["timestamp"] as? String {
                        resolved = ISO8601DateFormatter().date(from: ts)
                    }
                } else if let ts = snapshot.value as? String {
                    resolved = ISO8601DateFormatter().date(from: ts)
                }

                let stamp = resolved ?? Date()
                Task { @MainActor [weak self] in
                    self?.lastHeartbeatDate = stamp
                }
            },
            withCancel: { _ in }
        )
    }

    static func toDouble(_ v: Any?) -> Double? {
        switch v {
        case let n as NSNumber: return n.doubleValue
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s)
        default: return nil
        }
    }

    static func toBool(_ v: Any?) -> Bool? {
        switch v {
        case let n as NSNumber: return n.boolValue
        case let s as String:
            switch s.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Decode the Pi's light field, which is written as the string "light" or "dark".
    /// Also accepts a raw Bool for forward compatibility.
    static func lightStringToBool(_ v: Any?) -> Bool? {
        switch v {
        case let s as String:
            switch s.lowercased() {
            case "light", "on", "true",  "1": return true
            case "dark",  "off","false", "0": return false
            default: return nil
            }
        case let n as NSNumber: return n.boolValue
        default: return nil
        }
    }

    static func toInt(_ v: Any?) -> Int? {
        switch v {
        case let n as NSNumber: return n.intValue
        case let i as Int: return i
        case let d as Double: return Int(d)
        case let s as String: return Int(s)
        default: return nil
        }
    }

}
