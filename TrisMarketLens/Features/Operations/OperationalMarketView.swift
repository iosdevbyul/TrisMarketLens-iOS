import SwiftUI
import Charts
import WakTrainerDesignSystem

struct OperationalMarketView: View {
    let source: any OperationalMarketSource
    let isHTTP: Bool

    @State private var summary: OperationalMarketSummary?
    @State private var catalog: [OperationalMarketTicker] = []
    @State private var total = 0
    @State private var loading = true
    @State private var error: String?
    @State private var summaryError: String?
    @State private var requestID = UUID()

    var body: some View {
        List {
            Section("Operational evidence boundary") {
                Text("SHA-pinned offline operational SQLite observations. Unreviewed: not the research stock universe, verified KRX completeness, PIT/OOS qualification or trading evidence.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
                if !isHTTP {
                    Text("Backend is disconnected or in mock mode. Operational observations are never fabricated.")
                }
            }
            Section("Recorded snapshot coverage") {
                if let summary {
                    LabeledContent("Evidence", value: summary.evidenceStatus)
                    LabeledContent("Observed bars", value: summary.observationCount.formatted())
                    LabeledContent("Distinct tickers", value: summary.tickerCount.formatted())
                    LabeledContent("Trading days observed", value: summary.tradingDayCount.formatted())
                    LabeledContent("First observed date", value: summary.firstTradingDate ?? "Unavailable")
                    LabeledContent("Last observed date", value: summary.lastTradingDate ?? "Unavailable")
                } else if let summaryError {
                    Text(summaryError).foregroundStyle(WakColor.destructive)
                    Button("Retry summary") { Task { await loadSummary() } }
                } else {
                    ProgressView("Loading snapshot summary")
                }
            }
            Section("Collected tickers (unreviewed)") {
                if loading && catalog.isEmpty {
                    ProgressView("Loading recorded tickers")
                } else if let error {
                    Text(error).foregroundStyle(WakColor.destructive)
                    Button("Retry catalog") { Task { await reloadCatalog() } }
                } else if catalog.isEmpty {
                    ContentUnavailableView("No collected tickers", systemImage: "externaldrive.badge.questionmark", description: Text("This snapshot returned no observed tickers; completeness is not established."))
                } else {
                    Text("Showing \(catalog.count) of \(total) observed tickers")
                        .font(.caption)
                        .foregroundStyle(WakColor.textSecondary)
                    ForEach(catalog) { item in
                        NavigationLink {
                            OperationalMarketTickerView(source: source, ticker: item.ticker, latestObservedDate: item.latestDataDate)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.ticker).font(.headline.monospacedDigit())
                                Text("Latest recorded date: " + item.latestDataDate).font(.caption)
                                    .foregroundStyle(WakColor.textSecondary)
                            }
                        }
                    }
                    if catalog.count < total {
                        Button("Load more tickers") { Task { await loadMore() } }
                            .disabled(loading)
                    }
                    if loading { ProgressView("Loading more") }
                }
            }
        }
        .navigationTitle("Operational Market")
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .refreshable {
            await loadSummary()
            await reloadCatalog()
        }
        .task {
            await loadSummary()
            await reloadCatalog()
        }
    }

    @MainActor private func loadSummary() async {
        summaryError = nil
        summary = nil
        do {
            summary = try await source.getSummary()
        } catch {
            summaryError = ResearchErrorGuidance.message(for: error)
        }
    }

    @MainActor private func reloadCatalog() async {
        let id = UUID()
        requestID = id
        catalog = []
        total = 0
        loading = true
        error = nil
        await fetchPage(offset: 0, id: id)
    }

    @MainActor private func loadMore() async {
        guard !loading, catalog.count < total else { return }
        let id = UUID()
        requestID = id
        loading = true
        error = nil
        await fetchPage(offset: catalog.count, id: id)
    }

    @MainActor private func fetchPage(offset: Int, id: UUID) async {
        do {
            let result = try await source.getStocks(offset: offset)
            guard requestID == id, !Task.isCancelled else { return }
            guard (offset == 0 || result.total == total),
                  !result.items.isEmpty || offset == result.total,
                  Set(catalog.map(\.ticker)).isDisjoint(with: Set(result.items.map(\.ticker))) else {
                throw ResearchAPIError.invalidPayload
            }
            catalog.append(contentsOf: result.items)
            total = result.total
        } catch {
            guard requestID == id else { return }
            self.error = ResearchErrorGuidance.message(for: error)
        }
        if requestID == id { loading = false }
    }
}

private struct OperationalMarketTickerView: View {
    let source: any OperationalMarketSource
    let ticker: String
    let latestObservedDate: String

    @State private var bars: [OhlcvBar] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            Section("Unreviewed operational bars") {
                LabeledContent("Ticker", value: ticker)
                LabeledContent("Latest catalog date", value: latestObservedDate)
                Text("Unadjusted daily observations from an offline operational snapshot. These are not the research OHLCV series or authorized investment signals.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }
            Section("Collected OHLCV") {
                if loading {
                    ProgressView("Loading observed bars")
                } else if let error {
                    ContentUnavailableView("OHLCV unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
                    Button("Retry") { Task { await reload() } }
                } else if bars.isEmpty {
                    Text("No observed daily bars available.")
                } else {
                    Text("\(bars.count) chronological daily bars")
                        .font(.caption)
                        .foregroundStyle(WakColor.textSecondary)
                    Chart(bars) { bar in
                        LineMark(x: .value("Date", bar.date), y: .value("Close", bar.close))
                    }
                    .frame(height: 240)
                    ForEach(bars.suffix(25).reversed()) { bar in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bar.date).font(.headline)
                            LabeledContent("Open", value: bar.open.formatted())
                            LabeledContent("High", value: bar.high.formatted())
                            LabeledContent("Low", value: bar.low.formatted())
                            LabeledContent("Close", value: bar.close.formatted())
                            LabeledContent("Volume", value: bar.volume.formatted())
                        }
                    }
                    Text("Showing latest 25 rows below; chart includes up to the backend's 2,500 recorded bars.")
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                }
            }
        }
        .navigationTitle(ticker)
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .refreshable { await reload() }
        .task(id: ticker) { await reload() }
    }

    @MainActor private func reload() async {
        loading = true
        error = nil
        bars = []
        do {
            let value = try await source.getBars(ticker: ticker)
            guard !Task.isCancelled else { loading = false; return }
            bars = value.bars
        } catch {
            guard !Task.isCancelled else { loading = false; return }
            self.error = ResearchErrorGuidance.message(for: error)
        }
        loading = false
    }
}
