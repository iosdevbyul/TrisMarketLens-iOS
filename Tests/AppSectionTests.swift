import XCTest
@testable import TrisMarketLens

final class AppSectionTests: XCTestCase {
    func testSectionsMatchCurrentWebNavigation() {
        XCTAssertEqual(AppSection.allCases.map(\.rawValue), [
            "overview", "stocks", "screener", "history",
            "models", "evidence", "backtesting", "operations"
        ])
    }

    func testEverySectionHasTitleAndSymbol() {
        for section in AppSection.allCases {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.symbol.isEmpty)
        }
    }
}
