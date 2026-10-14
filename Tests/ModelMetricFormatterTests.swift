import XCTest
@testable import TrisMarketLens

final class ModelMetricFormatterTests: XCTestCase {
    func testClassificationMetricsUseConsistentPrecision() {
        XCTAssertEqual(ModelMetricFormatter.score(0.37486), "0.374860")
        XCTAssertEqual(ModelMetricFormatter.score(0), "0.000000")
        XCTAssertEqual(ModelMetricFormatter.score(1), "1.000000")
    }

    func testRoundingDoesNotChangeOriginalValues() {
        let value = 0.3694092
        XCTAssertEqual(ModelMetricFormatter.score(value), "0.369409")
        XCTAssertEqual(value, 0.3694092)
    }
}
