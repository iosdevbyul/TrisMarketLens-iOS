import XCTest
@testable import TrisMarketLens

final class HTTPAnalysisSourceTests: XCTestCase {
    func testScreenerRejectsDuplicateAnalysisIdentifiers() async throws {
        let client = try makeClient(
            #"{"entries":[{"ticker":"005930","name":"Example","analysisId":"run-1","modelId":"m","modelVersion":"1","direction":"up","score":0.8,"validation":"verified","dataThrough":"2026-10-01","analyzedAt":"2026-10-01T00:00:00Z"},{"ticker":"005930","name":"Example","analysisId":"run-1","modelId":"m","modelVersion":"1","direction":"up","score":0.8,"validation":"verified","dataThrough":"2026-10-01","analyzedAt":"2026-10-01T00:00:00Z"}]}"#
        )
        do {
            _ = try await HTTPScreenerSource(client: client).getScreener()
            XCTFail("Expected invalid payload")
        } catch ResearchAPIError.invalidPayload { }
    }

    func testPriceBarsRejectInvalidRange() async throws {
        let client = try makeClient(
            #"{"ticker":"005930","bars":[{"date":"2026-10-01","open":100,"high":90,"low":80,"close":110,"volume":10}]}"#
        )
        do {
            _ = try await HTTPStockResearchSource(client: client).getOhlcv(ticker: "005930")
            XCTFail("Expected invalid payload")
        } catch ResearchAPIError.invalidPayload { }
    }

    func testAnalysisRejectsOutOfRangeScore() async throws {
        let client = try makeClient(
            #"{"ticker":"005930","records":[{"id":"run-1","ticker":"005930","analyzedAt":"2026-10-01T00:00:00Z","dataThrough":"2026-10-01","modelId":"m","modelVersion":"1","direction":"up","score":2.0,"validation":"pending","explanation":null}]}"#
        )
        do {
            _ = try await HTTPStockResearchSource(client: client).getAnalysis(ticker: "005930")
            XCTFail("Expected invalid payload")
        } catch ResearchAPIError.invalidPayload { }
    }

    private func makeClient(_ json: String) throws -> ResearchAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AnalysisFixtureProtocol.self]
        AnalysisFixtureProtocol.body = Data(json.utf8)
        return try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: configuration)
        )
    }
}

private final class AnalysisFixtureProtocol: URLProtocol {
    static var body = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
