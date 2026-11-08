import XCTest
@testable import TrisMarketLens

final class ResearchReleasePreflightTests: XCTestCase {
    private func result(_ path: String, state: ResearchEndpointState = .available) -> ResearchEndpointResult {
        .init(name: path, path: path, state: state, detail: "Synthetic fixture")
    }

    func testDisconnectedAndNotCheckedCannotPass() {
        XCTAssertEqual(ResearchReleasePreflight.assess([], isHTTP: true).state, .notChecked)
        XCTAssertEqual(
            ResearchReleasePreflight.assess([result("/api/v1/stocks")], isHTTP: false).state,
            .notChecked
        )
    }

    func testOnlyCompleteRequiredEndpointSetIsResponding() {
        let required = ResearchReleasePreflight.requiredPaths.sorted().map { result($0) }
        let report = ResearchReleasePreflight.assess(required, isHTTP: true)
        XCTAssertEqual(report.state, .endpointsResponding)
        XCTAssertTrue(report.requiredUnavailable.isEmpty)
        XCTAssertEqual(report.availableCount, required.count)
        XCTAssertTrue(report.state.label.contains("release not approved"))
    }

    func testMissingRequiredPathDoesNotCountAsReady() {
        let required = ResearchReleasePreflight.requiredPaths.sorted()
        let report = ResearchReleasePreflight.assess(
            required.dropLast().map { result($0) }, isHTTP: true
        )
        XCTAssertEqual(report.state, .incomplete)
        XCTAssertEqual(report.requiredUnavailable, [required.last!])
    }

    func testHTTP503AndIncompatiblePayloadRemainUnavailable() {
        var required = ResearchReleasePreflight.requiredPaths.sorted().map { result($0) }
        let first = required.removeFirst()
        required.append(result(first.path, state: .notConfigured))
        let second = required.removeFirst()
        required.append(result(second.path, state: .incompatible))
        let report = ResearchReleasePreflight.assess(required, isHTTP: true)
        XCTAssertEqual(report.state, .incomplete)
        XCTAssertTrue(report.requiredUnavailable.contains(first.path))
        XCTAssertTrue(report.requiredUnavailable.contains(second.path))
    }

    func testOptionalArchiveAndEvaluationAreNotRequired() {
        let required = ResearchReleasePreflight.requiredPaths.sorted().map { result($0) }
        let extras = [
            result("/api/v1/research/historical-portfolios", state: .notConfigured),
            result("/api/v1/stocks/{ticker}/evaluations", state: .missing)
        ]
        let report = ResearchReleasePreflight.assess(required + extras, isHTTP: true)
        XCTAssertEqual(report.state, .endpointsResponding)
        XCTAssertEqual(report.unavailableCount, 2)
        XCTAssertEqual(report.checkedCount, required.count + 2)
    }

    func testNoAccessibleEndpointsDoesNotPass() {
        let responses = ResearchReleasePreflight.requiredPaths.sorted().map {
            result($0, state: .unavailable)
        }
        XCTAssertEqual(ResearchReleasePreflight.assess(responses, isHTTP: true).state, .sourceUnavailable)
    }

    func testDuplicateRequiredResponsesCannotPass() {
        let required = ResearchReleasePreflight.requiredPaths.sorted().map { result($0) }
        let report = ResearchReleasePreflight.assess(required + [required[0]], isHTTP: true)
        XCTAssertEqual(report.state, .incomplete)
        XCTAssertEqual(report.requiredUnavailable, [required[0].path])
    }
}
