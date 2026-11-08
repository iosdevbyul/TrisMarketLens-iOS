import Foundation

/// Independent endpoint states. A recorded projection does not establish source custody or approval.
enum OperationsTraceState: Equatable {
    case observed, empty, blocked, unavailable, demonstration

    var label: String {
        switch self {
        case .observed: return "Recorded source response"
        case .empty: return "No records published"
        case .blocked: return "Recorded blockers"
        case .unavailable: return "Source unavailable"
        case .demonstration: return "Not verified (demo/disconnected)"
        }
    }
}

enum OperationsTraceStage: String, CaseIterable, Identifiable {
    case execution, freshness, incidents, researchPublication, evidence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .execution: return "Recorded acquisition and execution runs"
        case .freshness: return "Source freshness and timestamp policy"
        case .incidents: return "Operational alerts and blockers"
        case .researchPublication: return "Published research screener"
        case .evidence: return "Research evidence layers"
        }
    }

    var limitation: String {
        switch self {
        case .execution: return "An execution outcome is not independent acquisition provenance or semantic approval."
        case .freshness: return "Freshness is source-specific; recent data does not certify complete market coverage."
        case .incidents: return "An empty alert page does not prove that every issue was monitored or resolved."
        case .researchPublication: return "Research records are a separate publication, not evidence that operational rows were promoted."
        case .evidence: return "A research evidence layer does not authorize trades or independently verify KRX coverage."
        }
    }
}

struct OperationsTraceSnapshot {
    var runCount: Int?
    var runEvidenceStatus: String?
    var runDiagnostic: String?
    var runsWithBlockers: Int = 0
    var freshnessCount: Int?
    var freshnessWithBlockers: Int = 0
    var alertCount: Int?
    var alertTotal: Int?
    var screenerCount: Int?
    var evidenceCount: Int?
    var evidenceWithBlockers: Int = 0
    var failures: Set<OperationsTraceStage> = []

    func state(for stage: OperationsTraceStage, isHTTP: Bool) -> OperationsTraceState {
        guard isHTTP else { return .demonstration }
        if failures.contains(stage) { return .unavailable }
        switch stage {
        case .execution:
            guard let runCount else { return .unavailable }
            if runsWithBlockers > 0 || runEvidenceStatus == "blocked" || runEvidenceStatus == "invalid" {
                return .blocked
            }
            return runCount == 0 ? .empty : .observed
        case .freshness:
            guard let freshnessCount else { return .unavailable }
            if freshnessWithBlockers > 0 { return .blocked }
            return freshnessCount == 0 ? .empty : .observed
        case .incidents:
            guard let alertCount else { return .unavailable }
            if alertCount > 0 { return .blocked }
            // Empty first page is not the same as no incidents when total is unknown.
            guard alertTotal == 0 else { return .unavailable }
            return .empty
        case .researchPublication:
            guard let screenerCount else { return .unavailable }
            return screenerCount == 0 ? .empty : .observed
        case .evidence:
            guard let evidenceCount else { return .unavailable }
            if evidenceWithBlockers > 0 { return .blocked }
            return evidenceCount == 0 ? .empty : .observed
        }
    }
}
