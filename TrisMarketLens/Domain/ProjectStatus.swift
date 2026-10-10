import Foundation

// Mirrors the web's src/domain/project.ts response shape.
// A research state is not a trading signal or an investment recommendation.
enum ResearchState: String, Codable {
    case verified
    case inProgress = "in_progress"
    case blocked
    case notStarted = "not_started"

    var title: String {
        switch self {
        case .verified: "Verified"
        case .inProgress: "In progress"
        case .blocked: "Blocked"
        case .notStarted: "Not started"
        }
    }
}

struct SummaryMetric: Codable, Identifiable {
    let label: String
    let value: String
    let detail: String

    var id: String { label }
}

struct ResearchCheckpoint: Codable, Identifiable {
    let label: String
    let state: ResearchState
    let detail: String

    var id: String { label }
}

struct ProjectStatus: Codable {
    let productName: String
    let sourceLabel: String
    let metrics: [SummaryMetric]
    let evidence: [ResearchCheckpoint]
    let baseline: [ResearchCheckpoint]
}
