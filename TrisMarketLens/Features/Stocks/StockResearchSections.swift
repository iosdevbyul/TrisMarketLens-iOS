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
    @State private var pricesRequestID = UUID()
    @State private var analysisRequestID = UUID()
    @State private var evaluationsRequestID = UUID()
    @State private var pricesLoading = true
    @State private var analysisLoading = true
    @State private var evaluationsLoading = true
    @State private var pricesError: String?
    @State private var analysisError: String?
    @State private var evaluationsError: String?

    private var visibleBars: [OhlcvBar] { selectedPeriod.filter(bars) }

    private var displayMode: StockChartDisplayMode { .mode(sessionCount: visibleBars.count) }

    private var dateRangeLabels: some View {
        let dates = StockChartAxisLabels.dates(for: visibleBars.map { $0.date }, maxLabels: 4)
        return HStack(spacing: 2) {
            ForEach(Array(dates.enumerated()), id: \.offset) { item in
                Text(String(item.element.suffix(5)))
                    .frame(maxWidth: .infinity, alignment: item.offset == 0 ? .leading : item.offset == dates.count - 1 ? .trailing : .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .font(.caption2)
        .foregroundStyle(WakColor.textSecondary)
        .padding(.trailing, 54)
        .accessibilityLabel("Visible dates from \(visibleBars.first?.date ?? "unknown") to \(visibleBars.last?.date ?? "unknown")")
    }

    private var selectedBar: OhlcvBar? {
        StockChartSelection.bar(for: selectedSession, in: visibleBars)
    }

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
                            if let session = selectedBar {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Selected trading session")
                                            .font(.caption)
                                            .foregroundStyle(WakColor.textSecondary)
                                        Text(session.date)
                                            .font(.headline)
                                            .monospacedDigit()
                                    }
                                    Spacer(minLength: 8)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Close")
                                            .font(.caption)
                                            .foregroundStyle(WakColor.textSecondary)
                                        Text(StockValueFormatter.price(session.close))
                                            .font(.headline)
                                            .monospacedDigit()
                                    }
                                    Button("Clear") {
                                        selectedSession = nil
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Clear selected trading session")
                                }
                                .accessibilityElement(children: .contain)
                            }
                            Chart {
                                if displayMode == .closingLine {
                                    ForEach(visibleBars) { bar in
                                        LineMark(
                                            x: .value("Session", bar.date),
                                            y: .value("Close", bar.close)
                                        )
                                        .foregroundStyle(WakColor.primary)
                                    }
                                } else {
                                    ForEach(visibleBars) { bar in
                                        BarMark(
                                            x: .value("Session", bar.date),
                                            yStart: .value("Low", bar.low),
                                            yEnd: .value("High", bar.high),
                                            width: 2
                                        )
                                        .foregroundStyle(bar.close >= bar.open ? Color.green : WakColor.destructive)
                                        RectangleMark(
                                            x: .value("Session", bar.date),
                                            yStart: .value("Body low", min(bar.open, bar.close)),
                                            yEnd: .value("Body high", max(bar.open, bar.close)),
                                            width: .fixed(StockChartCandleWidth.bodyWidth(for: visibleBars.count))
                                        )
                                        .foregroundStyle(bar.close >= bar.open ? Color.green : WakColor.destructive)
                                    }
                                }
                                if let selectedBar {
                                    RuleMark(x: .value("Selected session", selectedBar.date))
                                        .foregroundStyle(WakColor.textSecondary)
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                        .annotation(position: .top, spacing: 6) {
                                            Text(selectedBar.date)
                                                .font(.caption.bold())
                                                .monospacedDigit()
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(.black.opacity(0.85), in: Capsule())
                                                .accessibilityLabel("Selected trading date: \(selectedBar.date)")
                                        }
                                }
                            }
                            .chartXSelection(value: $selectedSession)
                            .chartXAxis(.hidden)
                            .frame(height: 220)
                            .accessibilityLabel(displayMode == .closingLine ? "Historical closing price chart" : "Historical OHLCV chart")
                            dateRangeLabels
                            Text("Touch or drag across the chart to inspect a trading session.")
                                .font(.caption2)
                                .foregroundStyle(WakColor.textSecondary)
                            if displayMode == .closingLine {
                                Text("Showing closing prices as a line for readability across longer periods.")
                                    .font(.caption)
                                    .foregroundStyle(WakColor.textSecondary)
                            }
                            if let session = selectedBar {
                                VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                                    Text(session.date).font(.headline)
                                    LabeledContent("Open", value: StockValueFormatter.price(session.open))
                                    LabeledContent("High", value: StockValueFormatter.price(session.high))
                                    LabeledContent("Low", value: StockValueFormatter.price(session.low))
                                    LabeledContent("Close", value: StockValueFormatter.price(session.close))
                                    LabeledContent("Volume", value: StockValueFormatter.volume(session.volume))
                                }
                                .accessibilityElement(children: .combine)
                            }
                            if let summary = StockChartSummary(bars: visibleBars) {
                                VStack(alignment: .leading, spacing: WakSpacing.xSmall) {
                                    Text("Selected period summary")
                                        .font(.headline)
                                    LabeledContent("From", value: summary.firstDate)
                                    LabeledContent("Through", value: summary.lastDate)
                                    LabeledContent("High", value: StockValueFormatter.price(summary.highest))
                                    LabeledContent("Low", value: StockValueFormatter.price(summary.lowest))
                                    LabeledContent("Total volume", value: StockValueFormatter.volume(summary.totalVolume))
                                    if let change = summary.changePercent {
                                        LabeledContent("Open-to-close change", value: StockValueFormatter.changePercent(change))
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                            Text("Daily sessions: \(visibleBars.count)")
                                .font(.caption)
                                .foregroundStyle(WakColor.textSecondary)
                            Chart {
                                ForEach(visibleBars) { bar in
                                    BarMark(
                                        x: .value("Session", bar.date),
                                        y: .value("Volume", bar.volume)
                                    )
                                    .foregroundStyle(bar.date == selectedSession ? WakColor.textPrimary : WakColor.primary)
                                }
                                if let selectedBar {
                                    RuleMark(x: .value("Selected session", selectedBar.date))
                                        .foregroundStyle(WakColor.textSecondary)
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                }
                            }
                            .frame(height: 100)
                            .chartYAxis {
                                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let volume = value.as(Double.self) {
                                            Text(volume.formatted(.number.notation(.compactName)))
                                        }
                                    }
                                }
                            }
                            .chartXAxis(.hidden)
                            dateRangeLabels
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
                                    StockAnalysisDetailView(record: record, evaluations: record.matchingEvaluations(in: evaluations), evaluationUnavailable: evaluationsLoading || evaluationsError != nil)
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
                                }
                                .buttonStyle(.plain)
                                Divider()
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
        let requestID = UUID()
        pricesRequestID = requestID
        guard !Task.isCancelled else { return }
        pricesLoading = true
        do {
            let result = try await source.getOhlcv(ticker: ticker)
            guard pricesRequestID == requestID else { return }
            if Task.isCancelled {
                pricesLoading = false
                return
            }
            guard result.ticker == ticker else { throw ResearchError.tickerMismatch }
            bars = result.bars
            selectedSession = nil
            pricesError = nil
        } catch {
            guard pricesRequestID == requestID else { return }
            if Task.isCancelled {
                pricesLoading = false
                return
            }
            bars = []
            selectedSession = nil
            if case ResearchAPIError.httpStatus(503) = error {
                pricesError = "Historical prices unavailable: the API market database is not enabled. An approved immutable Market DB and matching SHA-256 are required."
            } else {
                pricesError = ResearchErrorGuidance.message(for: error)
            }
        }
        pricesLoading = false
    }

    private func loadAnalysis() async {
        let requestID = UUID()
        analysisRequestID = requestID
        guard !Task.isCancelled else { return }
        analysisLoading = true
        do {
            let result = try await source.getAnalysis(ticker: ticker)
            guard analysisRequestID == requestID else { return }
            if Task.isCancelled {
                analysisLoading = false
                return
            }
            guard result.ticker == ticker else { throw ResearchError.tickerMismatch }
            analyses = result.newestFirst
            analysisError = nil
        } catch {
            guard analysisRequestID == requestID else { return }
            if Task.isCancelled {
                analysisLoading = false
                return
            }
            analyses = []
            analysisError = ResearchErrorGuidance.message(for: error)
        }
        analysisLoading = false
    }

    private func loadEvaluations() async {
        let requestID = UUID()
        evaluationsRequestID = requestID
        guard !Task.isCancelled else { return }
        evaluationsLoading = true
        do {
            let result = try await source.getEvaluations(ticker: ticker)
            guard evaluationsRequestID == requestID else { return }
            if Task.isCancelled {
                evaluationsLoading = false
                return
            }
            guard result.ticker == ticker else { throw ResearchError.tickerMismatch }
            evaluations = result.evaluations
            evaluationsError = nil
        } catch {
            guard evaluationsRequestID == requestID else { return }
            if Task.isCancelled {
                evaluationsLoading = false
                return
            }
            evaluations = []
            if case ResearchAPIError.httpStatus(404) = error {
                evaluationsError = "Prediction evaluation API is not supported by this server (HTTP 404)."
            } else {
                evaluationsError = ResearchErrorGuidance.message(for: error)
            }
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
