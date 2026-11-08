import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case stocks
    case screener
    case history
    case workbench
    case researchPath
    case models
    case evidence
    case backtesting
    case historicalPortfolios
    case operations
    case operationsTrace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .stocks: "Stocks"
        case .screener: "AI Screener"
        case .history: "AI Analysis History"
        case .workbench: "Research Workbench"
        case .researchPath: "Research Path"
        case .models: "Models"
        case .evidence: "Evidence"
        case .backtesting: "Backtesting"
        case .historicalPortfolios: "Historical Portfolios"
        case .operations: "Operations"
        case .operationsTrace: "Operations Trace"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .screener: "line.3.horizontal.decrease.circle"
        case .history: "clock.arrow.circlepath"
        case .workbench: "point.3.connected.trianglepath.dotted"
        case .researchPath: "point.topleft.down.curvedto.point.bottomright.up"
        case .models: "brain"
        case .evidence: "checkmark.shield"
        case .backtesting: "chart.bar.xaxis"
        case .historicalPortfolios: "archivebox"
        case .operations: "server.rack"
        case .operationsTrace: "point.3.filled.connected.trianglepath.dotted"
        }
    }
}
