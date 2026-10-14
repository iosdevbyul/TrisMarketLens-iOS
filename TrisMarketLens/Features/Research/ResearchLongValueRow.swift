import SwiftUI

/// Displays server-provided text without truncating hashes and long provenance values
/// on compact displays. Geometry is based on available width, not device model.
struct ResearchLongValueRow: View {
    let label: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .foregroundStyle(.secondary)
                Text(value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
