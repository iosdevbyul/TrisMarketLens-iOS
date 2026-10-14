import Foundation

enum ModelMetricFormatter {
    static func score(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(6)))
    }
}
