import Foundation

/// A local structural review of *published* identities. Matching list/detail IDs
/// and well-formed SHA-256 strings do not authenticate original source bytes.
enum PublishedIdentityState: Equatable {
    case present, missing, inconsistent

    var label: String {
        switch self {
        case .present: "Published, not independently authenticated"
        case .missing: "Unavailable"
        case .inconsistent: "Identity mismatch"
        }
    }
}

struct PublishedIdentityRecord: Identifiable, Equatable {
    let id: String
    let title: String
    let sourceScope: String
    let publishedFingerprint: String?
    let state: PublishedIdentityState
    let reason: String
}

enum ResearchSourceIdentityAudit {
    static func validSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    static func evidence(summary: EvidenceLayerSummary, detail: EvidenceDetail?) -> PublishedIdentityRecord {
        guard let detail else {
            return .init(id: "evidence:" + summary.id, title: summary.title,
                         sourceScope: "Unavailable", publishedFingerprint: nil,
                         state: .missing, reason: "Evidence detail was not published or could not be retrieved.")
        }
        guard detail.id == summary.id, detail.title == summary.title,
              detail.sourceLabel == summary.sourceLabel, detail.state == summary.state,
              detail.summary == summary.summary else {
            return .init(id: "evidence:" + summary.id, title: summary.title,
                         sourceScope: detail.sourceScope, publishedFingerprint: detail.fingerprint,
                         state: .inconsistent,
                         reason: "Evidence summary and detail disagree. Neither identity is accepted.")
        }
        guard !detail.sourceScope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .init(id: "evidence:" + summary.id, title: summary.title,
                         sourceScope: "Unavailable", publishedFingerprint: detail.fingerprint,
                         state: .inconsistent, reason: "Published source scope is empty.")
        }
        guard let fingerprint = detail.fingerprint, validSHA256(fingerprint) else {
            return .init(id: "evidence:" + summary.id, title: summary.title,
                         sourceScope: detail.sourceScope, publishedFingerprint: detail.fingerprint,
                         state: .missing,
                         reason: "No valid published 64-character lowercase SHA-256 fingerprint. No client hash is inferred.")
        }
        return .init(id: "evidence:" + summary.id, title: summary.title,
                     sourceScope: detail.sourceScope, publishedFingerprint: fingerprint,
                     state: .present,
                     reason: "The publication reports a plausible fingerprint; the app has not obtained or hashed original bytes.")
    }

    static func model(summary: ModelSummary, detail: ModelDetail?) -> PublishedIdentityRecord {
        guard let detail else {
            return .init(id: "model:" + summary.id, title: summary.modelName,
                         sourceScope: "Unavailable", publishedFingerprint: nil,
                         state: .missing, reason: "Model detail was not published or could not be retrieved.")
        }
        guard detail.id == summary.id, detail.direction == summary.direction,
              detail.modelName == summary.modelName, detail.role == summary.role,
              detail.validationAveragePrecision == summary.validationAveragePrecision,
              detail.oosAveragePrecision == summary.oosAveragePrecision,
              detail.note == summary.note else {
            return .init(id: "model:" + summary.id, title: summary.modelName,
                         sourceScope: detail.provenance.featureSet,
                         publishedFingerprint: detail.provenance.artifactSha256,
                         state: .inconsistent, reason: "Model summary and detail disagree.")
        }
        let hash = detail.provenance.artifactSha256
        guard validSHA256(hash) else {
            return .init(id: "model:" + summary.id, title: summary.modelName,
                         sourceScope: detail.provenance.featureSet,
                         publishedFingerprint: hash, state: .inconsistent,
                         reason: "Model artifact SHA-256 is malformed.")
        }
        return .init(id: "model:" + summary.id, title: summary.modelName,
                     sourceScope: detail.provenance.featureSet, publishedFingerprint: hash,
                     state: .present,
                     reason: "The artifact hash is published, but model bytes and signatures have not been independently verified.")
    }
}
