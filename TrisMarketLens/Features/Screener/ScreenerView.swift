import SwiftUI
import WakTrainerDesignSystem

struct ScreenerView: View {
    private let source: any ScreenerSource
    private let isConnected: Bool
    @State private var entries: [ScreenerEntry] = []
    @State private var activeRequestID = UUID()
    @State private var filter = ScreenerFilter()
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var filteredEntries: [ScreenerEntry] { filter.apply(to: entries) }

    init(source: any ScreenerSource = DisconnectedScreenerSource(), isConnected: Bool = false) {
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
                    Button("Retry") { Task { await reload() } }
                    ContentUnavailableView("Screener unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView(entries.isEmpty ? "No published analyses" : "No matching analyses", systemImage: "chart.xyaxis.line", description: Text(entries.isEmpty ? "The research source has no published screener records." : "Adjust your filters to see other published analyses."))
                } else {
                    ForEach(filteredEntries) { record in
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
        let requestID = UUID()
        activeRequestID = requestID
            if Task.isCancelled { return }
            isLoading = true
            do {
                let snapshot = try await source.getScreener()
                guard !Task.isCancelled, activeRequestID == requestID else { return }
                entries = snapshot.entries
                errorMessage = nil
            } catch {
                guard !Task.isCancelled, activeRequestID == requestID else { return }
                entries = []
                errorMessage = ResearchErrorGuidance.message(for: error)
            }
            isLoading = false
    }
}

#Preview {
    NavigationStack { ScreenerView() }
}
