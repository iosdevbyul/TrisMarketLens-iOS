import Foundation

/// Operations API v1: distinct execution, evidence, freshness, and advisory dimensions.
enum OperationsContract {
    static let version = "operations_v1"
    static let pageLimit = 25
    static let maximumOffset = 100_000
}

enum OperationsContractError: Error, Equatable {
    case unsupportedSchema(String)
    case invalidPagination
}

struct OperationsRunsPage: Decodable {
    let schemaVersion: String
    let items: [OperationRunV1]
    let total: Int
    let offset: Int
    let limit: Int
    let evidenceStatus: String
    let diagnostic: String?

    func validate(requestedOffset: Int, requestedLimit: Int) throws {
        guard schemaVersion == OperationsContract.version else { throw OperationsContractError.unsupportedSchema(schemaVersion) }
        guard offset == requestedOffset, limit == requestedLimit, total >= 0, offset <= OperationsContract.maximumOffset,
              items.count <= limit, Set(items.map(\.id)).count == items.count else { throw OperationsContractError.invalidPagination }
    }
}

struct OperationRunV1: Decodable, Identifiable {
    let id: String
    let operationType: String
    let startedAt: String?
    let completedAt: String?
    let executionStatus: String
    let evidenceStatus: String
    let recordCount: Int?
    let sourceType: String
    let semanticApproval: Bool
    let blockingStatus: String?
    let diagnostic: String?
}

struct OperationsFreshnessResponse: Decodable {
    let schemaVersion: String
    let items: [OperationsFreshnessItem]

    func validate() throws {
        guard schemaVersion == OperationsContract.version else { throw OperationsContractError.unsupportedSchema(schemaVersion) }
        guard Set(items.map(\.sourceId)).count == items.count else { throw ResearchAPIError.invalidPayload }
    }
}

struct OperationsFreshnessItem: Decodable, Identifiable {
    let sourceId: String
    let latestVerifiedDataAt: String?
    let latestSuccessfulIngestionAt: String?
    let latestDataDate: String?
    let recordCount: Int?
    let thresholdSeconds: Int?
    let blockingReason: String?
    let freshnessBasis: String
    let freshnessStatus: String
    let evidenceStatus: String
    var id: String { sourceId }
}

struct OperationsAlertsPage: Decodable {
    let schemaVersion: String
    let items: [OperationsAlert]
    let total: Int
    let offset: Int
    let limit: Int

    func validate(requestedOffset: Int, requestedLimit: Int) throws {
        guard schemaVersion == OperationsContract.version else { throw OperationsContractError.unsupportedSchema(schemaVersion) }
        guard offset == requestedOffset, limit == requestedLimit, total >= 0, offset <= OperationsContract.maximumOffset,
              items.count <= limit, Set(items.map(\.id)).count == items.count else { throw OperationsContractError.invalidPagination }
    }
}

struct OperationsAlert: Decodable, Identifiable {
    let id: String
    let category: String
    let severity: String
    let basis: String
    let sourceId: String
    let diagnostic: String
    let occurredAt: String?
    let verifiedCount: Int?
    let requiredCount: Int?
    let blockingStatus: String?
}

enum OperationsPresentation {
    static func title(_ value: String) -> String {
        return switch value {
        case "completed": "Completed"
        case "incomplete": "Incomplete"
        case "failed": "Failed"
        case "interrupted": "Interrupted"
        case "not_started": "Not started"
        case "validated": "Validated"
        case "partial": "Partial evidence"
        case "invalid": "Invalid evidence"
        case "unavailable": "Evidence unavailable"
        case "fresh": "Fresh"
        case "stale": "Stale"
        case "unknown": "Unknown"
        case "blocked": "Blocked"
        case "recorded": "Recorded incident"
        case "advisory": "Advisory"
        case "warning": "Warning"
        case "error": "Error"
        case "corporate-actions": "Corporate Actions"
        case "runner-tail": "Runner Tail"
        case "run-input-freeze": "Run Input Freeze"
        case "market_snapshot": "Market snapshot"
        case "dart_acquisition": "DART acquisition"
        case "dart_batch_acquisition": "DART batch acquisition"
        case "dart_session": "DART session"
        case "market_ingestion": "Market ingestion"
        case "pipeline_blocked": "Pipeline blocked"
        case "validation_failure": "Validation failure"
        case "execution_interruption": "Execution interrupted"
        case "acquisition_failure": "Acquisition failure"
        case "unresolved_reservation": "Unresolved reservation"
        case "missing_evidence": "Missing evidence"
        case "freshness_unknown": "Freshness unknown"
        case "freshness_stale": "Freshness stale"
        default: "Unrecognized (\(value))"
        }
    }

    static func timestamp(_ value: String?, timeZone: TimeZone = .current) -> String {
        guard let value else { return "Not available" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: value)
        if date == nil {
            parser.formatOptions = [.withInternetDateTime]
            date = parser.date(from: value)
        }
        guard let date else { return "Invalid timestamp" }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    static func freshnessBasis(_ value: String) -> String {
        switch value {
        case "acquisition_age": return "Acquisition age"
        case "unavailable": return "Freshness policy unavailable"
        default: return title(value)
        }
    }

    static func diagnostic(_ code: String?) -> String {
        guard let code, !code.isEmpty else { return "No diagnostic published." }
        return switch code {
        case "dart_evidence_busy": "DART evidence is temporarily busy; retry after the writer releases its lock."
        case "snapshot_pipeline_blocked": "The research snapshot reports a blocked pipeline."
        case "timestamp_and_freshness_policy_unavailable": "A verified timestamp and freshness policy are not available."
        case "acquisition_timestamp_or_policy_unavailable": "The acquisition timestamp or freshness policy is unavailable; freshness cannot be determined."
        case "freshness_policy_or_timestamp_unavailable": "A freshness policy or verified timestamp is unavailable."
        case "dart_evidence_not_configured": "DART evidence has not been configured on this server."
        case "recorded_outcome_not_provenance": "This recorded outcome does not independently verify ingestion provenance."
        case "market_audit_validation_failed": "Market collection audit validation failed."
        case "dart_evidence_validation_failed": "DART evidence validation failed."
        default: "Diagnostic available (\(code)); see backend operations documentation."
        }
    }
}
