import SwiftUI
import WakTrainerDesignSystem

struct StockDetailView: View {
    let ticker: String
    let source: any StockSource
    var researchSource: any StockResearchSource = DisconnectedStockResearchSource()

    @State private var detail: StockDetail?
    @State private var activeRequestID = UUID()
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if loading {
                ProgressView("Loading stock detail")
            } else if let errorMessage {
                ContentUnavailableView("Stock unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
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
        let requestID = UUID()
        activeRequestID = requestID
        guard activeRequestID == requestID, !Task.isCancelled else { return }
        loading = true
        do {
            let response = try await source.getStock(ticker: ticker)
            guard activeRequestID == requestID else { return }
            if Task.isCancelled {
                loading = false
                return
            }
            detail = response
            errorMessage = nil
        } catch {
            guard activeRequestID == requestID else { return }
            if Task.isCancelled {
                loading = false
                return
            }
            detail = nil
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        loading = false
    }
}
