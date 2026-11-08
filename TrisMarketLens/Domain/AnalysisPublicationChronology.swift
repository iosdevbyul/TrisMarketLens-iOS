import Foundation

/// Local chronology review of an existing published analysis record.
/// It does not authenticate historical PIT availability or publisher approval.
enum AnalysisPublicationChronology: Equatable {
    case consistent
    case invalidTimestamp
    case futureDataThrough
    case invalidPublication

    var label: String {
        switch self {
        case .consistent: "Dates structurally consistent; PIT not verified"
        case .invalidTimestamp: "Invalid publication timestamp/date"
        case .futureDataThrough: "Data-through date follows analysis date"
        case .invalidPublication: "Publication fields conflict with review status"
        }
    }

    static func assess(_ record: StockAnalysisRecord) -> AnalysisPublicationChronology {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var analyzed = iso.date(from: record.analyzedAt)
        if analyzed == nil {
            iso.formatOptions = [.withInternetDateTime]
            analyzed = iso.date(from: record.analyzedAt)
        }
        let dateParser = ISO8601DateFormatter()
        dateParser.timeZone = TimeZone(secondsFromGMT: 0)!
        dateParser.formatOptions = [.withFullDate]
        guard let analyzed,
              record.dataThrough.utf8.count == 10,
              let dataDate = dateParser.date(from: record.dataThrough),
              dateParser.string(from: dataDate) == record.dataThrough else {
            return .invalidTimestamp
        }
        let analysisDate = dateParser.string(from: analyzed)
        if record.dataThrough > analysisDate { return .futureDataThrough }
        if !["verified", "pending", "blocked"].contains(record.validation) {
            return .invalidPublication
        }
        if let score = record.score {
            guard score.isFinite, (0...1).contains(score), record.validation == "verified" else {
                return .invalidPublication
            }
        }
        return .consistent
    }
}
