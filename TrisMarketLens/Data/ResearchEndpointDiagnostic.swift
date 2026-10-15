import Foundation

enum ResearchEndpointState: Equatable {
    case available
    case notConfigured
    case missing
    case incompatible
    case unavailable
}

struct ResearchEndpointResult: Identifiable, Equatable {
    let name: String
    let path: String
    let state: ResearchEndpointState
    let detail: String
    var id: String { path }
}

/// Checks independently whether implemented FastAPI endpoints can return typed data.
/// HTTP 503 means the route exists but its immutable snapshot/source is unavailable.
/// No success is inferred from a passing health check.
struct ResearchEndpointDiagnostic {
    let client: ResearchAPIClient

    func check() async -> [ResearchEndpointResult] {
        var results: [ResearchEndpointResult] = []
        results.append(await probe("Project status", path: "/api/v1/project/status") {
            _ = try await HTTPProjectStatusSource(client: client).getProjectStatus()
        })
        results.append(await probe("Stocks", path: "/api/v1/stocks") {
            _ = try await HTTPStockSource(client: client).getStocks()
        })
        results.append(await probe("Models", path: "/api/v1/models") {
            _ = try await HTTPResearchCatalogSource(client: client).getModels()
        })
        results.append(await probe("Evidence", path: "/api/v1/evidence") {
            _ = try await HTTPResearchCatalogSource(client: client).getEvidenceLayers()
        })
        results.append(await probe("Baseline", path: "/api/v1/backtests/baseline") {
            guard let _ = try await HTTPBacktestingOperationsSource(client: client).getBaseline() else {
                throw ResearchAPIError.httpStatus(404)
            }
        })
        results.append(await probe("AI Screener", path: "/api/v1/analysis/screener") {
            _ = try await HTTPScreenerSource(client: client).getScreener()
        })
        let operations = HTTPOperationsV1Source(client: client)
        results.append(await probe("Operations runs", path: "/api/v1/operations/runs") {
            _ = try await operations.getRuns(offset: 0, limit: OperationsContract.pageLimit)
        })
        results.append(await probe("Operations freshness", path: "/api/v1/operations/freshness") {
            _ = try await operations.getFreshness()
        })
        results.append(await probe("Operations alerts", path: "/api/v1/operations/alerts") {
            _ = try await operations.getAlerts(offset: 0, limit: OperationsContract.pageLimit)
        })
        results.append(.init(name: "Prediction evaluations", path: "/api/v1/stocks/{ticker}/evaluations",
                             state: .missing, detail: "Not defined by the current backend FastAPI router."))
        return results
    }

    private func probe(_ name: String, path: String, run: () async throws -> Void) async -> ResearchEndpointResult {
        do {
            try await run()
            return .init(name: name, path: path, state: .available,
                         detail: "Decoded a response from this endpoint; this does not certify research publication.")
        } catch ResearchAPIError.httpStatus(503) {
            return .init(name: name, path: path, state: .notConfigured,
                         detail: "Endpoint returned 503; the backend reader or publication is not configured.")
        } catch ResearchAPIError.httpStatus(404) {
            return .init(name: name, path: path, state: .missing,
                         detail: "Endpoint returned 404.")
        } catch OperationsContractError.unsupportedSchema {
            return .init(name: name, path: path, state: .incompatible,
                         detail: "Unsupported Operations API schema version.")
        } catch OperationsContractError.invalidPagination {
            return .init(name: name, path: path, state: .incompatible,
                         detail: "Invalid pagination metadata.")
        } catch ResearchAPIError.invalidPayload {
            return .init(name: name, path: path, state: .incompatible,
                         detail: "Returned response does not match the iOS data contract.")
        } catch ResearchAPIError.httpStatus(let status) {
            return .init(name: name, path: path, state: .unavailable,
                         detail: "Endpoint returned HTTP \(status).")
        } catch {
            return .init(name: name, path: path, state: .unavailable,
                         detail: "Endpoint could not be reached.")
        }
    }
}
