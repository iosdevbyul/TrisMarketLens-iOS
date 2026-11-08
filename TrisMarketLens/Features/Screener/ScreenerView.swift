import SwiftUI
import WakTrainerDesignSystem

struct ScreenerView: View {
    private let source: any ScreenerSource
    private let researchSource: any StockResearchSource
    private let isConnected: Bool
    @State private var entries: [ScreenerEntry] = []
    @State private var requests = ResearchRequestGeneration()
    @State private var filter = ScreenerFilter()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var recoveryMessage = ""

    private var filteredEntries: [ScreenerEntry] { filter.apply(to: entries) }

    init(source: any ScreenerSource = DisconnectedScreenerSource(), researchSource: any StockResearchSource = DisconnectedStockResearchSource(), isConnected: Bool = false) {
        self.researchSource = researchSource
        self.isConnected = isConnected
        self.source = source
    }

    var body: some View {
        List {
            Section {
                Label(isConnected ? "Research API configured · Not investment advice" : "Not connected · No investment recommendations", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }
            Section("Filters") {
                Picker("Direction", selection: $filter.direction) {
                    Text("All").tag("all")
                    Text("Up").tag("up")
                    Text("Down").tag("down")
                    Text("Neutral").tag("neutral")
                }
                Picker("Validation", selection: $filter.validation) {
                    Text("All").tag("all")
                    Text("Verified").tag("verified")
                    Text("Pending").tag("pending")
                    Text("Blocked").tag("blocked")
                }
                Picker("Sort by", selection: $filter.sort) {
                    ForEach(ScreenerSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }
            Section {
                HStack {
                    Text("\(filteredEntries.count) of \(entries.count) analyses")
                        .foregroundStyle(WakColor.textSecondary)
                    Spacer()
                    if !filter.isDefault {
                        Button("Reset filters") { filter.reset() }
                    }
                }
                .font(.footnote)
            }
            Section("Research results") {
                if isLoading {
                    ProgressView("Loading screener")
                } else if let errorMessage {
                    ResearchFailurePanel(title: "Screener unavailable", message: errorMessage,
                                         recovery: recoveryMessage, retry: { Task { await reload() } })
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView(entries.isEmpty ? "No published analyses" : "No matching analyses", systemImage: "chart.xyaxis.line", description: Text(entries.isEmpty ? "The research source has no published screener records." : "Adjust your filters to see other published analyses."))
                } else {
                    ForEach(filteredEntries) { record in
                        NavigationLink {
                            ResearchObservationView(entry: record, source: researchSource)
                        } label: {
                        WakCard {
                            VStack(alignment: .leading, spacing: WakSpacing.small) {
                                Text(record.displayName).font(.headline).foregroundStyle(WakColor.textPrimary)
                                Text("\(record.ticker) · \(record.modelId) · \(record.direction.capitalized)")
                                    .font(.caption).foregroundStyle(WakColor.textSecondary)
                                Text("Validation: \(record.validation.capitalized)")
                                    .foregroundStyle(WakColor.textSecondary)
                                if let score = record.score {
                                    Text("Score: \(score.formatted(.number.precision(.fractionLength(4))))")
                                }
                                if record.score == nil {
                                    Text("Score: Not published")
                                        .foregroundStyle(WakColor.textSecondary)
                                }
                                Text("Data through: \(record.dataThrough)")
                                    .font(.footnote).foregroundStyle(WakColor.textSecondary)
                            }
                        }
                        }
                    }
                    .listRowBackground(WakColor.background)
                }
            }
        }
        .searchable(text: $filter.query, prompt: "Ticker, company, or model")
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("AI Screener")
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
        let requestID = requests.begin()
        guard !Task.isCancelled else { return }
        isLoading = true
        entries = []
        errorMessage = nil
        do {
            let result = try await source.getScreener()
            guard requests.accepts(requestID, cancelled: Task.isCancelled) else { return }
            entries = result.entries
            errorMessage = nil
        } catch {
            guard requests.accepts(requestID, cancelled: Task.isCancelled) else { return }
            entries = []
            errorMessage = ResearchErrorGuidance.message(for: error)
            recoveryMessage = ResearchErrorGuidance.recovery(for: error)
        }
        if requests.accepts(requestID, cancelled: Task.isCancelled) { isLoading = false }
    }
}

#Preview {
    NavigationStack { ScreenerView() }
}
