import Foundation

/// Structural checks only: passing them never certifies research or market provenance.
enum ResearchCatalogPayloadValidation {
    static func models(_ models: [ModelSummary]) -> Bool {
        guard models.count <= 5_000 else { return false }
        var ids = Set<String>()
        return models.allSatisfy { model in
            nonblank(model.id) && nonblank(model.modelName) &&
            ids.insert(model.id).inserted &&
            probability(model.validationAveragePrecision) &&
            probability(model.oosAveragePrecision)
        }
    }

    static func model(_ model: ModelDetail, requestedID: String) -> Bool {
        model.id == requestedID && nonblank(model.id) && nonblank(model.modelName) &&
        probability(model.validationAveragePrecision) &&
        probability(model.oosAveragePrecision) &&
        probability(model.selectionMeanAveragePrecision) &&
        model.selectionStdAveragePrecision.isFinite &&
        model.selectionStdAveragePrecision >= 0
    }

    static func layers(_ layers: [EvidenceLayerSummary]) -> Bool {
        guard layers.count <= 5_000 else { return false }
        var ids = Set<String>()
        return layers.allSatisfy { layer in
            nonblank(layer.id) && nonblank(layer.title) && ids.insert(layer.id).inserted
        }
    }

    static func layer(_ layer: EvidenceDetail, requestedID: String) -> Bool {
        guard layer.id == requestedID, nonblank(layer.id), nonblank(layer.title),
              layer.metrics.count <= 200, layer.findings.count <= 1_000 else { return false }
        var labels = Set<String>()
        return layer.metrics.allSatisfy { metric in
            nonblank(metric.label) && labels.insert(metric.label).inserted
        }
    }

    private static func probability(_ value: Double) -> Bool {
        value.isFinite && (0...1).contains(value)
    }

    private static func nonblank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
