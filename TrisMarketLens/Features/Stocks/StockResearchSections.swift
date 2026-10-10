import SwiftUI
import Charts
import WakTrainerDesignSystem

struct StockResearchSections: View {
    let ticker: String
    let source: any StockResearchSource

    @State private var bars: [OhlcvBar] = []
    @State private var analyses: [StockAnalysisRecord] = []
    @State private var evaluations: [PredictionEvaluation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: WakSpacing.regular) {
            if isLoading {
                ProgressView("Loading research")
            } else if let errorMessage {
                WakCard {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(WakColor.textSecondary)
                }
            } else {
                WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.regular) {
                        WakSectionHeader("Price and volume")
                        if bars.isEmpty {
                            emptyMessage("No validated OHLCV prices available.")
                        } else {
                            Chart(bars) { bar in
                                BarMark(
                                    x: .value("Session", bar.date),
                                    yStart: .value("Low", bar.low),
                                    yEnd: .value("High", bar.high),
                                    width: 2
                                )
                                .foregroundStyle(bar.close >= bar.open ? Color.green : WakColor.destructive)
                                RectangleMark(
                                    x: .value("Session", bar.date),
                                    yStart: .value("Open or close", min(bar.open, bar.close)),
                                    yEnd: .value("Close or open", max(bar.open, bar.close)),
                                    width: 6
                                )
                                .foregroundStyle(bar.close >= bar.open ? Color.green : WakColor.destructive)
                            }
                            .frame(height: 220)
                            .accessibilityLabel("Historical OHLCV chart")
                            Text("Bars are displayed only when supplied by the selected research source.")
                                .font(.footnote)
                                .foregroundStyle(WakColor.textSecondary)
                        }
                    }
                }
                WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.small) {
                        WakSectionHeader("AI analysis")
                        if analyses.isEmpty {
                            emptyMessage("No verified model analysis available.")
                        } else {
                            ForEach(analyses) { record in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.modelId).font(.headline)
                                    Text("\(record.direction.capitalized) · \(record.validation.capitalized) · \(record.dataThrough)")
                                    if let score = record.score {
                                        Text("Model score: \(score.formatted(.number.precision(.fractionLength(4))))")
                                    }
                                    if let explanation = record.explanation { Text(explanation) }
                                }
                                .foregroundStyle(WakColor.textPrimary)
                                Divider()
                            }
                        }
                    }
                }
                WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.small) {
                        WakSectionHeader("Prediction evaluation")
                        if evaluations.isEmpty {
                            emptyMessage("No evaluated predictions available.")
                        } else {
                            ForEach(evaluations) { evaluation in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(evaluation.analysisId).font(.headline)
                                    Text("Verdict: \(evaluation.verdict.capitalized)")
                                    Text("Reference: \(evaluation.referenceDate) · Horizon: \(evaluation.horizonSessions) sessions")
                                    if let result = evaluation.realizedReturn {
                                        Text("Realized return: \((result * 100).formatted(.number.precision(.fractionLength(2))))%")
                                    }
                                }
                                .foregroundStyle(WakColor.textPrimary)
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .task(id: ticker) {
            isLoading = true
            errorMessage = nil
            do {
                async let ohlcv = source.getOhlcv(ticker: ticker)
                async let analysis = source.getAnalysis(ticker: ticker)
                async let evaluation = source.getEvaluations(ticker: ticker)
                let (priceResult, analysisResult, evaluationResult) = try await (ohlcv, analysis, evaluation)
                guard priceResult.ticker == ticker,
                      analysisResult.ticker == ticker,
                      evaluationResult.ticker == ticker else {
                    throw ResearchError.tickerMismatch
                }
                bars = priceResult.bars
                analyses = analysisResult.records
                evaluations = evaluationResult.evaluations
            } catch {
                bars = []
                analyses = []
                evaluations = []
                errorMessage = "Research data unavailable. No mock fallback will be shown."
            }
            isLoading = false
        }
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(WakColor.textSecondary)
    }
}

private enum ResearchError: Error {
    case tickerMismatch
}
