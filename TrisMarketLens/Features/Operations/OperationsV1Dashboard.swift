import SwiftUI
import WakTrainerDesignSystem

struct OperationsV1Dashboard: View {
    let source: any OperationsV1Source

    @State private var runs: [OperationRunV1] = []
    @State private var freshness: [OperationsFreshnessItem] = []
    @State private var alerts: [OperationsAlert] = []
    @State private var runsTotal = 0
    @State private var alertsTotal = 0
    @State private var runsEvidence = "unavailable"
    @State private var runsDiagnostic: String?
    @State private var runsLoading = false
    @State private var freshnessLoading = false
    @State private var alertsLoading = false
    @State private var runsError: String?
    @State private var freshnessError: String?
    @State private var alertsError: String?
    @State private var runsRequestID = UUID()
    @State private var freshnessRequestID = UUID()
    @State private var alertsRequestID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: WakSpacing.regular) {
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Execution history")
                    Text("Execution and evidence validation are separate. DART acquisition is not corporate-action approval.")
                        .font(.footnote).foregroundStyle(WakColor.textSecondary)
                    Text("Evidence: \(OperationsPresentation.title(runsEvidence))")
                    if let runsDiagnostic { Text(OperationsPresentation.diagnostic(runsDiagnostic)).font(.footnote) }
                    if runs.isEmpty && !runsLoading && runsError == nil {
                        Text("No recorded runs available.").foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(runs) { run in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(OperationsPresentation.title(run.operationType)).font(.headline)
                            Text(run.id).font(.caption.monospaced()).textSelection(.enabled)
                            LabeledContent("Execution", value: OperationsPresentation.title(run.executionStatus))
                            LabeledContent("Evidence", value: OperationsPresentation.title(run.evidenceStatus))
                            LabeledContent("Records", value: run.recordCount.map { $0.formatted() } ?? "Not available")
                            LabeledContent("Started", value: OperationsPresentation.timestamp(run.startedAt))
                            LabeledContent("Completed", value: OperationsPresentation.timestamp(run.completedAt))
                            Text("Semantic approval: \(run.semanticApproval ? "Approved" : "Not approved")")
                            if let blocking = run.blockingStatus { Text("Blocking: \(OperationsPresentation.title(blocking))") }
                            if run.diagnostic != nil { Text(OperationsPresentation.diagnostic(run.diagnostic)).font(.footnote) }
                            Divider()
                        }
                    }
                    if let runsError { failure(runsError, action: { Task { await loadRuns(reset: runs.isEmpty) } }) }
                    if runsLoading { ProgressView("Loading runs") }
                    if !runsLoading && runs.count < runsTotal {
                        Button("Load more runs") { Task { await loadRuns(reset: false) } }
                    }
                    Text("Showing \(runs.count) of \(runsTotal) runs").font(.caption).foregroundStyle(WakColor.textSecondary)
                }
            }

            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Source freshness")
                    Text("DART acquisition recency does not establish document publication completeness.")
                        .font(.footnote).foregroundStyle(WakColor.textSecondary)
                    if freshness.isEmpty && !freshnessLoading && freshnessError == nil {
                        Text("No freshness sources reported.").foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(freshness) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(OperationsPresentation.title(item.sourceId)).font(.headline)
                            LabeledContent("Freshness", value: OperationsPresentation.title(item.freshnessStatus))
                            LabeledContent("Evidence", value: OperationsPresentation.title(item.evidenceStatus))
                            LabeledContent("Latest data date", value: item.latestDataDate ?? "Not available")
                            LabeledContent("Verified data at", value: OperationsPresentation.timestamp(item.latestVerifiedDataAt))
                            LabeledContent("Successful ingestion at", value: OperationsPresentation.timestamp(item.latestSuccessfulIngestionAt))
                            LabeledContent("Records", value: item.recordCount.map { $0.formatted() } ?? "Not available")
                            LabeledContent("Freshness basis", value: OperationsPresentation.title(item.freshnessBasis))
                            if let seconds = item.thresholdSeconds { LabeledContent("Threshold", value: "\(seconds) seconds") }
                            if let reason = item.blockingReason { Text(OperationsPresentation.diagnostic(reason)).font(.footnote) }
                            Divider()
                        }
                    }
                    if let freshnessError { failure(freshnessError, action: { Task { await loadFreshness() } }) }
                    if freshnessLoading { ProgressView("Loading freshness") }
                }
            }

            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Operational alerts")
                    if alerts.isEmpty && !alertsLoading && alertsError == nil {
                        Text("No operational alerts reported.").foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(alerts) { alert in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(OperationsPresentation.title(alert.category)).font(.headline)
                            Text(alert.id).font(.caption.monospaced()).textSelection(.enabled)
                            LabeledContent("Severity", value: OperationsPresentation.title(alert.severity))
                            LabeledContent("Basis", value: OperationsPresentation.title(alert.basis))
                            LabeledContent("Source", value: OperationsPresentation.title(alert.sourceId))
                            LabeledContent("Occurred", value: OperationsPresentation.timestamp(alert.occurredAt))
                            if let count = alert.verifiedCount { LabeledContent("Verified count", value: count.formatted()) }
                            if let count = alert.requiredCount { LabeledContent("Required count", value: count.formatted()) }
                            Text(OperationsPresentation.diagnostic(alert.diagnostic)).font(.footnote)
                            Divider()
                        }
                    }
                    if let alertsError { failure(alertsError, action: { Task { await loadAlerts(reset: alerts.isEmpty) } }) }
                    if alertsLoading { ProgressView("Loading alerts") }
                    if !alertsLoading && alerts.count < alertsTotal {
                        Button("Load more alerts") { Task { await loadAlerts(reset: false) } }
                    }
                    Text("Showing \(alerts.count) of \(alertsTotal) alerts").font(.caption).foregroundStyle(WakColor.textSecondary)
                }
            }
            Button("Refresh operations") {
                Task { await refreshAll() }
            }
            .accessibilityLabel("Refresh operations runs, freshness, and alerts")
        }
        .task { await refreshAll() }
    }

    @ViewBuilder private func failure(_ message: String, action: @escaping () -> Void) -> some View {
        Text(message).foregroundStyle(WakColor.textSecondary)
        Button("Retry") { action() }
    }

    private func refreshAll() async {
        async let a: Void = loadRuns(reset: true)
        async let b: Void = loadFreshness()
        async let c: Void = loadAlerts(reset: true)
        _ = await (a, b, c)
    }

    private func loadRuns(reset: Bool) async {
        guard !runsLoading else { return }
        let requestID = UUID()
        runsRequestID = requestID
        runsLoading = true
        runsError = nil
        let offset = reset ? 0 : runs.count
        do {
            let page = try await source.getRuns(offset: offset, limit: OperationsContract.pageLimit)
            guard runsRequestID == requestID else { return }
            if !Task.isCancelled {
                if reset { runs = page.items } else {
                    let existing = Set(runs.map(\.id))
                    runs.append(contentsOf: page.items.filter { !existing.contains($0.id) })
                }
                runsTotal = page.total
                runsEvidence = page.evidenceStatus
                runsDiagnostic = page.diagnostic
            }
        } catch {
            guard runsRequestID == requestID else { return }
            if !Task.isCancelled { runsError = message(error) }
        }
        if runsRequestID == requestID { runsLoading = false }
    }

    private func loadFreshness() async {
        guard !freshnessLoading else { return }
        let requestID = UUID()
        freshnessRequestID = requestID
        freshnessLoading = true
        freshnessError = nil
        do {
            let result = try await source.getFreshness()
            guard freshnessRequestID == requestID else { return }
            if !Task.isCancelled { freshness = result.items }
        } catch {
            guard freshnessRequestID == requestID else { return }
            if !Task.isCancelled { freshnessError = message(error) }
        }
        if freshnessRequestID == requestID { freshnessLoading = false }
    }

    private func loadAlerts(reset: Bool) async {
        guard !alertsLoading else { return }
        let requestID = UUID()
        alertsRequestID = requestID
        alertsLoading = true
        alertsError = nil
        let offset = reset ? 0 : alerts.count
        do {
            let page = try await source.getAlerts(offset: offset, limit: OperationsContract.pageLimit)
            guard alertsRequestID == requestID else { return }
            if !Task.isCancelled {
                if reset { alerts = page.items } else {
                    let existing = Set(alerts.map(\.id))
                    alerts.append(contentsOf: page.items.filter { !existing.contains($0.id) })
                }
                alertsTotal = page.total
            }
        } catch {
            guard alertsRequestID == requestID else { return }
            if !Task.isCancelled { alertsError = message(error) }
        }
        if alertsRequestID == requestID { alertsLoading = false }
    }

    private func message(_ error: Error) -> String {
        if case OperationsContractError.unsupportedSchema = error {
            return "Unsupported Operations API schema version."
        }
        if case OperationsContractError.invalidPagination = error {
            return "Invalid Operations pagination response."
        }
        return ResearchErrorGuidance.message(for: error)
    }
}
