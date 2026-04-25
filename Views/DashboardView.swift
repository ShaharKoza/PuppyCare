import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var loc: Localization
    @ObservedObject private var firebase = FirebaseService.shared
    @ObservedObject private var alertManager = AlertManager.shared
    @ObservedObject private var historyStore = SensorHistoryStore.shared
    @Binding var selectedTab: Int

    @State private var showConnectivityBanner = false
    @State private var showAlertsHistory = false
    @State private var activeChart: ChartDataType?

    private var dogName: String {
        let name = profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "My Dog" : name.capitalized
    }

    private var subtitleText: String {
        let breed = profileStore.profile.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let sex = profileStore.profile.sex.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !breed.isEmpty { parts.append(breed) }
        if !sex.isEmpty { parts.append(sex) }
        if firebase.sensorData.puppyMode { parts.append("Puppy Mode") }

        return parts.isEmpty ? "PuppyCare" : parts.joined(separator: " • ")
    }

    private var formattedTime: String {
        let iso = firebase.sensorData.timestamp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !iso.isEmpty else { return "--:--" }
        return String(iso.suffix(8).prefix(5))
    }

    /// Effective alert level for the dashboard headline.
    /// Forces "critical" when sound + motion are both currently active, so the
    /// pill goes red the moment the user's sensors light up — even if the Pi
    /// hasn't yet escalated kennel/alert.level on its end.
    private var normalizedLevel: String {
        if isLiveCombinedActivity { return "critical" }
        return firebase.sensorData.normalizedAlertLevel
    }

    private var statusTitle: String {
        switch normalizedLevel {
        case "critical": return loc.t("Immediate attention needed")
        case "warning":  return loc.t("Environment needs attention")
        default:         return loc.t("Environment looks stable")
        }
    }

    private var levelPillText: String {
        switch normalizedLevel {
        case "critical": return loc.t("Critical")
        case "warning":  return loc.t("Warning")
        default:         return loc.t("Normal")
        }
    }

    private var sleepPillText: String {
        firebase.sensorData.sleeping ? loc.t("Sleeping") : loc.t("Awake")
    }

    private var levelAccent: Color {
        switch normalizedLevel {
        case "critical": return AppTheme.alertCritical
        case "warning":  return AppTheme.alertWarning
        default:         return AppTheme.alertNormal
        }
    }

    private var levelTextColor: Color { levelAccent }

    private var levelIcon: String {
        switch normalizedLevel {
        case "critical": return "cross.case.fill"
        case "warning":  return "exclamationmark.circle.fill"
        default:         return "checkmark.circle.fill"
        }
    }

    private var presenceText: String {
        profileStore.profile.isInKennel ? loc.t("Dog is in the kennel") : loc.t("Dog is outside the kennel")
    }

    private var presenceTint: Color {
        profileStore.profile.isInKennel ? .green : .orange
    }

    private var presenceIcon: String {
        profileStore.profile.isInKennel ? "house.fill" : "figure.walk"
    }

    private var temperatureText: String {
        guard let value = firebase.sensorData.temperature else { return "--" }
        return String(format: "%.1f°C", value)
    }

    private var isTempStale: Bool { firebase.isTempStale }

    private var tempStaleSubtitle: String? {
        guard isTempStale else { return nil }

        if firebase.sensorData.temperature != nil,
           let mins = firebase.tempLastSeenMinutesAgo {
            return mins <= 1 ? "Reading may be delayed" : "Last updated \(mins) min ago"
        }

        return "Sensor not responding"
    }

    private var humidityText: String {
        guard let value = firebase.sensorData.humidity else { return "--" }
        return String(format: "%.1f%%", value)
    }

    private var motionText: String { firebase.sensorData.motionDetected ? loc.t("Detected") : loc.t("Still") }
    private var soundText: String { firebase.sensorData.soundActive ? loc.t("Active") : loc.t("Quiet") }
    private var barkCountText: String { "\(firebase.sensorData.barkCount5s)" }

    /// True iff the Pi's current alert level is "normal" (or absent).
    /// Anything else means the Pi has flagged a live concern — only then do we
    /// surface its `reasons` array. Without this gate, stale reasons left over
    /// from a past warning continue to show up after the situation has cleared.
    private var isAlertLevelNormal: Bool {
        let level = firebase.sensorData.alertLevel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return level.isEmpty || level == "normal"
    }

    /// True when motion AND sound are BOTH currently active right now, derived
    /// directly from the live tile state. The dashboard surfaces this as an
    /// immediate Critical banner so the user sees the combined event the moment
    /// both signals appear — without waiting for the Pi alert pipeline or the
    /// AlertManager combined-window to fire.
    private var isLiveCombinedActivity: Bool {
        let s = firebase.sensorData
        let soundOn  = s.soundActive || s.barkDetected || s.sustainedSound
        let motionOn = s.motionDetected
        return soundOn && motionOn
    }

    /// Reasons to display in the headline. Empty array means "all quiet" —
    /// the view renders a clear "no active alerts" state instead of repeating
    /// "Everything looks good" as a fake alert row.
    private var cleanedAlertReasons: [String] {
        guard !isAlertLevelNormal else { return [] }

        let raw = firebase.sensorData.alertReasons.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.lowercased() != "all clear"
        }
        return raw.map(translatePiReason(_:)).filter { !$0.isEmpty }
    }

    private func translatePiReason(_ reason: String) -> String {
        let lower = reason.lowercased()

        if lower.contains("dht") && (
            lower.contains("stale") ||
            lower.contains("fail") ||
            lower.contains("error") ||
            lower.contains("invalid") ||
            lower.contains("no valid")
        ) {
            return "Temperature sensor temporarily unavailable — check kennel sensor wiring"
        }

        if lower.contains("gpio") ||
            lower.contains("runtime error") ||
            lower.contains("runtimeerror") ||
            lower.contains("checksum") ||
            lower.contains("traceback") {
            return ""
        }

        return cleanReason(reason)
    }

    private var dismissedVaccineSet: Set<String> {
        Set(profileStore.profile.dismissedVaccineReminders)
    }

    /// Active (non-dismissed) structured health reminders derived from the profile.
    /// Drives both the Dashboard card and the scheduled notifications in ReminderManager
    /// — dismissing one here cancels the matching pending notification automatically.
    private var activeHealthItems: [HealthReminderItem] {
        profileStore.profile.derivedHealthReminders?.activeItems ?? []
    }

    /// Legacy string-based advisories — shown only when structured data is missing
    /// (profiles created before the DogProfileEngine refactor).
    private var legacyVaccineReminders: [String] {
        profileStore.profile.israelVaccineReminders.filter { !dismissedVaccineSet.contains($0) }
    }

    private var hasStructuredReminders: Bool {
        profileStore.profile.derivedHealthReminders != nil
    }

    /// True when there is at least one pending reminder the user hasn't dismissed,
    /// OR when age is missing (so the user sees the "set age" nudge).
    /// False once every real reminder has been checked off — the whole card hides.
    private var shouldShowVaccineCard: Bool {
        guard profileStore.profile.ageMonthsValue != nil else { return true }
        if hasStructuredReminders { return !activeHealthItems.isEmpty }
        return !legacyVaccineReminders.isEmpty
    }

    private var mealCount: Int { profileStore.profile.mealItems.count }
    private var walkCount: Int { profileStore.profile.walkItems.count }

    private var totalDailyGramsText: String {
        let grams = profileStore.profile.totalDailyGrams
        return grams > 0 ? "\(grams) g" : "Not set"
    }

    private var foodNameText: String {
        let food = profileStore.profile.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        return food.isEmpty ? "Not set" : food
    }

    private var nextScheduledItem: ScheduleItem? {
        let calendar = Calendar.current
        let now = Date()
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let sorted = profileStore.profile.scheduleItems.sorted { $0.time < $1.time }

        return sorted.first {
            let parts = $0.time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return false }
            return parts[0] * 60 + parts[1] >= nowMinutes
        } ?? sorted.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                headerSection

                if showConnectivityBanner && !firebase.isConnected {
                    offlineBanner
                }

                statusHeroCard
                cameraSection
                alertsCard
                sensorsSection
                presenceCard
                feedingSummaryCard
                if shouldShowVaccineCard {
                    vaccineCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            firebase.startListening()
            Task {
                try? await Task.sleep(for: .seconds(3))
                showConnectivityBanner = true
            }
        }
        .onDisappear {
            showConnectivityBanner = false
        }
        .sheet(item: $activeChart) { chartType in
            SensorChartView(dataType: chartType, historyStore: historyStore)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentBrown.opacity(0.12))
                    .frame(width: 62, height: 62)

                if !profileStore.profile.profileImageFilename.isEmpty,
                   let image = ImageStorageManager.shared.loadImage(
                    filename: profileStore.profile.profileImageFilename
                   ) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 62, height: 62)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accentBrown)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(dogName)
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitleText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.top, 2)
    }

    private var statusHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(formattedTime)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.accentBrown)

                Spacer()

                HStack(spacing: 8) {
                    pill(
                        text: sleepPillText,
                        textColor: AppTheme.accentBrown,
                        fill: AppTheme.accentBrown.opacity(0.10)
                    )

                    pill(
                        text: levelPillText,
                        textColor: levelTextColor,
                        fill: levelAccent.opacity(0.12)
                    )
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(levelAccent.opacity(0.15))
                        .frame(width: 54, height: 54)

                    Image(systemName: levelIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(levelAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current environment")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.accentBrown.opacity(0.85))

                    Text(statusTitle)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .cardStyle()
    }

    @ViewBuilder
    private var cameraSection: some View {
        CameraCardView(
            imageURL: firebase.cameraImageURL,
            updatedAt: firebase.cameraImageUpdatedAt
        )
    }

    private var sensorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Sensors")
                .font(AppTheme.sectionTitleFont)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                sensorTile(
                    title: loc.t("Temperature"),
                    value: temperatureText,
                    symbol: isTempStale ? "thermometer.trianglebadge.exclamationmark" : "thermometer.medium",
                    tint: isTempStale ? .orange : .red.opacity(0.75),
                    subtitle: tempStaleSubtitle,
                    chartType: .temperature
                )

                sensorTile(
                    title: loc.t("Humidity"),
                    value: humidityText,
                    symbol: "drop.fill",
                    tint: .blue,
                    chartType: .humidity
                )

                sensorTile(
                    title: loc.t("Motion"),
                    value: motionText,
                    symbol: "figure.walk",
                    tint: .green
                )

                sensorTile(
                    title: loc.t("Sound"),
                    value: soundText,
                    symbol: firebase.sensorData.soundActive ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    tint: firebase.sensorData.soundActive ? .blue : .gray
                )

                sensorTile(
                    title: loc.t("Bark Count"),
                    value: barkCountText,
                    symbol: "waveform",
                    tint: .pink
                )

                sensorTile(
                    title: loc.t("Light"),
                    value: firebase.sensorData.lightDetected ? loc.t("Light") : loc.t("Dark"),
                    symbol: firebase.sensorData.lightDetected ? "lightbulb.fill" : "moon.fill",
                    tint: firebase.sensorData.lightDetected ? .yellow : .indigo
                )
            }
        }
    }

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(loc.t("Alerts & Insights"))
                    .font(AppTheme.sectionTitleFont)

                Spacer()

                Button {
                    showAlertsHistory = true
                } label: {
                    HStack(spacing: 5) {
                        Text(loc.t("History"))
                            .font(.system(size: 14, weight: .semibold))

                        if alertManager.unreadCount > 0 {
                            Text("\(alertManager.unreadCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(AppTheme.accentBrown)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if isLiveCombinedActivity {
                    // Highest priority: motion AND sound right now → immediate Critical banner.
                    // This shows the moment both signals appear on the dashboard, regardless
                    // of whether the Pi alert pipeline or AlertManager combined-window
                    // has had time to fire yet.
                    Button {
                        showAlertsHistory = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.14))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.red)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc.t("Activity + noise in kennel"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(loc.t("Critical · happening now"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.red)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else if !cleanedAlertReasons.isEmpty {
                    // Live Pi-side reasons take precedence.
                    ForEach(cleanedAlertReasons.prefix(2), id: \.self) { reason in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(levelAccent)
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)

                            Text(reason)
                                .font(.system(size: 15, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else if let recent = mostRecentActiveAlert() {
                    // No live Pi reasons, but AlertManager fired something
                    // recently (e.g. motion = Warning). Surface it here so the
                    // dashboard matches History instead of saying "all quiet".
                    Button {
                        showAlertsHistory = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(recent.severity.badgeColor.opacity(0.14))
                                    .frame(width: 32, height: 32)

                                Image(systemName: recent.type.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(recent.severity.badgeColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(recent.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text("\(recent.severity.label) · \(relativeTime(recent.timestamp))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(recent.severity.badgeColor)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    // Truly all quiet — no Pi reasons, no recent records.
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)

                        Text(loc.t("No active alerts"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)
                    }

                    Text(loc.t("All sensors are within normal range."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .cardStyle()
        .sheet(isPresented: $showAlertsHistory) {
            AlertsHistoryView(alertManager: alertManager)
        }
    }

    private var presenceCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(presenceTint.opacity(0.14))
                    .frame(width: 50, height: 50)

                Image(systemName: presenceIcon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(presenceTint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Presence status")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(presenceText)
                    .font(.system(size: 17, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                if profileStore.profile.isInKennel,
                   let sessionStart = profileStore.profile.kennelSessionStart {
                    TimelineView(.periodic(from: sessionStart, by: 1)) { context in
                        Text("In kennel: \(formatDuration(from: sessionStart, to: context.date))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .id(sessionStart)
                }
            }

            Spacer()

            Toggle("", isOn: $profileStore.profile.isInKennel)
                .labelsHidden()
                .tint(AppTheme.accentBrown)
                .scaleEffect(0.9)
        }
        .padding(14)
        .cardStyle()
    }

    private var feedingSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Routine")
                    .font(AppTheme.sectionTitleFont)

                Spacer()

                Button {
                    selectedTab = 1
                } label: {
                    Text("Open")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentBrown.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                summaryTile(title: "Meals", value: "\(mealCount)")
                summaryTile(title: "Walks", value: "\(walkCount)")
                summaryTile(title: "Total grams", value: totalDailyGramsText)
                summaryTile(title: "Food", value: foodNameText)
            }

            if let next = nextScheduledItem {
                Divider().overlay(AppTheme.softBorder)

                HStack(spacing: 8) {
                    Image(systemName: next.type.systemIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(next.type.tint)

                    Text(next.time)
                        .font(.system(size: 13, weight: .bold))

                    Text(next.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text("Next up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var vaccineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Vaccine reminders")
                    .font(AppTheme.sectionTitleFont)

                Spacer()

                pill(
                    text: vaccinePillText,
                    textColor: AppTheme.accentBrown,
                    fill: AppTheme.accentBrown.opacity(0.10)
                )
            }

            if hasStructuredReminders {
                structuredVaccineList
            } else {
                legacyVaccineList
            }

            Text("Reminder only — confirm the exact schedule with your veterinarian.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .cardStyle()
    }

    // ── Structured path (dog profile engine wired through ReminderManager) ────

    @ViewBuilder
    private var structuredVaccineList: some View {
        if let item = activeHealthItems.first {
            Button {
                markHealthItemDismissed(key: item.key)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        if let due = dueText(for: item) {
                            Text(due)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(dueColor(for: item))
                        }
                        Text(item.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // ── Legacy path (older profiles without derived health reminders) ─────────

    @ViewBuilder
    private var legacyVaccineList: some View {
        if let item = legacyVaccineReminders.first {
            Button {
                markReminderDismissed(item)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                        .padding(.top, 2)

                    Text(item)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBrown)
                    .padding(.top, 2)
                Text("All current reminders were marked as done.")
                    .font(.system(size: 15, weight: .medium))
            }
        }
    }

    // ── Due-date presentation helpers ─────────────────────────────────────────

    private var vaccinePillText: String {
        if hasStructuredReminders {
            return activeHealthItems.isEmpty ? "Done" : "Check due"
        }
        return legacyVaccineReminders.isEmpty ? "Done" : "Check due"
    }

    private func dueText(for item: HealthReminderItem) -> String? {
        guard let due = item.dueDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: due)).day ?? 0
        if days < 0  { return "Overdue by \(-days) day\(days == -1 ? "" : "s")" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 30 { return "Due in \(days) days" }
        return "Due " + Self.dueDateFormatter.string(from: due)
    }

    private func dueColor(for item: HealthReminderItem) -> Color {
        guard let due = item.dueDate else { return .secondary }
        // Match dueText: compare at day granularity so the pill color and the
        // "Overdue by N days" text always agree.
        let cal = Calendar.current
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: Date()),
                                      to:   cal.startOfDay(for: due)).day ?? 0
        if days < 0   { return .red }
        if days <= 7  { return .orange }
        return AppTheme.accentBrown
    }

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func sensorTile(
        title: String,
        value: String,
        symbol: String,
        tint: Color,
        subtitle: String? = nil,
        chartType: ChartDataType? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Spacer(minLength: 0)

                if chartType != nil {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(subtitle != nil ? tint : .primary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 3)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                .fill(AppTheme.warmTile)
        )
        .onTapGesture {
            if let chartType {
                activeChart = chartType
            }
        }
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                .fill(AppTheme.warmTile)
        )
    }

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.orange)
                .frame(width: 7, height: 7)

            Text("Sensor data unavailable — no internet connection")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func pill(text: String, textColor: Color, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(fill)
            .clipShape(Capsule())
    }

    private func relativeTime(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86400 { return "\(s / 3600)h ago" }
        return "\(s / 86400)d ago"
    }

    /// Most recent Warning- or Critical-level alert from the last hour, or nil.
    /// Info-level events are excluded so the headline reflects something the user
    /// actually needs to glance at. Records are stored newest-first, so
    /// .first(where:) is O(k) — k is typically tiny.
    private func mostRecentActiveAlert() -> AlertRecord? {
        let cutoff = Date().addingTimeInterval(-3600)   // 1 hour
        return alertManager.records.first {
            $0.severity != .info && $0.timestamp >= cutoff
        }
    }

    private func cleanReason(_ reason: String) -> String {
        let text = reason
            .replacingOccurrences(of: "[warning] ",  with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[critical] ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[normal] ",   with: "", options: .caseInsensitive)

        guard let first = text.first else { return reason }
        return first.uppercased() + text.dropFirst()
    }

    private func markReminderDismissed(_ reminder: String) {
        var current = Set(profileStore.profile.dismissedVaccineReminders)
        current.insert(reminder)
        profileStore.profile.dismissedVaccineReminders = Array(current)
    }

    /// Marks a structured `HealthReminderItem` as dismissed by its stable key.
    /// The ProfileStore auto-save pipeline picks up the mutation and calls
    /// `ReminderManager.scheduleAllReminders(...)`, which cancels the matching
    /// pending notification automatically (dismissed items are filtered out of
    /// `activeItems` — the only list that gets scheduled).
    private func markHealthItemDismissed(key: String) {
        guard var reminders = profileStore.profile.derivedHealthReminders,
              let idx = reminders.items.firstIndex(where: { $0.key == key })
        else { return }
        reminders.items[idx].dismissed = true
        profileStore.profile.derivedHealthReminders = reminders
    }

    private func formatDuration(from start: Date, to now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(start)))
        let h = s / 3600
        let m = (s % 3600) / 60

        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
