import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Dog Profile Engine
//
// Pure static logic — no UI, no storage side effects.
// Input:  raw user-entered profile fields
// Output: DerivedSensorDefaults + DerivedHealthReminders
//
// Call onSaveDogProfile(_:) after the user completes setup.
// The returned tuple is what ProfileStore should apply to the live profile.
// ─────────────────────────────────────────────────────────────────────────────

enum DogProfileEngine {

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Public entry point
    // ─────────────────────────────────────────────────────────────────────────

    struct DerivedConfiguration {
        let operationalProfile: OperationalDogProfile
        let sensorDefaults:     DerivedSensorDefaults
        let healthReminders:    DerivedHealthReminders
    }

    /// Call this after the user saves their dog profile.
    /// Returns everything the ProfileStore needs to apply.
    static func derive(from profile: DogProfile) -> DerivedConfiguration {
        let opProfile  = deriveOperationalProfile(from: profile)
        let sensors    = deriveSensorDefaults(operationalProfile: opProfile,
                                             sizeGroup:         profile.sizeGroup,
                                             headType:          profile.headType,
                                             coatType:          profile.coatType,
                                             specialCondition:  profile.specialCondition,
                                             ageMonths:         profile.ageMonthsValue ?? 12)
        let reminders  = deriveHealthReminders(birthDate:       profile.birthDate,
                                              operationalProfile: opProfile,
                                              lifestyleFlags:   profile.lifestyleFlags,
                                              regionRisk:        profile.regionRisk)
        return DerivedConfiguration(
            operationalProfile: opProfile,
            sensorDefaults:     sensors,
            healthReminders:    reminders
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Derive Operational Profile
    // ─────────────────────────────────────────────────────────────────────────

    static func deriveOperationalProfile(from profile: DogProfile) -> OperationalDogProfile {
        // Explicit user selection takes highest priority
        if let selected = profile.selectedOperationalProfile {
            return selected
        }

        // Auto-derive from age + physical characteristics as fallback
        let months = profile.ageMonthsValue ?? 12

        // Brachycephalic overrides size-based logic
        if profile.headType == .brachycephalic {
            return .brachycephalic
        }

        // Puppy: under 3 months
        if months < 3 {
            return .youngPuppy
        }

        // Senior: over 84 months (7 years)
        if months >= 84 || profile.specialCondition == .chronicCondition || profile.specialCondition == .postSurgery {
            return .seniorSensitive
        }

        // Size-based
        switch profile.sizeGroup {
        case .small:
            return .smallDog
        case .large, .giant:
            return .largeGiantDog
        case .medium:
            // Medium with heat sensitivity → large profile thresholds
            if profile.specialCondition == .heatSensitive { return .largeGiantDog }
            return .smallDog  // default medium to small-dog thresholds (safer)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Derive Sensor Defaults
    // ─────────────────────────────────────────────────────────────────────────

    static func deriveSensorDefaults(
        operationalProfile: OperationalDogProfile,
        sizeGroup:          SizeGroup,
        headType:           HeadType,
        coatType:           CoatType,
        specialCondition:   SpecialCondition,
        ageMonths:          Double = 12    // used for intra-puppy fine-graining
    ) -> DerivedSensorDefaults {

        // ── Base thresholds by operational profile ──────────────────────────
        //
        // Temperature values are AMBIENT KENNEL temperature (°C), not body temp.
        //
        // Research sources:
        //   • Merck Veterinary Manual — Neonatal Puppy Care (thermoregulation
        //     capacity by week; optimal nest temperature 29–32 °C for neonates)
        //   • AVMA — Guidelines for the Euthanasia of Animals (housing temp refs)
        //   • Brachycephalic Obstructive Airway Syndrome (BOAS) clinical literature
        //     (Packer et al., 2015; Liu et al., 2016) — heat intolerance at >24 °C
        //   • Canine geriatric care references — reduced thermoregulatory efficiency
        //
        var warnHigh:     Double
        var criticalHigh: Double
        var warnLow:      Double
        var criticalLow:  Double
        var soundLevel:   SoundSensitivityLevel
        var soundAlone:   Bool
        var motionLevel:  MotionSensitivityLevel
        var inactiveMin:  Int

        switch operationalProfile {

        case .youngPuppy:
            // Puppies cannot regulate body temperature until ~3–4 weeks of age.
            // We sub-divide into three developmental stages with independent thresholds:

            if ageMonths < 1 {
                // ── Neonatal (0–4 weeks) ────────────────────────────────────────
                // Thermoregulation: essentially absent; fully dependent on ambient heat.
                // Source: Merck Vet Manual; Johnston, Root Kustritz & Olson (2001)
                //   Week 1: alert below 29 °C, alert above 33 °C (optimal 29.4–32.2 °C)
                //   Week 2: alert below 26 °C, alert above 30 °C
                //   Using week-1 values (most conservative) for the entire 0–4 week bucket.
                //   Critical low 26 °C: below this, rectal temp drops → hypothermia in min.
                //   Critical high 34 °C: near upper limit of safe whelping-box temperature.
                // Sound: barking neurologically impossible before 3–4 weeks (Scott & Fuller 1965).
                //   Sustained cry >90 s = distress (cold / hunger / pain / separation).
                //   KY-038 bark events alone are unreliable at this developmental stage.
                // Activity: sleep ~90 % of the day (≈21 h). Long inactivity is NORMAL.
                //   inactiveMin = 0 → DISABLES inactivity alerting for this stage.
                warnHigh = 33; criticalHigh = 34   // Merck week-1: alert >33 °C
                warnLow  = 29; criticalLow  = 26   // Merck week-1: alert <29 °C; critical <26 °C
                soundLevel  = .high
                soundAlone  = false   // cry not bark; KY-038 bark events unreliable
                motionLevel = .high
                inactiveMin = 0       // disabled — sleeping 90 % is developmentally normal

            } else if ageMonths < 2 {
                // ── Transitional (4–8 weeks / 1–2 months) ──────────────────────
                // Thermoregulation: beginning to develop; shivering reflex matures.
                // Source: Merck Vet Manual "Management of the Neonate"
                //   Optimal ambient: 21–24 °C; alert below 18 °C, alert above 27 °C.
                // Sound: proto-barks emerging ~3–4 weeks (Scott & Fuller 1965);
                //   whimpers still dominant. Bark events alone unreliable as distress signal.
                // Activity: sleep 18–20 h/day (Zanghi et al., J Vet Behav 2013).
                //   Alert after 3 hours without movement (long naps are developmentally normal).
                warnHigh = 27; criticalHigh = 30   // Merck: alert above 27 °C
                warnLow  = 18; criticalLow  = 15   // Merck: alert below 18 °C
                soundLevel  = .high
                soundAlone  = false   // bark reflex developing; don't alert on sound alone
                motionLevel = .high
                inactiveMin = 180     // 3 h — long naps are developmentally normal

            } else {
                // ── Juvenile puppy (2–4 months) ─────────────────────────────────
                // Thermoregulation: improving but still more sensitive than adults.
                // Source: ASPCA/AVMA kennel care guidelines; applied clinical norms.
                //   Optimal ambient: 18–24 °C; alert below 15 °C, alert above 27 °C.
                // Sound: bark now functional; soundAlone remains false because puppies
                //   whimper frequently — avoids excessive false alerts.
                // Activity: sleep ~16–18 h/day; 2-hour inactivity threshold (Zanghi 2013).
                warnHigh = 27; criticalHigh = 30   // AVMA: alert above 27 °C
                warnLow  = 15; criticalLow  = 12   // AVMA: alert below 15 °C
                soundLevel  = .standard
                soundAlone  = false   // developmentally frequent whimpers — avoid false alerts
                motionLevel = .high
                inactiveMin = 120     // 2 h — puppies still nap frequently
            }

        case .smallDog:
            // Small dogs (<10 kg) lose heat faster relative to body mass (higher
            // surface-area-to-volume ratio) → tighter cold thresholds.
            // Source: Reiter & Gaschen, JAVMA 2011; Merck Vet Manual "Heat Stroke"
            //   TNZ 20–25 °C; alert below 15 °C, alert above 27 °C.
            //   Hypothermia risk at ambient below 10 °C without shelter.
            warnHigh = 27; criticalHigh = 32   // alert above 27 °C (research); critical 32 °C
            warnLow  = 15; criticalLow  = 10   // alert below 15 °C; critical below 10 °C
            soundLevel  = .standard
            soundAlone  = true
            motionLevel = .standard
            inactiveMin = 60    // 1 h — healthy adult; flags unexpected daytime lethargy

        case .largeGiantDog:
            // Large/giant dogs (>25 kg) generate more body heat per unit of surface area.
            // Source: Merck Vet Manual "Heat Stroke and Heat Exhaustion"; NRC 2006
            //   TNZ 15–22 °C; alert below 10 °C, alert above 24 °C.
            //   Giant breeds (>45 kg) at elevated heat-stroke risk above 27 °C.
            warnHigh = 24; criticalHigh = 28   // alert above 24 °C; critical 28 °C
            warnLow  = 10; criticalLow  = 6    // alert below 10 °C; cold-tolerant
            soundLevel  = .standard
            soundAlone  = true
            motionLevel = .standard
            inactiveMin = 90    // 1.5 h — large dogs rest more; give extra margin

        case .brachycephalic:
            // BOAS severely limits panting (evaporative cooling) efficiency.
            // Source: Bruchim et al., J Vet Intern Med 2017; Roedler et al., Vet J 2013;
            //         Liu et al., PLOS ONE 2016 (sleep apnea in brachycephalic breeds)
            //   Strict safe ambient: 18–22 °C.
            //   Alert at 24 °C (panting becomes insufficient).
            //   Emergency alert above 26 °C (clinical heat crisis threshold).
            //   Cold: alert below 18 °C (same strict lower bound as upper).
            // Sound: stertor/stridor captured by KY-038 = clinically meaningful;
            //   soundAlone = false because respiratory sounds ≠ bark threshold events.
            // Inactivity: >60 min motionless at rest = hypoxic risk (Liu et al. 2016).
            //   Using 45 min as conservative buffer below the 60-min clinical threshold.
            warnHigh = 24; criticalHigh = 26   // research: alert 24 °C, emergency 26 °C
            warnLow  = 18; criticalLow  = 14   // research: strict lower bound 18 °C
            soundLevel  = .high
            soundAlone  = false   // respiratory sounds, not bark count
            motionLevel = .high
            inactiveMin = 45    // conservative buffer below 60-min BOAS rest threshold

        case .seniorSensitive:
            // Senior dogs (7+ years): reduced thermoregulatory efficiency,
            // narrowed thermoneutral zone in both directions.
            // Source: Laflamme, Vet Clin North Am 2005; AVMA Senior Pet Care Guidelines
            //   Recommended ambient: 20–24 °C; alert below 18 °C, alert above 26 °C.
            // Activity: senior dogs sleep 14–16 h/day; prolonged inactivity during
            //   daytime (>3 h) may signal illness (Zanghi 2013; Landsberg 2012).
            //   Using 120 min (2 h) as conservative daytime threshold.
            warnHigh = 26; criticalHigh = 30   // alert above 26 °C
            warnLow  = 18; criticalLow  = 14   // alert below 18 °C (was 14 — corrected)
            soundLevel  = .high
            soundAlone  = true
            motionLevel = .high
            inactiveMin = 120   // 2 h — research threshold is 3 h; 2 h is a safe buffer
        }

        // ── Coat adjustments ─────────────────────────────────────────────────
        switch coatType {
        case .short:
            // More cold-sensitive
            warnLow    = max(warnLow,  16)
            criticalLow = max(criticalLow, 12)
        case .thickDouble:
            // More heat-sensitive
            warnHigh     = min(warnHigh,     26)
            criticalHigh = min(criticalHigh, 30)
        case .regular:
            break
        }

        // ── Special condition overrides ───────────────────────────────────────
        switch specialCondition {
        case .heatSensitive:
            warnHigh     = min(warnHigh,     24)
            criticalHigh = min(criticalHigh, 28)
        case .coldSensitive:
            warnLow    = max(warnLow,   16)
            criticalLow = max(criticalLow, 13)
        case .postSurgery, .chronicCondition:
            // Tighten all thresholds by 1–2°C, raise motion sensitivity
            warnHigh     = min(warnHigh,     25)
            criticalHigh = min(criticalHigh, 29)
            warnLow      = max(warnLow,      16)
            criticalLow  = max(criticalLow,  13)
            motionLevel  = .high
            inactiveMin  = 30
        case .none:
            break
        }

        return DerivedSensorDefaults(
            tempWarnHigh:                warnHigh,
            tempCriticalHigh:            criticalHigh,
            tempWarnLow:                 warnLow,
            tempCriticalLow:             criticalLow,
            soundSensitivityLevel:       soundLevel,
            soundAsStandaloneTrigger:    soundAlone,
            motionSensitivityLevel:      motionLevel,
            lowActivityAlertAfterMinutes: inactiveMin
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Derive Health Reminders
    // ─────────────────────────────────────────────────────────────────────────

    static func deriveHealthReminders(
        birthDate:          Date?,
        operationalProfile: OperationalDogProfile,
        lifestyleFlags:     [LifestyleFlag],
        regionRisk:         RegionRisk
    ) -> DerivedHealthReminders {

        var items: [HealthReminderItem] = []
        let cal   = Calendar.current
        let today = Date()

        // ── Age in months (approximate) ─────────────────────────────────────
        let ageMonths: Double = {
            guard let bd = birthDate else { return 12 }
            let comps = cal.dateComponents([.month], from: bd, to: today)
            return Double(comps.month ?? 12)
        }()

        // ── Rabies (mandatory in Israel from 3 months, yearly) ──────────────
        if let bd = birthDate {
            // First rabies due at 3 months of age
            let firstRabiesDue = cal.date(byAdding: .month, value: 3, to: bd) ?? today
            let isFirstDue     = firstRabiesDue > today

            items.append(HealthReminderItem(
                key:         "rabies_first",
                title:       isFirstDue ? "First Rabies Vaccine Due" : "Annual Rabies Vaccine",
                detail:      "Mandatory in Israel from 3 months of age. Repeat annually.",
                dueDate:     isFirstDue ? firstRabiesDue : cal.date(byAdding: .year, value: 1,
                                             to: max(firstRabiesDue, today)),
                isActive:    true,
                isMandatory: true,
                category:    .rabies
            ))
        } else {
            // Birth date unknown — generic reminder
            items.append(HealthReminderItem(
                key:         "rabies_generic",
                title:       "Rabies Vaccination Status",
                detail:      "Enter birth date to get a precise rabies schedule. Mandatory in Israel from 3 months.",
                dueDate:     nil,
                isActive:    true,
                isMandatory: true,
                category:    .rabies
            ))
        }

        // ── Core Puppy Vaccines ───────────────────────────────────────────────
        if operationalProfile == .youngPuppy || ageMonths < 5 {
            let seriesStartAge: Double = 1.5  // 6 weeks

            if ageMonths < seriesStartAge {
                items.append(HealthReminderItem(
                    key:         "core_series_upcoming",
                    title:       "Puppy Core Vaccine Series — Upcoming",
                    detail:      "The first dose of the core puppy vaccine series is recommended at 6–8 weeks of age.",
                    dueDate:     birthDate.map { cal.date(byAdding: .weekOfYear, value: 6, to: $0) ?? today },
                    isActive:    true,
                    isMandatory: true,
                    category:    .coreVaccine
                ))
            } else if ageMonths < 4 {
                items.append(HealthReminderItem(
                    key:         "core_series_active",
                    title:       "Puppy Core Vaccine Series — In Progress",
                    detail:      "Series of 3–4 doses every 2–4 weeks, with the final dose at or after 16 weeks. Track each dose with your vet.",
                    dueDate:     nil,
                    isActive:    true,
                    isMandatory: true,
                    category:    .coreVaccine
                ))
            } else if ageMonths < 5 {
                items.append(HealthReminderItem(
                    key:         "core_series_overdue_check",
                    title:       "⚠️ Core Vaccine Series — Check Status",
                    detail:      "Puppy is over 16 weeks. If the core series is incomplete, this is a high-priority item. Contact your veterinarian.",
                    dueDate:     today,
                    isActive:    true,
                    isMandatory: true,
                    category:    .coreVaccine
                ))
            }

            // Booster at 6–12 months
            if let bd = birthDate {
                let boosterDue = cal.date(byAdding: .month, value: 9, to: bd) ?? today
                items.append(HealthReminderItem(
                    key:         "core_booster",
                    title:       "Core Vaccine Booster",
                    detail:      "First booster recommended at 6–12 months after completing the puppy series.",
                    dueDate:     boosterDue,
                    isActive:    boosterDue > today,
                    isMandatory: false,
                    category:    .coreVaccine
                ))
            }
        }

        // ── Vet Checkup ───────────────────────────────────────────────────────
        let vetIntervalMonths: Int
        switch operationalProfile {
        case .seniorSensitive: vetIntervalMonths = 6
        default:               vetIntervalMonths = 12
        }

        items.append(HealthReminderItem(
            key:         "vet_checkup",
            title:       "Routine Veterinary Check-up",
            detail:      operationalProfile == .seniorSensitive
                ? "Senior/sensitive dogs benefit from a check-up every 6 months."
                : "Annual routine check-up recommended.",
            dueDate:     cal.date(byAdding: .month, value: vetIntervalMonths, to: today),
            isActive:    true,
            isMandatory: false,
            category:    .vetCheckup
        ))

        // ── Park Worm (quarterly for outdoor dogs) ───────────────────────────
        let isOutdoor = lifestyleFlags.contains(.yardAccess) ||
                        lifestyleFlags.contains(.boardingRegular) ||
                        lifestyleFlags.contains(.groupTraining)

        if isOutdoor {
            items.append(HealthReminderItem(
                key:         "park_worm",
                title:       "Park Worm Prevention",
                detail:      "Quarterly deworming recommended for dogs with regular outdoor / park exposure in Israel.",
                dueDate:     cal.date(byAdding: .month, value: 3, to: today),
                isActive:    true,
                isMandatory: false,
                category:    .parkWorm
            ))
        }

        // ── Kennel Cough ─────────────────────────────────────────────────────
        let needsKennelCough = lifestyleFlags.contains(.boardingRegular) ||
                               lifestyleFlags.contains(.groupTraining)   ||
                               lifestyleFlags.contains(.frequentDogContact)

        if needsKennelCough {
            items.append(HealthReminderItem(
                key:         "kennel_cough",
                title:       "Kennel Cough Vaccine",
                detail:      "Recommended for dogs in boarding, group training, or frequent dog-contact environments.",
                dueDate:     cal.date(byAdding: .month, value: 12, to: today),
                isActive:    true,
                isMandatory: false,
                category:    .kennelCough
            ))
        }

        // ── Leptospirosis (risk-based: North Israel / Golan / water exposure) ─
        if regionRisk.leptospirosisRisk {
            items.append(HealthReminderItem(
                key:         "lepto",
                title:       "Leptospirosis Vaccine",
                detail:      "Recommended for dogs in northern Israel, the Golan, or areas with water-exposure risk. Discuss timing with your vet.",
                dueDate:     cal.date(byAdding: .month, value: 12, to: today),
                isActive:    true,
                isMandatory: false,
                category:    .leptospirosis
            ))
        }

        return DerivedHealthReminders(items: items)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Reminder urgency helper
    // ─────────────────────────────────────────────────────────────────────────

    enum ReminderUrgency {
        case overdue, withinWeek, withinMonth, upcoming, noDate
    }

    static func urgency(for item: HealthReminderItem) -> ReminderUrgency {
        guard let due = item.dueDate else { return .noDate }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        if days < 0  { return .overdue }
        if days <= 7 { return .withinWeek }
        if days <= 30 { return .withinMonth }
        return .upcoming
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Rabies reminder dates (30/14/7 day advance warnings)
    // ─────────────────────────────────────────────────────────────────────────

    static func rabiesReminderDates(dueDate: Date) -> [Date] {
        let cal = Calendar.current
        return [30, 14, 7].compactMap { days in
            cal.date(byAdding: .day, value: -days, to: dueDate)
        }
    }
}
