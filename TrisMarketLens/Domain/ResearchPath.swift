import Foundation

/// 'Observed' means a read-only endpoint returned records, not investment approval.
enum ResearchPathStatus: Equatable {
    case observed
    case empty
    case unavailable
    case blocked
    case demo

    var title: String {
        switch self {
        case .observed: return "Source responded"
        case .empty: return "No published records"
        case .unavailable: return "Unavailable"
        case .blocked: return "Unresolved blocker"
        case .demo: return "Demonstration only"
        }
    }
}

enum ResearchPathStage: String, CaseIterable, Identifiable {
    case collection, identity, models, analysis, validation, portfolio, operations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .collection: return "Recorded market observations"
        case .identity: return "Research universe and ticker identity"
        case .models: return "Frozen model qualification"
        case .analysis: return "Published per-ticker analysis"
        case .validation: return "Research evidence and blockers"
        case .portfolio: return "Historical portfolio research"
        case .operations: return "Acquisition and publication operations"
        }
    }

    var limitation: String {
        switch self {
        case .collection: return "An operational market snapshot does not establish approved KRX research coverage."
        case .identity: return "A current ticker listing does not prove uninterrupted historical identity."
        case .models: return "Global model metrics cannot certify a per-ticker inference."
        case .analysis: return "Observed analyses are not evaluated forecasts or trade signals."
        case .validation: return "Visible evidence does not waive missing source or lifecycle evidence."
        case .portfolio: return "Archived reports do not prove brokerage performance or live returns."
        case .operations: return "A completed operation does not establish semantic approval."
        }
    }
}

struct ResearchPathSnapshot {
    var stockCount: Int?
    var includesTicker: Bool = false
    var modelCount: Int?
    var analysisCount: Int?
    var evidenceCount: Int?
    var hasEvidenceBlockers = false
    var operationsCount: Int?
    var errorStages: Set<ResearchPathStage> = []

    func status(for stage: ResearchPathStage, isHTTP: Bool, hasTicker: Bool) -> ResearchPathStatus {
        guard isHTTP else { return .demo }
        if errorStages.contains(stage) { return .unavailable }
        switch stage {
        case .collection, .portfolio:
            // These require separately reviewed backend publication contracts.
            return .unavailable
        case .identity:
            guard let stockCount else { return .unavailable }
            guard stockCount > 0 else { return .empty }
            if hasTicker && !includesTicker { return .blocked }
            return .observed
        case .models:
            return Self.countState(modelCount)
        case .analysis:
            guard hasTicker else { return .unavailable }
            return Self.countState(analysisCount)
        case .validation:
            guard let evidenceCount else { return .unavailable }
            if hasEvidenceBlockers { return .blocked }
            return evidenceCount == 0 ? .empty : .observed
        case .operations:
            return Self.countState(operationsCount)
        }
    }

    private static func countState(_ count: Int?) -> ResearchPathStatus {
        guard let count else { return .unavailable }
        return count == 0 ? .empty : .observed
    }
}
