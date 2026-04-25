import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ProfileSummaryView
//
// Shown after DogProfileSetupView completes.
// Displays what the app automatically applied and gives the user two actions:
//   • Done — dismisses and returns to the app
//   • Customize Settings — opens ProfileView where thresholds can be edited
// ─────────────────────────────────────────────────────────────────────────────

struct ProfileSummaryView: View {

    let config:     DogProfileEngine.DerivedConfiguration
    let onDismiss:  () -> Void

    @EnvironmentObject private var profileStore: ProfileStore
    @State private var showCustomize = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.sectionSpacing) {

                    // ── Header ────────────────────────────────────────────────
                    successHeader

                    // ── Profile tile ──────────────────────────────────────────
                    profileTile

                    // ── Temperature ───────────────────────────────────────────
                    summarySection(title: "Temperature", icon: "thermometer.medium") {
                        SummaryRow(
                            label:  "Safe range",
                            value:  "\(Int(config.sensorDefaults.tempWarnLow))°C – \(Int(config.sensorDefaults.tempWarnHigh))°C"
                        )
                        SummaryRow(
                            label:  "Critical",
                            value:  "below \(Int(config.sensorDefaults.tempCriticalLow))°C or above \(Int(config.sensorDefaults.tempCriticalHigh))°C",
                            valueColor: .orange
                        )
                    }

                    // ── Sound & Motion ────────────────────────────────────────
                    summarySection(title: "Sound & Motion", icon: "waveform") {
                        SummaryRow(
                            label: "Sound sensitivity",
                            value: config.sensorDefaults.soundSensitivityLevel.displayName
                        )
                        SummaryRow(
                            label: "Sound as sole trigger",
                            value: config.sensorDefaults.soundAsStandaloneTrigger ? "Yes" : "No (combined events only)"
                        )
                        SummaryRow(
                            label: "Motion sensitivity",
                            value: config.sensorDefaults.motionSensitivityLevel.displayName
                        )
                        SummaryRow(
                            label: "Inactivity alert after",
                            value: "\(config.sensorDefaults.lowActivityAlertAfterMinutes) min"
                        )
                    }

                    // ── Health reminders ──────────────────────────────────────
                    if !config.healthReminders.activeItems.isEmpty {
                        healthRemindersSection
                    }

                    // ── Manual override notice ────────────────────────────────
                    manualOverrideCard

                    // ── Action buttons ────────────────────────────────────────
                    actionButtons

                    Spacer(minLength: 32)
                }
                .padding(.top, 20)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Settings Applied")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.accentBrown)
                }
            }
            .sheet(isPresented: $showCustomize) {
                // Opens the existing ProfileView in customize mode
                ProfileCustomizeSheet()
                    .environmentObject(profileStore)
            }
        }
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentBrown.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.accentBrown)
            }

            Text("Your dog's settings are ready")
                .font(AppTheme.sectionTitleFont)
                .multilineTextAlignment(.center)

            Text("The app has automatically applied the settings below based on your dog's profile. Review them and tap Customize Settings if you want to adjust anything.")
                .font(AppTheme.captionFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
    }

    // MARK: - Profile Tile

    private var profileTile: some View {
        HStack(spacing: 14) {
            Text(config.operationalProfile.icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 3) {
                Text("Selected Profile")
                    .font(AppTheme.captionFont)
                    .foregroundColor(.secondary)
                Text(config.operationalProfile.displayName)
                    .font(AppTheme.bodyFont)
                HStack(spacing: 12) {
                    riskPill("Heat", level: config.operationalProfile.heatRisk)
                    riskPill("Cold", level: config.operationalProfile.coldRisk)
                }
            }
            Spacer()
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
        .padding(.horizontal, AppTheme.horizontalPadding)
    }

    private func riskPill(_ label: String, level: RiskLevel) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(riskColor(level))
                .frame(width: 6, height: 6)
            Text("\(label): \(level.displayName)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(riskColor(level))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(riskColor(level).opacity(0.1))
        .clipShape(Capsule())
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .normal:   return .green
        case .elevated: return .orange
        case .high:     return .red
        }
    }

    // MARK: - Summary Section Builder

    @ViewBuilder
    private func summarySection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accentBrown)
                Text(title)
                    .font(AppTheme.fieldLabelFont)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)

            VStack(spacing: 0) {
                content()
            }
            .cardStyle()
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
    }

    // MARK: - Health Reminders Section

    private var healthRemindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accentBrown)
                Text("Active Health Reminders")
                    .font(AppTheme.fieldLabelFont)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)

            VStack(spacing: 0) {
                ForEach(config.healthReminders.activeItems) { item in
                    ReminderSummaryRow(item: item)
                    if item.id != config.healthReminders.activeItems.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal, AppTheme.horizontalPadding)

            // Next key dates
            if let rabies = config.healthReminders.nextRabiesDate {
                KeyDateRow(
                    label: "Next rabies vaccination",
                    date:  rabies,
                    icon:  "syringe"
                )
                .padding(.horizontal, AppTheme.horizontalPadding)
            }

            if let vet = config.healthReminders.nextVetCheckDate {
                KeyDateRow(
                    label: "Next routine check-up",
                    date:  vet,
                    icon:  "stethoscope"
                )
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
        }
    }

    // MARK: - Manual Override Card

    private var manualOverrideCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.accentBrown)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text("When to adjust settings manually")
                    .font(AppTheme.fieldLabelFont)

                let reasons = [
                    "Your veterinarian gave different instructions",
                    "Your dog is sick, recovering, or post-surgery",
                    "Your dog is new to the system (no baseline yet)",
                    "Your dog is mixed-breed and doesn't fit one profile exactly"
                ]

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(AppTheme.accentBrown)
                            Text(reason)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
        .padding(.horizontal, AppTheme.horizontalPadding)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showCustomize = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Customize Settings")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.accentBrown)
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.floatingButtonHeight)
                .background(AppTheme.accentBrown.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous)
                        .stroke(AppTheme.accentBrown.opacity(0.3), lineWidth: 1)
                )
            }

            Button(action: onDismiss) {
                Text("Done — Start Monitoring")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppTheme.floatingButtonHeight)
                    .background(AppTheme.accentBrown)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
            }
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SummaryRow
// ─────────────────────────────────────────────────────────────────────────────

private struct SummaryRow: View {
    let label:      String
    let value:      String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(AppTheme.captionFont)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 10)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ReminderSummaryRow
// ─────────────────────────────────────────────────────────────────────────────

private struct ReminderSummaryRow: View {
    let item: HealthReminderItem

    private var urgency: DogProfileEngine.ReminderUrgency {
        DogProfileEngine.urgency(for: item)
    }

    private var urgencyColor: Color {
        switch urgency {
        case .overdue:     return .red
        case .withinWeek:  return .orange
        case .withinMonth: return .yellow
        default:           return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.accentBrown)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(AppTheme.captionFont)
                        .fontWeight(.semibold)
                    if item.isMandatory {
                        Text("REQUIRED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.75))
                            .clipShape(Capsule())
                    }
                }
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let due = item.dueDate {
                Text(due, style: .date)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(urgencyColor)
            }
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 11)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - KeyDateRow
// ─────────────────────────────────────────────────────────────────────────────

private struct KeyDateRow: View {
    let label: String
    let date:  Date
    let icon:  String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.accentBrown)
                .frame(width: 24)
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(.secondary)
            Spacer()
            Text(date, style: .date)
                .font(AppTheme.captionFont)
                .fontWeight(.semibold)
        }
        .padding(AppTheme.innerTilePadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                .fill(AppTheme.warmTile)
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ProfileCustomizeSheet
// A lightweight wrapper that opens ProfileView's editing section directly.
// ─────────────────────────────────────────────────────────────────────────────

private struct ProfileCustomizeSheet: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ProfileView()
                .environmentObject(profileStore)
                .navigationTitle("Customize Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.accentBrown)
                    }
                }
        }
    }
}
