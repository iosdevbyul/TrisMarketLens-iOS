import Foundation

enum AnalysisValidationPresentation {
    static func explanation(for value: String) -> String {
        switch value.lowercased() {
        case "verified":
            return "Research validation is marked verified by the publisher. This is not a prediction outcome."
        case "pending":
            return "Research validation is pending. No completed validation is implied."
        case "blocked":
            return "Research validation is blocked. The observation must not be treated as qualified."
        default:
            return "The research publisher returned an unrecognized validation state. No verified status is inferred."
        }
    }
}
