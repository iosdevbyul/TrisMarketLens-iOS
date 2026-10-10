import Foundation

enum ResearchErrorGuidance {
    static func message(for error: Error) -> String {
        guard let failure = error as? ResearchAPIError else {
            return "The research source is unavailable. Check your connection and try again."
        }
        switch failure {
        case .invalidConfiguration:
            return "The research server configuration is invalid. Check the API base URL."
        case .invalidResponse:
            return "The research server returned an unexpected response."
        case .invalidPayload:
            return "The research response could not be validated. No unverified results were displayed."
        case .transport:
            return "Unable to reach the research server. Check the connection and try again."
        case .httpStatus(let code):
            switch code {
            case 401: return "Research access requires authentication."
            case 403: return "Access to this research endpoint is denied."
            case 404: return "The requested research resource was not found."
            case 429: return "Too many requests. Wait before trying again."
            case 500...599: return "The research service is currently unavailable (HTTP \(code)). Try again later."
            default: return "Research request failed (HTTP \(code))."
            }
        }
    }
}
