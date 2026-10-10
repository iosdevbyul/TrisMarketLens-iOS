import Foundation

/// Mirrors the web's strict ISO calendar-date and offset timestamp contracts.
enum ResearchPayloadIntegrity {
    static func date(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let bytes = Array(value.utf8)
        guard bytes.count == 10,
              bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({ index, byte in
                  index == 4 || index == 7 || (48...57).contains(byte)
              }) else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let parsed = formatter.date(from: value) else { return false }
        return formatter.string(from: parsed) == value
    }

    static func timestamp(_ value: String) -> Bool {
        guard value.hasSuffix("Z") ||
                value.range(of: #"[+-][0-9]{2}:[0-9]{2}$"#, options: .regularExpression) != nil else {
            return false
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: value) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) != nil
    }

    static func score(_ value: Double?) -> Bool {
        value.map { $0.isFinite && (0...1).contains($0) } ?? true
    }

    static func ticker(_ value: String) -> Bool {
        value.count == 6 && value.utf8.allSatisfy { (48...57).contains($0) }
    }

    static func analysisFields(
        ticker: String, modelId: String, modelVersion: String,
        date: String, analyzedAt: String, direction: String,
        validation: String, score: Double?
    ) -> Bool {
        Self.ticker(ticker) &&
        !modelId.isEmpty && !modelVersion.isEmpty &&
        Self.date(date) && Self.timestamp(analyzedAt) &&
        ["up", "down", "neutral"].contains(direction) &&
        ["verified", "pending", "blocked"].contains(validation) &&
        Self.score(score)
    }

    static func bar(_ bar: OhlcvBar, after previous: String) -> Bool {
        guard date(bar.date), bar.date > previous, bar.volume >= 0,
              [bar.open, bar.high, bar.low, bar.close].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            return false
        }
        let noTrade = bar.open == 0 && bar.high == 0 && bar.low == 0 &&
            bar.close > 0 && bar.volume == 0
        let normal = bar.open > 0 && bar.close > 0 && bar.low > 0 &&
            bar.high >= max(bar.open, bar.close, bar.low) &&
            bar.low <= min(bar.open, bar.close)
        return noTrade || normal
    }

    static func evaluation(_ item: PredictionEvaluation) -> Bool {
        guard ticker(item.ticker), !item.id.isEmpty, !item.analysisId.isEmpty,
              !item.policyId.isEmpty, (1...1000).contains(item.horizonSessions),
              date(item.referenceDate),
              item.evaluationDate.map(date) ?? true,
              item.evaluatedAt.map(timestamp) ?? true,
              ["correct", "incorrect", "inconclusive", "pending"].contains(item.verdict),
              item.referencePrice.map({ $0.isFinite && $0 > 0 }) ?? true,
              item.evaluationPrice.map({ $0.isFinite && $0 > 0 }) ?? true,
              item.realizedReturn.map(\.isFinite) ?? true else {
            return false
        }
        if item.verdict == "pending" {
            return item.evaluatedAt == nil &&
                item.evaluationDate == nil &&
                item.evaluationPrice == nil &&
                item.realizedReturn == nil
        }
        return true
    }
}
