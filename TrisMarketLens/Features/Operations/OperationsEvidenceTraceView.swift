import SwiftUI
import WakTrainerDesignSystem

/// Read-only, source-separated trace; no implied lineage between independent projections.
struct OperationsEvidenceTraceView: View {
    let operations: any OperationsV1Source
    let screener: any ScreenerSource
    let catalog: any ResearchCatalogSource
    let isHTTP: Bool

    @State private var snapshot = OperationsTraceSnapshot()
    @State private var runs: [OperationRunV1] = []
    @State private var alerts: [OperationsAlert] = []
    @State private var freshness: [OperationsFreshnessItem] = []
    @State private var errors: [OperationsTraceStage: String] = [:]
    @State private var loading = true
    @State private var requestID = UUID()

    var body: some View {
        List {
            Section {
                Label(
                    isHTTP ? "Read-only backend evidence. Independent projections are not a proven custody chain." :
                        "Disconnected/demo mode. No independently verified operations evidence.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(WakColor.textSecondary)
                if loading { ProgressView("Inspecting published sources") }
                Button("Refresh source trace") { Task { await reload() } }
                    .disabled(loading)
            }

            ForEach(OperationsTraceStage.allCases) { stage in
                Section(stage.title) {
                    LabeledContent("State", value: snapshot.state(for: stage, isHTTP: isHTTP).label)
                    if let error = errors[stage] {
                        Text(error).foregroundStyle(WakColor.destructive)
                    }
                    stageDetails(stage)
                    Text(stage.limitation)
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                }
            }

            Section("Verification boundary") {
                Text("The operational-market source, scheduler execution authority, and research snapshot may use separate datasets. This view does not assert that a market row was admitted to AI inference.")
                    .font(.footnote)
                Text("No exchange completeness, PIT/OOS qualification, investment approval, order execution or real profitability is inferred.")
                    .font(.footnote)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("Operations Trace")
        .refreshable { await reload() }
        .task { await reload() }
    }

    @ViewBuilder
    private func stageDetails(_ stage: OperationsTraceStage) -> some View {
        switch stage {
        case .execution:
            if let runCount = snapshot.runCount {
                LabeledContent("Runs on first page", value: "\(runCount)")
                LabeledContent("Evidence state", value: OperationsPresentation.title(snapshot.runEvidenceStatus ?? "unavailable"))
                if let diagnostic = snapshot.runDiagnostic {
                    Text(OperationsPresentation.diagnostic(diagnostic)).font(.footnote)
                }
            }
            ForEach(runs) { run in
                DisclosureGroup(OperationsPresentation.title(run.operationType) + " · " + run.id) {
                    LabeledContent("Execution", value: OperationsPresentation.title(run.executionStatus))
                    LabeledContent("Evidence", value: OperationsPresentation.title(run.evidenceStatus))
                    LabeledContent("Source type", value: run.sourceType)
                    LabeledContent("Semantic approval", value: run.semanticApproval ? "Backend approved" : "Not approved")
                    LabeledContent("Records", value: run.recordCount.map(String.init) ?? "Unavailable")
                    LabeledContent("Started", value: OperationsPresentation.timestamp(run.startedAt))
                    LabeledContent("Completed", value: OperationsPresentation.timestamp(run.completedAt))
                    if let blocking = run.blockingStatus {
                        LabeledContent("Blocking status", value: OperationsPresentation.title(blocking))
                    }
                    if run.diagnostic != nil { Text(OperationsPresentation.diagnostic(run.diagnostic)).font(.footnote) }
                    Text("Run ID: " + run.id).font(.caption.monospaced()).textSelection(.enabled)
                }
            }
            Text("First page only. Additional runs and source pagination remain available in Operations.")
                .font(.caption).foregroundStyle(WakColor.textSecondary)
        case .freshness:
            if let count = snapshot.freshnessCount { LabeledContent("Reported sources", value: "\(count)") }
            ForEach(freshness) { item in
                DisclosureGroup(item.sourceId + " · " + OperationsPresentation.title(item.freshnessStatus)) {
                    LabeledContent("Evidence", value: OperationsPresentation.title(item.evidenceStatus))
                    LabeledContent("Basis", value: OperationsPresentation.freshnessBasis(item.freshnessBasis))
                    LabeledContent("Latest data date", value: item.latestDataDate ?? "Unavailable")
                    LabeledContent("Verified at", value: OperationsPresentation.timestamp(item.latestVerifiedDataAt))
                    LabeledContent("Ingested at", value: OperationsPresentation.timestamp(item.latestSuccessfulIngestionAt))
                    if let reason = item.blockingReason {
                        Text(OperationsPresentation.diagnostic(reason)).font(.footnote)
                    }
                }
            }
        case .incidents:
            if let total = snapshot.alertTotal { LabeledContent("Total reported alerts", value: "\(total)") }
            ForEach(alerts) { alert in
                DisclosureGroup(OperationsPresentation.title(alert.category) + " · " + alert.id) {
                    LabeledContent("Severity", value: OperationsPresentation.title(alert.severity))
                    LabeledContent("Source", value: alert.sourceId)
                    LabeledContent("Evidence basis", value: OperationsPresentation.title(alert.basis))
                    LabeledContent("Occurred", value: OperationsPresentation.timestamp(alert.occurredAt))
                    Text(OperationsPresentation.diagnostic(alert.diagnostic)).font(.footnote)
                    if let status = alert.blockingStatus {
                        LabeledContent("Blocking status", value: OperationsPresentation.title(status))
                    }
                    Text("Alert ID: " + alert.id).font(.caption.monospaced()).textSelection(.enabled)
                }
            }
            Text("Alerts are displayed independently; identical source labels do not prove a run-to-alert event link.")
                .font(.caption).foregroundStyle(WakColor.textSecondary)
        case .researchPublication:
            if let count = snapshot.screenerCount {
                LabeledContent("Published screener records", value: "\(count)")
            }
            Text("This read-only count is not tied to a specific operational run.")
                .font(.caption).foregroundStyle(WakColor.textSecondary)
        case .evidence:
            if let count = snapshot.evidenceCount {
                LabeledContent("Evidence layers", value: "\(count)")
                LabeledContent("Unresolved layers", value: "\(snapshot.evidenceWithBlockers)")
            }
            Text("Evidence states describe research documentation, not an implicit operational-to-research join.")
                .font(.caption).foregroundStyle(WakColor.textSecondary)
        }
    }

    @MainActor
    private func reload() async {
        let id = UUID()
        requestID = id
        loading = true
        snapshot = OperationsTraceSnapshot()
        errors = [:]
        runs = []
        alerts = []
        freshness = []

        // Separate try/catch blocks intentionally preserve independent source failures.
        do {
            let page = try await operations.getRuns(offset: 0, limit: OperationsContract.pageLimit)
            guard requestID == id, !Task.isCancelled else { return }
            runs = page.items
            snapshot.runCount = page.items.count
            snapshot.runEvidenceStatus = page.evidenceStatus
            snapshot.runDiagnostic = page.diagnostic
            snapshot.runsWithBlockers = page.items.filter {
                !$0.semanticApproval || $0.blockingStatus != nil || ["invalid", "blocked", "unavailable"].contains($0.evidenceStatus)
            }.count
        } catch {
            guard requestID == id else { return }
            record(error, stage: .execution)
        }
        do {
            let data = try await operations.getFreshness()
            guard requestID == id, !Task.isCancelled else { return }
            freshness = data.items
            snapshot.freshnessCount = data.items.count
            snapshot.freshnessWithBlockers = data.items.filter {
                $0.blockingReason != nil || ["blocked", "stale", "unknown"].contains($0.freshnessStatus) ||
                ["invalid", "blocked", "unavailable"].contains($0.evidenceStatus)
            }.count
        } catch {
            guard requestID == id else { return }
            record(error, stage: .freshness)
        }
        do {
            let page = try await operations.getAlerts(offset: 0, limit: OperationsContract.pageLimit)
            guard requestID == id, !Task.isCancelled else { return }
            alerts = page.items
            snapshot.alertCount = page.items.count
            snapshot.alertTotal = page.total
        } catch {
            guard requestID == id else { return }
            record(error, stage: .incidents)
        }
        do {
            let data = try await screener.getScreener()
            guard requestID == id, !Task.isCancelled else { return }
            snapshot.screenerCount = data.entries.count
        } catch {
            guard requestID == id else { return }
            record(error, stage: .researchPublication)
        }
        do {
            let layers = try await catalog.getEvidenceLayers()
            guard requestID == id, !Task.isCancelled else { return }
            snapshot.evidenceCount = layers.count
            snapshot.evidenceWithBlockers = layers.filter { $0.state != .verified }.count
        } catch {
            guard requestID == id else { return }
            record(error, stage: .evidence)
        }
        if requestID == id { loading = false }
    }

    @MainActor
    private func record(_ error: Error, stage: OperationsTraceStage) {
        snapshot.failures.insert(stage)
        errors[stage] = ResearchErrorGuidance.message(for: error)
    }
}
