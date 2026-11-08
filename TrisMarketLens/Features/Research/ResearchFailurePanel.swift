import SwiftUI
import WakTrainerDesignSystem

/// An explicit retry surface for read-only research requests.
/// This component never schedules or automatically repeats a failed request.
struct ResearchFailurePanel: View {
    let title: String
    let message: String
    let recovery: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WakSpacing.small) {
            Label(title, systemImage: "wifi.exclamationmark")
                .font(.headline)
                .foregroundStyle(WakColor.destructive)
            Text(message)
                .foregroundStyle(WakColor.textPrimary)
            Text(recovery)
                .font(.footnote)
                .foregroundStyle(WakColor.textSecondary)
            Button("Retry request", action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Manually repeats the read-only request once. No automatic retry occurs.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WakSpacing.regular)
        .accessibilityElement(children: .contain)
    }
}
