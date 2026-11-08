import SwiftUI
import WakTrainerDesignSystem

/// Opens the authoritative stock analysis record only when its identity matches
/// the screener publication. No substitution from a different run or data mode.
struct ResearchObservationView: View {
    let entry: ScreenerEntry
    let source: any StockResearchSource

    @State private var record: StockAnalysisRecord?
    @State private var requests = ResearchRequestGeneration()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var missingPublication = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading published analysis")
            } else if let record {
                StockAnalysisDetailView(record: record, evaluations: [], evaluationUnavailable: true)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Analysis unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") { Task { await reload() } }
                }
            } else if missingPublication {
                ContentUnavailableView {
                    Label("Analysis not corroborated", systemImage: "exclamationmark.shield")
                } description: {
                    Text("The stock analysis response did not contain exactly one matching published record. No other analysis is substituted.")
                } actions: {
                    Button("Retry") { Task { await reload() } }
                }
            }
        }
        .navigationTitle("Research observation")
        .task(id: entry.id) { await reload() }
    }

    @MainActor
    private func reload() async {
        let token = requests.begin()
        guard !Task.isCancelled else { isLoading = false; return }
        isLoading = true
        record = nil
        missingPublication = false
        errorMessage = nil
        do {
            let snapshot = try await source.getAnalysis(ticker: entry.ticker)
            guard requests.accepts(token, cancelled: Task.isCancelled) else { return }
            if let match = ResearchObservationMatch.resolve(entry, in: snapshot) {
                record = match
            } else {
                missingPublication = true
            }
        } catch {
            guard requests.accepts(token, cancelled: Task.isCancelled) else { return }
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        if requests.accepts(token, cancelled: Task.isCancelled) { isLoading = false }
    }
}
