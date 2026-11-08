import Foundation

/// A monotonically replaced request token for view-owned async operations.
/// Only the latest token may publish a response or failure.
struct ResearchRequestGeneration {
    private(set) var current = UUID()

    @discardableResult
    mutating func begin() -> UUID {
        current = UUID()
        return current
    }

    func accepts(_ token: UUID, cancelled: Bool = false) -> Bool {
        token == current && !cancelled
    }
}
