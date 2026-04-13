import Foundation
import FirebaseDatabase
import Combine

// MARK: - Live Firebase Schema
//
//   kennel/sensors  — written every ~5 s (all confirmed live)
//     temperature    Double   e.g. 22.3
//     humidity       Double   e.g. 59.4
//     light          String   "light" | "dark"
//     motion         Bool
//     motion_streak  Int      consecutive cycles with motion
//     sound          Bool     any sound active
//     sound_streak   Int      consecutive cycles with sound
//     sleeping       Bool
//     timestamp      String   "HH:MM:SS"
//
//   kennel/sound  — written by bark-detection loop (may exist separately)
//     sound_active   Bool
//     bark_detected  Bool     true when bark pattern recognised
//     bark_count_5s  Int      distinct barks in last 5 s
//     sustained_sound Bool
//     timestamp      String
//
//   kennel/alert  — optional; written by the alert evaluator
//     level          String   "normal" | "warning" | "stress" | "emergency"
//     sleeping       Bool
//     puppy_mode     Bool
//     puppy_age      String
//     reasons        Array<String>
//     timestamp      String   ISO
//
//   kennel/camera — written by camera.py
//     image_url      String

@MainActor
final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published var sensorData            = SensorData()
    @Published var isConnected: Bool     = false
    @Published var cameraImageURL: URL?
    @Published var cameraImageUpdatedAt: Date?

    /// Timestamp of the last DHT22 reading that contained a valid (non-nil) temperature.
    /// Used by the dashboard to display a staleness warning when the sensor stops reporting.
    @Published var lastValidTempDate: Date?

    /// True when no valid temperature has been received for more than 300 seconds (5 min).
    /// 300 s gives DHT22 several missed poll cycles before raising an alarm — prevents
    /// false "sensor not responding" when the Pi is busy or the DHT needs a few retries.
    var isTempStale: Bool {
        guard let date = lastValidTempDate else { return sensorData.temperature == nil }
        return Date().timeIntervalSince(date) > 300
    }

    /// How long ago the last valid temperature was received, rounded to the nearest minute.
    var tempLastSeenMinutesAgo: Int? {
        guard let date = lastValidTempDate else { return nil }
        return max(0, Int(Date().timeIntervalSince(date)) / 60)
    }

    private let rootRef = Database.database().reference()

    private var connectionHandle: DatabaseHandle?
    private var sensorsHandle:    DatabaseHandle?   // kennel/sensors — temperature, humidity, motion, sound, light, sleeping
    private var soundHandle:      DatabaseHandle?   // kennel/sound   — bark_detected, bark_count_5s, sustained_sound
    private var alertHandle:      DatabaseHandle?   // kennel/alert   — optional alert metadata
    private var cameraHandle:     DatabaseHandle?   // kennel/camera

    private var isListening = false

    private init() {}

    // MARK: - Public API

    func startListening() {
        #if DEBUG
        print("🔥 FirebaseService.startListening() — isListening=\(isListening), db=\(rootRef.url)")
        #endif
        guard !isListening else {
            #if DEBUG
            print("🔥 Already listening — skipping")
            #endif
            return
        }
        isListening = true
        listenToConnection()
        listenToSensors()
        listenToSound()
        listenToAlert()
        listenToCamera()
        #if DEBUG
        print("🔥 All listeners registered")
        #endif
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
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
        isConnected = false
    }

    // MARK: - FCM Token

    func saveFCMToken(_ token: String) {
        rootRef.child("kennel/fcm_token").setValue(token)
    }

    // MARK: - Camera capture request

    func requestCapture() {
        rootRef.child("kennel/camera/capture_request").setValue(ServerValue.timestamp())
    }

    // MARK: - Connection state

    private func listenToConnection() {
        connectionHandle = Database.database()
            .reference(withPath: ".info/connected")
            .observe(.value) { [weak self] snapshot in
                let connected = snapshot.value as? Bool ?? false
                #if DEBUG
                print("🔥 Firebase connected=\(connected)")
                #endif
                Task { @MainActor [weak self] in self?.isConnected = connected }

            }
    }

    // MARK: - kennel/sensors  (PRIMARY — all live sensor data)
    //
    // This is the single source of truth for all sensor readings.
    // Confirmed live keys: temperature, humidity, light (String), motion (Bool),
    // sound (Bool), sleeping (Bool), motion_streak, sound_streak, timestamp.

    private func listenToSensors() {
        let path = "kennel/sensors"
        #if DEBUG
        print("🔥 Registering listener on: \(path)")
        #endif

        sensorsHandle = rootRef.child(path).observe(
            .value,
            with: { [weak self] snapshot in
                #if DEBUG
                print("🔥 \(path) callback — exists:\(snapshot.exists())")
                #endif

                guard self != nil else { return }

                guard snapshot.exists() else {
                    #if DEBUG
                    print("🔥 \(path): path does not exist in the database")
                    #endif
                    return
                }

                guard let dict = snapshot.value as? [String: Any] else {
                    #if DEBUG
                    print("🔥 \(path): value is not [String:Any] — type=\(type(of: snapshot.value)), value=\(String(describing: snapshot.value))")
                    #endif
                    return
                }

                #if DEBUG
                print("🔥 \(path) keys: \(dict.keys.sorted())")
                #endif

                // ── Parse every confirmed field ────────────────────────────────

                let temperature   = FirebaseService.toDouble(dict["temperature"])
                let humidity      = FirebaseService.toDouble(dict["humidity"])
                let motion        = FirebaseService.toBool(dict["motion"])
                let sound         = FirebaseService.toBool(dict["sound"])
                let sleeping      = FirebaseService.toBool(dict["sleeping"])
                // "light" is the STRING "light" / "dark" — NOT a bool
                let lightDetected = FirebaseService.lightStringToBool(dict["light"])
                let timestamp     = dict["timestamp"] as? String
                // motion_streak / sound_streak are streak counters, not mapped to
                // bark/motion fields — those come from kennel/sound and kennel/pir.

                #if DEBUG
                print("🔥 \(path) → temp=\(String(describing:temperature))  hum=\(String(describing:humidity))  motion=\(String(describing:motion))  sound=\(String(describing:sound))  light=\(String(describing:lightDetected))")
                #endif

                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let temperature   {
                        self.sensorData.temperature    = temperature
                        self.lastValidTempDate         = Date()   // reset staleness clock
                    }
                    if let humidity      { self.sensorData.humidity       = humidity      }
                    if let motion        { self.sensorData.motionDetected = motion        }
                    if let sound         { self.sensorData.soundActive    = sound         }
                    if let sleeping      { self.sensorData.sleeping       = sleeping      }
                    if let lightDetected { self.sensorData.lightDetected  = lightDetected }
                    if let timestamp     { self.sensorData.timestamp      = timestamp     }

                    SensorHistoryStore.shared.record(temperature: temperature, humidity: humidity)
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                }
            },
            withCancel: { error in
                #if DEBUG
                print("🔥 \(path) PERMISSION DENIED or CANCELLED — \(error.localizedDescription)")
                #endif
            }
        )
    }

    // MARK: - kennel/sound  (bark detection — may exist alongside kennel/sensors)
    //
    // The Pi bark-detection loop writes detailed sound analysis here:
    //   sound_active   Bool — any sound detected
    //   bark_detected  Bool — bark pattern recognised this cycle
    //   bark_count_5s  Int  — distinct barks in the last 5 seconds
    //   sustained_sound Bool — long continuous sound (not a bark burst)
    //
    // kennel/sensors.sound gives us a simple active/inactive bool.
    // kennel/sound gives us the richer bark breakdown the dashboard needs.

    private func listenToSound() {
        let path = "kennel/sound"
        soundHandle = rootRef.child(path).observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil, snapshot.exists() else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                let soundActive    = FirebaseService.toBool(dict["sound_active"])
                let barkDetected   = FirebaseService.toBool(dict["bark_detected"])
                let barkCount      = FirebaseService.toInt(dict["bark_count_5s"])
                let sustainedSound = FirebaseService.toBool(dict["sustained_sound"])

                #if DEBUG
                print("🔥 \(path) → barkDetected=\(String(describing:barkDetected))  barkCount=\(String(describing:barkCount))  sustained=\(String(describing:sustainedSound))")
                #endif

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // soundActive from kennel/sound overrides kennel/sensors.sound
                    // since it comes from the same measurement, more precise path
                    if let soundActive    { self.sensorData.soundActive    = soundActive    }
                    if let barkDetected   { self.sensorData.barkDetected   = barkDetected   }
                    if let barkCount      { self.sensorData.barkCount5s    = barkCount      }
                    if let sustainedSound { self.sensorData.sustainedSound = sustainedSound }
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                }
            },
            withCancel: { _ in }   // path may not exist on all Pi setups
        )
    }

    // MARK: - kennel/alert  (optional — may not exist)
    //
    // Provides alert level, reasons, puppy mode.  If the Pi is not writing
    // to this path, the snapshot will not exist and we skip silently.

    private func listenToAlert() {
        let path = "kennel/alert"
        alertHandle = rootRef.child(path).observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil, snapshot.exists() else { return }
                guard let dict = snapshot.value as? [String: Any] else { return }

                #if DEBUG
                print("🔥 \(path) → \(dict.keys.sorted())")
                #endif

                let alertLevel = dict["level"]      as? String
                let sleeping   = FirebaseService.toBool(dict["sleeping"])
                let puppyMode  = FirebaseService.toBool(dict["puppy_mode"])
                let puppyAge   = dict["puppy_age"]  as? String ?? ""
                let timestamp  = dict["timestamp"]  as? String

                let alertReasons: [String]
                if let arr = dict["reasons"] as? [String] {
                    alertReasons = arr
                } else if let arr = dict["reasons"] as? [Any] {
                    alertReasons = arr.compactMap { $0 as? String }
                } else {
                    alertReasons = []
                }

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let alertLevel { self.sensorData.alertLevel   = alertLevel }
                    if let sleeping   { self.sensorData.sleeping     = sleeping   }
                    if let puppyMode  { self.sensorData.puppyMode    = puppyMode  }
                    self.sensorData.puppyAge     = puppyAge
                    self.sensorData.alertReasons = alertReasons
                    // ISO timestamp from alert path overwrites the HH:MM:SS from sensors
                    if let timestamp  { self.sensorData.timestamp    = timestamp  }
                    AlertManager.shared.processSensorUpdate(self.sensorData)
                }
            },
            withCancel: { _ in }   // path may not exist — silence the error
        )
    }

    // MARK: - kennel/camera

    private func listenToCamera() {
        cameraHandle = rootRef.child("kennel/camera").observe(
            .value,
            with: { [weak self] snapshot in
                guard self != nil else { return }
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

    // MARK: - Type parsers
    //
    // Firebase iOS SDK bridges JSON through the ObjC runtime:
    //   JSON number  → NSNumber  (int or float depending on Python type)
    //   Python True  → NSNumber with boolValue = true
    //   Python None  → NSNull → all parsers return nil

    static func toDouble(_ v: Any?) -> Double? {
        switch v {
        case let n as NSNumber: return n.doubleValue
        case let d as Double:   return d
        case let i as Int:      return Double(i)
        case let s as String:   return Double(s)
        default:                return nil
        }
    }

    static func toBool(_ v: Any?) -> Bool? {
        switch v {
        case let n as NSNumber: return n.boolValue
        case let b as Bool:     return b
        case let i as Int:      return i != 0
        case let s as String:
            switch s.lowercased() {
            case "true",  "1", "yes": return true
            case "false", "0", "no":  return false
            default:                  return nil
            }
        default: return nil
        }
    }

    static func toInt(_ v: Any?) -> Int? {
        switch v {
        case let n as NSNumber: return n.intValue
        case let i as Int:      return i
        case let d as Double:   return Int(d)
        case let s as String:   return Int(s)
        default:                return nil
        }
    }

    /// Converts the Pi's "light" / "dark" string to Bool.
    static func lightStringToBool(_ v: Any?) -> Bool? {
        guard let s = v as? String else { return nil }
        switch s.lowercased() {
        case "light", "on",  "true":  return true
        case "dark",  "off", "false": return false
        default:                      return nil
        }
    }
}
