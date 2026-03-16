import SwiftUI

struct SummaryRow: View {
    let label: String
    let value: Double
    var isBold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .light))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Color.theme.textSecondary)
            Spacer()
            Text(String(format: "$%.2f", value))
                .font(.system(size: isBold ? 11 : 9, weight: .light, design: isBold ? .serif : .monospaced))
                .tracking(isBold ? -0.3 : 0.5)
                .foregroundColor(isBold ? Color.theme.textPrimary : Color.theme.accentSecondary)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
        }
    }
}
