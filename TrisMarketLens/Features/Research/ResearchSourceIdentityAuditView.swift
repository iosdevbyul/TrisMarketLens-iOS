import SwiftUI
import WakTrainerDesignSystem

/// Operator-facing read-only review. This view never claims an end-to-end lineage proof.
struct ResearchSourceIdentityAuditView: View {
    let catalog: any ResearchCatalogSource
    let isHTTP: Bool

    @State private var records: [PublishedIdentityRecord] = []
    @State private var loading = true
    @State private var errors: [String] = []
    @State private var requestID = UUID()

    var body: some View {
        List {
            Section("Published identity boundaries") {
                Text("Published SHA-256 values are reported identifiers, not independently checked source bytes. Operational SQLite SHA, original KRX capture receipts, signature authority and model-to-market lineage are not provided by these APIs.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
                LabeledContent("Source access", value: isHTTP ? "Configured HTTP" : "Disconnected or demonstration")
                LabeledContent("End-to-end provenance", value: "Unavailable")
            }
            if loading {
                ProgressView("Reviewing published identities")
            }
            if !errors.isEmpty {
                Section("Unavailable publications") {
                    ForEach(errors, id: \.self) { error in Text(error).foregroundStyle(WakColor.destructive) }
                }
            }
            Section("Source identities") {
                if records.isEmpty && !loading {
                    Text("No independently reviewable published identities available.")
                }
                ForEach(records) { record in
                    DisclosureGroup(record.title + " · " + record.state.label) {
                        LabeledContent("Published ID", value: record.id)
                        LabeledContent("Source scope / feature set", value: record.sourceScope)
                        if let fingerprint = record.publishedFingerprint {
                            Text(fingerprint).font(.caption.monospaced()).textSelection(.enabled)
                        } else {
                            LabeledContent("Fingerprint", value: "Unavailable")
                        }
                        Text(record.reason).font(.footnote)
                            .foregroundStyle(WakColor.textSecondary)
                    }
                }
            }
            Section("Review result") {
                let inconsistent = records.filter { $0.state == .inconsistent }.count
                let missing = records.filter { $0.state == .missing }.count
                LabeledContent("Contradictory identities", value: inconsistent.formatted())
                LabeledContent("Missing identities", value: missing.formatted())
                LabeledContent("Research approval", value: "Not independently authorized")
                Text("Even if every displayed fingerprint is present and consistent, cross-source custody and PIT/OOS or brokerage eligibility remain unverified.")
                    .font(.footnote)
                    .foregroundStyle(WakColor.textSecondary)
            }
        }
        .navigationTitle("Source Identity Audit")
        .scrollContentBackground(.hidden)
        .background(WakColor.background)
        .refreshable { await reload() }
        .task { await reload() }
    }

    @MainActor private func reload() async {
        let id = UUID()
        requestID = id
        loading = true
        records = []
        errors = []
        guard isHTTP else {
            errors = ["No independently verified identity in disconnected/demo mode."]
            loading = false
            return
        }
        do {
            let evidence = try await catalog.getEvidenceLayers()
            guard id == requestID, !Task.isCancelled else { return }
            for summary in evidence {
                do {
                    let detail = try await catalog.getEvidenceLayer(id: summary.id)
                    guard id == requestID, !Task.isCancelled else { return }
                    records.append(ResearchSourceIdentityAudit.evidence(summary: summary, detail: detail))
                } catch {
                    guard id == requestID else { return }
                    records.append(ResearchSourceIdentityAudit.evidence(summary: summary, detail: nil))
                    errors.append("Evidence " + summary.id + ": " + ResearchErrorGuidance.message(for: error))
                }
            }
        } catch {
            guard id == requestID else { return }
            errors.append("Evidence index: " + ResearchErrorGuidance.message(for: error))
        }
        do {
            let models = try await catalog.getModels()
            guard id == requestID, !Task.isCancelled else { return }
            for summary in models {
                do {
                    let detail = try await catalog.getModel(id: summary.id)
                    guard id == requestID, !Task.isCancelled else { return }
                    records.append(ResearchSourceIdentityAudit.model(summary: summary, detail: detail))
                } catch {
                    guard id == requestID else { return }
                    records.append(ResearchSourceIdentityAudit.model(summary: summary, detail: nil))
                    errors.append("Model " + summary.id + ": " + ResearchErrorGuidance.message(for: error))
                }
            }
        } catch {
            guard id == requestID else { return }
            errors.append("Model index: " + ResearchErrorGuidance.message(for: error))
        }
        if id == requestID { loading = false }
    }
}
