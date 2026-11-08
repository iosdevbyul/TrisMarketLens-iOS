import XCTest
@testable import TrisMarketLens

final class AnalysisPublicationChronologyTests: XCTestCase {
    private func record(
        analyzedAt: String = "2026-11-02T02:00:00Z",
        dataThrough: String = "2026-11-01",
        validation: String = "verified",
        score: Double? = 0.7
    ) -> StockAnalysisRecord {
        .init(id: "analysis-1", ticker: "005930", analyzedAt: analyzedAt,
              dataThrough: dataThrough, modelId: "example", modelVersion: "v1",
              direction: "up", score: score, validation: validation, explanation: nil)
    }

    func testPublicationAfterDataThroughIsOnlyStructurallyConsistent() {
        XCTAssertEqual(AnalysisPublicationChronology.assess(record()), .consistent)
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            analyzedAt: "2026-11-02T00:10:00+09:00",
            dataThrough: "2026-11-01"
        )), .consistent)
    }

    func testTimezoneConversionUsesUTCAnalysisDay() {
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            analyzedAt: "2026-11-02T00:10:00+09:00",
            dataThrough: "2026-11-02"
        )), .futureDataThrough)
    }

    func testFutureDataThroughDoesNotBecomeVerifiedHistory() {
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            dataThrough: "2026-11-03"
        )), .futureDataThrough)
    }

    func testInvalidDateAndNaiveTimestampFailClosed() {
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            analyzedAt: "2026-11-02T02:00:00"
        )), .invalidTimestamp)
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            dataThrough: "2026-02-30"
        )), .invalidTimestamp)
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            dataThrough: "2026/11/01"
        )), .invalidTimestamp)
    }

    func testOnlyVerifiedRecordMayPublishScore() {
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            validation: "pending", score: 0.7
        )), .invalidPublication)
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            validation: "blocked", score: nil
        )), .consistent)
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            validation: "verified", score: 1.5
        )), .invalidPublication)
        XCTAssertEqual(AnalysisPublicationChronology.assess(record(
            validation: "unexpected", score: nil
        )), .invalidPublication)
    }
}
