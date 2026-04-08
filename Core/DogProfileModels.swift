import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Operational Dog Profile
// ─────────────────────────────────────────────────────────────────────────────

/// The five operational profiles the system supports.
/// These drive auto-configuration — they are NOT a breed list.
enum OperationalDogProfile: String, Codable, CaseIterable, Identifiable {
    case youngPuppy      = "youngPuppy"
    case smallDog        = "smallDog"
    case largeGiantDog   = "largeGiantDog"
    case brachycephalic  = "brachycephalic"
    case seniorSensitive = "seniorSensitive"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .youngPuppy:      return "Young Puppy"
        case .smallDog:        return "Small Dog"
        case .largeGiantDog:   return "Large / Giant Dog"
        case .brachycephalic:  return "Brachycephalic"
        case .seniorSensitive: return "Senior / Sensitive Dog"
        }
    }

    var subtitle: String {
        switch self {
        case .youngPuppy:
            return "For puppies up to ~3 months; increases heat/cold sensitivity and activates puppy vaccination reminders."
        case .smallDog:
            return "For small or short-coated dogs that may need stronger protection from cold."
        case .largeGiantDog:
            return "For larger dogs that may overheat more easily during humidity or exertion."
        case .brachycephalic:
            return "For flat-faced dogs — Pugs, Bulldogs, French Bulldogs — with increased sensitivity to heat stress."
        case .seniorSensitive:
            return "For older or medically sensitive dogs that require more careful, frequent monitoring."
        }
    }

    var icon: String {
        switch self {
        case .youngPuppy:      return "🐶"
        case .smallDog:        return "🐩"
        case .largeGiantDog:   return "🦮"
        case .brachycephalic:  return "😤"
        case .seniorSensitive: return "🐕‍🦺"
        }
    }

    var heatRisk: RiskLevel {
        switch self {
        case .youngPuppy:      return .elevated
        case .smallDog:        return .normal
        case .largeGiantDog:   return .elevated
        case .brachycephalic:  return .high
        case .seniorSensitive: return .elevated
        }
    }

    var coldRisk: RiskLevel {
        switch self {
        case .youngPuppy:      return .elevated
        case .smallDog:        return .elevated
        case .largeGiantDog:   return .normal
        case .brachycephalic:  return .normal
        case .seniorSensitive: return .elevated
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Supporting Enums
// ─────────────────────────────────────────────────────────────────────────────

enum SizeGroup: String, Codable, CaseIterable, Identifiable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"
    case giant  = "giant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:  return "Small (up to 10 kg)"
        case .medium: return "Medium (10–25 kg)"
        case .large:  return "Large (25–45 kg)"
        case .giant:  return "Giant (45 kg +)"
        }
    }
}

enum HeadType: String, Codable, CaseIterable, Identifiable {
    case normal         = "normal"
    case brachycephalic = "brachycephalic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .brachycephalic:
            return "Flat-faced (Brachycephalic)"
        }
    }

    var subtitle: String {
        switch self {
        case .normal:
            return "Standard muzzle shape"
        case .brachycephalic:
            return "Pug, Bulldog, French Bulldog, Shih Tzu, Boxer…"
        }
    }
}

enum CoatType: String, Codable, CaseIterable, Identifiable {
    case short       = "short"
    case regular     = "regular"
    case thickDouble = "thickDouble"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .short:       return "Short / Thin"
        case .regular:     return "Regular"
        case .thickDouble: return "Thick / Double Coat"
        }
    }

    var subtitle: String {
        switch self {
        case .short:       return "Chihuahua, Doberman, Greyhound…"
        case .regular:     return "Labrador, Beagle, Poodle…"
        case .thickDouble: return "Husky, Malamute, Chow Chow…"
        }
    }
}

enum SpecialCondition: String, Codable, CaseIterable, Identifiable {
    case none             = "none"
    case heatSensitive    = "heatSensitive"
    case coldSensitive    = "coldSensitive"
    case postSurgery      = "postSurgery"
    case chronicCondition = "chronicCondition"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:             return "None"
        case .heatSensitive:    return "Heat-sensitive"
        case .coldSensitive:    return "Cold-sensitive"
        case .postSurgery:      return "Post-surgery / recovering"
        case .chronicCondition: return "Chronic medical condition"
        }
    }
}

enum LifestyleFlag: String, Codable, CaseIterable, Identifiable {
    case indoorOnly         = "indoorOnly"
    case yardAccess         = "yardAccess"
    case boardingRegular    = "boardingRegular"
    case groupTraining      = "groupTraining"
    case frequentDogContact = "frequentDogContact"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .indoorOnly:         return "Primarily indoor"
        case .yardAccess:         return "Has yard / outdoor access"
        case .boardingRegular:    return "Regular boarding"
        case .groupTraining:      return "Group training or classes"
        case .frequentDogContact: return "Frequent dog-to-dog contact"
        }
    }

    var icon: String {
        switch self {
        case .indoorOnly:         return "house.fill"
        case .yardAccess:         return "tree.fill"
        case .boardingRegular:    return "building.2.fill"
        case .groupTraining:      return "person.3.fill"
        case .frequentDogContact: return "pawprint.fill"
        }
    }
}

enum RegionRisk: String, Codable, CaseIterable, Identifiable {
    case centralOrSouth = "centralOrSouth"
    case northernIsrael = "northernIsrael"
    case golanOrWater   = "golanOrWater"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .centralOrSouth: return "Central / South Israel"
        case .northernIsrael: return "Northern Israel"
        case .golanOrWater:   return "Golan / high water-exposure area"
        }
    }

    var leptospirosisRisk: Bool {
        switch self {
        case .centralOrSouth: return false
        case .northernIsrael, .golanOrWater: return true
        }
    }
}

enum RiskLevel: String, Codable {
    case normal
    case elevated
    case high

    var displayName: String {
        switch self {
        case .normal:   return "Normal"
        case .elevated: return "Elevated"
        case .high:     return "High"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Derived Sensor Defaults
// ─────────────────────────────────────────────────────────────────────────────

/// Auto-configured sensor thresholds derived from the dog's profile.
/// These populate DogProfile's temp fields and drive AlertManager.
struct DerivedSensorDefaults: Codable {

    // Temperature (°C)
    var tempWarnHigh:     Double
    var tempCriticalHigh: Double
    var tempWarnLow:      Double
    var tempCriticalLow:  Double

    // Sound — descriptive labels (app maps these to actual sensitivity constants)
    var soundSensitivityLevel:      SoundSensitivityLevel
    var soundAsStandaloneTrigger:   Bool   // false = sound alone should not trigger alert

    // Motion
    var motionSensitivityLevel:     MotionSensitivityLevel
    var lowActivityAlertAfterMinutes: Int  // alert if no movement for this long

    // Human-readable summary
    var temperatureSummary: String {
        "Safe range \(Int(tempWarnLow))°C – \(Int(tempWarnHigh))°C · Critical below \(Int(tempCriticalLow))°C or above \(Int(tempCriticalHigh))°C"
    }

    var soundSummary: String {
        soundSensitivityLevel.displayName + (soundAsStandaloneTrigger ? "" : " · Sound alone won't trigger an alert")
    }

    var motionSummary: String {
        motionSensitivityLevel.displayName + " · Alert if no movement for \(lowActivityAlertAfterMinutes) min"
    }
}

enum SoundSensitivityLevel: String, Codable {
    case low      = "low"
    case standard = "standard"
    case high     = "high"

    var displayName: String {
        switch self {
        case .low:      return "Low sensitivity"
        case .standard: return "Standard sensitivity"
        case .high:     return "High sensitivity"
        }
    }
}

enum MotionSensitivityLevel: String, Codable {
    case low      = "low"
    case standard = "standard"
    case high     = "high"

    var displayName: String {
        switch self {
        case .low:      return "Low sensitivity"
        case .standard: return "Standard sensitivity"
        case .high:     return "High sensitivity"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Health Reminder Item
// ─────────────────────────────────────────────────────────────────────────────

struct HealthReminderItem: Codable, Identifiable {
    var id:          UUID   = UUID()
    var key:         String          // unique key, e.g. "rabies_2025"
    var title:       String
    var detail:      String
    var dueDate:     Date?
    var isActive:    Bool
    var isMandatory: Bool
    var category:    HealthReminderCategory
    var dismissed:   Bool = false
}

enum HealthReminderCategory: String, Codable, CaseIterable {
    case rabies        = "rabies"
    case coreVaccine   = "coreVaccine"
    case leptospirosis = "leptospirosis"
    case kennelCough   = "kennelCough"
    case parkWorm      = "parkWorm"
    case vetCheckup    = "vetCheckup"

    var displayName: String {
        switch self {
        case .rabies:        return "Rabies"
        case .coreVaccine:   return "Core Vaccines"
        case .leptospirosis: return "Leptospirosis"
        case .kennelCough:   return "Kennel Cough"
        case .parkWorm:      return "Park Worm Prevention"
        case .vetCheckup:    return "Veterinary Check-up"
        }
    }

    var icon: String {
        switch self {
        case .rabies:        return "syringe"
        case .coreVaccine:   return "cross.vial.fill"
        case .leptospirosis: return "drop.fill"
        case .kennelCough:   return "lungs.fill"
        case .parkWorm:      return "ant.fill"
        case .vetCheckup:    return "stethoscope"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Derived Health Reminders
// ─────────────────────────────────────────────────────────────────────────────

struct DerivedHealthReminders: Codable {
    var items: [HealthReminderItem]

    var activeItems: [HealthReminderItem] {
        items.filter { $0.isActive && !$0.dismissed }
    }

    var nextRabiesDate: Date? {
        items.first(where: { $0.category == .rabies && $0.isActive && !$0.dismissed })?.dueDate
    }

    var nextVetCheckDate: Date? {
        items.first(where: { $0.category == .vetCheckup && $0.isActive && !$0.dismissed })?.dueDate
    }
}
