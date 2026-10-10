import Foundation

protocol ResearchCatalogSource {
    func getModels() async throws -> [ModelSummary]
    func getModel(id: String) async throws -> ModelDetail?
    func getEvidenceLayers() async throws -> [EvidenceLayerSummary]
    func getEvidenceLayer(id: String) async throws -> EvidenceDetail?
}

/// No research qualification or evidence verification is inferred by the client.
struct DisconnectedResearchCatalogSource: ResearchCatalogSource {
    func getModels() async throws -> [ModelSummary] { [] }
    func getModel(id: String) async throws -> ModelDetail? { nil }
    func getEvidenceLayers() async throws -> [EvidenceLayerSummary] { [] }
    func getEvidenceLayer(id: String) async throws -> EvidenceDetail? { nil }
}
