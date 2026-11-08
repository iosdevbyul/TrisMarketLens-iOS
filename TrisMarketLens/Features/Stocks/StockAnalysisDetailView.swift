import SwiftUI
import WakTrainerDesignSystem

struct StockAnalysisDetailView: View {
    let record: StockAnalysisRecord
    let evaluations: [PredictionEvaluation]
    let evaluationUnavailable: Bool

    private var validatedEvaluations: [PredictionEvaluation] {
        EvaluationPublicationIntegrity.visible(evaluations, analyses: [record])
    }

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
                Text(AnalysisValidationPresentation.explanation(for: record.validation))
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
                LabeledContent("Data through", value: record.dataThrough)
                LabeledContent("Analyzed at", value: record.analyzedAt)
                LabeledContent("Chronology", value: AnalysisPublicationChronology.assess(record).label)
                Text("Chronology is based on published timestamps only; it does not verify point-in-time source availability.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
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
                } else if validatedEvaluations.isEmpty {
                    Text("No published evaluation is available for this analysis.")
                        .foregroundStyle(WakColor.textSecondary)
                } else {
                    if validatedEvaluations.count < evaluations.count {
                        Text("Unlinked or inconsistent evaluations are withheld.")
                            .foregroundStyle(WakColor.destructive)
                    }
                    ForEach(validatedEvaluations) { evaluation in
                        VStack(alignment: .leading, spacing: WakSpacing.small) {
                            LabeledContent("Evaluation ID", value: evaluation.id)
                            LabeledContent("Linked analysis ID", value: evaluation.analysisId)
                            LabeledContent("Integrity", value: EvaluationPublicationIntegrity.assess(evaluation, against: [record]).label)
                            LabeledContent("Published verdict", value: evaluation.verdict.capitalized)
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
                            if EvaluationPublicationIntegrity.assess(evaluation, against: [record]) == .structurallyLinked, let realizedReturn = evaluation.realizedReturn {
                                LabeledContent("Published return (unverified)", value: (realizedReturn * 100).formatted(.number.precision(.fractionLength(2))) + "%")
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
