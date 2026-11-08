import Foundation

/// Network preflight is an observation, not a publication or release approval.
/// Even complete route reachability cannot certify KRX custody or device signing.
enum ResearchReleasePreflightState: Equatable {
    case notChecked
    case sourceUnavailable
    case incomplete
    case endpointsResponding

    var label: String {
        switch self {
        case .notChecked: "Not checked"
        case .sourceUnavailable: "Source unavailable"
        case .incomplete: "Some routes unavailable or unconfigured"
        case .endpointsResponding: "Required routes responded; release not approved"
        }
    }
}

struct ResearchReleasePreflight {
    let state: ResearchReleasePreflightState
    let checkedCount: Int
    let availableCount: Int
    let unavailableCount: Int
    let requiredUnavailable: [String]

    /// Optional and intentionally local-only archive routes cannot cause a remote
    /// configuration to appear broken; they are still shown in the endpoint list.
    static let requiredPaths: Set<String> = [
        "/api/v1/project/status",
        "/api/v1/stocks",
        "/api/v1/models",
        "/api/v1/evidence",
        "/api/v1/operational/summary",
        "/api/v1/operational/stocks",
        "/api/v1/operations/runs"
    ]

    static func assess(_ results: [ResearchEndpointResult], isHTTP: Bool) -> ResearchReleasePreflight {
        guard isHTTP, !results.isEmpty else {
            return .init(state: .notChecked, checkedCount: results.count,
                         availableCount: 0, unavailableCount: results.count,
                         requiredUnavailable: Array(requiredPaths).sorted())
        }
        let available = results.filter { $0.state == .available }.count
        let failures = results.filter { $0.state != .available }.count
        let lookup = Dictionary(grouping: results, by: \.path)
        let missing = requiredPaths.filter { path in
            guard let matches = lookup[path], matches.count == 1 else { return true }
            return matches[0].state != .available
        }.sorted()
        let state: ResearchReleasePreflightState =
            available == 0 ? .sourceUnavailable : (missing.isEmpty ? .endpointsResponding : .incomplete)
        return .init(state: state, checkedCount: results.count,
                     availableCount: available, unavailableCount: failures,
                     requiredUnavailable: missing)
    }
}
