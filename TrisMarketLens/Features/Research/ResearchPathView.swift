import SwiftUI
import WakTrainerDesignSystem

/// Traces the existence of read-only research publications without inferring approvals.
struct ResearchPathView: View {
    let stocks: any StockSource
    let catalog: any ResearchCatalogSource
    let screener: any ScreenerSource
    let research: any StockResearchSource
    let operations: any OperationsV1Source
    let historicalPortfolios: any HistoricalPortfolioSource
    let operationalMarket: any OperationalMarketSource
    let isHTTP: Bool

    @State private var tickerInput = ""
    @State private var snapshot = ResearchPathSnapshot()
    @State private var errors: [ResearchPathStage: String] = [:]
    @State private var isLoading = true
    @State private var requestID = UUID()
    @State private var tickerRequestID = UUID()
    @State private var isTickerLoading = false
    @State private var universe: [StockSummary]?
    @State private var screenerEntries: [ScreenerEntry]?
    @State private var tickerAnalysis: StockAnalysisSnapshot?
    @State private var operationalEvidence: OperationalMarketSummary?
    @State private var publishedEvidence: [EvidenceLayerSummary]?
    @State private var publishedModels: [ModelSummary]?
    @State private var recordedRuns: OperationsRunsPage?

    private var publicationGate: ResearchPublicationGate {
        ResearchPublicationGate.evaluate(
            isHTTP: isHTTP, observations: operationalEvidence,
            evidenceLayers: publishedEvidence, models: publishedModels, runs: recordedRuns
        )
    }

    private var ticker: String? { ResearchWorkbenchEvidence.normalizedTicker(tickerInput) }

    var body: some View {
        List {
            Section {
                Label(
                    isHTTP ? "Read-only research source journey; no trading approval." : "Not a verified HTTP research journey.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(WakColor.textSecondary)
                TextField("Ticker (six letters or digits)", text: $tickerInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await inspectTicker() } }
                    .onChange(of: tickerInput) { _, _ in
                        tickerRequestID = UUID()
                        tickerAnalysis = nil
                        snapshot.analysisCount = nil
                        snapshot.includesTicker = false
                        snapshot.errorStages.remove(.analysis)
                        errors[.analysis] = nil
                    }
                if !tickerInput.isEmpty && ticker == nil {
                    Text("Enter exactly six letters or digits.")
                        .foregroundStyle(WakColor.destructive)
                }
                Button("Trace selected ticker") { Task { await inspectTicker() } }
                    .disabled(ticker == nil || isTickerLoading)
                if isLoading || isTickerLoading { ProgressView("Checking published sources") }
                Button("Reload source overview") { Task { await reload() } }
            }

            Section("Published source identity review") {
                NavigationLink("Inspect evidence fingerprints and model artifact hashes") {
                    ResearchSourceIdentityAuditView(catalog: catalog, isHTTP: isHTTP)
                }
                Text("Identifier consistency can be assessed; approved raw KRX capture lineage cannot be established from these read-only projections.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }

            Section("Research publication eligibility") {
                LabeledContent("Gate", value: publicationGate.status.label)
                Text("These independent read-only sources do not provide a reviewed end-to-end approval. No collected row is automatically promoted to model input or trade evidence.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
                ForEach(publicationGate.checks) { check in
                    DisclosureGroup(check.label + " · " + check.outcome.label) {
                        Text(check.explanation)
                            .font(.footnote)
                            .foregroundStyle(WakColor.textSecondary)
                    }
                }
            }

            ForEach(ResearchPathStage.allCases) { stage in
                Section(stage.title) {
                    LabeledContent("Status", value: snapshot.status(for: stage, isHTTP: isHTTP, hasTicker: ticker != nil).title)
                    if let error = errors[stage] {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(WakColor.destructive)
                    }
                    switch stage {
                    case .collection:
                        if let count = snapshot.operationalObservationCount {
                            LabeledContent("Observed daily bars", value: count.formatted())
                            LabeledContent("Observed tickers", value: (snapshot.operationalTickerCount ?? 0).formatted())
                            LabeledContent("First observed date", value: snapshot.operationalFirstDate ?? "Unavailable")
                            LabeledContent("Last observed date", value: snapshot.operationalLastDate ?? "Unavailable")
                            LabeledContent("Evidence", value: snapshot.operationalEvidenceStatus ?? "Unavailable")
                        }
                        Text("Snapshot SHA and original provider custody proof are not exposed by this endpoint; independent research approval remains unavailable.")
                            .font(.footnote)
                            .foregroundStyle(WakColor.textSecondary)
                        NavigationLink("Inspect collected operational observations") {
                            OperationalMarketView(source: operationalMarket, isHTTP: isHTTP)
                        }
                    case .identity:
                        if let stockCount = snapshot.stockCount {
                            LabeledContent("Research universe records", value: "\(stockCount)")
                        }
                        if let ticker {
                            Text(snapshot.includesTicker ? "Ticker appears in the current returned universe." : "Ticker not yet confirmed in the returned universe.")
                                .font(.footnote)
                        }
                        NavigationLink("Browse research securities") {
                            StocksView(source: stocks, isDemo: !isHTTP, researchSource: research)
                        }
                    case .models:
                        if let count = snapshot.modelCount {
                            LabeledContent("Global model directions", value: "\(count)")
                        }
                        NavigationLink("Inspect model qualifications") {
                            ResearchCatalogView(kind: .models, source: catalog)
                        }
                    case .analysis:
                        if let count = snapshot.analysisCount {
                            LabeledContent("Exactly corroborated ticker observations", value: "\(count)")
                        }
                        if let ticker, tickerAnalysis != nil {
                            Text("Only records corroborated by both published HTTP projections are counted.")
                                .font(.footnote)
                            NavigationLink("Inspect ticker workbench") {
                                ResearchWorkbenchView(catalog: catalog, screener: screener, research: research, isHTTP: isHTTP)
                            }
                            Text("Selected ticker: \(ticker)")
                        }
                    case .validation:
                        if let count = snapshot.evidenceCount {
                            LabeledContent("Evidence layers", value: "\(count)")
                        }
                        NavigationLink("Inspect evidence and blockers") {
                            ResearchCatalogView(kind: .evidence, source: catalog)
                        }
                    case .portfolio:
                        if let count = snapshot.publishedPortfolioCount {
                            LabeledContent("Approved archive publications", value: "\(count)")
                        }
                        Text("Historical research is operator-pinned and loopback-only; publication is not model or trade approval.")
                            .font(.footnote)
                        NavigationLink("Browse historical portfolio reports") {
                            HistoricalPortfoliosView(source: historicalPortfolios, isHTTP: isHTTP)
                        }
                    case .operations:
                        if let count = snapshot.operationsCount {
                            LabeledContent("Runs in first page", value: "\(count)")
                        }
                        NavigationLink("Inspect operations dashboard") {
                            BacktestingOperationsView(page: .operations, source: DisconnectedBacktestingOperationsSource(), operationsV1Source: operations)
                        }
                    }
                    Text(stage.limitation)
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Research Path")
        .refreshable { await reload() }
        .task { await reload() }
    }

    @MainActor
    private func reload() async {
        let id = UUID()
        requestID = id
        tickerRequestID = UUID()
        isLoading = true
        isTickerLoading = false
        snapshot = ResearchPathSnapshot()
        errors = [:]
        universe = nil
        screenerEntries = nil
        tickerAnalysis = nil
        operationalEvidence = nil
        publishedEvidence = nil
        publishedModels = nil
        recordedRuns = nil

        do {
            let observed = try await operationalMarket.getSummary()
            try observed.validate()
            guard id == requestID, !Task.isCancelled else { return }
            operationalEvidence = observed
            snapshot.operationalObservationCount = observed.observationCount
            snapshot.operationalTickerCount = observed.tickerCount
            snapshot.operationalFirstDate = observed.firstTradingDate
            snapshot.operationalLastDate = observed.lastTradingDate
            snapshot.operationalEvidenceStatus = observed.evidenceStatus
        } catch {
            guard id == requestID else { return }
            record(error, for: .collection)
        }
        do {
            let result = try await stocks.getStocks()
            guard id == requestID, !Task.isCancelled else { return }
            universe = result
            snapshot.stockCount = result.count
        } catch {
            guard id == requestID else { return }
            record(error, for: .identity)
        }
        do {
            let result = try await catalog.getModels()
            guard id == requestID, !Task.isCancelled else { return }
            publishedModels = result
            snapshot.modelCount = result.count
        } catch {
            guard id == requestID else { return }
            record(error, for: .models)
        }
        do {
            let result = try await catalog.getEvidenceLayers()
            guard id == requestID, !Task.isCancelled else { return }
            publishedEvidence = result
            snapshot.evidenceCount = result.count
            snapshot.hasEvidenceBlockers = result.contains { $0.state.title.lowercased() != "verified" }
        } catch {
            guard id == requestID else { return }
            record(error, for: .validation)
        }
        do {
            let result = try await screener.getScreener()
            guard id == requestID, !Task.isCancelled else { return }
            screenerEntries = result.entries
        } catch {
            guard id == requestID else { return }
            record(error, for: .analysis)
        }
        do {
            let result = try await historicalPortfolios.getPage(offset: 0)
            guard id == requestID, !Task.isCancelled else { return }
            snapshot.publishedPortfolioCount = result.total
        } catch {
            guard id == requestID else { return }
            record(error, for: .portfolio)
        }
        do {
            let result = try await operations.getRuns(offset: 0, limit: OperationsContract.pageLimit)
            guard id == requestID, !Task.isCancelled else { return }
            recordedRuns = result
            snapshot.operationsCount = result.items.count
        } catch {
            guard id == requestID else { return }
            record(error, for: .operations)
        }
        guard id == requestID else { return }
        isLoading = false
        if ticker != nil { await inspectTicker() }
    }

    @MainActor
    private func inspectTicker() async {
        guard let ticker, !isLoading else { return }
        let id = UUID()
        tickerRequestID = id
        isTickerLoading = true
        tickerAnalysis = nil
        snapshot.analysisCount = nil
        snapshot.includesTicker = universe?.contains(where: { $0.ticker == ticker }) ?? false
        snapshot.errorStages.remove(.analysis)
        errors[.analysis] = nil

        guard isHTTP else {
            isTickerLoading = false
            return
        }
        guard let entries = screenerEntries else {
            snapshot.errorStages.insert(.analysis)
            errors[.analysis] = "Screener publication unavailable; cannot cross-check."
            isTickerLoading = false
            return
        }
        do {
            let response = try await research.getAnalysis(ticker: ticker)
            guard id == tickerRequestID, !Task.isCancelled else { return }
            tickerAnalysis = response
            guard response.ticker == ticker else {
                snapshot.errorStages.insert(.analysis)
                errors[.analysis] = "Ticker publication identity mismatch."
                isTickerLoading = false
                return
            }
            let matching = entries.filter { $0.ticker == ticker && ResearchObservationMatch.resolve($0, in: response) != nil }
            snapshot.analysisCount = matching.count
        } catch {
            guard id == tickerRequestID else { return }
            record(error, for: .analysis)
        }
        if id == tickerRequestID { isTickerLoading = false }
    }

    @MainActor
    private func record(_ error: Error, for stage: ResearchPathStage) {
        snapshot.errorStages.insert(stage)
        errors[stage] = ResearchErrorGuidance.message(for: error)
    }
}
