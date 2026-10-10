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
    @State private var baseline: BaselineBacktestSnapshot?
    @State private var operations = OperationsSnapshot.disconnected
    @State private var loading = true
    @State private var failed = false

    init(page: Page, source: any BacktestingOperationsSource = DisconnectedBacktestingOperationsSource()) {
        self.page = page
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WakSpacing.regular) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(WakColor.textPrimary)
                Label("Research API not connected", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)

                if loading {
                    ProgressView("Loading research")
                } else if failed {
                    ContentUnavailableView("Research unavailable", systemImage: "exclamationmark.triangle")
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
        .task {
            loading = true
            failed = false
            do {
                switch page {
                case .backtesting: baseline = try await source.getBaseline()
                case .operations: operations = try await source.getOperations()
                }
            } catch {
                failed = true
            }
            loading = false
        }
    }

    @ViewBuilder private var backtestingContent: some View {
        if let baseline {
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader(LocalizedStringKey(baseline.title))
                    Text(baseline.summary)
                    Text("Status: \(baseline.state.title)")
                    Text(baseline.performanceAvailable ? "Backend reports performance available" : "No executed backtest performance")
                        .foregroundStyle(WakColor.textSecondary)
                }
            }
            WakCard {
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    WakSectionHeader("Run readiness")
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
                    ForEach(baseline.timeline) { item in
                        LabeledContent(item.label, value: item.value)
                    }
                    WakSectionHeader("Fingerprints")
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
