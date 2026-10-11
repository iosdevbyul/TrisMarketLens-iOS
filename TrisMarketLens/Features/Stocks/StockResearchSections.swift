import SwiftUI
import Charts
import WakTrainerDesignSystem

struct StockResearchSections: View {
    let ticker: String
    let source: any StockResearchSource

    @State private var bars: [OhlcvBar] = []
    @State private var selectedPeriod: StockChartPeriod = .quarter
    @State private var selectedSession: String?
    @State private var analyses: [StockAnalysisRecord] = []
    @State private var evaluations: [PredictionEvaluation] = []
    @State private var pricesLoading = true
    @State private var analysisLoading = true
    @State private var evaluationsLoading = true
    @State private var pricesError: String?
    @State private var analysisError: String?
    @State private var evaluationsError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: WakSpacing.regular) {
            WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.regular) {
                        WakSectionHeader("Price and volume")
                        if pricesLoading {
                            ProgressView("Loading prices")
                        } else if let pricesError {
                            Label(pricesError, systemImage: "exclamationmark.triangle")
                            Button("Retry prices") { Task { await loadPrices() } }
                        } else if bars.isEmpty {
                            emptyMessage("No validated OHLCV prices available.")
                        } else {
                            Picker("Period", selection: $selectedPeriod) {
                                ForEach(StockChartPeriod.allCases) { period in
                                    Text(period.rawValue).tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel("Price chart period")
                            .onChange(of: selectedPeriod) { _, _ in selectedSession = nil }
                            Chart(selectedPeriod.filter(bars)) { bar in
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
                            .chartXSelection(value: $selectedSession)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                    AxisTick()
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let date = value.as(String.self) {
                                            Text(String(date.suffix(5)))
                                        }
                                    }
                                }
                            }
                            .frame(height: 220)
                            .accessibilityLabel("Historical OHLCV chart")
                            if let session = selectedPeriod.filter(bars).first(where: { $0.date == selectedSession }) {
                                VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                                    Text(session.date).font(.headline)
                                    LabeledContent("Open", value: session.open.formatted())
                                    LabeledContent("High", value: session.high.formatted())
                                    LabeledContent("Low", value: session.low.formatted())
                                    LabeledContent("Close", value: session.close.formatted())
                                    LabeledContent("Volume", value: session.volume.formatted())
                                }
                                .accessibilityElement(children: .combine)
                            }
                            if let summary = StockChartSummary(bars: selectedPeriod.filter(bars)) {
                                VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                                    Text("Selected period summary")
                                        .font(.headline)
                                    LabeledContent("From", value: summary.firstDate)
                                    LabeledContent("Through", value: summary.lastDate)
                                    LabeledContent("High", value: summary.highest.formatted())
                                    LabeledContent("Low", value: summary.lowest.formatted())
                                    LabeledContent("Total volume", value: summary.totalVolume.formatted())
                                    if let change = summary.changePercent {
                                        LabeledContent("Open-to-close change", value: change.formatted(.number.precision(.fractionLength(2))) + "%")
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                            Text("Daily sessions: \(selectedPeriod.filter(bars).count)")
                                .font(.caption)
                                .foregroundStyle(WakColor.textSecondary)
                            Chart(selectedPeriod.filter(bars)) { bar in
                                BarMark(
                                    x: .value("Session", bar.date),
                                    y: .value("Volume", bar.volume)
                                )
                                .foregroundStyle(WakColor.primary)
                            }
                            .frame(height: 100)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                    AxisValueLabel {
                                        if let date = value.as(String.self) {
                                            Text(String(date.suffix(5)))
                                        }
                                    }
                                }
                            }
                            .accessibilityLabel("Historical traded volume chart")
                            Text("Bars are displayed only when supplied by the selected research source.")
                                .font(.footnote)
                                .foregroundStyle(WakColor.textSecondary)
                        }
                    }
                }
                WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.small) {
                        WakSectionHeader("AI analysis")
                        if analysisLoading {
                            ProgressView("Loading analysis")
                        } else if let analysisError {
                            Label(analysisError, systemImage: "exclamationmark.triangle")
                            Button("Retry analysis") { Task { await loadAnalysis() } }
                        } else if analyses.isEmpty {
                            emptyMessage("No verified model analysis available.")
                        } else {
                            ForEach(analyses) { record in
                                NavigationLink {
                                    StockAnalysisDetailView(record: record)
                                } label: {
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
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                WakCard {
                    VStack(alignment: .leading, spacing: WakSpacing.small) {
                        WakSectionHeader("Prediction evaluation")
                        if evaluationsLoading {
                            ProgressView("Loading evaluations")
                        } else if let evaluationsError {
                            Label(evaluationsError, systemImage: "exclamationmark.triangle")
                            Button("Retry evaluations") { Task { await loadEvaluations() } }
                        } else if evaluations.isEmpty {
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
        .task(id: ticker) { await loadPrices() }
        .task(id: ticker) { await loadAnalysis() }
        .task(id: ticker) { await loadEvaluations() }
    }

    private func loadPrices() async {
        guard !Task.isCancelled else { return }
        pricesLoading = true
        do {
            let result = try await source.getOhlcv(ticker: ticker)
            guard !Task.isCancelled else { return }
            guard result.ticker == ticker else { throw ResearchError.tickerMismatch }
            bars = result.bars
            selectedSession = nil
            pricesError = nil
        } catch {
            guard !Task.isCancelled else { return }
            bars = []
            selectedSession = nil
            pricesError = ResearchErrorGuidance.message(for: error)
        }
        pricesLoading = false
    }

    private func loadAnalysis() async {
        guard !Task.isCancelled else { return }
        analysisLoading = true
        do {
            let result = try await source.getAnalysis(ticker: ticker)
            guard !Task.isCancelled else { return }
            guard result.ticker == ticker else { throw ResearchError.tickerMismatch }
            analyses = result.records
            analysisError = nil
        } catch {
            guard !Task.isCancelled else { return }
            analyses = []
            analysisError = ResearchErrorGuidance.message(for: error)
        }
        analysisLoading = false
    }

    private func loadEvaluations() async {
        guard !Task.isCancelled else { return }
        evaluationsLoading = true
        do {
            let result = try await source.getEvaluations(ticker: ticker)
            guard !Task.isCancelled else { return }
            guard result.ticker == ticker else { throw ResearchError.tickerMismatch }
            evaluations = result.evaluations
            evaluationsError = nil
        } catch {
            guard !Task.isCancelled else { return }
            evaluations = []
            evaluationsError = ResearchErrorGuidance.message(for: error)
        }
        evaluationsLoading = false
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
