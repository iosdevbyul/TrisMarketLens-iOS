import SwiftUI

struct RootView: View {
    @State private var selection: AppSection? = .overview

    private let configuration = Result { try ResearchEnvironment.fromProcess() }

    var body: some View {
        Group {
            switch configuration {
            case .success(let environment): content(environment)
            case .failure:
                ContentUnavailableView("Invalid research configuration", systemImage: "exclamationmark.triangle", description: Text("Check TRIS_DATA_MODE and TRIS_API_BASE_URL. No automatic mock fallback."))
            }
        }
    }

    private func content(_ environment: ResearchEnvironment) -> some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
            }
            .navigationTitle("TrisMarketLens")
        } detail: {
            if selection == .overview || selection == nil {
                OverviewView(source: environment.project(), isDemo: environment.mode != .http)
            } else if selection == .stocks {
                NavigationStack {
                    StocksView(source: environment.stocks(), isDemo: environment.mode != .http)
                }
            } else if selection == .screener {
                NavigationStack {
                    ScreenerView()
                }
            } else if selection == .history {
                NavigationStack {
                    AnalysisHistoryView()
                }
             } else if selection == .models {
                NavigationStack {
                    ResearchCatalogView(kind: .models, source: environment.catalog())
                }
            } else if selection == .evidence {
                NavigationStack {
                    ResearchCatalogView(kind: .evidence, source: environment.catalog())
                }
             } else if selection == .backtesting {
                NavigationStack {
                    BacktestingOperationsView(page: .backtesting, source: environment.operations())
                }
            } else if selection == .operations {
                NavigationStack {
                    BacktestingOperationsView(page: .operations, source: environment.operations())
                }
            } else if let selection {
                SectionPlaceholderView(section: selection)
            }
        }
    }
}

private struct SectionPlaceholderView: View {
    let section: AppSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(section.title, systemImage: section.symbol)
                    .font(.largeTitle.bold())

                ContentUnavailableView(
                    "Waiting for verified data",
                    systemImage: "externaldrive.badge.questionmark",
                    description: Text("This screen will use the same validated research contracts as TrisMarketLens on the web.")
                )

                Text("No investment signals or performance claims")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(section.title)
    }
}

#Preview {
    RootView()
}
