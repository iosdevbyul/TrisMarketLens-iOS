import XCTest
@testable import TrisMarketLens

final class ScreenerTests: XCTestCase {
    private let entries: [ScreenerEntry] = [
        .init(ticker: "000001", name: "Alpha", analysisId: "a1", modelId: "M1", modelVersion: "v1", direction: "up", score: 0.8, validation: "verified", dataThrough: "2026-10-01", analyzedAt: "2026-10-01T00:00:00Z"),
        .init(ticker: "000002", name: nil, analysisId: "a2", modelId: "M2", modelVersion: "v1", direction: "down", score: nil, validation: "blocked", dataThrough: "2026-09-30", analyzedAt: "2026-09-30T00:00:00Z")
    ]

    func testFiltersAndSortMatchWebContract() {
        var filter = ScreenerFilter()
        XCTAssertEqual(filter.apply(to: entries).map(\.ticker), ["000001", "000002"])
        filter.direction = "down"
        XCTAssertEqual(filter.apply(to: entries).map(\.ticker), ["000002"])
        filter.direction = "all"
        filter.query = "alpha"
        XCTAssertEqual(filter.apply(to: entries).count, 1)
        filter.query = ""
        filter.validation = "verified"
        XCTAssertEqual(filter.apply(to: entries).count, 1)
        filter.validation = "all"
        filter.sort = .ticker
        XCTAssertEqual(filter.apply(to: entries).first?.ticker, "000001")
    }

    func testScreenerDecodesNullableScore() throws {
        let json = #"{"entries":[{"ticker":"000001","name":null,"analysisId":"a1","modelId":"M1","modelVersion":"v1","direction":"up","score":null,"validation":"pending","dataThrough":"2026-10-01","analyzedAt":"2026-10-01T00:00:00Z"}]}"#
        let result = try JSONDecoder().decode(ScreenerSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(result.entries.first?.score)
        XCTAssertEqual(result.entries.first?.displayName, "000001")
    }

    func testDisconnectedSourceDoesNotInventPredictions() async throws {
        let result = try await DisconnectedScreenerSource().getScreener()
        XCTAssertTrue(result.entries.isEmpty)
    }
    func testResetRestoresDefaultFilters() {
        var filter = ScreenerFilter()
        XCTAssertTrue(filter.isDefault)
        filter.query = "alpha"
        filter.direction = "up"
        filter.validation = "verified"
        filter.sort = .ticker
        XCTAssertFalse(filter.isDefault)
        filter.reset()
        XCTAssertTrue(filter.isDefault)
        XCTAssertEqual(filter.apply(to: entries).count, 2)
    }

    func testWhitespaceQueryRemainsUnfiltered() {
        var filter = ScreenerFilter()
        filter.query = "   "
        XCTAssertTrue(filter.isDefault)
        XCTAssertEqual(filter.apply(to: entries).count, 2)
    }

}
