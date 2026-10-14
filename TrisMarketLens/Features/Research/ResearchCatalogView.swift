import SwiftUI
import WakTrainerDesignSystem

struct ResearchCatalogView: View {
    enum SectionKind {
        case models, evidence

        var title: String {
            switch self {
            case .models: "Models"
            case .evidence: "Evidence"
            }
        }
    }

    let kind: SectionKind
    private let source: any ResearchCatalogSource
    @State private var models: [ModelSummary] = []
    @State private var activeRequestID = UUID()
    @State private var layers: [EvidenceLayerSummary] = []
    @State private var loading = true
    @State private var failure = false
    @State private var errorMessage: String?

    init(kind: SectionKind, source: any ResearchCatalogSource = DisconnectedResearchCatalogSource()) {
        self.kind = kind
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WakSpacing.regular) {
                Text(kind == .models
                     ? "Research classification metrics, not backtest returns."
                     : "Evidence status is supplied by research; no client-side verification is inferred.")
                    .foregroundStyle(WakColor.textSecondary)

                if loading {
                    ProgressView("Loading research")
                } else if failure {
                    ContentUnavailableView("Research unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage ?? "Unable to load research."))
                    Button("Retry") { Task { await reload() } }
                } else if kind == .models {
                    if models.isEmpty {
                        ContentUnavailableView("No qualified models loaded", systemImage: "brain", description: Text("The research API is not connected."))
                    }
                    ForEach(models) { model in
                        NavigationLink {
                            ModelResearchDetailView(id: model.id, source: source)
                        } label: {
                            WakCard {
                                VStack(alignment: .leading, spacing: WakSpacing.small) {
                                    Text(model.modelName).font(.headline).foregroundStyle(WakColor.textPrimary)
                                    Text("\(model.direction) · \(model.role)")
                                    Text("Validation AP: \(model.validationAveragePrecision.formatted(.number.precision(.fractionLength(6))))")
                                    Text("OOS AP: \(model.oosAveragePrecision.formatted(.number.precision(.fractionLength(6))))")
                                    Text(model.note)
                                }
                                .foregroundStyle(WakColor.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    if layers.isEmpty {
                        ContentUnavailableView("No evidence layers loaded", systemImage: "checkmark.shield", description: Text("The research API is not connected."))
                    }
                    ForEach(layers) { layer in
                        NavigationLink {
                            EvidenceResearchDetailView(id: layer.id, source: source)
                        } label: {
                            WakCard {
                                VStack(alignment: .leading, spacing: WakSpacing.small) {
                                    Text(layer.title).font(.headline).foregroundStyle(WakColor.textPrimary)
                                    Text(layer.state.title)
                                    Text(layer.summary)
                                    Text(layer.sourceLabel)
                                }
                                .foregroundStyle(WakColor.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(WakSpacing.regular)
        }
        .background(WakColor.background)
        .navigationTitle(kind.title)
        .refreshable { await reload() }
        .onAppear { Task { await reload() } }
    }

    private func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        guard activeRequestID == requestID else { return }
        loading = true
        failure = false
        errorMessage = nil
        do {
            switch kind {
            case .models:
                let response = try await source.getModels()
                guard activeRequestID == requestID else { return }
                if Task.isCancelled {
                    loading = false
                    return
                }
                models = response
            case .evidence:
                let response = try await source.getEvidenceLayers()
                guard activeRequestID == requestID else { return }
                if Task.isCancelled {
                    loading = false
                    return
                }
                layers = response
            }
        } catch {
            guard activeRequestID == requestID else { return }
                if Task.isCancelled {
                    loading = false
                    return
                }
            models = []
            layers = []
            failure = true
            errorMessage = ResearchErrorGuidance.message(for: error)
        }
        loading = false
    }
}

private struct ModelResearchDetailView: View {
    let id: String
    let source: any ResearchCatalogSource
    @State private var loading = true
    @State private var activeRequestID = UUID()
    @State private var errorMessage: String?
    @State private var detail: ModelDetail?

    var body: some View {
        List {
            if loading {
                ProgressView("Loading detail")
            } else if let errorMessage {
                ContentUnavailableView("Research unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                Button("Retry") { Task { await reload() } }
            } else if let detail {
                Section("Model") {
                    LabeledContent("Name", value: detail.modelName)
                    LabeledContent("Direction", value: detail.direction)
                    LabeledContent("Role", value: detail.role)
                    LabeledContent("Feature set", value: detail.provenance.featureSet)
                    LabeledContent("Artifact SHA-256", value: detail.provenance.artifactSha256)
                    Button("Copy artifact SHA-256") {
                        UIPasteboard.general.string = detail.provenance.artifactSha256
                    }
                    LabeledContent("Label", value: detail.provenance.label)
                    LabeledContent("Prediction horizon", value: "\(detail.provenance.horizonSessions) sessions")
                    LabeledContent("Classification threshold", value: detail.provenance.threshold.formatted())
                }
                Section("Model reproducibility") {
                    LabeledContent("Random seed", value: detail.provenance.randomSeed.formatted())
                    LabeledContent("Max iterations", value: detail.provenance.maxIterations.formatted())
                    LabeledContent("Learning rate", value: detail.provenance.learningRate.formatted())
                    LabeledContent("Min samples per leaf", value: detail.provenance.minSamplesLeaf.formatted())
                    LabeledContent("L2 regularization", value: detail.provenance.l2Regularization.formatted())
                    LabeledContent("Class weight", value: detail.provenance.classWeight)
                    LabeledContent("Early stopping", value: detail.provenance.earlyStopping ? "Enabled" : "Disabled")
                }
                Section("Validation") {
                    Text("Classification validation metrics, not investment returns.")
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                    LabeledContent("Average precision", value: ModelMetricFormatter.score(detail.validation.averagePrecision))
                    LabeledContent("Sample count", value: detail.validation.sampleCount.formatted())
                    LabeledContent("Precision", value: ModelMetricFormatter.score(detail.validation.precision))
                    LabeledContent("Recall", value: ModelMetricFormatter.score(detail.validation.recall))
                    LabeledContent("F1", value: ModelMetricFormatter.score(detail.validation.f1))
                    LabeledContent("Brier score", value: ModelMetricFormatter.score(detail.validation.brier))
                }
                Section("Out of sample") {
                    Text("Out-of-sample metrics do not imply live trading performance.")
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                    LabeledContent("Average precision", value: ModelMetricFormatter.score(detail.oos.averagePrecision))
                    LabeledContent("Sample count", value: detail.oos.sampleCount.formatted())
                    LabeledContent("Precision", value: ModelMetricFormatter.score(detail.oos.precision))
                    LabeledContent("Recall", value: ModelMetricFormatter.score(detail.oos.recall))
                    LabeledContent("F1", value: ModelMetricFormatter.score(detail.oos.f1))
                    LabeledContent("Brier score", value: ModelMetricFormatter.score(detail.oos.brier))
                }
            } else {
                ContentUnavailableView("Model detail unavailable", systemImage: "brain")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Model detail")
         .refreshable { await reload() }
        .task(id: id) { await reload() }
    }

    private func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        guard activeRequestID == requestID else { return }
            if Task.isCancelled {
                loading = false
                return
            }
        loading = true
        do {
            let response = try await source.getModel(id: id)
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

private struct EvidenceResearchDetailView: View {
    let id: String
    let source: any ResearchCatalogSource
    @State private var loading = true
    @State private var activeRequestID = UUID()
    @State private var errorMessage: String?
    @State private var detail: EvidenceDetail?

    var body: some View {
        List {
            if loading {
                ProgressView("Loading detail")
            } else if let errorMessage {
                ContentUnavailableView("Research unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                Button("Retry") { Task { await reload() } }
            } else if let detail {
                Section("Research evidence") {
                    LabeledContent("State", value: detail.state.title)
                    LabeledContent("Source", value: detail.sourceLabel)
                    LabeledContent("Source scope", value: detail.sourceScope)
                    if let fingerprint = detail.fingerprint, !fingerprint.isEmpty {
                        LabeledContent("Fingerprint", value: fingerprint)
                        Button("Copy fingerprint") {
                            UIPasteboard.general.string = fingerprint
                        }
                    } else {
                        LabeledContent("Fingerprint", value: "Not published")
                    }
                    Text(detail.summary)
                    if let blocker = detail.blocker, !blocker.isEmpty {
                        Text("Blocker: \(blocker)")
                    } else {
                        Text("No blocker published.")
                            .foregroundStyle(WakColor.textSecondary)
                    }
                }
                Section("Metrics") {
                    if detail.metrics.isEmpty {
                        Text("No evidence metrics published.")
                            .foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(detail.metrics) { metric in
                        VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                            LabeledContent(metric.label, value: metric.value)
                            if !metric.detail.isEmpty {
                                Text(metric.detail)
                                    .font(.footnote)
                                    .foregroundStyle(WakColor.textSecondary)
                            }
                        }
                    }
                }
                Section("Findings") {
                    if detail.findings.isEmpty {
                        Text("No findings published.")
                            .foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(detail.findings, id: \.self) { finding in
                        Text(finding)
                    }
                }
            } else {
                ContentUnavailableView("Evidence detail unavailable", systemImage: "checkmark.shield")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Evidence detail")
         .refreshable { await reload() }
        .task(id: id) { await reload() }
    }

    private func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        guard activeRequestID == requestID else { return }
            if Task.isCancelled {
                loading = false
                return
            }
        loading = true
        do {
            let response = try await source.getEvidenceLayer(id: id)
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
