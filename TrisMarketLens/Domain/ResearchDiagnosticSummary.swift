import Foundation

/// Shareable, deterministic diagnostics without private endpoint hosts or credentials.
/// A healthy API does not imply verified source custody or release approval.
enum ResearchDiagnosticSummary {
    static func render(connection: ResearchConnectionReport, results: [ResearchEndpointResult]) -> String {
        let preflight = ResearchReleasePreflight.assess(
            results, isHTTP: connection.state == .reachable
        )
        var lines: [String] = [
            "TrisMarketLens iOS — Read-only API diagnostic summary v1",
            "Connection: \(connectionLabel(connection.state))",
            "Required API status: \(preflight.state.label)",
            "Routes responding: \(preflight.availableCount) / \(preflight.checkedCount)",
            "Required routes not responding: \(preflight.requiredUnavailable.count)",
        ]
        lines.append(contentsOf: preflight.requiredUnavailable.map { "  - \($0)" })
        lines.append("Endpoint results:")
        for result in results.sorted(by: { $0.path < $1.path }) {
            // Only route templates and fixed state labels are exported.
            // Server-provided text and request URLs are deliberately excluded.
            let path = ResearchReleasePreflight.requiredPaths.contains(result.path)
                ? result.path : safeRoute(result.path)
            lines.append("  \(path): \(endpointLabel(result.state))")
        }
        if results.isEmpty { lines.append("  Not checked") }
        lines += [
            "Independent KRX source authorization: NOT VERIFIED",
            "Original market-data custody and publication: NOT VERIFIED",
            "Physical-device QA and signing: NOT VERIFIED",
            "Live collection and trading approval: NOT GRANTED",
            "This report establishes API response observations only, not scientific or release readiness.",
        ]
        return lines.joined(separator: "\n")
    }

    private static func connectionLabel(_ state: ResearchConnectionState) -> String {
        switch state {
        case .notConfigured: "Not configured"
        case .reachable: "Health endpoint reachable"
        case .unhealthy: "Unhealthy response"
        case .unavailable: "Unavailable"
        case .incompatible: "Incompatible response"
        }
    }

    private static func endpointLabel(_ state: ResearchEndpointState) -> String {
        switch state {
        case .available: "Responded"
        case .notConfigured: "Not configured"
        case .missing: "Missing"
        case .incompatible: "Incompatible"
        case .unavailable: "Unavailable"
        }
    }

    private static func safeRoute(_ path: String) -> String {
        guard path.hasPrefix("/api/v1/"),
              path.utf8.count <= 160,
              path.unicodeScalars.allSatisfy({ scalar in
                  (48...57).contains(scalar.value) ||
                  (65...90).contains(scalar.value) ||
                  (97...122).contains(scalar.value) ||
                  "/-_{}".unicodeScalars.contains(scalar)
              }) else {
            return "[unrecognized route]"
        }
        return path
    }
}
