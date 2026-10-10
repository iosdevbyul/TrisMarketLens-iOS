import SwiftUI
import WakTrainerDesignSystem

struct StockDetailView: View {
    let ticker: String
    let source: any StockSource

    @State private var detail: StockDetail?
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        List {
            if loading {
                ProgressView("Loading stock detail")
            } else if failed {
                ContentUnavailableView("Stock unavailable", systemImage: "exclamationmark.triangle")
            } else if let detail {
                Section("Stock research") {
                    LabeledContent("Ticker", value: detail.ticker)
                    LabeledContent("Market", value: detail.market)
                    LabeledContent("Sector", value: detail.sectorLabel)
                    LabeledContent("Data mode", value: detail.dataStatus == "mock" ? "Mock only" : "API")
                }
                Section("Historical coverage") {
                    LabeledContent("Available from", value: detail.availableFrom)
                    LabeledContent("Latest coverage", value: detail.latestDataDate)
                }
                Section("Quality and lifecycle") {
                    Text(detail.evidenceNote)
                    Text("No inferred quality state.")
                        .foregroundStyle(.secondary)
                }
                Section("AI analysis and prediction evaluation") {
                    Text("No verified analysis or evaluation loaded.")
                        .foregroundStyle(.secondary)
                }
                Section("Price and volume") {
                    Text(detail.chartNote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView("Stock not found", systemImage: "magnifyingglass")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle(detail?.displayName ?? ticker)
        .task(id: ticker) {
            loading = true
            do {
                detail = try await source.getStock(ticker: ticker)
                failed = false
            } catch {
                detail = nil
                failed = true
            }
            loading = false
        }
    }
}
