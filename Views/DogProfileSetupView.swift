import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DogProfileSetupView
//
// 4-step wizard: Age → Profile Type → Coat & Conditions → Lifestyle & Region
// On completion: calls ProfileStore.applyDerivedConfiguration(_:)
// Then presents ProfileSummaryView as a full-screen cover.
//
// Entry points:
//   • Onboarding flow — shown automatically if !profile.hasCompletedProfileSetup
//   • ProfileView "Reconfigure Monitoring" button — shown on-demand
// ─────────────────────────────────────────────────────────────────────────────

struct DogProfileSetupView: View {

    @EnvironmentObject private var profileStore: ProfileStore
    var onComplete: (() -> Void)? = nil        // called after summary is dismissed

    // ── Wizard state ─────────────────────────────────────────────────────────
    @State private var step: Int = 0           // 0…3
    @State private var showSummary = false

    // ── Step 1 — Age / birth date ─────────────────────────────────────────────
    @State private var useBirthDate     = true
    @State private var birthDate        = Calendar.current.date(
                                              byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var ageMonthsText    = "3"
    @State private var sizeGroup        = SizeGroup.medium

    // ── Step 2 — Operational profile ─────────────────────────────────────────
    @State private var selectedProfile: OperationalDogProfile? = nil
    @State private var headType = HeadType.normal

    // ── Step 3 — Coat & conditions ────────────────────────────────────────────
    @State private var coatType         = CoatType.regular
    @State private var specialCondition = SpecialCondition.none

    // ── Step 4 — Lifestyle & region ───────────────────────────────────────────
    @State private var lifestyleFlags = Set<LifestyleFlag>()
    @State private var regionRisk     = RegionRisk.centralOrSouth

    // ── Derived config (set on save) ──────────────────────────────────────────
    @State private var derivedConfig: DogProfileEngine.DerivedConfiguration? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, 8)
                    .padding(.horizontal, AppTheme.horizontalPadding)

                TabView(selection: $step) {
                    step1AgeSize.tag(0)
                    step2ProfileType.tag(1)
                    step3CoatCondition.tag(2)
                    step4LifestyleRegion.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: step)

                bottomBar
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.bottom, 28)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Dog Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showSummary) {
            if let config = derivedConfig {
                ProfileSummaryView(config: config) {
                    showSummary = false
                    onComplete?()
                }
                .environmentObject(profileStore)
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i <= step ? AppTheme.accentBrown : Color.primary.opacity(0.12))
                    .frame(height: 4)
                    .animation(.easeInOut, value: step)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.primary.opacity(0.5))
            }

            Spacer()

            Button {
                handleNext()
            } label: {
                HStack(spacing: 6) {
                    Text(step < 3 ? "Continue" : "Apply Settings")
                        .font(.system(size: 15, weight: .bold))
                    Image(systemName: step < 3 ? "chevron.right" : "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, AppTheme.floatingButtonHorizontalPadding)
                .frame(height: AppTheme.floatingButtonHeight)
                .background(
                    nextButtonEnabled
                        ? AppTheme.accentBrown
                        : Color.primary.opacity(0.15)
                )
                .foregroundColor(nextButtonEnabled ? .white : .primary.opacity(0.35))
                .clipShape(Capsule())
            }
            .disabled(!nextButtonEnabled)
        }
    }

    private var nextButtonEnabled: Bool {
        switch step {
        case 1: return selectedProfile != nil
        default: return true
        }
    }

    private func handleNext() {
        if step < 3 {
            withAnimation { step += 1 }
        } else {
            saveAndDerive()
        }
    }

    // MARK: - Save & Derive

    private func saveAndDerive() {
        // Write user inputs back to the live profile
        let bd: Date? = useBirthDate ? birthDate : nil

        profileStore.profile.birthDate        = bd
        profileStore.profile.sizeGroup        = sizeGroup
        profileStore.profile.headType         = headType
        profileStore.profile.coatType         = coatType
        profileStore.profile.specialCondition = specialCondition
        profileStore.profile.lifestyleFlags   = Array(lifestyleFlags)
        profileStore.profile.regionRisk       = regionRisk

        // Sync ageMonths string from birth date if using date picker
        if let bd {
            let months = Calendar.current.dateComponents([.month], from: bd, to: Date()).month ?? 0
            profileStore.profile.ageMonths = "\(max(0, months))"
        }

        // Explicit profile selection overrides auto-derivation
        profileStore.profile.selectedOperationalProfile = selectedProfile

        // Derive and apply
        let config = DogProfileEngine.derive(from: profileStore.profile)
        profileStore.applyDerivedConfiguration(config)

        derivedConfig = config
        showSummary   = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Step 1: Age & Size
    // ─────────────────────────────────────────────────────────────────────────

    private var step1AgeSize: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                stepHeader(
                    icon: "birthday.cake.fill",
                    title: "Age & Size",
                    subtitle: "This helps us pick safe temperature and activity defaults for your dog."
                )

                // ── Age input toggle ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("How do you want to enter age?")
                        .font(AppTheme.fieldLabelFont)
                        .foregroundColor(.secondary)

                    Picker("", selection: $useBirthDate) {
                        Text("Birth date").tag(true)
                        Text("Age in months").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if useBirthDate {
                        DatePicker(
                            "Birth date",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .tint(AppTheme.accentBrown)
                        .cardStyle()
                        .padding(AppTheme.cardPadding)
                    } else {
                        HStack {
                            Text("Age")
                                .font(AppTheme.bodyFont)
                            Spacer()
                            TextField("months", text: $ageMonthsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("months")
                                .foregroundColor(.secondary)
                                .font(AppTheme.captionFont)
                        }
                        .padding(AppTheme.cardPadding)
                        .cardStyle()
                    }
                }

                // ── Size group ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("Size group")
                        .font(AppTheme.fieldLabelFont)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(SizeGroup.allCases) { sg in
                            SelectionRow(
                                title: sg.displayName,
                                isSelected: sizeGroup == sg
                            ) { sizeGroup = sg }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 20)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Step 2: Operational Profile + Head Type
    // ─────────────────────────────────────────────────────────────────────────

    private var step2ProfileType: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                stepHeader(
                    icon: "dog.fill",
                    title: "Choose Dog Type",
                    subtitle: "Choose the profile that best matches your dog. The app will automatically apply recommended temperature ranges, sensitivity levels, and health reminders. You can adjust any setting manually at any time."
                )

                // ── Profile cards ─────────────────────────────────────────────
                VStack(spacing: 10) {
                    ForEach(OperationalDogProfile.allCases) { op in
                        ProfileTypeCard(
                            profile: op,
                            isSelected: selectedProfile == op
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedProfile = op
                                // Auto-set head type for brachycephalic
                                if op == .brachycephalic {
                                    headType = .brachycephalic
                                }
                            }
                        }
                    }
                }

                // ── Head type (separate from brachycephalic profile —
                //    a medium dog can still be brachycephalic) ──────────────
                if selectedProfile != .brachycephalic {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Head shape")
                            .font(AppTheme.fieldLabelFont)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            ForEach(HeadType.allCases) { ht in
                                SelectionRow(
                                    title: ht.displayName,
                                    subtitle: ht.subtitle,
                                    isSelected: headType == ht
                                ) { headType = ht }
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 20)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Step 3: Coat & Special Conditions
    // ─────────────────────────────────────────────────────────────────────────

    private var step3CoatCondition: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                stepHeader(
                    icon: "thermometer.medium",
                    title: "Coat & Health",
                    subtitle: "Coat type affects temperature sensitivity. Any health condition shifts alert thresholds to a safer range."
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Coat type")
                        .font(AppTheme.fieldLabelFont)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(CoatType.allCases) { ct in
                            SelectionRow(
                                title: ct.displayName,
                                subtitle: ct.subtitle,
                                isSelected: coatType == ct
                            ) { coatType = ct }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Special condition")
                        .font(AppTheme.fieldLabelFont)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(SpecialCondition.allCases) { sc in
                            SelectionRow(
                                title: sc.displayName,
                                isSelected: specialCondition == sc
                            ) { specialCondition = sc }
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 20)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Step 4: Lifestyle & Region
    // ─────────────────────────────────────────────────────────────────────────

    private var step4LifestyleRegion: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                stepHeader(
                    icon: "map.fill",
                    title: "Lifestyle & Region",
                    subtitle: "This activates the right health reminders — kennel cough, leptospirosis, and park worm prevention are only shown when relevant."
                )

                // ── Lifestyle (multi-select) ───────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lifestyle (select all that apply)")
                        .font(AppTheme.fieldLabelFont)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(LifestyleFlag.allCases) { flag in
                            MultiSelectRow(
                                title: flag.displayName,
                                icon: flag.icon,
                                isSelected: lifestyleFlags.contains(flag)
                            ) {
                                withAnimation {
                                    if lifestyleFlags.contains(flag) {
                                        lifestyleFlags.remove(flag)
                                    } else {
                                        lifestyleFlags.insert(flag)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Region risk ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("Region (for leptospirosis reminders)")
                        .font(AppTheme.fieldLabelFont)
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(RegionRisk.allCases) { rr in
                            SelectionRow(
                                title: rr.displayName,
                                isSelected: regionRisk == rr
                            ) { regionRisk = rr }
                        }
                    }
                }

                // ── Safety disclaimer ──────────────────────────────────────────
                SafetyDisclaimerCard()

                Spacer(minLength: 40)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 20)
        }
    }

    // MARK: - Step header builder

    @ViewBuilder
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.accentBrown)
                Text(title)
                    .font(AppTheme.sectionTitleFont)
            }
            Text(subtitle)
                .font(AppTheme.captionFont)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ProfileTypeCard
// ─────────────────────────────────────────────────────────────────────────────

private struct ProfileTypeCard: View {
    let profile:    OperationalDogProfile
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text(profile.icon)
                    .font(.system(size: 28))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(.primary)
                    Text(profile.subtitle)
                        .font(AppTheme.captionFont)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.accentBrown : Color.primary.opacity(0.2))
                    .animation(.spring(response: 0.25), value: isSelected)
            }
            .padding(AppTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(isSelected ? AppTheme.accentBrown.opacity(0.08) : AppTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(
                                isSelected ? AppTheme.accentBrown : AppTheme.softBorder,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .shadow(color: AppTheme.softShadow, radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SelectionRow (single-select)
// ─────────────────────────────────────────────────────────────────────────────

private struct SelectionRow: View {
    let title:      String
    var subtitle:   String? = nil
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(.primary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(AppTheme.captionFont)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.accentBrown : Color.primary.opacity(0.2))
                    .animation(.spring(response: 0.2), value: isSelected)
            }
            .padding(AppTheme.innerTilePadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .fill(isSelected ? AppTheme.accentBrown.opacity(0.07) : AppTheme.warmTile)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                            .stroke(
                                isSelected ? AppTheme.accentBrown.opacity(0.5) : AppTheme.softBorder,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MultiSelectRow (checkbox style)
// ─────────────────────────────────────────────────────────────────────────────

private struct MultiSelectRow: View {
    let title:      String
    let icon:       String
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? AppTheme.accentBrown : .secondary)
                    .frame(width: 24)
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppTheme.accentBrown : Color.primary.opacity(0.2))
                    .animation(.spring(response: 0.2), value: isSelected)
            }
            .padding(AppTheme.innerTilePadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .fill(isSelected ? AppTheme.accentBrown.opacity(0.07) : AppTheme.warmTile)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                            .stroke(
                                isSelected ? AppTheme.accentBrown.opacity(0.5) : AppTheme.softBorder,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Safety Disclaimer Card
// ─────────────────────────────────────────────────────────────────────────────

struct SafetyDisclaimerCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.red.opacity(0.75))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text("Important Safety Note")
                    .font(AppTheme.fieldLabelFont)
                    .foregroundColor(.primary)

                Text(
                    "These are smart defaults based on your dog's profile — they do not replace veterinary care or judgment. " +
                    "If you notice significant heat stress, breathing difficulty, unusual lethargy, or severe behavioral change, " +
                    "contact a veterinarian immediately."
                )
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(Color.red.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .stroke(Color.red.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
