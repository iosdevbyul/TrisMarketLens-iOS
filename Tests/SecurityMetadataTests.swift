import XCTest
@testable import TrisMarketLens

final class SecurityMetadataTests: XCTestCase {
    private let ticker = "005930"

    func testVerifiedKoreanSecurityNameUsesEvidence() throws {
        let metadata = try decode(name: "삼성전자", english: nil, status: "verified_in_source_snapshot", evidence: "official-1")
        XCTAssertEqual(StockDisplayNameResolver.resolve(ticker: ticker, legacyCorporationName: "SAMSUNG ELECTRONICS", metadata: metadata, language: "ko"), "삼성전자")
        XCTAssertEqual(StockDisplayNameResolver.resolve(ticker: ticker, legacyCorporationName: "SAMSUNG ELECTRONICS", metadata: metadata, language: "en"), "SAMSUNG ELECTRONICS")
    }

    func testEnglishVerifiedNameTakesPriorityInEnglish() throws {
        let metadata = try decode(name: "삼성전자", english: "Samsung Electronics", status: "verified_in_source_snapshot", evidence: "official-1")
        XCTAssertEqual(StockDisplayNameResolver.resolve(ticker: ticker, legacyCorporationName: "CORPORATION", metadata: metadata, language: "en"), "Samsung Electronics")
    }

    func testUnverifiedNameAndWrongTickerCannotReplaceLegacyName() throws {
        let metadata = try decode(name: "Candidate", english: nil, status: "unavailable", evidence: nil)
        XCTAssertEqual(StockDisplayNameResolver.resolve(ticker: ticker, legacyCorporationName: "Legacy", metadata: metadata, language: "ko"), "Legacy")
        XCTAssertEqual(StockDisplayNameResolver.resolve(ticker: "000001", legacyCorporationName: nil, metadata: metadata, language: "ko"), "000001")
        XCTAssertEqual(StockDisplayNameResolver.resolve(ticker: ticker, legacyCorporationName: nil, metadata: nil, language: "ko"), ticker)
    }

    private func decode(name: String?, english: String?, status: String, evidence: String?) throws -> SecurityMetadata {
        let payload: [String: Any] = [
            "ticker": ticker, "securityName": name.map { $0 as Any } ?? NSNull(), "securityNameEnglish": english.map { $0 as Any } ?? NSNull(),
            "nameEvidenceReference": evidence.map { $0 as Any } ?? NSNull(), "nameStatus": status,
            "corporationId": NSNull(), "securityType": "unknown"
        ]
        return try JSONDecoder().decode(SecurityMetadata.self, from: JSONSerialization.data(withJSONObject: payload))
    }
}
