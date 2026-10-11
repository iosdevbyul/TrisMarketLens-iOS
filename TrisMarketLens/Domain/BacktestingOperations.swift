import Foundation

struct BacktestReadinessStep: Codable, Identifiable {
    let label: String
    let state: ResearchState
    let detail: String
    var id: String { label }
}

struct BacktestRule: Codable, Identifiable {
    let label: String
    let value: String
    let detail: String
    var id: String { label }
}

struct BacktestRuleGroup: Codable, Identifiable {
    let title: String
    let rules: [BacktestRule]
    var id: String { title }
}

struct BacktestTimelineItem: Codable, Identifiable {
    let label: String
    let value: String
    let detail: String
    var id: String { label }
}

struct BacktestFingerprint: Codable, Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

struct BaselineBacktestSnapshot: Codable {
    let id: String
    let title: String
    let state: ResearchState
    let summary: String
    let readiness: [BacktestReadinessStep]
    let timeline: [BacktestTimelineItem]
    let policyGroups: [BacktestRuleGroup]
    let fingerprints: [BacktestFingerprint]
    let performanceAvailable: Bool
}

struct AnalysisRun: Codable, Identifiable {
    let id: String
    let pipeline: String
    let state: String
    let startedAt: String?
    let finishedAt: String?
    let dataThrough: String?
    let summary: String?
}

struct OperationsSnapshot: Codable {
    let connection: String
    let checkedAt: String?
    let latestDataThrough: String?
    let nextScheduledRun: String?
    let runs: [AnalysisRun]

    static let disconnected = OperationsSnapshot(
        connection: "not_connected",
        checkedAt: nil,
        latestDataThrough: nil,
        nextScheduledRun: nil,
        runs: []
    )
}

extension OperationsSnapshot {
    var newestRunsFirst: [AnalysisRun] {
        runs.sorted { lhs, rhs in
            switch (lhs.startedAt, rhs.startedAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                return lhs.id < rhs.id
            }
        }
    }
}
