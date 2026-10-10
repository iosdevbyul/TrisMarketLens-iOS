import SwiftUI

struct StocksView: View {
    private let source: any StockSource
    @State private var stocks: [StockSummary] = []
    @State private var query = ""
    @State private var loading = true
    @State private var errorMessage: String?

    init(source: any StockSource = MockStockSource()) {
        self.source = source
    }

    private var filteredStocks: [StockSummary] {
        stocks.filter { $0.matches(query) }
    }

    var body: some View {
        List {
            Section {
                Label("Synthetic demo data — not live market coverage", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            if loading {
                ProgressView("Loading stocks")
            } else if let errorMessage {
                ContentUnavailableView("Stocks unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if filteredStocks.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                Section("Research universe · \(filteredStocks.count) displayed") {
                    ForEach(filteredStocks) { stock in
                        NavigationLink {
                            StockDetailView(ticker: stock.ticker, source: source)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(stock.displayName).font(.headline)
                                Text("\(stock.ticker) · \(stock.market) · \(stock.sectorLabel)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search ticker, name, or sector")
        .navigationTitle("Stocks")
        .task {
            do {
                stocks = try await source.getStocks()
                errorMessage = nil
            } catch {
                stocks = []
                errorMessage = "The selected stock data source could not be loaded."
            }
            loading = false
        }
    }
}
