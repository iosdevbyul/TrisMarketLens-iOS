import SwiftUI
import Charts

/// Read-only market sessions; never treats historical coverage as a live quote.
struct StockOHLCVChartView: View {
    let series: OhlcvSeries
    @State private var period: StockChartPeriod = .month

    private var bars: [OhlcvBar] { period.filter(series.bars) }
    private var summary: StockChartSummary? { StockChartSummary(bars: bars) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("History", selection: $period) {
                ForEach(StockChartPeriod.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            if bars.isEmpty {
                ContentUnavailableView("No market observations", systemImage: "chart.xyaxis.line")
            } else {
                if let summary {
                    HStack {
                        Text("Last close")
                        Spacer()
                        Text(summary.lastClose, format: .number)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                Chart(bars) { bar in
                    LineMark(x: .value("Session", bar.date), y: .value("Close", bar.close))
                        .interpolationMethod(.linear)
                }
                .chartXScale(domain: bars.map(\.date))
                .chartXAxis {
                    AxisMarks(values: StockChartAxisLabels.dates(for: bars.map(\.date))) {
                        AxisValueLabel()
                    }
                }
                .frame(height: 220)
                Text("Volume")
                    .font(.subheadline.weight(.semibold))
                Chart(bars) { bar in
                    BarMark(x: .value("Session", bar.date), y: .value("Volume", bar.volume))
                }
                .chartXScale(domain: bars.map(\.date))
                .chartXAxis {
                    AxisMarks(values: StockChartAxisLabels.dates(for: bars.map(\.date))) {
                        AxisValueLabel()
                    }
                }
                .frame(height: 100)
                Text("Original KRX sessions · unadjusted · not a live quote")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
