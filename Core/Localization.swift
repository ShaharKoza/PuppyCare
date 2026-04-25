import Foundation
import SwiftUI
import Combine

// MARK: - Supported languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case hebrew  = "he"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .hebrew:  return "עברית"
        }
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .english: return .leftToRight
        case .hebrew:  return .rightToLeft
        }
    }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .hebrew:  return Locale(identifier: "he_IL")
        }
    }
}

// MARK: - Singleton

/// Pragmatic in-memory localization layer.
///
/// Why not Apple's `Localizable.strings`?
/// - Adding a `.lproj` file pair to an existing `.xcodeproj` from outside Xcode
///   is fragile (PBXFileReference / variant-group surgery). This singleton works
///   the moment the file lands in the Compile Sources phase, no project edits.
///
/// Usage from views:
///     @EnvironmentObject var loc: Localization
///     Text(loc.t("Dashboard"))
///
/// Untranslated keys fall through unchanged — every English source string is
/// also a valid display string, so a missing translation is graceful.
@MainActor
final class Localization: ObservableObject {
    static let shared = Localization()

    private let storageKey = "puppycare.appLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "puppycare.appLanguage"),
           let stored = AppLanguage(rawValue: raw) {
            language = stored
        } else {
            language = .english
        }
    }

    /// Translate a key. The key is the English source string itself, so any
    /// view that has not been touched by the localization pass still renders
    /// readable text — it just always shows English.
    func t(_ key: String) -> String {
        if language == .english { return key }
        return Self.hebrew[key] ?? key
    }

    // MARK: - Hebrew dictionary
    //
    // Kept inline (not a JSON resource) so the file ships with the binary
    // without any project-file changes. Strings cover the screens the user
    // actually sees on the demo path: tabs, Dashboard, Alerts, Profile.
    private static let hebrew: [String: String] = [
        // ── Tab bar ──────────────────────────────────────────────────────
        "Home":              "בית",
        "Routine":           "שגרה",
        "Assistant":         "עוזר",
        "Profile":           "פרופיל",

        // ── Dashboard headline ───────────────────────────────────────────
        "Environment looks stable":      "הסביבה יציבה",
        "Environment needs attention":   "הסביבה דורשת תשומת לב",
        "Immediate attention needed":    "נדרשת התייחסות מיידית",
        "Normal":                        "תקין",
        "Warning":                       "אזהרה",
        "Critical":                      "קריטי",
        "Sleeping":                      "ישן",
        "Awake":                         "ער",
        "Dog is in the kennel":          "הכלב בכלוב",
        "Dog is outside the kennel":     "הכלב מחוץ לכלוב",

        // ── Sensor tiles ─────────────────────────────────────────────────
        "Temperature":       "טמפרטורה",
        "Humidity":          "לחות",
        "Motion":            "תנועה",
        "Sound":             "קול",
        "Bark Count":        "ספירת נביחות",
        "Light":             "אור",
        "Detected":          "זוהה",
        "Still":             "ללא תנועה",
        "Active":            "פעיל",
        "Quiet":             "שקט",
        "Dark":              "חושך",

        // ── Alerts card ──────────────────────────────────────────────────
        "Alerts & Insights":        "התראות ותובנות",
        "History":                  "היסטוריה",
        "No active alerts":         "אין התראות פעילות",
        "All sensors are within normal range.": "כל החיישנים בטווח התקין.",
        "Activity + noise in kennel":           "פעילות ורעש בכלוב",
        "Critical · happening now":             "קריטי · קורה עכשיו",
        "Lights turned on":                     "האור נדלק",
        "Lights turned off":                    "האור כבה",
        "Motion in kennel":                     "תנועה בכלוב",
        "Barking in kennel":                    "נביחות בכלוב",
        "Sustained barking in kennel":          "נביחות מתמשכות בכלוב",
        "Kennel overheating":                   "הכלוב חם מדי",
        "Kennel getting warm":                  "הכלוב מתחמם",
        "Kennel too cold":                      "הכלוב קר מדי",
        "Kennel getting cold":                  "הכלוב מתקרר",
        "Extended inactivity":                  "חוסר פעילות ממושך",
        "Extended rest period":                 "תקופת מנוחה ארוכה",

        // ── Camera card ──────────────────────────────────────────────────
        "Camera":                  "מצלמה",
        "Take Snapshot":           "צלם תמונה",
        "Updated at":              "עודכן בשעה",

        // ── Profile screen ───────────────────────────────────────────────
        "Settings":                "הגדרות",
        "Language":                "שפה",
        "Edit Profile":            "עריכת פרופיל",
        "Reconfigure Monitoring":  "הגדרת ניטור מחדש",
        "Notifications":           "התראות",
        "About":                   "אודות",
        "Version":                 "גרסה",
        "Open Landing Page":       "פתיחת דף הנחיתה",
        "GitHub Repository":       "מאגר GitHub",
        "Delete All Data":         "מחיקת כל הנתונים",

        // ── Common buttons ───────────────────────────────────────────────
        "Save":      "שמור",
        "Cancel":    "ביטול",
        "Done":      "סיום",
        "Delete":    "מחק",
        "Confirm":   "אישור",
        "Back":      "חזרה",
        "Next":      "הבא",
        "Continue":  "המשך",
        "Clear All": "נקה הכל",

        // ── Filter chips ─────────────────────────────────────────────────
        "All": "הכל",

        // ── Connectivity / Pi status ─────────────────────────────────────
        "Pi offline":         "ה-Pi לא מקוון",
        "Reading may be delayed": "הקריאה עשויה להתעכב",
        "Sensor not responding":  "החיישן לא מגיב",

        // ── About / version ─────────────────────────────────────────────
        "PuppyCare":         "PuppyCare",
        "Smart Kennel Monitoring": "ניטור חכם לכלוב",
    ]
}
