import SwiftUI
import WakTrainerDesignSystem

struct HistoricalPortfoliosView: View {
    let source: any HistoricalPortfolioSource
    let isHTTP: Bool

    @State private var reports: [HistoricalPortfolioItem] = []
    @State private var offset = 0
    @State private var total = 0
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var requestID = UUID()

    var body: some View {
        List {
            Section {
                Label(
                    "Operator-pinned, loopback-only historical research. Not brokerage trading, PIT/OOS verification, or investment advice.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(WakColor.textSecondary)
                if !isHTTP {
                    Text("HTTP research source is not configured. No demo portfolios are substituted.")
                }
            }
            Section("Published historical reports") {
                if loading {
                    ProgressView("Loading historical publications")
                } else if let errorMessage {
                    ContentUnavailableView("Archive unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    Button("Retry") { Task { await reload() } }
                } else if reports.isEmpty {
                    ContentUnavailableView("No published reports", systemImage: "doc.text.magnifyingglass", description: Text("The approved archive returned no reports."))
                } else {
                    Text("Showing \(reports.count) of \(total) authorized reports")
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                    ForEach(reports) { report in
                        NavigationLink {
                            HistoricalPortfolioDetailView(report: report, source: source)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(report.modelFamily.uppercased() + " · " + report.tickers.joined(separator: ", "))
                                    .font(.headline)
                                Text(report.period["start", default: "?"] + " to " + report.period["end", default: "?"])
                                Text("Source: " + report.evidenceScope)
                                Text("Report: " + String(report.reportId.prefix(16)) + "…")
                                    .font(.caption.monospaced())
                            }
                            .foregroundStyle(WakColor.textSecondary)
                        }
                    }
                    if reports.count < total {
                        Button("Load more reports") { Task { await loadMore() } }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Historical Portfolios")
        .refreshable { await reload() }
        .task { await reload() }
    }

    @MainActor private func reload() async {
        let id = UUID()
        requestID = id
        reports = []
        total = 0
        offset = 0
        errorMessage = nil
        loading = true
        do {
            let page = try await source.getPage(offset: 0)
            guard requestID == id, !Task.isCancelled else { return }
            reports = page.items
            total = page.total
            offset = page.items.count
        } catch {
            guard requestID == id else { return }
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        if requestID == id { loading = false }
    }

    @MainActor private func loadMore() async {
        guard !loading, offset < total else { return }
        let id = UUID()
        requestID = id
        loading = true
        do {
            let page = try await source.getPage(offset: offset)
            guard requestID == id, !Task.isCancelled else { return }
            guard !page.items.isEmpty, !page.items.contains(where: { item in reports.contains(where: { $0.id == item.id }) }) else {
                throw ResearchAPIError.invalidPayload
            }
            reports.append(contentsOf: page.items)
            offset += page.items.count
            total = page.total
            errorMessage = nil
        } catch {
            guard requestID == id else { return }
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        if requestID == id { loading = false }
    }
}

private struct HistoricalPortfolioDetailView: View {
    let report: HistoricalPortfolioItem
    let source: any HistoricalPortfolioSource

    @State private var detail: HistoricalPortfolioSummary?
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if loading {
                ProgressView("Loading verified report summary")
            } else if let errorMessage {
                ContentUnavailableView("Report unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                Button("Retry") { Task { await reload() } }
            } else if let detail {
                Section("Research restrictions") {
                    Text("Research only. Not executable, PIT/OOS verified, investment suitable, or brokerage eligible.")
                    LabeledContent("Evidence scope", value: detail.evidenceScope)
                    LabeledContent("Origin", value: detail.dataOrigin)
                    LabeledContent("Published at", value: detail.publishedAt)
                }
                Section("Historical recorded result") {
                    LabeledContent("Model", value: detail.modelFamily + " · " + detail.modelId)
                    LabeledContent("Tickers", value: detail.tickers.joined(separator: ", "))
                    LabeledContent("Initial virtual cash", value: detail.initialVirtualCash)
                    LabeledContent("Final virtual cash", value: detail.finalTotalCash)
                    LabeledContent("Realized P&L (source)", value: detail.realizedNetPnl)
                    LabeledContent("Portfolio equity (source)", value: detail.finalPortfolioEquity ?? "Unavailable")
                    LabeledContent("Return (source)", value: detail.portfolioReturn ?? "Unavailable")
                    LabeledContent("Decisions", value: "\(detail.decisionCount)")
                    LabeledContent("Fills", value: "\(detail.fillCount)")
                }
                Section("Recorded security decisions") {
                    Text("Archived opportunities and simulated fills retain source evidence; not executed brokerage trades.")
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                    NavigationLink("All recorded trade opportunities") {
                        HistoricalPortfolioTimelineView(reportID: detail.reportId, ticker: nil, source: source)
                    }
                    ForEach(detail.tickers, id: \.self) { ticker in
                        NavigationLink(ticker + " decision history") {
                            HistoricalPortfolioTimelineView(reportID: detail.reportId, ticker: ticker, source: source)
                        }
                    }
                }
                Section("Immutable provenance") {
                    LabeledContent("Report ID", value: detail.reportId)
                    LabeledContent("Archive transport hash", value: detail.archiveTransportHash)
                    LabeledContent("Result hash", value: detail.resultHash)
                    LabeledContent("Report hash", value: detail.reportHash)
                    LabeledContent("Run hash", value: detail.runHash)
                    LabeledContent("Performance hash", value: detail.performanceHash)
                    ForEach(detail.limitations, id: \.self) { Text($0) }
                }
            }
        }
        .navigationTitle("Archived report")
        .task(id: report.id) { await reload() }
        .refreshable { await reload() }
    }

    @MainActor private func reload() async {
        loading = true
        errorMessage = nil
        detail = nil
        do {
            let response = try await source.getSummary(reportID: report.id)
            guard !Task.isCancelled else { loading = false; return }
            guard response.modelFamily == report.modelFamily,
                  response.tickers == report.tickers,
                  response.publishedAt == report.publishedAt,
                  response.evidenceScope == report.evidenceScope else {
                throw ResearchAPIError.invalidPayload
            }
            detail = response
        } catch {
            guard !Task.isCancelled else { loading = false; return }
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        loading = false
    }
}
