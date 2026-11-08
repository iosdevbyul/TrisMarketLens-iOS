import SwiftUI
import WakTrainerDesignSystem

/// Compare only explicitly published, operator-pinned offline research.
struct HistoricalPortfolioComparisonView: View {
    let selectedIDs: [String]
    let source: any HistoricalPortfolioSource

    @State private var comparison: HistoricalPortfolioComparison?
    @State private var errorMessage: String?
    @State private var loading = true
    @State private var requestID = UUID()

    var body: some View {
        List {
            Section("Research-only comparison") {
                Text("Original historical outputs only. No ranking, trading recommendation, PIT/OOS qualification or live performance inference.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
                if loading {
                    ProgressView("Comparing published reports")
                } else if let errorMessage {
                    ContentUnavailableView("Comparison unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    Button("Retry") { Task { await reload() } }
                }
            }
            if let comparison {
                Section("Comparability and missing evidence") {
                    LabeledContent("Research periods differ", value: comparison.comparability.periodsDiffer ? "Yes" : "No")
                    LabeledContent("Valuation times differ", value: answer(comparison.comparability.valuationTimestampsDiffer))
                    LabeledContent("Observed mark fields differ", value: answer(comparison.comparability.observedMarkFieldsDiffer))
                    LabeledContent("Valuation policy", value: "Unavailable")
                    ForEach(comparison.comparability.notices, id: \.self) { notice in
                        Text(notice.replacingOccurrences(of: "_", with: " "))
                            .font(.footnote)
                    }
                    ForEach(comparison.comparability.unavailable.keys.sorted(), id: \.self) { key in
                        LabeledContent(key, value: comparison.comparability.unavailable[key] ?? "Unavailable")
                    }
                }
                ForEach(Array(comparison.items.enumerated()), id: \.element.id) { index, item in
                    Section("Report \(index + 1) · " + String(item.id.prefix(12)) + "…") {
                        LabeledContent("Model", value: item.summary.modelFamily.uppercased() + " · " + item.summary.modelId)
                        LabeledContent("Research period", value: item.summary.period["start", default: "?"] + " to " + item.summary.period["end", default: "?"])
                        LabeledContent("Tickers", value: item.summary.tickers.joined(separator: ", "))
                        LabeledContent("Evidence scope", value: item.summary.evidenceScope)
                        LabeledContent("Data origin", value: item.summary.dataOrigin)
                        LabeledContent("Initial virtual cash", value: item.summary.initialVirtualCash)
                        LabeledContent("Final virtual cash", value: item.summary.finalTotalCash)
                        LabeledContent("Realized P&L (source)", value: item.summary.realizedNetPnl)
                        LabeledContent("Final portfolio equity", value: item.summary.finalPortfolioEquity ?? "Unavailable")
                        LabeledContent("Portfolio return", value: item.summary.portfolioReturn ?? "Unavailable")
                        LabeledContent("Simulated fills", value: "\(item.summary.fillCount)")
                        LabeledContent("Valuation observed at", value: item.valuationBasis.timestamp ?? "Unavailable")
                        LabeledContent("Valuation source fields", value: item.valuationBasis.observedMarkFields?.joined(separator: ", ") ?? "Unavailable")
                        Text("Comparison order is the selected report order, not performance rank.")
                            .font(.footnote)
                            .foregroundStyle(WakColor.textSecondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Portfolio Comparison")
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func answer(_ value: Bool?) -> String {
        guard let value else { return "Unavailable" }
        return value ? "Yes" : "No"
    }

    @MainActor private func reload() async {
        let id = UUID()
        requestID = id
        loading = true
        comparison = nil
        errorMessage = nil
        do {
            let result = try await source.compare(reportIDs: selectedIDs)
            guard id == requestID, !Task.isCancelled else { return }
            comparison = result
        } catch {
            guard id == requestID else { return }
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        if id == requestID { loading = false }
    }
}
