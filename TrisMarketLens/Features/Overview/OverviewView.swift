import SwiftUI
import WakTrainerDesignSystem

struct OverviewView: View {
    private let source: any ProjectStatusSource
    private let isDemo: Bool
    @State private var status: ProjectStatus?
    @State private var requests = ResearchRequestGeneration()
    @State private var errorMessage: String?
    @State private var recoveryMessage = ""
    @State private var loading = true

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

                if loading {
                    ProgressView("Loading research status")
                } else if let status {
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
                    ResearchFailurePanel(
                        title: "Research status unavailable",
                        message: errorMessage,
                        recovery: recoveryMessage,
                        retry: { Task { await reload() } }
                    )
                } else {
                    Text("No research status publication is available.")
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(WakSpacing.regular)
        }
        .background(WakColor.background)
        .navigationTitle("Overview")
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
        let requestID = requests.begin()
        guard !Task.isCancelled else { return }
        loading = true
        status = nil
        errorMessage = nil
        do {
            let result = try await source.getProjectStatus()
            guard requests.accepts(requestID, cancelled: Task.isCancelled) else { return }
            status = result
            errorMessage = nil
        } catch {
            guard requests.accepts(requestID, cancelled: Task.isCancelled) else { return }
            if Task.isCancelled {
                return
            }
            status = nil
            errorMessage = ResearchErrorGuidance.message(for: error)
            recoveryMessage = ResearchErrorGuidance.recovery(for: error)
        }
        if requests.accepts(requestID, cancelled: Task.isCancelled) { loading = false }
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
