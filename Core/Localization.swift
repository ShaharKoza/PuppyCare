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

        // ── Onboarding ──────────────────────────────────────────────────
        "Welcome to PuppyCare":  "ברוכים הבאים ל-PuppyCare",
        "Let's set up your dog's profile":  "בואו נגדיר את פרופיל הכלב שלכם",
        "Puppy Setup":           "הגדרת הגור",
        "Set up your puppy's profile to get started.":
            "הגדירו את פרופיל הגור כדי להתחיל.",
        "Setup progress":        "התקדמות הגדרה",
        "Dog Currently In Kennel": "הכלב כרגע בכלוב",
        "You can change this later from the main app.":
            "תוכלו לשנות זאת מאוחר יותר מהאפליקציה הראשית.",
        "Mixed":                 "מעורב",
        "Dog's name":            "שם הכלב",
        "Name":                  "שם",
        "Breed":                 "גזע",
        "Sex":                   "מין",
        "Male":                  "זכר",
        "Female":                "נקבה",
        "Age (months)":          "גיל (חודשים)",
        "Weight (kg)":           "משקל (ק״ג)",
        "Date of birth":         "תאריך לידה",
        "Add photo":             "הוסף תמונה",
        "Change photo":          "החלף תמונה",
        "Get started":           "התחל",
        "Complete the required fields to continue": "השלם את השדות החסרים כדי להמשיך",
        "Skip for now":          "דלג כרגע",

        // ── Profile setup wizard ────────────────────────────────────────
        "Dog Profile Setup":     "הגדרת פרופיל הכלב",
        "Profile Type":          "סוג פרופיל",
        "Size":                  "גודל",
        "Head Type":             "צורת ראש",
        "Coat":                  "פרווה",
        "Special Conditions":    "מצבים מיוחדים",
        "Lifestyle":             "אורח חיים",
        "Apply Settings":        "החל הגדרות",
        "Manual Override":       "ביטול ברירות מחדל",

        // ── Lifestyle options ──────────────────────────────────────────
        "Primarily indoor":          "בעיקר בבית",
        "Has yard / outdoor access": "יש חצר / גישה לחוץ",
        "Regular boarding":          "פנסיון קבוע",
        "Group training or classes": "אילוף קבוצתי / שיעורים",
        "Frequent dog-to-dog contact": "מגע תכוף עם כלבים אחרים",

        // ── Alerts history ─────────────────────────────────────────────
        "Alerts":                "התראות",
        "Alerts History":        "היסטוריית התראות",
        "Recent Activity":       "פעילות אחרונה",
        "Today":                 "היום",
        "Yesterday":             "אתמול",
        "No alerts yet":         "אין עדיין התראות",
        "Filters":               "סינון",
        "Info":                  "מידע",
        "Mark all as read":      "סמן הכל כנקרא",
        "Clear all alerts?":     "לנקות את כל ההתראות?",
        "This cannot be undone.":"לא ניתן לשחזר פעולה זו.",
        "Everything looks good — no alerts have been logged yet.":
            "הכל נראה תקין — עדיין לא נרשמו התראות.",
        "alerts recorded.":      "התראות נרשמו.",

        // ── Vaccine card ───────────────────────────────────────────────
        "Vaccine reminders":     "תזכורות חיסונים",
        "Check due":             "בדוק תפוגה",
        "Annual Rabies Vaccine": "חיסון כלבת שנתי",
        "First Rabies Vaccine — Upcoming": "חיסון כלבת ראשון — מתקרב",
        "Reminder only — confirm the exact schedule with your veterinarian.":
            "תזכורת בלבד — אמתו את לוח הזמנים המדויק עם הוטרינר.",
        "Due today":             "להיום",
        "Due tomorrow":          "למחר",

        // ── Routine ────────────────────────────────────────────────────
        "Daily Routine":         "שגרה יומית",
        "Add meal":              "הוסף ארוחה",
        "Add walk":              "הוסף הליכה",
        "Add play":              "הוסף משחק",
        "Meals":                 "ארוחות",
        "Walks":                 "הליכות",
        "Play":                  "משחק",
        "Time":                  "שעה",
        "Grams":                 "גרמים",
        "Duration":              "משך",
        "Edit":                  "ערוך",

        // ── Food Assistant ─────────────────────────────────────────────
        "Food Assistant":        "עוזר תזונה",
        "Ask about any food":    "שאל על כל מאכל",
        "Safe":                  "בטוח",
        "Caution":                "זהירות",
        "Dangerous":             "מסוכן",
        "Unknown":               "לא ידוע",
        "Ask":                   "שאל",
        "I'm not sure about that food.": "אני לא בטוח לגבי המאכל הזה.",

        // ── Connectivity / offline banners ─────────────────────────────
        "Sensor data unavailable — no internet connection":
            "נתוני חיישנים אינם זמינים — אין חיבור לאינטרנט",
        "Notifications are off": "ההתראות כבויות",
        "Vaccine and meal reminders won't be delivered. Tap to open Settings.":
            "תזכורות חיסונים וארוחות לא יישלחו. הקש לפתיחת הגדרות.",

        // ── Sensor chart ───────────────────────────────────────────────
        "Last 24 Hours":         "24 השעות האחרונות",
        "Current":               "נוכחי",
        "Min 24h":               "מינ׳ 24 ש׳",
        "Max 24h":               "מקס׳ 24 ש׳",
        "No data yet":           "אין עדיין נתונים",
        "Building the chart…":   "בונה את הגרף…",
    ]
}
