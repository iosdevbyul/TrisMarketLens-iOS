import Foundation

enum OperationsStatusPresentation {
    static func connectionTitle(_ state: String) -> String {
        switch state.lowercased() {
        case "connected": "Connected"
        case "degraded": "Degraded"
        case "not_connected", "disconnected": "Not connected"
        default: "Unknown connection state: \(state)"
        }
    }

    static func runStateTitle(_ state: String) -> String {
        switch state.lowercased() {
        case "completed", "success", "succeeded": "Completed"
        case "failed", "failure": "Failed"
        case "running", "in_progress": "In progress"
        case "pending", "queued": "Pending"
        case "blocked": "Blocked"
        default: "Unknown: \(state)"
        }
    }
}
