import Foundation

/// Operational observations are never reviewed research evidence or trading authorization.
struct OperationalMarketSummary: Decodable {
    let schemaVersion: String
    let evidenceStatus: String
    let observationCount: Int
    let tickerCount: Int
    let tradingDayCount: Int
    let firstTradingDate: String?
    let lastTradingDate: String?

    func validate() throws {
        guard schemaVersion == "operational_snapshot_summary_v1",
              evidenceStatus == "unreviewed",
              observationCount >= 0, tickerCount >= 0, tradingDayCount >= 0,
              tickerCount <= observationCount, tradingDayCount <= observationCount,
              (firstTradingDate == nil) == (lastTradingDate == nil),
              (observationCount == 0) == (firstTradingDate == nil) else {
            throw ResearchAPIError.invalidPayload
        }
        if let firstTradingDate, let lastTradingDate {
            guard OperationalMarketContract.validDate(firstTradingDate),
                  OperationalMarketContract.validDate(lastTradingDate),
                  firstTradingDate <= lastTradingDate else {
                throw ResearchAPIError.invalidPayload
            }
        }
    }
}

struct OperationalMarketTicker: Decodable, Identifiable {
    let ticker: String
    let latestDataDate: String
    var id: String { ticker }

    func validate() throws {
        guard HistoricalPortfolioContract.validTicker(ticker),
              OperationalMarketContract.validDate(latestDataDate) else {
            throw ResearchAPIError.invalidPayload
        }
    }
}

struct OperationalMarketPage: Decodable {
    let schemaVersion: String
    let evidenceStatus: String
    let items: [OperationalMarketTicker]
    let total: Int
    let offset: Int
    let limit: Int

    func validate(offset expected: Int) throws {
        guard schemaVersion == "operational_market_v1",
              evidenceStatus == "unreviewed",
              total >= 0, offset == expected,
              limit == OperationalMarketContract.pageLimit,
              items.count <= limit,
              items.count <= max(0, total - offset),
              Set(items.map(\.ticker)).count == items.count else {
            throw ResearchAPIError.invalidPayload
        }
        try items.forEach { try $0.validate() }
    }
}

enum OperationalMarketContract {
    static let pageLimit = 25
    static let maximumOffset = 100_000

    static func validDate(_ value: String) -> Bool {
        guard value.utf8.count == 10,
              let date = ISO8601DateFormatter().date(from: value + "T00:00:00Z") else {
            return false
        }
        let format = ISO8601DateFormatter()
        format.formatOptions = [.withFullDate]
        format.timeZone = TimeZone(secondsFromGMT: 0)!
        return format.string(from: date) == value
    }

    static func validateBars(_ series: OhlcvSeries, ticker: String) throws {
        guard series.ticker == ticker, series.bars.count <= 2500 else {
            throw ResearchAPIError.invalidPayload
        }
        var lastDate = ""
        for bar in series.bars {
            guard validDate(bar.date), bar.date > lastDate,
                  bar.open.isFinite, bar.high.isFinite, bar.low.isFinite, bar.close.isFinite,
                  bar.open >= 0, bar.close >= 0, bar.low >= 0, bar.high >= 0,
                  bar.high >= max(bar.open, bar.close, bar.low),
                  bar.low <= min(bar.open, bar.close),
                  bar.volume >= 0 else {
                throw ResearchAPIError.invalidPayload
            }
            lastDate = bar.date
        }
    }
}
