import Foundation

/// Independent of legacy StockSummary.name, which is a DART corporation name.
struct SecurityMetadata: Decodable {
    let ticker: String
    let securityName: String?
    let securityNameEnglish: String?
    let nameEvidenceReference: String?
    let nameStatus: String
    let corporationId: String?
    let securityType: String
}

struct CorporationMetadata: Decodable {
    let corporationId: String
    let koreanName: String
    let englishName: String?
}

struct SecurityMetadataEnvelope: Decodable {
    let artifact: SecurityMetadataArtifact
    let fingerprint: String
}

struct SecurityMetadataArtifact: Decodable {
    let version: String
    let securities: [SecurityMetadata]
}

struct SecurityMetadataDetail: Decodable {
    let security: SecurityMetadata
    let corporation: CorporationMetadata?
}

enum StockDisplayNameResolver {
    static func resolve(
        ticker: String,
        legacyCorporationName: String?,
        metadata: SecurityMetadata?,
        language: String
    ) -> String {
        let legacy = nonblank(legacyCorporationName)
        guard let metadata, metadata.ticker == ticker,
              metadata.nameStatus == "verified_in_source_snapshot",
              nonblank(metadata.nameEvidenceReference) != nil else {
            return legacy ?? ticker
        }
        let korean = nonblank(metadata.securityName)
        let english = nonblank(metadata.securityNameEnglish)
        if language == "ko" { return korean ?? english ?? legacy ?? ticker }
        return english ?? legacy ?? ticker
    }

    private static func nonblank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
