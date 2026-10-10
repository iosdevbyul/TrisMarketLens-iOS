import SwiftUI

struct RootView: View {
    @State private var selection: AppSection? = .overview

    var body: some View {
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
                OverviewView()
            } else if selection == .stocks {
                NavigationStack {
                    StocksView()
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
                    ResearchCatalogView(kind: .models)
                }
            } else if selection == .evidence {
                NavigationStack {
                    ResearchCatalogView(kind: .evidence)
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
