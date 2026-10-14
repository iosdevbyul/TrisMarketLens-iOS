import SwiftUI
import WakTrainerDesignSystem

struct BacktestingOperationsView: View {
    enum Page {
        case backtesting
        case operations

        var title: String {
            switch self {
            case .backtesting: "Backtesting"
            case .operations: "Operations"
            }
        }
    }

    let page: Page
    private let source: any BacktestingOperationsSource
    private let diagnostic: ResearchConnectionDiagnostic?
    @State private var connection = ResearchConnectionReport.notConfigured
    @State private var activeRequestID = UUID()
    @State private var activeDiagnosticID = UUID()
    @State private var endpointResults: [ResearchEndpointResult] = []
    @State private var checkingConnection = false
    @State private var baseline: BaselineBacktestSnapshot?
    @State private var operations = OperationsSnapshot.disconnected
    @State private var loading = true
    @State private var failed = false
    @State private var operationsHistoryMissing = false
    @State private var errorMessage: String?

    init(page: Page, source: any BacktestingOperationsSource = DisconnectedBacktestingOperationsSource(), diagnostic: ResearchConnectionDiagnostic? = nil) {
        self.diagnostic = diagnostic
        self.page = page
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WakSpacing.regular) {
                if page == .operations {
                    Label(diagnostic == nil ? "Research API not connected" : "Research API configured", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                    connectionContent
                    endpointContent
                }

                if loading {
                    ProgressView("Loading research")
                } else if page == .operations && operationsHistoryMissing {
                    operationsHistoryUnavailableContent
                } else if failed {
                    ContentUnavailableView("Research unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage ?? "Unable to load research operations."))
                    Button("Retry") { Task { await reload() } }
                } else {
                    switch page {
                    case .backtesting: backtestingContent
                    case .operations: operationsContent
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(WakSpacing.regular)
        }
        .background(WakColor.background)
        .navigationTitle(page.title)
        .refreshable { await reload() }
        .onAppear { Task { await reload() } }
    }

    private func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        guard !Task.isCancelled else { return }
        loading = true
        failed = false
        operationsHistoryMissing = false
        errorMessage = nil
        if page == .operations { await refreshConnection() }
        guard activeRequestID == requestID else { return }
        if Task.isCancelled {
            loading = false
            return
        }
        do {
            switch page {
            case .backtesting:
                let response = try await source.getBaseline()
                guard activeRequestID == requestID else { return }
                if Task.isCancelled {
                    loading = false
                    return
                }
                baseline = response
            case .operations:
                let response = try await source.getOperations()
                guard activeRequestID == requestID else { return }
                if Task.isCancelled {
                    loading = false
                    return
                }
                operations = response
            }
        } catch {
            guard activeRequestID == requestID else { return }
            if Task.isCancelled {
                loading = false
                return
            }
            if page == .operations, case ResearchAPIError.httpStatus(404) = error {
                operationsHistoryMissing = true
            } else {
                failed = true
                errorMessage = ResearchErrorGuidance.message(for: error)
            }
        }
        loading = false
    }

    private var operationsHistoryUnavailableContent: some View {
        WakCard {
            VStack(alignment: .leading, spacing: WakSpacing.small) {
                WakSectionHeader("Operations history unavailable")
                Text("This server does not provide the operations history endpoint (HTTP 404).")
                    .foregroundStyle(WakColor.textSecondary)
                Text("Health and other research endpoints remain independently available. No analysis run history or freshness data is inferred.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }
        }
    }

    private var connectionContent: some View {
        WakCard {
            VStack(alignment: .leading, spacing: WakSpacing.small) {
                WakSectionHeader("API connectivity")
                Text(connection.state == .reachable ? "Health endpoint reachable" :
                     connection.state == .notConfigured ? "Not configured" :
                     connection.state == .incompatible ? "Incompatible response" :
                     connection.state == .unhealthy ? "Unhealthy response" : "Unavailable")
                    .font(.headline)
                Text(connection.detail)
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
                if diagnostic != nil {
                    Button("Check connection again") {
                        Task { await refreshConnection() }
                    }
                    .disabled(checkingConnection)
                    if checkingConnection {
                        ProgressView("Checking API endpoints")
                            .font(.footnote)
                    }
                }
            }
        }
    }

    @ViewBuilder private var endpointContent: some View {
        if diagnostic != nil {
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Research endpoint readiness")
                    if endpointResults.isEmpty {
                        Text(checkingConnection ? "Checking endpoint availability…" : "No endpoint diagnostics available.")
                            .font(.footnote)
                            .foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(endpointResults) { result in
                        VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                            Text(result.name).font(.headline)
                            Text(result.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(WakColor.textSecondary)
                                .textSelection(.enabled)
                            Label(String(describing: result.state).capitalized, systemImage: result.state == .available ? "checkmark.circle" : "info.circle")
                                .font(.subheadline.weight(.medium))
                            Text(result.detail).font(.footnote).foregroundStyle(WakColor.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func refreshConnection() async {
        let diagnosticID = UUID()
        activeDiagnosticID = diagnosticID
        guard !Task.isCancelled else { return }
        checkingConnection = true
        let response = await diagnostic?.check() ?? .notConfigured
        guard activeDiagnosticID == diagnosticID else { return }
        if Task.isCancelled {
            checkingConnection = false
            return
        }
        connection = response
        endpointResults = []
        if let diagnostic, response.state == .reachable {
            let results = await ResearchEndpointDiagnostic(client: diagnostic.client).check()
            guard activeDiagnosticID == diagnosticID else { return }
            if Task.isCancelled {
                checkingConnection = false
                return
            }
            endpointResults = results
        }
        checkingConnection = false
    }

    @ViewBuilder private var backtestingContent: some View {
        if let baseline {
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader(LocalizedStringKey(baseline.title))
                    Text(baseline.summary)
                    Text("Status: \(baseline.state.title)")
                    Text(baseline.performanceAvailable ? "Backend reports performance availability; no returns are inferred." : "No executed backtest performance")
                        .foregroundStyle(WakColor.textSecondary)
                }
            }
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Run readiness")
                    if baseline.readiness.isEmpty {
                        Text("No readiness checks published.")
                            .foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(baseline.readiness) { step in
                        Text("\(step.label): \(step.state.title)")
                        Text(step.detail).font(.footnote).foregroundStyle(WakColor.textSecondary)
                    }
                }
            }
            ForEach(baseline.policyGroups) { group in
                WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.small) {
                        WakSectionHeader(LocalizedStringKey(group.title))
                        if group.rules.isEmpty {
                            Text("No rules published for this policy group.")
                                .foregroundStyle(WakColor.textSecondary)
                        }
                        ForEach(group.rules) { rule in
                            LabeledContent(rule.label, value: rule.value)
                            Text(rule.detail).font(.footnote).foregroundStyle(WakColor.textSecondary)
                        }
                    }
                }
            }
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Timeline")
                    if baseline.timeline.isEmpty {
                        Text("No execution timeline published.")
                            .foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(baseline.timeline) { item in
                        LabeledContent(item.label, value: item.value)
                        Text(item.detail).font(.footnote).foregroundStyle(WakColor.textSecondary)
                    }
                    WakSectionHeader("Fingerprints")
                    if baseline.fingerprints.isEmpty {
                        Text("No fingerprints published.")
                            .foregroundStyle(WakColor.textSecondary)
                    }
                    ForEach(baseline.fingerprints) { item in
                        VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                            Text(item.label)
                                .font(.subheadline.weight(.semibold))
                            Text(item.value)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(WakColor.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                UIPasteboard.general.string = item.value
                            } label: {
                                Label("Copy fingerprint", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .accessibilityLabel("Copy \(item.label) fingerprint")
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "Baseline research unavailable",
                systemImage: "lock.shield",
                description: Text("No locked policy or performance was loaded. Nothing is inferred.")
            )
        }
    }

    @ViewBuilder private var operationsContent: some View {
        WakCard {
            VStack(alignment: .leading, spacing: WakSpacing.small) {
                WakSectionHeader("Engine connection")
                Text(OperationsStatusPresentation.connectionTitle(operations.connection))
                    .foregroundStyle(WakColor.textPrimary)
                LabeledContent("Latest validated data", value: operations.latestDataThrough ?? "—")
                LabeledContent("Next scheduled analysis", value: operations.nextScheduledRun ?? "—")
                LabeledContent("Last checked", value: operations.checkedAt ?? "Not published")
                Text("Engine connection and API health do not confirm successful research runs.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }
        }
        WakCard {
            VStack(alignment: .leading, spacing: WakSpacing.small) {
                WakSectionHeader("Analysis run history")
                if operations.runs.isEmpty {
                    Text("No recorded analysis runs available.")
                        .foregroundStyle(WakColor.textSecondary)
                }
                ForEach(operations.newestRunsFirst) { run in
                    VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                        Text(run.pipeline).font(.headline)
                        Text("Status: \(OperationsStatusPresentation.runStateTitle(run.state))")
                        Text("Data through: \(run.dataThrough ?? "—")")
                        Text("Started: \(run.startedAt ?? "—")")
                        Text("Finished: \(run.finishedAt ?? "Not published")")
                        if run.finishedAt == nil {
                            Text("Completion time was not provided; completion is not inferred.")
                                .font(.footnote)
                                .foregroundStyle(WakColor.textSecondary)
                        }
                        if let summary = run.summary { Text(summary) }
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BacktestingOperationsView(page: .operations)
    }
}
