import Foundation

// MARK: - Puppy Age Profile

enum PuppyAgeProfile: String, Codable, CaseIterable {
    case age0To4Weeks  = "0–4 weeks"
    case age1To2Months = "1–2 months"
    case age2To4Months = "2–4 months"
    case age4PlusMonths = "4+ months"

    var shortLabel: String { rawValue }
}

// MARK: - Daily Routine Schedule

enum ScheduleItemType: String, Codable, CaseIterable {
    case meal = "meal"
    case walk = "walk"
    case play = "play"

    var displayName: String {
        switch self {
        case .meal: return "Meal"
        case .walk: return "Walk"
        case .play: return "Play"
        }
    }

    var systemIcon: String {
        switch self {
        case .meal: return "fork.knife"
        case .walk: return "figure.walk"
        case .play: return "figure.play"
        }
    }

    var notificationEmoji: String {
        switch self {
        case .meal: return "🍽️"
        case .walk: return "🐕"
        case .play: return "🎾"
        }
    }
}

struct ScheduleItem: Codable, Identifiable {
    var id:              UUID
    var type:            ScheduleItemType
    var time:            String   // "HH:mm"
    var label:           String
    var grams:           Int?     // meal only
    var durationMinutes: Int?     // play only

    init(
        id: UUID = UUID(),
        type: ScheduleItemType,
        time: String,
        label: String,
        grams: Int? = nil,
        durationMinutes: Int? = nil
    ) {
        self.id              = id
        self.type            = type
        self.time            = time
        self.label           = label
        self.grams           = grams
        self.durationMinutes = durationMinutes
    }

    /// Auto-generates a human-friendly label from type and time string.
    static func autoLabel(type: ScheduleItemType, timeString: String) -> String {
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        let hour  = parts.first ?? 8
        switch type {
        case .meal:
            if hour < 9  { return "Breakfast"      }
            if hour < 11 { return "Morning Snack"  }
            if hour < 14 { return "Lunch"          }
            if hour < 17 { return "Afternoon Meal" }
            return "Dinner"
        case .walk:
            if hour < 9  { return "Morning Walk"       }
            if hour < 13 { return "Late Morning Walk"  }
            if hour < 17 { return "Afternoon Walk"     }
            return "Evening Walk"
        case .play:
            if hour < 9  { return "Morning Play"   }
            if hour < 13 { return "Midday Play"    }
            if hour < 17 { return "Afternoon Play" }
            return "Evening Play"
        }
    }
}

// MARK: - Dog Profile

struct DogProfile: Codable {

    // MARK: Core identity
    var name:                 String
    var breed:                String
    var sex:                  String
    var ageMonths:            String
    var weightKg:             String
    var profileImageFilename: String
    var isInKennel:           Bool

    // MARK: Food
    var foodName:             String
    var foodCaloriesPer100g:  String

    // MARK: Daily routine (new source of truth)
    var scheduleItems: [ScheduleItem]

    // MARK: Legacy feeding fields (kept for migration; no longer primary source of truth)
    var mealsPerDay:      Int
    var gramsPerMeal:     Int
    var morningMealTime:  String
    var secondMealTime:   String
    var thirdMealTime:    String
    var eveningMealTime:  String

    // MARK: Kennel session
    var kennelSessionStart: Date?

    // MARK: Custom alert thresholds
    var tempWarnHigh:     Double
    var tempCriticalHigh: Double
    var tempWarnLow:      Double
    var tempCriticalLow:  Double

    // MARK: Legacy walk times (migrated into scheduleItems)
    var walkTimes: [String]

    // MARK: Misc
    var dismissedVaccineReminders: [String]
    var hasCompletedOnboarding:    Bool

    // MARK: - Dog Profile Auto-Configuration (new — all optional/defaulted for backward compatibility)

    /// The operational profile the user explicitly selected in setup.
    /// nil = not yet configured via the new setup flow.
    var selectedOperationalProfile: OperationalDogProfile?

    /// Birth date — used for precise vaccine reminder scheduling.
    var birthDate: Date?

    /// Physical / lifestyle inputs used by DogProfileEngine.
    var sizeGroup:        SizeGroup        = .medium
    var headType:         HeadType         = .normal
    var coatType:         CoatType         = .regular
    var specialCondition: SpecialCondition = .none
    var lifestyleFlags:   [LifestyleFlag]  = []
    var regionRisk:       RegionRisk       = .centralOrSouth

    /// Auto-configured health reminders — computed and saved by DogProfileEngine.
    var derivedHealthReminders: DerivedHealthReminders?

    /// Auto-configured sensor defaults (sound/motion sensitivity, inactivity threshold)
    /// derived by DogProfileEngine. Persisted so AlertManager can be fully configured
    /// on launch without needing to re-run the engine.
    var derivedSensorDefaults: DerivedSensorDefaults?

    /// True after the user has completed the new auto-config setup flow at least once.
    var hasCompletedProfileSetup: Bool = false

    /// Whether the user has manually overridden any auto-configured thresholds.
    var manualOverridesEnabled: Bool = false

    // MARK: - Empty default

    static let empty = DogProfile(
        name: "", breed: "", sex: "", ageMonths: "", weightKg: "",
        profileImageFilename: "", isInKennel: false,
        foodName: "", foodCaloriesPer100g: "380",
        scheduleItems: [],
        mealsPerDay: 0, gramsPerMeal: 0,
        morningMealTime: "07:00", secondMealTime: "11:00",
        thirdMealTime: "15:00", eveningMealTime: "19:00",
        kennelSessionStart: nil,
        tempWarnHigh: 28, tempCriticalHigh: 32,
        tempWarnLow: 12, tempCriticalLow: 8,
        walkTimes: [],
        dismissedVaccineReminders: [], hasCompletedOnboarding: false
    )

    // MARK: - Custom Codable (backwards-compatible)

    enum CodingKeys: String, CodingKey {
        case name, breed, sex, ageMonths, weightKg, profileImageFilename, isInKennel
        case foodName, foodCaloriesPer100g
        case scheduleItems
        case mealsPerDay, gramsPerMeal, morningMealTime, secondMealTime, thirdMealTime, eveningMealTime
        case kennelSessionStart
        case tempWarnHigh, tempCriticalHigh, tempWarnLow, tempCriticalLow
        case walkTimes
        case dismissedVaccineReminders, hasCompletedOnboarding
        // New keys
        case selectedOperationalProfile
        case birthDate
        case sizeGroup, headType, coatType, specialCondition, lifestyleFlags, regionRisk
        case derivedHealthReminders
        case derivedSensorDefaults
        case hasCompletedProfileSetup, manualOverridesEnabled
    }

    init(
        name: String, breed: String, sex: String, ageMonths: String, weightKg: String,
        profileImageFilename: String, isInKennel: Bool,
        foodName: String, foodCaloriesPer100g: String,
        scheduleItems: [ScheduleItem] = [],
        mealsPerDay: Int, gramsPerMeal: Int,
        morningMealTime: String, secondMealTime: String,
        thirdMealTime: String, eveningMealTime: String,
        kennelSessionStart: Date? = nil,
        tempWarnHigh: Double = 28, tempCriticalHigh: Double = 32,
        tempWarnLow: Double = 12, tempCriticalLow: Double = 8,
        walkTimes: [String] = [],
        dismissedVaccineReminders: [String], hasCompletedOnboarding: Bool,
        // New — all optional with safe defaults
        selectedOperationalProfile: OperationalDogProfile? = nil,
        birthDate: Date? = nil,
        sizeGroup: SizeGroup = .medium,
        headType: HeadType = .normal,
        coatType: CoatType = .regular,
        specialCondition: SpecialCondition = .none,
        lifestyleFlags: [LifestyleFlag] = [],
        regionRisk: RegionRisk = .centralOrSouth,
        derivedHealthReminders: DerivedHealthReminders? = nil,
        derivedSensorDefaults: DerivedSensorDefaults? = nil,
        hasCompletedProfileSetup: Bool = false,
        manualOverridesEnabled: Bool = false
    ) {
        self.name = name; self.breed = breed; self.sex = sex
        self.ageMonths = ageMonths; self.weightKg = weightKg
        self.profileImageFilename = profileImageFilename; self.isInKennel = isInKennel
        self.foodName = foodName; self.foodCaloriesPer100g = foodCaloriesPer100g
        self.scheduleItems = scheduleItems
        self.mealsPerDay = mealsPerDay; self.gramsPerMeal = gramsPerMeal
        self.morningMealTime = morningMealTime; self.secondMealTime = secondMealTime
        self.thirdMealTime = thirdMealTime; self.eveningMealTime = eveningMealTime
        self.kennelSessionStart = kennelSessionStart
        self.tempWarnHigh = tempWarnHigh; self.tempCriticalHigh = tempCriticalHigh
        self.tempWarnLow = tempWarnLow; self.tempCriticalLow = tempCriticalLow
        self.walkTimes = walkTimes
        self.dismissedVaccineReminders = dismissedVaccineReminders
        self.hasCompletedOnboarding = hasCompletedOnboarding
        // New fields
        self.selectedOperationalProfile = selectedOperationalProfile
        self.birthDate = birthDate
        self.sizeGroup = sizeGroup; self.headType = headType
        self.coatType = coatType; self.specialCondition = specialCondition
        self.lifestyleFlags = lifestyleFlags; self.regionRisk = regionRisk
        self.derivedHealthReminders = derivedHealthReminders
        self.derivedSensorDefaults  = derivedSensorDefaults
        self.hasCompletedProfileSetup = hasCompletedProfileSetup
        self.manualOverridesEnabled = manualOverridesEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name                    = try c.decode(String.self,  forKey: .name)
        breed                   = try c.decode(String.self,  forKey: .breed)
        sex                     = try c.decode(String.self,  forKey: .sex)
        ageMonths               = try c.decode(String.self,  forKey: .ageMonths)
        weightKg                = try c.decode(String.self,  forKey: .weightKg)
        profileImageFilename    = try c.decode(String.self,  forKey: .profileImageFilename)
        isInKennel              = try c.decode(Bool.self,    forKey: .isInKennel)
        foodName                = try c.decode(String.self,  forKey: .foodName)
        foodCaloriesPer100g     = try c.decode(String.self,  forKey: .foodCaloriesPer100g)
        mealsPerDay             = try c.decode(Int.self,     forKey: .mealsPerDay)
        gramsPerMeal            = try c.decode(Int.self,     forKey: .gramsPerMeal)
        morningMealTime         = try c.decode(String.self,  forKey: .morningMealTime)
        secondMealTime          = try c.decode(String.self,  forKey: .secondMealTime)
        thirdMealTime           = try c.decode(String.self,  forKey: .thirdMealTime)
        eveningMealTime         = try c.decode(String.self,  forKey: .eveningMealTime)
        dismissedVaccineReminders = try c.decode([String].self, forKey: .dismissedVaccineReminders)
        hasCompletedOnboarding  = try c.decode(Bool.self,    forKey: .hasCompletedOnboarding)

        // Existing optional fields — safe defaults when key is absent
        scheduleItems       = (try? c.decode([ScheduleItem].self, forKey: .scheduleItems))  ?? []
        kennelSessionStart  = try? c.decodeIfPresent(Date.self,   forKey: .kennelSessionStart)
        tempWarnHigh        = (try? c.decode(Double.self,         forKey: .tempWarnHigh))       ?? 28
        tempCriticalHigh    = (try? c.decode(Double.self,         forKey: .tempCriticalHigh))   ?? 32
        tempWarnLow         = (try? c.decode(Double.self,         forKey: .tempWarnLow))        ?? 12
        tempCriticalLow     = (try? c.decode(Double.self,         forKey: .tempCriticalLow))    ?? 8
        walkTimes           = (try? c.decode([String].self,       forKey: .walkTimes))          ?? []

        // New auto-config fields — all safe-defaulted so old saved data never breaks
        selectedOperationalProfile = try? c.decodeIfPresent(OperationalDogProfile.self, forKey: .selectedOperationalProfile)
        birthDate          = try? c.decodeIfPresent(Date.self,               forKey: .birthDate)
        sizeGroup          = (try? c.decode(SizeGroup.self,        forKey: .sizeGroup))        ?? .medium
        headType           = (try? c.decode(HeadType.self,         forKey: .headType))         ?? .normal
        coatType           = (try? c.decode(CoatType.self,         forKey: .coatType))         ?? .regular
        specialCondition   = (try? c.decode(SpecialCondition.self, forKey: .specialCondition)) ?? .none
        lifestyleFlags     = (try? c.decode([LifestyleFlag].self,  forKey: .lifestyleFlags))   ?? []
        regionRisk         = (try? c.decode(RegionRisk.self,       forKey: .regionRisk))       ?? .centralOrSouth
        derivedHealthReminders  = try? c.decodeIfPresent(DerivedHealthReminders.self,  forKey: .derivedHealthReminders)
        derivedSensorDefaults   = try? c.decodeIfPresent(DerivedSensorDefaults.self,   forKey: .derivedSensorDefaults)
        hasCompletedProfileSetup = (try? c.decode(Bool.self,       forKey: .hasCompletedProfileSetup)) ?? false
        manualOverridesEnabled   = (try? c.decode(Bool.self,       forKey: .manualOverridesEnabled))   ?? false
    }

    // MARK: - Derived helpers

    var ageMonthsValue: Double? {
        Double(ageMonths.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var isCompleteForOnboarding: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ageMonths.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !weightKg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var ageProfile: PuppyAgeProfile? {
        guard let months = ageMonthsValue else { return nil }
        if months < 1  { return .age0To4Weeks   }
        if months < 2  { return .age1To2Months  }
        if months < 4  { return .age2To4Months  }
        return .age4PlusMonths
    }

    var isYoungPuppy: Bool {
        guard let profile = ageProfile else { return false }
        switch profile {
        case .age0To4Weeks, .age1To2Months, .age2To4Months: return true
        case .age4PlusMonths: return false
        }
    }

    /// Convenience: meal items sorted by time.
    var mealItems: [ScheduleItem] {
        scheduleItems.filter { $0.type == .meal }.sorted { $0.time < $1.time }
    }

    /// Convenience: walk items sorted by time.
    var walkItems: [ScheduleItem] {
        scheduleItems.filter { $0.type == .walk }.sorted { $0.time < $1.time }
    }

    /// Convenience: play items sorted by time.
    var playItems: [ScheduleItem] {
        scheduleItems.filter { $0.type == .play }.sorted { $0.time < $1.time }
    }

    /// Total grams across all meal items that have a grams value.
    var totalDailyGrams: Int {
        mealItems.compactMap { $0.grams }.reduce(0, +)
    }

    var israelVaccineReminders: [String] {
        guard let months = ageMonthsValue else {
            return ["Set your dog's age to see vaccine reminders."]
        }
        var reminders: [String] = []
        if months < 1.5 {
            reminders.append("Discuss the first puppy multivalent vaccine timing with your veterinarian.")
        } else if months < 3 {
            reminders.append("Confirm the puppy multivalent vaccine series is in progress and not overdue.")
        } else if months < 12 {
            reminders.append("Rabies vaccination is legally required in Israel from 3 months of age.")
            reminders.append("If this is the first rabies vaccine, verify that the microchip requirement was completed.")
            reminders.append("Confirm the puppy multivalent series has been completed and ask when the next booster is due.")
        } else {
            reminders.append("Rabies vaccination should remain current yearly in Israel.")
            reminders.append("Ask your veterinarian whether the annual booster is due.")
        }
        return reminders
    }
}

// MARK: - Sensor Data

struct SensorData {
    var temperature:        Double?
    var humidity:           Double?
    /// Decoded from the Pi's "light"/"dark" string (or raw Bool). Drives the
    /// dashboard Light tile and the AlertManager light-edge tracking.
    var lightDetected:      Bool   = false
    var soundActive:        Bool   = false
    var barkDetected:       Bool   = false
    var barkCount5s:        Int    = 0
    var sustainedSound:     Bool   = false
    var motionDetected:     Bool   = false
    var lastMotion:         String = "never"
    var secondsSinceMotion: Int?
    /// Consecutive writer-loop cycles (~5 s each) during which motion was detected.
    /// Written by the Pi to kennel/sensors.motion_streak.
    var motionStreak:       Int    = 0
    /// Consecutive writer-loop cycles during which bark_detected or sustained_sound was active.
    /// Written by the Pi to kennel/sensors.sound_streak.
    var soundStreak:        Int    = 0
    var alertLevel:         String = "normal"
    var sleeping:           Bool   = false
    var alertReasons:       [String] = []
    var puppyMode:          Bool   = false
    var puppyAge:           String = ""
    var timestamp:          String = ""

    /// Maps any incoming Pi level (including legacy "stress"/"emergency") onto the
    /// active 3-tier model: normal | warning | critical.
    var normalizedAlertLevel: String {
        let value = alertLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "warning":                   return "warning"
        case "critical", "stress", "emergency": return "critical"
        default:                          return "normal"
        }
    }
}

// MARK: - Dog Data Options

enum DogDataOptions {
    static let sexOptions: [String] = ["Male", "Female"]

    static let mixedBreedOptions: [String] = [
        "Mixed Breed", "Small Mixed Breed", "Medium Mixed Breed", "Large Mixed Breed"
    ]

    static let ageMonths: [String] = stride(from: 1, through: 24, by: 1).map { "\($0)" }

    static let weightOptions: [String] = stride(from: 1.0, through: 20.0, by: 0.5).map {
        $0.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", $0)
            : String(format: "%.1f", $0)
    }

    static let allBreeds: [String] = [
        "Dachshund", "Labrador Retriever", "Golden Retriever", "German Shepherd",
        "French Bulldog", "Poodle", "Chihuahua", "Shih Tzu", "Cocker Spaniel",
        "Yorkshire Terrier", "Boxer", "Beagle", "Pug", "Rottweiler", "Border Collie",
        "Siberian Husky", "Pomeranian", "Maltese", "Boston Terrier",
        "Cavalier King Charles Spaniel"
    ] + mixedBreedOptions

    static func prioritizedBreeds(searchText: String) -> [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allBreeds }
        return allBreeds.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}
