import Foundation

/// Fail-closed presentation of independent research evidence boundaries.
/// Never promotes observation counts, local checksum validation or a model metric
/// into approval for research publication, PIT/OOS, execution or trading.
enum ResearchPublicationGateStatus: Equatable {
    case blocked
    case insufficientEvidence

    var label: String {
        switch self {
        case .blocked: "Blocked by recorded evidence"
        case .insufficientEvidence: "Not independently authorized"
        }
    }
}

struct ResearchPublicationGateCheck: Identifiable, Equatable {
    enum Outcome: Equatable {
        case blocker, unavailable, observed

        var label: String {
            switch self {
            case .blocker: "Blocker"
            case .unavailable: "Not verified"
            case .observed: "Observed, not approved"
            }
        }
    }

    let id: String
    let label: String
    let outcome: Outcome
    let explanation: String
}

struct ResearchPublicationGate {
    let status: ResearchPublicationGateStatus
    let checks: [ResearchPublicationGateCheck]

    /// All evaluated sources represent independent projections. No cross-endpoint
    /// joins, original capture SHA receipt or signed operator approval is available.
    static func evaluate(
        isHTTP: Bool,
        observations: OperationalMarketSummary?,
        evidenceLayers: [EvidenceLayerSummary]?,
        models: [ModelSummary]?,
        runs: OperationsRunsPage?
    ) -> ResearchPublicationGate {
        guard isHTTP else {
            return ResearchPublicationGate(
                status: .insufficientEvidence,
                checks: [
                    .init(id: "transport", label: "Backend transport",
                          outcome: .unavailable, explanation: "Disconnected or mock mode is not independent evidence.")
                ]
            )
        }

        var checks: [ResearchPublicationGateCheck] = []
        if let observations {
            checks.append(.init(
                id: "operational", label: "KRX operational observations",
                outcome: .unavailable,
                explanation: "Snapshot reports \(observations.observationCount) unreviewed daily bars; source receipts, reviewed capture identity and research admission are not published here."
            ))
        } else {
            checks.append(.init(
                id: "operational", label: "KRX operational observations",
                outcome: .unavailable,
                explanation: "No validated operational snapshot response."
            ))
        }

        if let evidenceLayers {
            if evidenceLayers.isEmpty {
                checks.append(.init(id: "evidence", label: "Research evidence layers",
                                    outcome: .unavailable, explanation: "No evidence publication is available to assess."))
            } else {
                let unresolved = evidenceLayers.filter { $0.state.title.lowercased() != "verified" }
                checks.append(.init(
                    id: "evidence", label: "Research evidence layers",
                    outcome: unresolved.isEmpty ? .observed : .blocker,
                    explanation: unresolved.isEmpty
                        ? "All returned labels are verified; this does not establish raw source custody or investment approval."
                        : "\(unresolved.count) of \(evidenceLayers.count) published layers are not verified."
                ))
            }
        } else {
            checks.append(.init(id: "evidence", label: "Research evidence layers",
                                outcome: .unavailable, explanation: "Research evidence source unavailable."))
        }

        if let models {
            let nonResearch = models.filter { $0.role != "research_only" }
            checks.append(.init(
                id: "models", label: "Model qualification",
                outcome: nonResearch.isEmpty && !models.isEmpty ? .observed : (nonResearch.isEmpty ? .unavailable : .blocker),
                explanation: nonResearch.isEmpty
                    ? "Published model metrics, even with research_only roles, cannot independently authorize production inference."
                    : "Model roles outside research_only are not accepted by the native publication gate."
            ))
        } else {
            checks.append(.init(id: "models", label: "Model qualification",
                                outcome: .unavailable, explanation: "Model qualification publication unavailable."))
        }

        if let runs {
            let invalid = runs.evidenceStatus == "invalid" || runs.items.contains {
                $0.blockingStatus == "blocked" || ["invalid", "unavailable"].contains($0.evidenceStatus) ||
                    ["failed", "interrupted"].contains($0.executionStatus)
            }
            checks.append(.init(
                id: "operations", label: "Collection execution history",
                outcome: invalid ? .blocker : (runs.items.isEmpty ? .unavailable : .observed),
                explanation: invalid
                    ? "Recorded operations contain invalid evidence, failures or blocked items."
                    : "Recorded execution outcomes do not prove raw provenance or semantic approval."
            ))
        } else {
            checks.append(.init(id: "operations", label: "Collection execution history",
                                outcome: .unavailable, explanation: "Operations history unavailable."))
        }

        checks.append(.init(
            id: "authorization", label: "Source custody and publication authorization",
            outcome: .unavailable,
            explanation: "No cross-source proof of captured KRX bytes, approved snapshot lineage, independent PIT/OOS review or investment eligibility is exposed by these APIs."
        ))

        return ResearchPublicationGate(
            status: checks.contains(where: { $0.outcome == .blocker }) ? .blocked : .insufficientEvidence,
            checks: checks
        )
    }
}
