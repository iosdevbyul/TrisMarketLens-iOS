import Foundation

struct ResearchHealthPayload: Decodable {
    let status: String
    let service: String
    let mode: String
}

enum ResearchConnectionState: Equatable {
    case notConfigured
    case reachable
    case unhealthy
    case unavailable
    case incompatible
}

struct ResearchConnectionReport: Equatable {
    let state: ResearchConnectionState
    let detail: String

    static let notConfigured = Self(
        state: .notConfigured,
        detail: "HTTP mode is not enabled. Research connectivity has not been checked."
    )
}

struct ResearchConnectionDiagnostic {
    let client: ResearchAPIClient

    func check() async -> ResearchConnectionReport {
        do {
            let health = try await client.fetch(ResearchHealthPayload.self, path: ["api", "v1", "health"])
            guard health.service == "DonghakStockVision", health.mode == "read_only" else {
                return .init(state: .incompatible, detail: "The response is not the expected read-only research service.")
            }
            guard health.status == "ok" else {
                return .init(state: .unhealthy, detail: "The research server responded but did not report healthy status.")
            }
            return .init(state: .reachable, detail: "Read-only research health endpoint responded. Research data endpoints are not yet verified.")
        } catch ResearchAPIError.invalidPayload {
            return .init(state: .incompatible, detail: "Health endpoint response did not match the expected contract.")
        } catch ResearchAPIError.httpStatus(let code) {
            return .init(state: .unavailable, detail: "Health endpoint returned HTTP \(code).")
        } catch {
            return .init(state: .unavailable, detail: "Research server could not be reached or validated.")
        }
    }
}
