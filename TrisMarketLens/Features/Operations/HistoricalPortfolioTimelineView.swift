import SwiftUI
import WakTrainerDesignSystem

struct HistoricalPortfolioTimelineView: View {
    let reportID: String
    let ticker: String?
    let source: any HistoricalPortfolioSource

    @State private var trades: [HistoricalPortfolioTrade] = []
    @State private var tickerPage: HistoricalPortfolioTickerPage?
    @State private var offset = 0
    @State private var total = 0
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var requestID = UUID()

    var body: some View {
        List {
            Section("Publication restrictions") {
                Text("Offline historical research only. Opportunity records, simulated fills and pending orders are not exchange execution evidence.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
                if let ticker { LabeledContent("Ticker", value: ticker) }
                LabeledContent("Report", value: String(reportID.prefix(16)) + "…")
            }
            Section(ticker == nil ? "Recorded opportunities" : "Security decision timeline") {
                if loading && offset == 0 {
                    ProgressView("Loading historical events")
                } else if let errorMessage {
                    ContentUnavailableView("Timeline unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    Button("Retry") { Task { await reload() } }
                } else {
                    if let page = tickerPage {
                        LabeledContent("Model ID", value: page.modelId)
                        LabeledContent("Realized P&L (source)", value: page.realizedNetPnl ?? "Unavailable")
                        if page.realizedNetPnl == nil {
                            Text("Unavailable reason: " + (page.unavailable["realizedNetPnl"] ?? "Not published"))
                                .font(.footnote)
                                .foregroundStyle(WakColor.textSecondary)
                        }
                    }
                    LabeledContent("Recorded rows", value: "\(offset) of \(total)")
                    if ticker == nil {
                        ForEach(trades) { trade in
                            evidenceRow(trade.evidence, category: trade.classification, terminalStatus: trade.terminalStatus)
                        }
                    } else if let tickerPage {
                        ForEach(tickerPage.timeline, id: \.opportunity_id) { evidence in
                            evidenceRow(evidence, category: nil, terminalStatus: nil)
                        }
                    }
                    if total == 0 {
                        Text("No published timeline entries. This does not indicate neutral signals.")
                            .foregroundStyle(WakColor.textSecondary)
                    }
                    if offset < total {
                        Button("Next page") { Task { await loadMore() } }
                            .disabled(loading)
                    }
                    if loading { ProgressView("Loading next page") }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle(ticker == nil ? "Archived trades" : "Ticker history")
        .refreshable { await reload() }
        .task(id: reportID + (ticker ?? "")) { await reload() }
    }

    private func evidenceRow(_ evidence: HistoricalTimelineEvidence, category: String?, terminalStatus: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(evidence.trading_date + " · " + evidence.ticker)
                    .font(.headline)
                Spacer()
                if let category { Text(category.capitalized).font(.caption) }
            }
            LabeledContent("Decision", value: evidence.action ?? "Unavailable")
            LabeledContent("Rule", value: evidence.selected_rule ?? "Unavailable")
            if let timestamp = evidence.decision_at {
                LabeledContent("Decision recorded", value: timestamp)
            }
            if let terminalStatus { LabeledContent("Terminal status", value: terminalStatus) }
            Text("Opportunity: " + evidence.opportunity_id)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            if let hash = evidence.source?.run_hash {
                Text("Run source: " + hash)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            if let scope = evidence.signal_evidence_scope {
                Text("Evidence scope: " + scope)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor private func reload() async {
        let id = UUID()
        requestID = id
        trades = []
        tickerPage = nil
        offset = 0
        total = 0
        loading = true
        errorMessage = nil
        await fetchPage(requestID: id)
    }

    @MainActor private func loadMore() async {
        guard !loading, offset < total else { return }
        let id = UUID()
        requestID = id
        loading = true
        errorMessage = nil
        await fetchPage(requestID: id)
    }

    @MainActor private func fetchPage(requestID id: UUID) async {
        do {
            if let ticker {
                let page = try await source.getTicker(reportID: reportID, ticker: ticker, offset: offset)
                guard self.requestID == id, !Task.isCancelled else { return }
                guard page.total >= offset, page.timeline.count > 0 || offset == page.total else {
                    throw ResearchAPIError.invalidPayload
                }
                let previous = tickerPage?.timeline ?? []
                guard Set(previous.map(\.opportunity_id)).isDisjoint(with: Set(page.timeline.map(\.opportunity_id))) else {
                    throw ResearchAPIError.invalidPayload
                }
                total = page.total
                offset += page.timeline.count
                // The next page must retain the current publication's model/financial identity.
                if let old = tickerPage {
                    guard old.modelId == page.modelId, old.realizedNetPnl == page.realizedNetPnl,
                          old.total == page.total else { throw ResearchAPIError.invalidPayload }
                }
                tickerPage = page
                if !previous.isEmpty {
                    // Preserve earlier pages while retaining the latest pagination metadata.
                    tickerPage = HistoricalPortfolioTickerPage(
                        schemaVersion: page.schemaVersion, researchOnly: page.researchOnly,
                        operationalEligible: page.operationalEligible, executable: page.executable,
                        pitVerified: page.pitVerified, oosVerified: page.oosVerified,
                        investmentSuitabilityVerified: page.investmentSuitabilityVerified,
                        brokerageEligible: page.brokerageEligible, reportId: page.reportId,
                        ticker: page.ticker, modelId: page.modelId,
                        realizedNetPnl: page.realizedNetPnl, unavailable: page.unavailable,
                        timeline: previous + page.timeline, total: page.total,
                        offset: page.offset, limit: page.limit
                    )
                }
            } else {
                let page = try await source.getTrades(reportID: reportID, ticker: nil, offset: offset)
                guard self.requestID == id, !Task.isCancelled else { return }
                guard page.items.count > 0 || offset == page.total,
                      page.total == total || offset == 0,
                      Set(trades.map(\.eventId)).isDisjoint(with: Set(page.items.map(\.eventId))) else {
                    throw ResearchAPIError.invalidPayload
                }
                trades.append(contentsOf: page.items)
                total = page.total
                offset += page.items.count
            }
        } catch {
            guard self.requestID == id else { return }
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        if self.requestID == id { loading = false }
    }
}
