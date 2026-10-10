import SwiftUI
import WakTrainerDesignSystem

struct ScreenerView: View {
    private let source: any ScreenerSource
    private let isConnected: Bool
    @State private var entries: [ScreenerEntry] = []
    @State private var filter = ScreenerFilter()
    @State private var isLoading = true
    @State private var errorMessage: String?

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
            Section("Research results") {
                if isLoading {
                    ProgressView("Loading screener")
                } else if let errorMessage {
                    ContentUnavailableView("Screener unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if filter.apply(to: entries).isEmpty {
                    ContentUnavailableView("No verified analyses", systemImage: "chart.xyaxis.line", description: Text("The research API is not connected or no records match these filters."))
                } else {
                    ForEach(filter.apply(to: entries)) { record in
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
        .task {
            isLoading = true
            do {
                let snapshot = try await source.getScreener()
                entries = snapshot.entries
                errorMessage = nil
            } catch {
                entries = []
                errorMessage = "Research data could not be loaded. No mock fallback is available."
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack { ScreenerView() }
}
