import Foundation

protocol BacktestingOperationsSource {
    func getBaseline() async throws -> BaselineBacktestSnapshot?
    func getOperations() async throws -> OperationsSnapshot
}

struct DisconnectedBacktestingOperationsSource: BacktestingOperationsSource {
    func getBaseline() async throws -> BaselineBacktestSnapshot? { nil }
    func getOperations() async throws -> OperationsSnapshot { .disconnected }
}
