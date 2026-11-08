import Foundation

enum ResearchErrorGuidance {
    static func recovery(for error: Error) -> String {
        guard let failure = error as? ResearchAPIError else {
            return "Review connectivity before retrying. No cached or demonstration records are substituted."
        }
        switch failure {
        case .timeout:
            return "The request exceeded the configured time limit. Check network stability, then retry explicitly."
        case .offline:
            return "Restore Wi-Fi or cellular access, then press Retry request. No automatic retry is scheduled."
        case .transport:
            return "Confirm the API address and network availability before retrying."
        case .httpStatus(429):
            return "The service is rate limiting requests. Retry later; repeated automatic requests are disabled."
        case .httpStatus(503):
            return "The server is reachable but may need an approved snapshot or publication configured by an operator."
        case .httpStatus(401), .httpStatus(403):
            return "Access must be granted by the service operator. Repeating the request cannot bypass authorization."
        case .httpStatus(404):
            return "Confirm that this API route and publication exist on the configured server."
        case .invalidPayload, .invalidResponse:
            return "The response failed validation. No partial or mock results have been accepted."
        case .invalidConfiguration:
            return "Correct TRIS_DATA_MODE and TRIS_API_BASE_URL before retrying."
        case .httpStatus:
            return "Check service health and try again manually when the service is available."
        }
    }

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
        case .timeout:
            return "The research request timed out. Check the connection, then retry manually."
        case .offline:
            return "Your network connection is offline or was interrupted. Reconnect, then retry manually."
        case .httpStatus(let code):
            switch code {
            case 401: return "Research access requires authentication."
            case 403: return "Access to this research endpoint is denied."
            case 404: return "The requested research resource was not found."
            case 503: return "Research API is reachable, but the snapshot reader or reviewed analysis publication is not configured (HTTP 503)."
            case 429: return "Too many requests. Wait before trying again."
            case 500...599: return "The research service is currently unavailable (HTTP \(code)). Try again later."
            default: return "Research request failed (HTTP \(code))."
            }
        }
    }
}
