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

    func testHTTPStockListRejectsDuplicateAndInvalidIdentifiers() async throws {
        let good = #"{"ticker":"005930","name":null,"market":"KOSPI","sector":null}"#
        let duplicate = "[\(good),\(good)]"
        let invalidTicker = #"[{"ticker":"BAD","name":null,"market":"KOSPI","sector":null}]"#
        let blankMarket = #"[{"ticker":"005930","name":null,"market":"  ","sector":null}]"#
        for payload in [duplicate, invalidTicker, blankMarket] {
            let source = HTTPStockSource(client: try client(payload: payload))
            do {
                _ = try await source.getStocks()
                XCTFail("Invalid stock-list payload must fail closed")
            } catch ResearchAPIError.invalidPayload { }
        }
        let valid = try await HTTPStockSource(client: client(payload: "[\(good)]")).getStocks()
        XCTAssertEqual(valid.map(\.ticker), ["005930"])
    }

    func testHTTPStockDetailRejectsCrossTickerAndBlankMetadata() async throws {
        let valid = #"{"ticker":"005930","name":null,"market":"KOSPI","sector":null,"dataStatus":"unavailable","latestDataDate":"","availableFrom":"","evidenceNote":"","chartNote":""}"#
        let mismatched = valid.replacingOccurrences(of: "005930", with: "000660")
        let blank = valid.replacingOccurrences(of: "\"market\":\"KOSPI\"", with: "\"market\":\" \"")
        let missingStatus = valid.replacingOccurrences(of: "\"dataStatus\":\"unavailable\"", with: "\"dataStatus\":\" \"")
        for payload in [mismatched, blank, missingStatus] {
            do {
                _ = try await HTTPStockSource(client: client(payload: payload)).getStock(ticker: "005930")
                XCTFail("Invalid stock-detail payload must fail closed")
            } catch ResearchAPIError.invalidPayload { }
        }
        let value = try await HTTPStockSource(client: client(payload: valid)).getStock(ticker: "005930")
        XCTAssertEqual(value?.ticker, "005930")
        XCTAssertEqual(value?.displayName, "005930")
    }

    func testProjectStatusRejectsDuplicateLabelsAndBlankSourceIdentity() async throws {
        let valid = #"{"productName":"Research","sourceLabel":"API","metrics":[{"label":"Universe","value":"10","detail":""}],"evidence":[{"label":"Source","state":"blocked","detail":""}],"baseline":[]}"#
        let duplicateMetric = valid.replacingOccurrences(
            of: #""metrics":[{"label":"Universe","value":"10","detail":""}]"#,
            with: #""metrics":[{"label":"Universe","value":"10","detail":""},{"label":"Universe","value":"11","detail":""}]"#
        )
        let duplicateCheckpoint = valid.replacingOccurrences(
            of: #""evidence":[{"label":"Source","state":"blocked","detail":""}]"#,
            with: #""evidence":[{"label":"Source","state":"blocked","detail":""},{"label":"Source","state":"blocked","detail":""}]"#
        )
        let blankSource = valid.replacingOccurrences(of: #""sourceLabel":"API""#, with: #""sourceLabel":" ""#)
        let blankValue = valid.replacingOccurrences(of: #""value":"10""#, with: #""value":" ""#)
        for payload in [duplicateMetric, duplicateCheckpoint, blankSource, blankValue] {
            do {
                _ = try await HTTPProjectStatusSource(client: client(payload: payload)).getProjectStatus()
                XCTFail("Invalid project status must not be displayed")
            } catch ResearchAPIError.invalidPayload { }
        }
        let status = try await HTTPProjectStatusSource(client: client(payload: valid)).getProjectStatus()
        XCTAssertEqual(status.metrics.count, 1)
        XCTAssertEqual(status.evidence.first?.state, .blocked)
    }

    func testProjectStatusAllowsEmptySectionsWithoutInventingEvidence() async throws {
        let payload = #"{"productName":"Research","sourceLabel":"API","metrics":[],"evidence":[],"baseline":[]}"#
        let status = try await HTTPProjectStatusSource(client: client(payload: payload)).getProjectStatus()
        XCTAssertTrue(status.metrics.isEmpty)
        XCTAssertTrue(status.evidence.isEmpty)
        XCTAssertTrue(status.baseline.isEmpty)
    }


    func testStockResearchEndpointsDecodeEmptySnapshots() async throws {
        let tests: [(String, String)] = [
            ("ohlcv", #"{"ticker":"005930","bars":[]}"#),
            ("analysis", #"{"ticker":"005930","records":[]}"#),
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
                XCTFail("Unexpected endpoint")
            }
            XCTAssertEqual(ContractURLProtocol.lastRequest?.url?.path, "/api/v1/stocks/005930/\(endpoint)")
        }
    }

    func testUnpublishedRoutesFailClosedWithoutHTTP() async throws {
        ContractURLProtocol.lastRequest = nil
        let api = try client()
        do {
            _ = try await HTTPBacktestingOperationsSource(client: api).getOperations()
            XCTFail("Legacy operations endpoint is not supported")
        } catch ResearchAPIError.invalidConfiguration {}
        XCTAssertNil(ContractURLProtocol.lastRequest)

        do {
            _ = try await HTTPStockResearchSource(client: api).getEvaluations(ticker: "005930")
            XCTFail("Prediction evaluations endpoint is not published")
        } catch ResearchAPIError.invalidConfiguration {}
        XCTAssertNil(ContractURLProtocol.lastRequest)
    }

    func test503AndInvalidJSONAreNotEmptyScreenerResults() async throws {
        do {
            _ = try await HTTPScreenerSource(client: client(status: 503)).getScreener()
            XCTFail("503 must remain unavailable")
        } catch ResearchAPIError.httpStatus(let status) {
            XCTAssertEqual(status, 503)
        }

        do {
            _ = try await HTTPScreenerSource(client: client(payload: #"{bad json"#)).getScreener()
            XCTFail("Malformed JSON must remain an error")
        } catch ResearchAPIError.invalidPayload {}
    }

    func testSecurityMetadataEndpointsAndUnavailableFallback() async throws {
        let response = """
        {"artifact":{"version":"security_metadata_v1","securities":[{"ticker":"005930","securityName":null,"securityNameEnglish":null,"nameEvidenceReference":null,"nameStatus":"unavailable","corporationId":null,"securityType":"unknown"}]},"fingerprint":"example"}
        """
        let source = HTTPSecurityMetadataSource(client: try client(payload: response))
        let values = try await source.getAll()
        XCTAssertEqual(values.map(\.ticker), ["005930"])
        XCTAssertEqual(ContractURLProtocol.lastRequest?.url?.path, "/api/v1/security-metadata")

        let detailSource = HTTPSecurityMetadataSource(client: try client(status: 404))
        let missing = try await detailSource.get(ticker: "005930")
        XCTAssertNil(missing)
        XCTAssertEqual(ContractURLProtocol.lastRequest?.url?.path, "/api/v1/security-metadata/005930")

        let unavailable = HTTPSecurityMetadataSource(client: try client(status: 503))
        do {
            _ = try await unavailable.getAll()
            XCTFail("503 must not be mistaken for verified metadata")
        } catch ResearchAPIError.httpStatus(let status) {
            XCTAssertEqual(status, 503)
        }
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

    func testTimeoutSurfacesAsSpecificTimeoutFailure() async throws {
        let api = try client(error: URLError(.timedOut))
        do {
            _ = try await HTTPProjectStatusSource(client: api).getProjectStatus()
            XCTFail("Timeout must not fall back to mock")
        } catch ResearchAPIError.timeout {}
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
