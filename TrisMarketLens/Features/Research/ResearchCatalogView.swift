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
    @State private var layers: [EvidenceLayerSummary] = []
    @State private var loading = true
    @State private var failure = false

    init(kind: SectionKind, source: any ResearchCatalogSource = DisconnectedResearchCatalogSource()) {
        self.kind = kind
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WakSpacing.regular) {
                Text(kind.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(WakColor.textPrimary)
                Text(kind == .models
                     ? "Research classification metrics, not backtest returns."
                     : "Evidence status is supplied by research; no client-side verification is inferred.")
                    .foregroundStyle(WakColor.textSecondary)

                if loading {
                    ProgressView("Loading research")
                } else if failure {
                    ContentUnavailableView("Research unavailable", systemImage: "exclamationmark.triangle")
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
        .task { await reload() }
    }

    private func reload() async {
        guard !Task.isCancelled else { return }
        loading = true
        failure = false
        do {
            switch kind {
            case .models:
                let response = try await source.getModels()
                guard !Task.isCancelled else { return }
                models = response
            case .evidence:
                let response = try await source.getEvidenceLayers()
                guard !Task.isCancelled else { return }
                layers = response
            }
        } catch {
            guard !Task.isCancelled else { return }
            models = []
            layers = []
            failure = true
        }
        loading = false
    }
}

private struct ModelResearchDetailView: View {
    let id: String
    let source: any ResearchCatalogSource
    @State private var detail: ModelDetail?

    var body: some View {
        List {
            if let detail {
                Section("Model") {
                    LabeledContent("Name", value: detail.modelName)
                    LabeledContent("Direction", value: detail.direction)
                    LabeledContent("Role", value: detail.role)
                    LabeledContent("Feature set", value: detail.provenance.featureSet)
                    LabeledContent("Artifact SHA-256", value: detail.provenance.artifactSha256)
                }
                Section("Validation") {
                    LabeledContent("Average precision", value: detail.validation.averagePrecision.formatted())
                    LabeledContent("Sample count", value: String(detail.validation.sampleCount))
                }
                Section("Out of sample") {
                    LabeledContent("Average precision", value: detail.oos.averagePrecision.formatted())
                    LabeledContent("Sample count", value: String(detail.oos.sampleCount))
                }
            } else {
                ContentUnavailableView("Model detail unavailable", systemImage: "brain")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Model detail")
        .task { detail = try? await source.getModel(id: id) }
    }
}

private struct EvidenceResearchDetailView: View {
    let id: String
    let source: any ResearchCatalogSource
    @State private var detail: EvidenceDetail?

    var body: some View {
        List {
            if let detail {
                Section("Research evidence") {
                    LabeledContent("State", value: detail.state.title)
                    LabeledContent("Source", value: detail.sourceLabel)
                    Text(detail.summary)
                    if let blocker = detail.blocker {
                        Text("Blocker: \(blocker)")
                    }
                }
                Section("Metrics") {
                    ForEach(detail.metrics) { metric in
                        LabeledContent(metric.label, value: metric.value)
                    }
                }
                Section("Findings") {
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
        .task { detail = try? await source.getEvidenceLayer(id: id) }
    }
}
