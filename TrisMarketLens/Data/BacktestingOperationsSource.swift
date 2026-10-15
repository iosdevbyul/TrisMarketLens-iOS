import Foundation

protocol BacktestingOperationsSource {
    func getBaseline() async throws -> BaselineBacktestSnapshot?
    func getOperations() async throws -> OperationsSnapshot
}

struct DisconnectedBacktestingOperationsSource: BacktestingOperationsSource {
    func getBaseline() async throws -> BaselineBacktestSnapshot? { nil }
    func getOperations() async throws -> OperationsSnapshot { .disconnected }
}

protocol OperationsV1Source {
    func getRuns(offset: Int, limit: Int) async throws -> OperationsRunsPage
    func getFreshness() async throws -> OperationsFreshnessResponse
    func getAlerts(offset: Int, limit: Int) async throws -> OperationsAlertsPage
}

struct UnavailableOperationsV1Source: OperationsV1Source {
    func getRuns(offset: Int, limit: Int) async throws -> OperationsRunsPage { throw ResearchAPIError.invalidConfiguration }
    func getFreshness() async throws -> OperationsFreshnessResponse { throw ResearchAPIError.invalidConfiguration }
    func getAlerts(offset: Int, limit: Int) async throws -> OperationsAlertsPage { throw ResearchAPIError.invalidConfiguration }
}
