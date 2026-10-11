import SwiftUI
import WakTrainerDesignSystem

struct StockAnalysisDetailView: View {
    let record: StockAnalysisRecord

    var body: some View {
        List {
            Section("Analysis identity") {
                LabeledContent("Ticker", value: record.ticker)
                LabeledContent("Analysis ID", value: record.id)
                LabeledContent("Model", value: record.modelId)
                LabeledContent("Model version", value: record.modelVersion)
            }
            Section("Research observation") {
                LabeledContent("Direction", value: record.direction.capitalized)
                LabeledContent("Validation", value: record.validation.capitalized)
                LabeledContent("Data through", value: record.dataThrough)
                LabeledContent("Analyzed at", value: record.analyzedAt)
                if let score = record.score {
                    LabeledContent("Model score", value: score.formatted(.number.precision(.fractionLength(4))))
                } else {
                    LabeledContent("Model score", value: "Not published")
                }
            }
            Section("Research explanation") {
                if let explanation = record.explanation, !explanation.isEmpty {
                    Text(explanation)
                } else {
                    Text("No explanation was published for this analysis.")
                        .foregroundStyle(WakColor.textSecondary)
                }
            }
            Section {
                Text("This is a published research observation, not a trade recommendation or realized performance.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .navigationTitle("AI analysis detail")
    }
}
