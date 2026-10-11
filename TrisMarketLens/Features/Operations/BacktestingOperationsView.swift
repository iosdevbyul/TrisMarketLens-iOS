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
    @State private var endpointResults: [ResearchEndpointResult] = []
    @State private var baseline: BaselineBacktestSnapshot?
    @State private var operations = OperationsSnapshot.disconnected
    @State private var loading = true
    @State private var failed = false

    init(page: Page, source: any BacktestingOperationsSource = DisconnectedBacktestingOperationsSource(), diagnostic: ResearchConnectionDiagnostic? = nil) {
        self.diagnostic = diagnostic
        self.page = page
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WakSpacing.regular) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(WakColor.textPrimary)
                Label(diagnostic == nil ? "Research API not connected" : "Research API configured", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)

                if page == .operations {
                    connectionContent
                    endpointContent
                }

                if loading {
                    ProgressView("Loading research")
                } else if failed {
                    ContentUnavailableView("Research unavailable", systemImage: "exclamationmark.triangle")
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
        .task { await reload() }
    }

    private func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        guard !Task.isCancelled, activeRequestID == requestID else { return }
        loading = true
        failed = false
        if page == .operations { await refreshConnection() }
        guard !Task.isCancelled, activeRequestID == requestID else { return }
        do {
            switch page {
            case .backtesting:
                let response = try await source.getBaseline()
                guard !Task.isCancelled, activeRequestID == requestID else { return }
                baseline = response
            case .operations:
                let response = try await source.getOperations()
                guard !Task.isCancelled, activeRequestID == requestID else { return }
                operations = response
            }
        } catch {
            guard !Task.isCancelled, activeRequestID == requestID else { return }
            failed = true
        }
        loading = false
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
                }
            }
        }
    }

    @ViewBuilder private var endpointContent: some View {
        if diagnostic != nil {
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Research endpoint readiness")
                    ForEach(endpointResults) { result in
                        VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                            Text(result.name).font(.headline)
                            Text(result.path).font(.caption).foregroundStyle(WakColor.textSecondary)
                            Text(String(describing: result.state).capitalized)
                            Text(result.detail).font(.footnote).foregroundStyle(WakColor.textSecondary)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func refreshConnection() async {
        let requestID = activeRequestID
        let response = await diagnostic?.check() ?? .notConfigured
        guard !Task.isCancelled, activeRequestID == requestID else { return }
        connection = response
        if let diagnostic, response.state == .reachable {
            let results = await ResearchEndpointDiagnostic(client: diagnostic.client).check()
            guard !Task.isCancelled, activeRequestID == requestID else { return }
            endpointResults = results
        } else {
            endpointResults = []
        }
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
                        LabeledContent(item.label, value: item.value)
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
                Text(operations.connection == "connected" ? "Connected" :
                     operations.connection == "degraded" ? "Degraded" : "Not connected")
                    .foregroundStyle(WakColor.textPrimary)
                LabeledContent("Latest validated data", value: operations.latestDataThrough ?? "—")
                LabeledContent("Next scheduled analysis", value: operations.nextScheduledRun ?? "—")
                LabeledContent("Last checked", value: operations.checkedAt ?? "—")
            }
        }
        WakCard {
            VStack(alignment: .leading, spacing: WakSpacing.small) {
                WakSectionHeader("Analysis run history")
                if operations.runs.isEmpty {
                    Text("No recorded analysis runs available.")
                        .foregroundStyle(WakColor.textSecondary)
                }
                ForEach(operations.runs) { run in
                    VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                        Text(run.pipeline).font(.headline)
                        Text("Status: \(run.state.capitalized)")
                        Text("Data through: \(run.dataThrough ?? "—")")
                        Text("Started: \(run.startedAt ?? "—")")
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
