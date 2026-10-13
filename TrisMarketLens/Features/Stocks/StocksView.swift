import SwiftUI
import WakTrainerDesignSystem

struct StocksView: View {
    private let source: any StockSource
    private let isDemo: Bool
    private let researchSource: any StockResearchSource
    @State private var stocks: [StockSummary] = []
    @State private var activeRequestID = UUID()
    @State private var query = ""
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var requestStatus = "Waiting for request"

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
                VStack(alignment: .leading, spacing: WakSpacing.small) {
                    ProgressView("Loading stocks")
                    #if DEBUG
                    Text(requestStatus)
                        .font(.footnote)
                        .foregroundStyle(WakColor.textSecondary)
                    #endif
                    Button("Retry loading") { Task { await reload() } }
                }
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

    @MainActor
    private func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        loading = true
        errorMessage = nil
        requestStatus = "Request started"

        do {
            let result = try await source.getStocks()
            guard activeRequestID == requestID else { return }
            if Task.isCancelled {
                requestStatus = "Request canceled"
                loading = false
                return
            }
            stocks = result
            requestStatus = "Loaded \\(result.count) stocks"
            #if DEBUG
            print("[Stocks] Loaded \\(result.count) published stocks")
            #endif
        } catch {
            guard activeRequestID == requestID else { return }
            if Task.isCancelled {
                requestStatus = "Request canceled"
                loading = false
                return
            }
            stocks = []
            errorMessage = ResearchErrorGuidance.message(for: error)
            requestStatus = "Request failed: \\(String(describing: error))"
            #if DEBUG
            print("[Stocks] Request failed: \\(String(reflecting: error))")
            #endif
        }
        loading = false
    }
}
