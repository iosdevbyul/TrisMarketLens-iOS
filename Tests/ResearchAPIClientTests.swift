import XCTest
@testable import TrisMarketLens

final class ResearchAPIClientTests: XCTestCase {
    func testRejectsInvalidBaseURL() {
        XCTAssertThrowsError(try ResearchAPIClient(baseURL: URL(fileURLWithPath: "/tmp")))
    }

    func testHTTPFailureDoesNotBecomeMockData() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ResearchMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = try ResearchAPIClient(baseURL: URL(string: "https://example.test")!, session: session)
        ResearchMockURLProtocol.statusCode = 503
        do {
            _ = try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
            XCTFail("Expected explicit HTTP failure")
        } catch ResearchAPIError.httpStatus(let code) {
            XCTAssertEqual(code, 503)
        }
    }

    func testProjectStatusResponseDecodes() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ResearchMockURLProtocol.self]
        let client = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: config)
        )
        ResearchMockURLProtocol.statusCode = 200
        let result = try await HTTPProjectStatusSource(client: client).getProjectStatus()
        XCTAssertEqual(result.productName, "TrisMarketLens")
    }
}

private final class ResearchMockURLProtocol: URLProtocol {
    static var statusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = #"{"productName":"TrisMarketLens","sourceLabel":"API","metrics":[],"evidence":[],"baseline":[]}"#
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
