import Foundation
import FirebaseDatabase
import Combine

@MainActor
final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published var sensorData      = SensorData()
    @Published var isConnected: Bool = false
    /// Set whenever the Pi writes a new camera image URL to kennel/camera/image_url.
    @Published var cameraImageURL: URL?
    /// Wall-clock time when cameraImageURL was last updated. Shown as "Updated at HH:mm".
    @Published var cameraImageUpdatedAt: Date?

    private let rootRef = Database.database().reference()

    private var dhtHandle:        DatabaseHandle?
    private var lightHandle:      DatabaseHandle?
    private var soundHandle:      DatabaseHandle?
    private var pirHandle:        DatabaseHandle?
    private var alertHandle:      DatabaseHandle?
    private var connectionHandle: DatabaseHandle?
    private var cameraHandle:     DatabaseHandle?

    private var isListening = false

    private init() {}

    // MARK: - Public API

    func startListening() {
        guard !isListening else { return }
        isListening = true

        listenToConnection()
        listenToDHT()
        listenToLight()
        listenToSound()
        listenToPIR()
        listenToAlert()
        listenToCamera()
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false

        if let h = connectionHandle {
            Database.database().reference(withPath: ".info/connected").removeObserver(withHandle: h)
            connectionHandle = nil
        }
        if let h = dhtHandle    { rootRef.child("kennel/dht").removeObserver(withHandle: h);   dhtHandle    = nil }
        if let h = lightHandle  { rootRef.child("kennel/light").removeObserver(withHandle: h); lightHandle  = nil }
        if let h = soundHandle  { rootRef.child("kennel/sound").removeObserver(withHandle: h); soundHandle  = nil }
        if let h = pirHandle    { rootRef.child("kennel/pir").removeObserver(withHandle: h);   pirHandle    = nil }
        if let h = alertHandle  { rootRef.child("kennel/alert").removeObserver(withHandle: h); alertHandle  = nil }
        if let h = cameraHandle { rootRef.child("kennel/camera").removeObserver(withHandle: h); cameraHandle = nil }

        isConnected = false
    }

    // MARK: - FCM Token

    func saveFCMToken(_ token: String) {
        rootRef.child("kennel/fcm_token").setValue(token)
    }

    // MARK: - Camera capture request

    /// Writes the current server timestamp to kennel/camera/capture_request.
    /// The Pi listens to this path and calls trigger_camera() when it changes.
    func requestCapture() {
        rootRef.child("kennel/camera/capture_request").setValue(ServerValue.timestamp())
    }

    // MARK: - Connection state

    private func listenToConnection() {
        connectionHandle = Database.database()
            .reference(withPath: ".info/connected")
            .observe(.value) { [weak self] snapshot in
                guard self != nil else { return }
                let connected = snapshot.value as? Bool ?? false
                Task { @MainActor [weak self] in
                    self?.isConnected = connected
                }
            }
    }

    // MARK: - Sensor listeners

    private func listenToDHT() {
        dhtHandle = rootRef.child("kennel/dht").observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let temperature = dict["temperature"] as? Double
                    ?? (dict["temperature"] as? NSNumber)?.doubleValue
                let humidity = dict["humidity"] as? Double
                    ?? (dict["humidity"] as? NSNumber)?.doubleValue
                let timestamp = dict["timestamp"] as? String

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let temperature { self.sensorData.temperature = temperature }
                    if let humidity    { self.sensorData.humidity    = humidity    }
                    if let timestamp   { self.sensorData.timestamp   = timestamp   }
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                    SensorHistoryStore.shared.record(temperature: temperature, humidity: humidity)
                }
            },
            withCancel: { _ in }
        )
    }

    private func listenToLight() {
        lightHandle = rootRef.child("kennel/light").observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let lightDetected = dict["light_detected"] as? Bool
                let timestamp     = dict["timestamp"]      as? String

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let lightDetected { self.sensorData.lightDetected = lightDetected }
                    if let timestamp, self.sensorData.timestamp.isEmpty {
                        self.sensorData.timestamp = timestamp
                    }
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
                guard self != nil else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let soundActive    = dict["sound_active"]    as? Bool
                let barkDetected   = dict["bark_detected"]   as? Bool
                let barkCount      = dict["bark_count_5s"]   as? Int
                    ?? (dict["bark_count_5s"] as? NSNumber)?.intValue
                let sustainedSound = dict["sustained_sound"] as? Bool

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let soundActive    { self.sensorData.soundActive    = soundActive    }
                    if let barkDetected   { self.sensorData.barkDetected   = barkDetected   }
                    if let barkCount      { self.sensorData.barkCount5s    = barkCount      }
                    if let sustainedSound { self.sensorData.sustainedSound = sustainedSound }
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                }
            },
            withCancel: { _ in }
        )
    }

    private func listenToPIR() {
        pirHandle = rootRef.child("kennel/pir").observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let motionDetected = dict["motion_detected"] as? Bool
                let lastMotion     = dict["last_motion"]     as? String

                let secondsSinceMotion: Int?
                if let v = dict["seconds_since_motion"] as? Int {
                    secondsSinceMotion = v
                } else if let v = dict["seconds_since_motion"] as? NSNumber {
                    secondsSinceMotion = v.intValue
                } else {
                    secondsSinceMotion = nil
                }

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let motionDetected { self.sensorData.motionDetected     = motionDetected }
                    if let lastMotion     { self.sensorData.lastMotion         = lastMotion     }
                    self.sensorData.secondsSinceMotion = secondsSinceMotion
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
                guard self != nil else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let alertLevel = dict["level"]      as? String
                let sleeping   = dict["sleeping"]   as? Bool
                let puppyMode  = dict["puppy_mode"] as? Bool
                let puppyAge   = dict["puppy_age"]  as? String ?? ""
                let timestamp  = dict["timestamp"]  as? String

                let alertReasons: [String]
                if let reasons = dict["reasons"] as? [String] {
                    alertReasons = reasons
                } else if let reasonsAny = dict["reasons"] as? [Any] {
                    alertReasons = reasonsAny.compactMap { $0 as? String }
                } else {
                    alertReasons = []
                }

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let alertLevel { self.sensorData.alertLevel = alertLevel }
                    if let sleeping   { self.sensorData.sleeping   = sleeping   }
                    if let puppyMode  { self.sensorData.puppyMode  = puppyMode  }
                    self.sensorData.puppyAge     = puppyAge
                    self.sensorData.alertReasons = alertReasons
                    if let timestamp { self.sensorData.timestamp = timestamp }
                }
            },
            withCancel: { _ in }
        )
    }

    // MARK: - Camera

    private func listenToCamera() {
        // Listen to the whole kennel/camera node so we pick up image_url regardless
        // of whether the Pi writes it as a direct string or as a child key.
        cameraHandle = rootRef.child("kennel/camera").observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil else { return }

                // Accept image_url as either a direct string value or a child key.
                let urlString: String? =
                    (snapshot.value as? String) ??
                    (snapshot.childSnapshot(forPath: "image_url").value as? String)

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let urlString, let url = URL(string: urlString) {
                        self.cameraImageURL       = url
                        self.cameraImageUpdatedAt = Date()
                    }
                }
            },
            withCancel: { _ in }
        )
    }
}
