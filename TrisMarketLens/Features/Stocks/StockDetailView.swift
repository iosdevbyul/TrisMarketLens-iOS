import SwiftUI
import WakTrainerDesignSystem

struct StockDetailView: View {
    let ticker: String
    let source: any StockSource
    var researchSource: any StockResearchSource = DisconnectedStockResearchSource()

    @State private var detail: StockDetail?
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        List {
            if loading {
                ProgressView("Loading stock detail")
            } else if failed {
                ContentUnavailableView("Stock unavailable", systemImage: "exclamationmark.triangle")
                Button("Retry") { Task { await reload() } }
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
                Section("Research evidence") {
                    StockResearchSections(ticker: ticker, source: researchSource)
                        .listRowBackground(WakColor.background)
                }
            } else {
                ContentUnavailableView("Stock not found", systemImage: "magnifyingglass")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle(detail?.displayName ?? ticker)
        .refreshable { await reload() }
        .task(id: ticker) { await reload() }
    }

    private func reload() async {
        guard !Task.isCancelled else { return }
        loading = true
        do {
            let response = try await source.getStock(ticker: ticker)
            guard !Task.isCancelled else { return }
            detail = response
            failed = false
        } catch {
            guard !Task.isCancelled else { return }
            detail = nil
            failed = true
        }
        loading = false
    }
}
