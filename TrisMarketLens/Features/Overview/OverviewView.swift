import SwiftUI
import WakTrainerDesignSystem

struct OverviewView: View {
    private let source: any ProjectStatusSource
    private let isDemo: Bool
    @State private var status: ProjectStatus?
    @State private var errorMessage: String?

    init(source: any ProjectStatusSource = MockProjectStatusSource(), isDemo: Bool = true) {
        self.isDemo = isDemo
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Research dashboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("TrisMarketLens")
                        .foregroundStyle(WakColor.textPrimary)
                        .font(.largeTitle.bold())
                    Label(isDemo ? "Mock data · Not live research" : "Configured research source", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let status {
                    Text(status.sourceLabel)
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(status.metrics) { metric in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(metric.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(metric.value)
                                    .font(WakTypography.metricMedium)
                                    .foregroundStyle(WakColor.textPrimary)
                                Text(metric.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(WakColor.surface, in: RoundedRectangle(cornerRadius: WakRadius.card))
                        }
                    }
                    checkpointSection("Research readiness", items: status.evidence)
                    checkpointSection("Historical baseline", items: status.baseline)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Research status unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    ProgressView("Loading research status")
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(WakSpacing.regular)
        }
        .background(WakColor.background)
        .navigationTitle("Overview")
        .task {
            do {
                status = try await source.getProjectStatus()
                errorMessage = nil
            } catch {
                status = nil
                errorMessage = "Could not load the selected data source."
            }
        }
    }

    private func checkpointSection(_ title: String, items: [ResearchCheckpoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WakSectionHeader(LocalizedStringKey(title))
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.state == .verified ? "checkmark.circle" : "circle.dotted")
                        .foregroundStyle(item.state == .verified ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.headline)
                        Text(item.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text(item.state.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NavigationStack {
        OverviewView()
    }
}
