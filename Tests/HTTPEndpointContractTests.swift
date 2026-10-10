import Foundation
import XCTest
@testable import TrisMarketLens

final class HTTPEndpointContractTests: XCTestCase {
    private func client(status: Int = 200, payload: String = "{}", error: URLError? = nil) throws -> ResearchAPIClient {
        ContractURLProtocol.handler = { request in
            if let error { throw error }
            return (status, Data(payload.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContractURLProtocol.self]
        return try ResearchAPIClient(
            baseURL: URL(string: "https://research.example.test")!,
            session: URLSession(configuration: configuration)
        )
    }

    func testSuccessfulListEndpointsDecodeAndUseGET() async throws {
        let endpoints: [(String, String)] = [
            ("stocks", #"[]"#),
            ("models", #"[]"#),
            ("evidence", #"[]"#),
            ("analysis/screener", #"{"entries":[]}"#)
        ]
        for (endpoint, json) in endpoints {
            let api = try client(payload: json)
            switch endpoint {
            case "stocks":
                let result = try await HTTPStockSource(client: api).getStocks()
                XCTAssertTrue(result.isEmpty)
            case "models":
                let result = try await HTTPResearchCatalogSource(client: api).getModels()
                XCTAssertTrue(result.isEmpty)
            case "evidence":
                let result = try await HTTPResearchCatalogSource(client: api).getEvidenceLayers()
                XCTAssertTrue(result.isEmpty)
            default:
                let result = try await HTTPScreenerSource(client: api).getScreener()
                XCTAssertTrue(result.entries.isEmpty)
            }
            XCTAssertEqual(ContractURLProtocol.lastRequest?.httpMethod, "GET")
            XCTAssertEqual(ContractURLProtocol.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(ContractURLProtocol.lastRequest?.url?.path, "/api/v1/\(endpoint)")
        }
    }

    func testStockResearchEndpointsDecodeEmptySnapshots() async throws {
        let tests: [(String, String)] = [
            ("ohlcv", #"{"ticker":"005930","bars":[]}"#),
            ("analysis", #"{"ticker":"005930","records":[]}"#),
            ("evaluations", #"{"ticker":"005930","evaluations":[]}"#)
        ]
        for (endpoint, json) in tests {
            let source = HTTPStockResearchSource(client: try client(payload: json))
            switch endpoint {
            case "ohlcv":
                let result = try await source.getOhlcv(ticker: "005930")
                XCTAssertTrue(result.bars.isEmpty)
            case "analysis":
                let result = try await source.getAnalysis(ticker: "005930")
                XCTAssertTrue(result.records.isEmpty)
            default:
                let result = try await source.getEvaluations(ticker: "005930")
                XCTAssertTrue(result.evaluations.isEmpty)
            }
            XCTAssertEqual(ContractURLProtocol.lastRequest?.url?.path, "/api/v1/stocks/005930/\(endpoint)")
        }
    }

    func testOperationsEndpointDecodesDisconnectedPayload() async throws {
        let json = #"{"connection":"not_connected","checkedAt":null,"latestDataThrough":null,"nextScheduledRun":null,"runs":[]}"#
        let snapshot = try await HTTPBacktestingOperationsSource(client: client(payload: json)).getOperations()
        XCTAssertEqual(snapshot.connection, "not_connected")
        XCTAssertEqual(ContractURLProtocol.lastRequest?.url?.path, "/api/v1/operations")
    }

    func test404DetailIsNilButList404Throws() async throws {
        let api = try client(status: 404)
        let stock = try await HTTPStockSource(client: api).getStock(ticker: "005930")
        XCTAssertNil(stock)
        let catalog = HTTPResearchCatalogSource(client: api)
        let model = try await catalog.getModel(id: "up")
        let evidence = try await catalog.getEvidenceLayer(id: "calendar")
        XCTAssertNil(model)
        XCTAssertNil(evidence)
        let baseline = try await HTTPBacktestingOperationsSource(client: api).getBaseline()
        XCTAssertNil(baseline)
        do {
            _ = try await HTTPStockSource(client: api).getStocks()
            XCTFail("List 404 must fail, not masquerade as empty data")
        } catch ResearchAPIError.httpStatus(let status) {
            XCTAssertEqual(status, 404)
        }
    }

    func test500AndMalformedPayloadRemainErrors() async throws {
        let unavailable = try client(status: 500)
        do {
            _ = try await HTTPProjectStatusSource(client: unavailable).getProjectStatus()
            XCTFail("500 must fail")
        } catch ResearchAPIError.httpStatus(let status) {
            XCTAssertEqual(status, 500)
        }

        let malformed = try client(payload: #"{"productName": "#)
        do {
            _ = try await HTTPProjectStatusSource(client: malformed).getProjectStatus()
            XCTFail("Invalid JSON must fail")
        } catch ResearchAPIError.invalidPayload {}
    }

    func testTimeoutSurfacesAsTransportFailure() async throws {
        let api = try client(error: URLError(.timedOut))
        do {
            _ = try await HTTPProjectStatusSource(client: api).getProjectStatus()
            XCTFail("Timeout must not fall back to mock")
        } catch ResearchAPIError.transport {}
    }

    func testRejectsUnsafePathSegmentsBeforeRequest() async throws {
        let api = try client()
        do {
            _ = try await api.fetch(ProjectStatus.self, path: ["api", "..", "status"])
            XCTFail("Traversal path must be rejected")
        } catch ResearchAPIError.invalidConfiguration {}
    }
}

private final class ContractURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        do {
            let (status, body) = try Self.handler?(request) ?? (500, Data())
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
