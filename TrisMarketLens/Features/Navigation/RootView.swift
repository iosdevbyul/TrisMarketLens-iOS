import SwiftUI

struct RootView: View {
    @State private var selection: AppSection = .overview

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("TrisMarketLens")
        } detail: {
            SectionPlaceholderView(section: selection)
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

                Text("Research data is not connected yet.")
                    .foregroundStyle(.secondary)

                ContentUnavailableView(
                    "Waiting for verified data",
                    systemImage: "externaldrive.badge.questionmark",
                    description: Text("This screen will use the same validated research contracts as TrisMarketLens on the web.")
                )

                Text("Mock mode · No investment signals or performance claims")
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
