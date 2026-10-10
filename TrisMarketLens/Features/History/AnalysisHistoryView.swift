import SwiftUI
import Charts
import WakTrainerDesignSystem

struct AnalysisHistoryView: View {
    private let source: any ScreenerSource
    private let isConnected: Bool
    @State private var history: [DailyAnalysisSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(source: any ScreenerSource = DisconnectedScreenerSource(), isConnected: Bool = false) {
        self.isConnected = isConnected
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WakSpacing.regular) {
                Text("AI Analysis History")
                    .font(.largeTitle.bold())
                    .foregroundStyle(WakColor.textPrimary)
                Text("Observed model analysis activity only. This is not a backtest.")
                    .foregroundStyle(WakColor.textSecondary)
                Label(isConnected ? "Research API configured" : "Not connected · No verified history loaded", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)

                WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.regular) {
                        WakSectionHeader("Analysis activity by date")
                        if isLoading {
                            ProgressView("Loading analysis history")
                        } else if let errorMessage {
                            Button("Retry") { Task { await reload() } }
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(WakColor.destructive)
                        } else if history.isEmpty {
                            ContentUnavailableView(
                                "No observed analysis dates",
                                systemImage: "chart.bar.xaxis",
                                description: Text("Verified analysis records will appear when the research source is connected.")
                            )
                        } else {
                            Chart(history) { day in
                                BarMark(
                                    x: .value("Data through", day.date),
                                    y: .value("Analysis count", day.records)
                                )
                                .foregroundStyle(WakColor.primary)
                            }
                            .frame(height: 220)
                            ForEach(history.reversed()) { day in
                                VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                                    Text(day.date).font(.headline)
                                    Text("\(day.records) analyses · \(day.securities) securities")
                                    Text("Up \(day.up) · Down \(day.down) · Neutral \(day.neutral)")
                                    Text("Verified \(day.verified) · Pending \(day.pending) · Blocked \(day.blocked)")
                                    Text("Latest analysis: \(day.latestAnalyzedAt)")
                                        .font(.footnote)
                                }
                                .foregroundStyle(WakColor.textSecondary)
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(WakSpacing.regular)
        }
        .background(WakColor.background)
        .navigationTitle("AI Analysis History")
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
            if Task.isCancelled { return }
            isLoading = true
            do {
                let snapshot = try await source.getScreener()
                let result = DailyAnalysisSummary.summarize(snapshot.entries)
                guard !Task.isCancelled else { return }
                history = result
                errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                history = []
                errorMessage = ResearchErrorGuidance.message(for: error)
            }
            isLoading = false
    }
}

#Preview {
    NavigationStack { AnalysisHistoryView() }
}
