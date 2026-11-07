import SwiftUI
import WakTrainerDesignSystem

/// A read-only research navigation surface, not a trading signal generator.
/// Every remote collection retains its own error state instead of borrowing demo data.
struct ResearchWorkbenchView: View {
    let catalog: any ResearchCatalogSource
    let screener: any ScreenerSource
    let research: any StockResearchSource
    let isHTTP: Bool

    @State private var direction = "up"
    @State private var tickerInput = ""
    @State private var models: [ModelSummary]?
    @State private var evidence: [EvidenceLayerSummary]?
    @State private var entries: [ScreenerEntry]?
    @State private var analysis: StockAnalysisSnapshot?
    @State private var modelError: String?
    @State private var evidenceError: String?
    @State private var screenerError: String?
    @State private var analysisError: String?
    @State private var isLoading = true
    @State private var isAnalysisLoading = false
    @State private var activeRequestID = UUID()
    @State private var activeAnalysisRequestID = UUID()

    private var ticker: String? { ResearchWorkbenchEvidence.normalizedTicker(tickerInput) }
    private var selectedModel: ModelSummary? { models?.first { $0.id == direction } }
    private var matchingEntries: [ScreenerEntry] {
        guard let ticker else { return [] }
        return entries?.filter { $0.ticker == ticker } ?? []
    }
    private var publicationState: WorkbenchPublicationState {
        guard let ticker, screenerError == nil, analysisError == nil else { return .unavailable }
        return ResearchWorkbenchEvidence.verify(
            ticker: ticker, entries: entries, snapshot: analysis, isHTTP: isHTTP
        )
    }

    var body: some View {
        List {
            Section {
                Label(
                    isHTTP ? "Read-only backend research. No trade approvals." : "Demonstration or disconnected source. No verified publication.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(WakColor.textSecondary)
                if isLoading {
                    ProgressView("Loading research sources")
                }
            }

            Section("Explore published research") {
                Picker("Qualified direction", selection: $direction) {
                    Text("Up").tag("up")
                    Text("Down").tag("down")
                }
                TextField("Six-character security ticker", text: $tickerInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await loadTicker() } }
                    .onChange(of: tickerInput) { _, _ in
                        analysis = nil
                        analysisError = nil
                        activeAnalysisRequestID = UUID()
                    }
                if !tickerInput.isEmpty && ticker == nil {
                    Label("Ticker must contain exactly six letters or digits.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(WakColor.destructive)
                }
                Button("Inspect ticker publication") { Task { await loadTicker() } }
                    .disabled(ticker == nil || isAnalysisLoading)
                if isAnalysisLoading { ProgressView("Loading ticker analysis") }
            }

            Section("Frozen global model qualification") {
                if let modelError {
                    sourceFailure(modelError)
                } else if let models {
                    if models.isEmpty {
                        Text("No model qualifications published.")
                    } else if let selectedModel {
                        LabeledContent("Model", value: selectedModel.modelName)
                        LabeledContent("Role", value: selectedModel.role)
                        LabeledContent("Validation AP", value: selectedModel.validationAveragePrecision.formatted(.number.precision(.fractionLength(6))))
                        LabeledContent("Frozen OOS AP", value: selectedModel.oosAveragePrecision.formatted(.number.precision(.fractionLength(6))))
                    } else {
                        Text("No qualification for the selected direction.")
                    }
                    NavigationLink("Explore model source and provenance") {
                        ResearchCatalogView(kind: .models, source: catalog)
                    }
                } else if !isLoading {
                    Text("Model source unavailable.")
                }
                Text("Global model qualification does not establish a ticker-specific model identity.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }

            Section("Research evidence and blockers") {
                if let evidenceError {
                    sourceFailure(evidenceError)
                } else if let evidence {
                    if evidence.isEmpty {
                        Text("No evidence layers published.")
                    }
                    ForEach(evidence) { layer in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(layer.title).font(.headline)
                            Text("State: \(layer.state.title)")
                            Text(layer.summary)
                            Text("Source: \(layer.sourceLabel)")
                                .font(.caption)
                        }
                    }
                    NavigationLink("Inspect evidence layer details") {
                        ResearchCatalogView(kind: .evidence, source: catalog)
                    }
                } else if !isLoading {
                    Text("Evidence source unavailable.")
                }
            }

            Section("Per-security source correspondence") {
                if let screenerError { sourceFailure("Screener: " + screenerError) }
                if let analysisError { sourceFailure("Ticker analysis: " + analysisError) }
                if let entries {
                    LabeledContent("Published screener entries", value: "\(entries.count)")
                }
                if let ticker, let analysis {
                    LabeledContent("Selected ticker", value: ticker)
                    LabeledContent("Matching screener entries", value: "\(matchingEntries.count)")
                    LabeledContent("Ticker analysis records", value: "\(analysis.records.count)")
                    switch publicationState {
                    case .corroborated:
                        Label("Matching HTTP publication identities found", systemImage: "checkmark.shield")
                        ForEach(matchingEntries) { entry in
                            if let match = ResearchObservationMatch.resolve(entry, in: analysis) {
                                NavigationLink {
                                    StockAnalysisDetailView(record: match, evaluations: [], evaluationUnavailable: true)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text("\(match.modelId) · \(match.modelVersion)")
                                        Text("\(match.id) · \(match.validation)")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    case .notConfirmed:
                        Label("No exact published correspondence; nothing is inferred.", systemImage: "exclamationmark.shield")
                    case .unavailable:
                        Label("Source correspondence unavailable.", systemImage: "exclamationmark.triangle")
                    case .demonstration:
                        Label("Demo data only. Publication cannot be corroborated.", systemImage: "info.circle")
                    }
                } else if !tickerInput.isEmpty && ticker != nil && !isAnalysisLoading && analysisError == nil {
                    Text("Select Inspect ticker publication to load the stock source.")
                } else if tickerInput.isEmpty {
                    Text("Select a ticker to compare the screener index with its stock publication.")
                }
                Text("A matching research record is not an evaluated prediction, investment approval or realized return.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Research Workbench")
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func sourceFailure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(WakColor.destructive)
            Button("Retry research sources") { Task { await reload() } }
        }
    }

    @MainActor
    private func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        models = nil
        evidence = nil
        entries = nil
        modelError = nil
        evidenceError = nil
        screenerError = nil
        do {
            let result = try await catalog.getModels()
            guard activeRequestID == requestID, !Task.isCancelled else { isLoading = false; return }
            models = result
        } catch {
            guard activeRequestID == requestID else { return }
            modelError = ResearchErrorGuidance.message(for: error)
        }
        do {
            let result = try await catalog.getEvidenceLayers()
            guard activeRequestID == requestID, !Task.isCancelled else { isLoading = false; return }
            evidence = result
        } catch {
            guard activeRequestID == requestID else { return }
            evidenceError = ResearchErrorGuidance.message(for: error)
        }
        do {
            let result = try await screener.getScreener()
            guard activeRequestID == requestID, !Task.isCancelled else { isLoading = false; return }
            entries = result.entries
        } catch {
            guard activeRequestID == requestID else { return }
            screenerError = ResearchErrorGuidance.message(for: error)
        }
        guard activeRequestID == requestID else { return }
        isLoading = false
        if ticker != nil { await loadTicker() }
    }

    @MainActor
    private func loadTicker() async {
        guard let ticker else { return }
        let requestID = UUID()
        activeAnalysisRequestID = requestID
        isAnalysisLoading = true
        analysis = nil
        analysisError = nil
        do {
            let result = try await research.getAnalysis(ticker: ticker)
            guard activeAnalysisRequestID == requestID else { return }
            if !Task.isCancelled { analysis = result }
        } catch {
            guard activeAnalysisRequestID == requestID else { return }
            if !Task.isCancelled { analysisError = ResearchErrorGuidance.message(for: error) }
        }
        if activeAnalysisRequestID == requestID { isAnalysisLoading = false }
    }
}
