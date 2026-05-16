//
//  SmartKennelTests.swift
//  SmartKennelTests
//
//  Unit tests covering the logic that's caused real bugs over the life of
//  the project. Each test traces back to a concrete fix in git history —
//  these aren't theoretical coverage, they're regressions we never want to
//  re-introduce. Comments cite the commit / audit finding that motivated
//  each test.

import Testing
import Foundation
@testable import SmartKennel

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DogProfileEngine: rabies anniversary
//
// Regression for 94cb85b (later subsumed into ed65c76).
//
// The pre-fix code computed the next rabies due date as
//     max(firstRabiesDue, today) + 1 year
// which collapsed to "today + 1 year" for any dog past its first dose. A
// 3-year-old dog whose first dose was July showed its next dose 1 year from
// the moment the app was opened, not on the actual anniversary.
// ─────────────────────────────────────────────────────────────────────────────

struct RabiesAnniversaryTests {

    // Helper: build a profile and pull the active rabies reminder out of the
    // engine. Returns nil if the engine emitted no rabies item — which would
    // itself be a regression (Israel-mandatory rabies must always be present).
    private func rabiesReminder(birthYear: Int, birthMonth: Int, birthDay: Int) -> HealthReminderItem? {
        let cal = Calendar(identifier: .gregorian)
        let birth = cal.date(from: DateComponents(year: birthYear, month: birthMonth, day: birthDay))!
        var profile = DogProfile.empty
        profile.birthDate = birth
        profile.name = "Test"
        profile.breed = "Labrador"
        profile.sex = "Male"
        profile.weightKg = "20"
        let config = DogProfileEngine.derive(from: profile)
        return config.healthReminders.items.first { $0.category == .rabies }
    }

    @Test("First rabies for a < 3-month-old puppy is upcoming on bd + 3 months")
    func firstRabiesUpcoming() {
        // For a puppy that won't reach 3 months for another month, the engine
        // must surface a "First Rabies Vaccine — Upcoming" item with a due
        // date that's exactly bd + 3 months (NOT a moving target relative to
        // today).
        let cal = Calendar(identifier: .gregorian)
        let twoMonthsAgo = cal.date(byAdding: .month, value: -2, to: Date())!
        let bd = cal.dateComponents([.year, .month, .day], from: twoMonthsAgo)
        let item = rabiesReminder(birthYear: bd.year!, birthMonth: bd.month!, birthDay: bd.day!)
        #expect(item != nil)
        #expect(item!.title.contains("Upcoming"))
        let expected = cal.date(byAdding: .month, value: 3, to: twoMonthsAgo)!
        let dayDiff = abs(cal.dateComponents([.day], from: expected, to: item!.dueDate!).day ?? 99)
        #expect(dayDiff <= 1, "Due date should be bd + 3 months, off by \(dayDiff) days")
    }

    @Test("Adult dog: due date is the NEXT anniversary, not today + 1 year")
    func adultDogAnnualBooster() {
        let cal = Calendar(identifier: .gregorian)
        // Born 14 months ago — first dose was 11 months ago, anniversary is
        // in 1 more month (not 12 months as the pre-fix bug would yield).
        let bd = cal.date(byAdding: .month, value: -14, to: Date())!
        let comps = cal.dateComponents([.year, .month, .day], from: bd)
        let item = rabiesReminder(birthYear: comps.year!, birthMonth: comps.month!, birthDay: comps.day!)
        #expect(item != nil)
        #expect(item!.title == "Annual Rabies Vaccine")
        // Next anniversary = bd + 3mo + (yearsSince+1)*1y. For 14 mo old → yearsSince=0 → bd + 3mo + 1y.
        let expected = cal.date(byAdding: .year, value: 1, to: cal.date(byAdding: .month, value: 3, to: bd)!)!
        let dayDiff = abs(cal.dateComponents([.day], from: expected, to: item!.dueDate!).day ?? 99)
        #expect(dayDiff <= 1, "Adult anniversary was wrong by \(dayDiff) days")
    }

    @Test("Detail string reports the correct number of doses already owed by age")
    func dosesOwedByAge() {
        // 5-year-old → 1 first + 4 annual = 5 doses on the record.
        let cal = Calendar(identifier: .gregorian)
        let bd = cal.date(byAdding: .year, value: -5, to: Date())!
        let comps = cal.dateComponents([.year, .month, .day], from: bd)
        let item = rabiesReminder(birthYear: comps.year!, birthMonth: comps.month!, birthDay: comps.day!)
        #expect(item != nil)
        #expect(item!.detail.contains("5 rabies vaccinations"),
                "Expected dose count of 5, got: \(item!.detail)")
    }

    @Test("Israel-mandatory: ONLY rabies is emitted, never DHPP / kennel cough")
    func onlyMandatoryVaccines() {
        // Audit-driven regression — the engine used to emit core puppy
        // series, kennel cough, leptospirosis, and park-worm reminders
        // even though none of those are legally required in Israel.
        let cal = Calendar(identifier: .gregorian)
        let bd = cal.date(byAdding: .month, value: -6, to: Date())!
        let comps = cal.dateComponents([.year, .month, .day], from: bd)
        let item = rabiesReminder(birthYear: comps.year!, birthMonth: comps.month!, birthDay: comps.day!)
        #expect(item != nil, "Rabies must always be present")

        var p = DogProfile.empty
        p.birthDate = bd
        let allItems = DogProfileEngine.derive(from: p).healthReminders.items
        let categories = Set(allItems.map(\.category))
        #expect(categories == [.rabies],
                "Engine emitted non-mandatory items: \(categories)")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SensorData: alert-level normalisation
//
// Regression for bb91038 — when the Pi still wrote the legacy 4-tier values
// "stress" and "emergency", the iOS app needed to map them to the active
// 3-tier model so old dashboards on the wire didn't render as "normal".
// ─────────────────────────────────────────────────────────────────────────────

struct SensorDataNormalisationTests {

    @Test("Legacy 'stress' and 'emergency' both map to critical")
    func legacyLevelsMapToCritical() {
        var sd = SensorData()
        sd.alertLevel = "stress"
        #expect(sd.normalizedAlertLevel == "critical")
        sd.alertLevel = "emergency"
        #expect(sd.normalizedAlertLevel == "critical")
    }

    @Test("Current 3-tier values pass through unchanged")
    func currentLevelsPassThrough() {
        var sd = SensorData()
        sd.alertLevel = "normal"
        #expect(sd.normalizedAlertLevel == "normal")
        sd.alertLevel = "warning"
        #expect(sd.normalizedAlertLevel == "warning")
        sd.alertLevel = "critical"
        #expect(sd.normalizedAlertLevel == "critical")
    }

    @Test("Unknown / empty levels default to normal")
    func unknownLevelsFallToNormal() {
        var sd = SensorData()
        sd.alertLevel = ""
        #expect(sd.normalizedAlertLevel == "normal")
        sd.alertLevel = "  WARNING  "
        // Whitespace and casing are normalised.
        #expect(sd.normalizedAlertLevel == "warning")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DogProfile: live age tracking
//
// Regression for ce25bab — ageMonthsValue used to just parse the stored
// `ageMonths` string, which only updated when the user re-saved the profile.
// A puppy that aged past 4 months kept being treated as a puppy by
// AlertManager and ProfileStore.syncThresholds. Now it derives live from
// birthDate when present.
// ─────────────────────────────────────────────────────────────────────────────

struct LiveAgeTests {

    @Test("birthDate set: ageMonthsValue tracks real time, ignores the stale string")
    func birthDateOverridesString() {
        let cal = Calendar(identifier: .gregorian)
        var p = DogProfile.empty
        p.birthDate = cal.date(byAdding: .month, value: -7, to: Date())!
        p.ageMonths = "1"  // stale string from initial setup 6 months ago
        #expect(p.ageMonthsValue == 7.0,
                "Expected 7, got \(p.ageMonthsValue ?? -1) — string took precedence")
    }

    @Test("birthDate nil: legacy profile falls back to the string")
    func legacyProfileFallback() {
        var p = DogProfile.empty
        p.birthDate = nil
        p.ageMonths = "8"
        #expect(p.ageMonthsValue == 8.0)
    }

    @Test("birthDate today: age is 0 (clamped, not negative)")
    func newbornAgeIsZero() {
        var p = DogProfile.empty
        p.birthDate = Date()
        p.ageMonths = ""
        #expect(p.ageMonthsValue == 0.0)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DogProfileEngine.urgency: day-granular consistency
//
// Regression for ce25bab — urgency(for:) used to compare raw Date(), while
// the user-visible dueText used startOfDay. A reminder due "yesterday 18:00"
// when "now is today 14:30" was simultaneously showing "Overdue by 1 day"
// text but a non-overdue (orange) pill color. Both must now agree.
// ─────────────────────────────────────────────────────────────────────────────

struct UrgencyConsistencyTests {

    private func makeItem(daysFromNow: Int) -> HealthReminderItem {
        let due = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return HealthReminderItem(
            key: "test", title: "T", detail: "D", dueDate: due,
            isActive: true, isMandatory: true, category: .rabies
        )
    }

    @Test("Yesterday's due date is overdue (was previously withinWeek)")
    func yesterdayIsOverdue() {
        let item = makeItem(daysFromNow: -1)
        #expect(DogProfileEngine.urgency(for: item) == .overdue)
    }

    @Test("Tomorrow is within-week")
    func tomorrowWithinWeek() {
        let item = makeItem(daysFromNow: 1)
        #expect(DogProfileEngine.urgency(for: item) == .withinWeek)
    }

    @Test("Item without due date returns noDate, not overdue")
    func noDate() {
        let item = HealthReminderItem(
            key: "x", title: "T", detail: "D", dueDate: nil,
            isActive: true, isMandatory: true, category: .rabies
        )
        #expect(DogProfileEngine.urgency(for: item) == .noDate)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FirebaseService static parsers
//
// Regression for the pi/iOS schema cleanup — `light` is written as a string
// ("light"/"dark") and `sound`/`motion` come back as NSNumber. These helpers
// have been the source of "tile stuck at default" bugs in the past.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
struct FirebaseParserTests {

    @Test("lightStringToBool decodes 'light' / 'dark' and Bool fallback")
    func lightDecoding() {
        #expect(FirebaseService.lightStringToBool("light")  == true)
        #expect(FirebaseService.lightStringToBool("dark")   == false)
        #expect(FirebaseService.lightStringToBool("LIGHT")  == true) // case-insensitive
        #expect(FirebaseService.lightStringToBool(NSNumber(value: true))  == true)
        #expect(FirebaseService.lightStringToBool(NSNumber(value: false)) == false)
        #expect(FirebaseService.lightStringToBool("garbage") == nil)
        #expect(FirebaseService.lightStringToBool(nil) == nil)
    }

    @Test("toBool accepts NSNumber, strings, and rejects garbage")
    func boolDecoding() {
        #expect(FirebaseService.toBool(NSNumber(value: true))  == true)
        #expect(FirebaseService.toBool(NSNumber(value: false)) == false)
        #expect(FirebaseService.toBool("yes")    == true)
        #expect(FirebaseService.toBool("no")     == false)
        #expect(FirebaseService.toBool("1")      == true)
        #expect(FirebaseService.toBool("0")      == false)
        #expect(FirebaseService.toBool("banana") == nil)
    }

    @Test("toDouble handles NSNumber, Int, String — covers Firebase JS number quirks")
    func doubleDecoding() {
        #expect(FirebaseService.toDouble(NSNumber(value: 22.5)) == 22.5)
        #expect(FirebaseService.toDouble(22) == 22.0)
        #expect(FirebaseService.toDouble("18.7") == 18.7)
        #expect(FirebaseService.toDouble(nil) == nil)
        #expect(FirebaseService.toDouble("not-a-number") == nil)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Localization: graceful English fallback
//
// Regression for c5a3089 — the runtime Localization layer must never return
// nil and must fall back to the English source string for any untranslated
// key, so screens we haven't touched still render readable text.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
struct LocalizationTests {

    @Test("Known Hebrew keys translate")
    func translatedKey() {
        let loc = Localization.shared
        let saved = loc.language
        defer { loc.language = saved }

        loc.language = .hebrew
        #expect(loc.t("Home") == "בית")
        #expect(loc.t("Critical") == "קריטי")
    }

    @Test("Untranslated keys return the source string in BOTH languages")
    func untranslatedKeyFallsThrough() {
        let loc = Localization.shared
        let saved = loc.language
        defer { loc.language = saved }

        loc.language = .english
        #expect(loc.t("SomeRandomScreenString") == "SomeRandomScreenString")

        loc.language = .hebrew
        #expect(loc.t("SomeRandomScreenString") == "SomeRandomScreenString")
    }

    @Test("English mode always returns the key unchanged")
    func englishMode() {
        let loc = Localization.shared
        let saved = loc.language
        defer { loc.language = saved }

        loc.language = .english
        #expect(loc.t("Home") == "Home")
        #expect(loc.t("Critical") == "Critical")
    }
}
