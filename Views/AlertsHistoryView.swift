import SwiftUI

struct AlertsHistoryView: View {
    @ObservedObject var alertManager: AlertManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: AlertType? = nil
    @State private var showClearConfirm = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppTheme.sectionSpacing) {
                    summaryCardsRow
                    insightsCard
                    barkChartCard
                    filterTabsRow
                    alertListSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 16)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Alerts History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !alertManager.records.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog("Clear all alerts?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) { alertManager.clearAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear { alertManager.markAllRead() }
        }
    }

    // MARK: - Summary Cards

    private var summaryCardsRow: some View {
        let analytics = alertManager.analytics

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.contentSpacing) {
                SummaryCard(
                    icon: "waveform",
                    iconColor: .purple,
                    value: "\(analytics.totalBarksToday)",
                    label: "Barks Today"
                )
                SummaryCard(
                    icon: "figure.walk",
                    iconColor: .blue,
                    value: "\(analytics.totalActiveMinutesEstimate)m",
                    label: "Active Est."
                )
                SummaryCard(
                    icon: "thermometer.medium",
                    iconColor: .orange,
                    value: tempRangeText(analytics),
                    label: "Temp Range"
                )
                SummaryCard(
                    icon: analytics.overallStatus.icon,
                    iconColor: analytics.overallStatus.color,
                    value: "\(analytics.todayCriticals + analytics.todayWarnings)",
                    label: "Alerts Today"
                )
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
        .padding(.horizontal, -AppTheme.horizontalPadding)
    }

    private func tempRangeText(_ analytics: SensorAnalytics) -> String {
        if let lo = analytics.minTempToday, let hi = analytics.maxTempToday {
            return String(format: "%.0f–%.0f°", lo, hi)
        }
        return "--"
    }

    // MARK: - Insights Card

    private var insightsCard: some View {
        let insights = alertManager.analytics.behaviorInsights
        return VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
            Text("Behavior Insights")
                .font(AppTheme.sectionTitleFont)

            ForEach(insights) { insight in
                HStack(spacing: 10) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(insight.color)
                        .frame(width: 22)
                    Text(insight.text)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Bark Chart

    private var barkChartCard: some View {
        let data = alertManager.analytics.last12HoursBarksByHour
        let maxCount = max(data.map { $0.count }.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
            Text("Barking — Last 12 Hours")
                .font(AppTheme.sectionTitleFont)

            GeometryReader { geo in
                let barWidth  = (geo.size.width - CGFloat(data.count - 1) * 4) / CGFloat(data.count)
                let chartHeight = geo.size.height - 22

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                        let fraction  = CGFloat(entry.count) / CGFloat(maxCount)
                        let barHeight = max(fraction * chartHeight, entry.count > 0 ? 4 : 2)
                        let isPeak    = entry.count == maxCount && entry.count > 0

                        VStack(spacing: 2) {
                            Spacer(minLength: 0)

                            if isPeak && entry.count > 0 {
                                Text("\(entry.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.orange)
                            }

                            Rectangle()
                                .fill(isPeak ? Color.orange : Color.purple.opacity(0.50))
                                .frame(width: barWidth, height: barHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                            Text(String(format: "%02d", entry.hour))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(width: barWidth)
                        }
                    }
                }
            }
            .frame(height: 120)
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Filter Tabs

    private var filterTabsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All",
                    icon: "list.bullet",
                    color: .gray,
                    isSelected: selectedFilter == nil
                ) {
                    withAnimation(.spring(duration: 0.25)) { selectedFilter = nil }
                }

                ForEach(AlertType.allCases, id: \.self) { type in
                    FilterChip(
                        label: type.displayName,
                        icon: type.icon,
                        color: type.tint,
                        isSelected: selectedFilter == type
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedFilter = (selectedFilter == type) ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
        .padding(.horizontal, -AppTheme.horizontalPadding)
    }

    // MARK: - Alert List

    private var filteredRecords: [AlertRecord] {
        guard let filter = selectedFilter else { return alertManager.records }
        return alertManager.records.filter { $0.type == filter }
    }

    private var groupedRecords: [(title: String, records: [AlertRecord])] {
        let sorted = filteredRecords.sorted { $0.timestamp > $1.timestamp }

        // Use an index dictionary for O(1) section lookup instead of O(n) firstIndex.
        var sections  = [(title: String, records: [AlertRecord])]()
        var keyToIdx  = [String: Int]()

        for record in sorted {
            let key = sectionKey(for: record.timestamp)
            if let idx = keyToIdx[key] {
                sections[idx].records.append(record)
            } else {
                keyToIdx[key] = sections.count
                sections.append((title: key, records: [record]))
            }
        }
        return sections
    }

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func sectionKey(for date: Date) -> String {
        if calendar.isDateInToday(date)     { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return Self.sectionDateFormatter.string(from: date)
    }

    @ViewBuilder
    private var alertListSection: some View {
        if filteredRecords.isEmpty {
            emptyState
        } else {
            ForEach(groupedRecords, id: \.title) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(AppTheme.captionFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(section.records) { record in
                            AlertRow(record: record)
                                // .swipeActions only works inside List — use contextMenu
                                // so delete is actually reachable in this LazyVStack layout.
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            alertManager.deleteRecord(withID: record.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

                            if section.records.last?.id != record.id {
                                Divider()
                                    .padding(.leading, 58)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .fill(AppTheme.cardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                    .stroke(AppTheme.softBorder, lineWidth: 1)
                            )
                            .shadow(color: AppTheme.softShadow, radius: 10, y: 4)
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("No alerts")
                .font(AppTheme.bodyTitleFont)
            Text(
                selectedFilter == nil
                    ? "Everything looks good — no alerts have been logged yet."
                    : "No \(selectedFilter!.displayName.lowercased()) alerts recorded."
            )
            .font(AppTheme.bodyFont)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Views

private struct SummaryCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.innerTilePadding)
        .frame(minWidth: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                .fill(AppTheme.warmTile)
        )
    }
}

private struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(AppTheme.captionFont)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : AppTheme.warmTile)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct AlertRow: View {
    let record: AlertRecord

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(record.type.tint.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: record.type.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(record.type.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(record.title)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Text(Self.timeFormatter.string(from: record.timestamp))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Text(record.detail)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Circle()
                        .fill(record.severity.badgeColor)
                        .frame(width: 5, height: 5)
                    Text(record.severity.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(record.severity.badgeColor)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 12)
        .background(record.isRead ? Color.clear : AppTheme.accentBrown.opacity(0.07))
    }
}
