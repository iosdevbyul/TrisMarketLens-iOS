import Foundation

protocol SecurityMetadataSource {
    func getAll() async throws -> [SecurityMetadata]
    func get(ticker: String) async throws -> SecurityMetadata?
}

struct HTTPSecurityMetadataSource: SecurityMetadataSource {
    let client: ResearchAPIClient

    func getAll() async throws -> [SecurityMetadata] {
        let response = try await client.fetch(SecurityMetadataEnvelope.self, path: ["api", "v1", "security-metadata"])
        guard response.artifact.version == "security_metadata_v1" else {
            throw ResearchAPIError.invalidPayload
        }
        return response.artifact.securities
    }

    func get(ticker: String) async throws -> SecurityMetadata? {
        do {
            let response = try await client.fetch(SecurityMetadataDetail.self, path: ["api", "v1", "security-metadata", ticker])
            guard response.security.ticker == ticker else { throw ResearchAPIError.invalidPayload }
            return response.security
        } catch ResearchAPIError.httpStatus(404) {
            return nil
        }
    }
}

struct UnavailableSecurityMetadataSource: SecurityMetadataSource {
    func getAll() async throws -> [SecurityMetadata] { [] }
    func get(ticker: String) async throws -> SecurityMetadata? { nil }
}
