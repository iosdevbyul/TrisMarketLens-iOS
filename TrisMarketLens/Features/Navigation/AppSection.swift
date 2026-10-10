import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case stocks
    case screener
    case history
    case models
    case evidence
    case backtesting
    case operations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .stocks: "Stocks"
        case .screener: "AI Screener"
        case .history: "AI Analysis History"
        case .models: "Models"
        case .evidence: "Evidence"
        case .backtesting: "Backtesting"
        case .operations: "Operations"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .screener: "line.3.horizontal.decrease.circle"
        case .history: "clock.arrow.circlepath"
        case .models: "brain"
        case .evidence: "checkmark.shield"
        case .backtesting: "chart.bar.xaxis"
        case .operations: "server.rack"
        }
    }
}
