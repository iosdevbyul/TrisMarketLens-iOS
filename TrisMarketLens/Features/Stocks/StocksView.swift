import SwiftUI
import WakTrainerDesignSystem

struct StocksView: View {
    private let source: any StockSource
    private let isDemo: Bool
    private let researchSource: any StockResearchSource
    @State private var stocks: [StockSummary] = []
    @State private var query = ""
    @State private var loading = true
    @State private var errorMessage: String?

    init(source: any StockSource = MockStockSource(), isDemo: Bool = true, researchSource: any StockResearchSource = DisconnectedStockResearchSource()) {
        self.researchSource = researchSource
        self.isDemo = isDemo
        self.source = source
    }

    private var filteredStocks: [StockSummary] {
        stocks.filter { $0.matches(query) }
    }

    var body: some View {
        List {
            Section {
                Label(isDemo ? "Synthetic demo data — not live market coverage" : "Configured research source", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            if loading {
                ProgressView("Loading stocks")
            } else if let errorMessage {
                Button("Retry") { Task { await reload() } }
                ContentUnavailableView("Stocks unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if filteredStocks.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                Section("Research universe · \(filteredStocks.count) displayed") {
                    ForEach(filteredStocks) { stock in
                        NavigationLink {
                            StockDetailView(ticker: stock.ticker, source: source, researchSource: researchSource)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(stock.displayName).font(WakTypography.sectionTitle)
                                    .foregroundStyle(WakColor.textPrimary)
                                Text("\(stock.ticker) · \(stock.market) · \(stock.sectorLabel)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, WakSpacing.xSmall)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .searchable(text: $query, prompt: "Search ticker, name, or sector")
        .navigationTitle("Stocks")
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
            loading = true
            if Task.isCancelled { return }
            do {
                let result = try await source.getStocks()
                guard !Task.isCancelled else { return }
                stocks = result
                errorMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                stocks = []
                errorMessage = "The selected stock data source could not be loaded."
            }
            loading = false
    }
}
