import Foundation

enum StockValueFormatter {
    static func price(_ value: Double) -> String {
        value.formatted(.number.grouping(.automatic).precision(.fractionLength(0...2)))
    }

    static func volume(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func changePercent(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return sign + value.formatted(.number.grouping(.automatic).precision(.fractionLength(2))) + "%"
    }
}
