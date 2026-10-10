import Foundation

protocol ProjectStatusSource {
    func getProjectStatus() async throws -> ProjectStatus
}

// Explicit fixtures prevent unfinished backend responses being presented as live research.
struct MockProjectStatusSource: ProjectStatusSource {
    func getProjectStatus() async throws -> ProjectStatus {
        ProjectStatus(
            productName: "TrisMarketLens",
            sourceLabel: "Mock research snapshot",
            metrics: [
                SummaryMetric(label: "Universe", value: "993", detail: "Sample KOSPI coverage"),
                SummaryMetric(label: "Market data", value: "Demo", detail: "Not connected to the research API"),
                SummaryMetric(label: "Qualified model", value: "Pending", detail: "Awaiting verified API data"),
                SummaryMetric(label: "OOS evaluation", value: "Pending", detail: "No live evaluation loaded")
            ],
            evidence: [
                ResearchCheckpoint(label: "Exchange calendar", state: .inProgress, detail: "Sample checkpoint"),
                ResearchCheckpoint(label: "Corporate actions", state: .blocked, detail: "Sample checkpoint")
            ],
            baseline: [
                ResearchCheckpoint(label: "Historical backtest", state: .notStarted, detail: "No execution result loaded")
            ]
        )
    }
}
