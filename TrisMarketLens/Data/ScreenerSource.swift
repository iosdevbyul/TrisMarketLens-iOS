import Foundation

protocol ScreenerSource {
    func getScreener() async throws -> ScreenerSnapshot
}

/// The app fails closed until a validated research API source is configured.
struct DisconnectedScreenerSource: ScreenerSource {
    func getScreener() async throws -> ScreenerSnapshot {
        ScreenerSnapshot(entries: [])
    }
}
