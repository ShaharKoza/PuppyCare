import SwiftUI
import Charts

// MARK: - Chart type descriptor

enum ChartDataType: String, Identifiable, CaseIterable {
    case temperature = "Temperature"
    case humidity    = "Humidity"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .temperature: return "°C"
        case .humidity:    return "%"
        }
    }

    var color: Color {
        switch self {
        case .temperature: return Color.red.opacity(0.80)
        case .humidity:    return Color.blue
        }
    }

    var icon: String {
        switch self {
        case .temperature: return "thermometer.medium"
        case .humidity:    return "drop.fill"
        }
    }

    func value(from reading: SensorReading) -> Double? {
        switch self {
        case .temperature: return reading.temperature
        case .humidity:    return reading.humidity
        }
    }
}

// MARK: - View

struct SensorChartView: View {
    let dataType: ChartDataType
    @ObservedObject var historyStore: SensorHistoryStore
    @Environment(\.dismiss) private var dismiss

    private var chartPoints: [(date: Date, value: Double)] {
        historyStore.last24HoursReadings.compactMap { reading in
            guard let v = dataType.value(from: reading) else { return nil }
            return (reading.timestamp, v)
        }
    }

    private var current: Double? { chartPoints.last?.value }
    private var minVal:  Double? { chartPoints.map(\.value).min() }
    private var maxVal:  Double? { chartPoints.map(\.value).max() }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    statsRow
                    chartCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 16)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(dataType.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                }
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(label: "Current", value: current.map { fmt($0) } ?? "--")
            statCard(label: "Min 24h",  value: minVal.map  { fmt($0) } ?? "--")
            statCard(label: "Max 24h",  value: maxVal.map  { fmt($0) } ?? "--")
        }
        .padding(.top, AppTheme.screenTopSpacing)
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTheme.tileLabelFont)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(dataType.color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.innerTilePadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                .fill(AppTheme.warmTile)
        )
    }

    // MARK: - Chart card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
            HStack(spacing: 8) {
                Image(systemName: dataType.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(dataType.color)
                Text("Last 24 Hours")
                    .font(AppTheme.sectionTitleFont)
            }

            if chartPoints.isEmpty {
                emptyState
            } else if chartPoints.count == 1 {
                singlePointState
            } else {
                chart
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    private var chart: some View {
        Chart {
            ForEach(chartPoints, id: \.date) { point in
                LineMark(
                    x: .value("Time",          point.date),
                    y: .value(dataType.rawValue, point.value)
                )
                .foregroundStyle(dataType.color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time",          point.date),
                    y: .value(dataType.rawValue, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [dataType.color.opacity(0.18), dataType.color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(fmt(v)).font(.system(size: 11))
                    }
                }
            }
        }
        .frame(height: 220)
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: dataType.icon)
                .font(.system(size: 40))
                .foregroundStyle(dataType.color.opacity(0.35))
            Text("No data yet")
                .font(AppTheme.bodyTitleFont)
            Text("Readings appear here as the kennel sensor\nreports in. History builds while the app is open.")
                .font(AppTheme.captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var singlePointState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 36))
                .foregroundStyle(dataType.color.opacity(0.45))
            Text("Building the chart…")
                .font(AppTheme.bodyTitleFont)
            Text("Got the first reading. One more sample and the\n24-hour trend will start rendering.")
                .font(AppTheme.captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Format helper

    private func fmt(_ v: Double) -> String {
        String(format: "%.1f\(dataType.unit)", v)
    }
}
