import Foundation

struct ModelSummary: Codable, Identifiable {
    let id: String
    let direction: String
    let modelName: String
    let role: String
    let validationAveragePrecision: Double
    let oosAveragePrecision: Double
    let note: String
}

struct ClassificationMetrics: Codable {
    let sampleCount: Int
    let precision: Double
    let recall: Double
    let f1: Double
    let averagePrecision: Double
    let brier: Double
}

struct ModelProvenance: Codable {
    let artifactSha256: String
    let featureSet: String
    let label: String
    let horizonSessions: Int
    let threshold: Double
    let maxLeafNodes: Int
    let learningRate: Double
    let maxIterations: Int
    let minSamplesLeaf: Int
    let l2Regularization: Double
    let maxBins: Int
    let classWeight: String
    let earlyStopping: Bool
    let randomSeed: Int
}

struct ModelDetail: Codable {
    let id: String
    let direction: String
    let modelName: String
    let role: String
    let validationAveragePrecision: Double
    let oosAveragePrecision: Double
    let note: String
    let selectionMeanAveragePrecision: Double
    let selectionStdAveragePrecision: Double
    let validation: ClassificationMetrics
    let oos: ClassificationMetrics
    let provenance: ModelProvenance
}

struct EvidenceLayerSummary: Codable, Identifiable {
    let id: String
    let title: String
    let state: ResearchState
    let summary: String
    let sourceLabel: String
}

struct EvidenceMetric: Codable, Identifiable {
    let label: String
    let value: String
    let detail: String

    var id: String { label }
}

struct EvidenceDetail: Codable {
    let id: String
    let title: String
    let state: ResearchState
    let summary: String
    let sourceLabel: String
    let metrics: [EvidenceMetric]
    let findings: [String]
    let blocker: String?
    let fingerprint: String?
    let sourceScope: String
}
