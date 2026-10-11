import SwiftUI
import WakTrainerDesignSystem

struct StockAnalysisDetailView: View {
    let record: StockAnalysisRecord
    let evaluations: [PredictionEvaluation]
    let evaluationUnavailable: Bool

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
            Section("Prediction evaluation") {
                if evaluationUnavailable {
                    Text("Evaluation service unavailable. No evaluation status is inferred.")
                        .foregroundStyle(WakColor.textSecondary)
                } else if evaluations.isEmpty {
                    Text("No published evaluation is available for this analysis.")
                        .foregroundStyle(WakColor.textSecondary)
                } else {
                    ForEach(evaluations) { evaluation in
                        VStack(alignment: .leading, spacing: WakSpacing.small) {
                            LabeledContent("Evaluation ID", value: evaluation.id)
                            LabeledContent("Linked analysis ID", value: evaluation.analysisId)
                            LabeledContent("Verdict", value: evaluation.verdict.capitalized)
                            LabeledContent("Horizon", value: "\(evaluation.horizonSessions) sessions")
                            LabeledContent("Reference date", value: evaluation.referenceDate)
                            if let referencePrice = evaluation.referencePrice {
                                LabeledContent("Reference price", value: referencePrice.formatted())
                            }
                            if let evaluationDate = evaluation.evaluationDate {
                                LabeledContent("Evaluation date", value: evaluationDate)
                            }
                            if let evaluationPrice = evaluation.evaluationPrice {
                                LabeledContent("Evaluation price", value: evaluationPrice.formatted())
                            }
                            LabeledContent("Policy", value: evaluation.policyId)
                            if let evaluatedAt = evaluation.evaluatedAt {
                                LabeledContent("Evaluated at", value: evaluatedAt)
                            }
                            if let realizedReturn = evaluation.realizedReturn {
                                LabeledContent("Realized return", value: (realizedReturn * 100).formatted(.number.precision(.fractionLength(2))) + "%")
                            } else {
                                LabeledContent("Realized return", value: "Not published")
                            }
                            if let explanation = evaluation.explanation, !explanation.isEmpty {
                                Text(explanation)
                            }
                        }
                    }
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
