import SwiftUI

struct HostSetupView: View {
    @Binding var session: SplitSession
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToShare = false

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav
                HStack {
                    Button { dismiss() } label: {
                        Text("← Back")
                            .font(.system(size: 9, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)

                ScrollView {
                    VStack(spacing: 0) {
                        // Tip label
                        Text("Your details")
                            .font(.system(size: 8, weight: .light))
                            .tracking(2.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 4)

                        // Name field
                        fieldRow(icon: "person") {
                            TextField("Your name", text: $session.hostName)
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(Color.theme.textPrimary)
                        }

                        // Venmo field
                        fieldRow(icon: "at") {
                            TextField("Venmo username", text: $session.venmoUsername)
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(Color.theme.textPrimary)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }

                        // Tip section
                        Text("Tip")
                            .font(.system(size: 8, weight: .light))
                            .tracking(2.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.top, 28)
                            .padding(.bottom, 14)

                        // Tip buttons
                        HStack(spacing: 8) {
                            ForEach([15, 18, 20, 25], id: \.self) { pct in
                                tipButton(pct)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)

                        // Custom tip
                        fieldRow(icon: "dollarsign") {
                            TextField("Custom tip", value: $session.tip, format: .currency(code: "USD"))
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(Color.theme.textPrimary)
                                .keyboardType(.decimalPad)
                        }

                        // Summary
                        VStack(spacing: 0) {
                            summaryLine(label: "Subtotal", value: session.subtotal)
                            summaryLine(label: "Tax", value: session.tax)
                            summaryLine(label: "Tip", value: session.tip)

                            HStack(alignment: .lastTextBaseline) {
                                Text("Total")
                                    .font(.system(size: 9, weight: .light))
                                    .tracking(2)
                                    .textCase(.uppercase)
                                    .foregroundColor(Color.theme.textSecondary)
                                Spacer()
                                Text(String(format: "$%.2f", session.total))
                                    .font(.system(size: 22, weight: .light, design: .serif))
                                    .foregroundColor(Color.theme.textPrimary)
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }

                NavigationLink(isActive: $navigateToShare) {
                    ShareSessionView(session: session)
                } label: {
                    EmptyView()
                }
                .hidden()

                Button { navigateToShare = true } label: {
                    Text("Generate QR Code")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color(hex: 0x0B0907))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: 0xEDE3D4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: — Field Row

    private func fieldRow<F: View>(icon: String, @ViewBuilder field: () -> F) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(Color.theme.textSecondary)
                .frame(width: 18)
            field()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
    }

    // MARK: — Tip Button

    private func tipButton(_ pct: Int) -> some View {
        let tip = session.subtotal * Double(pct) / 100
        let isSelected = abs(session.tip - tip) < 0.01
        return Button { withAnimation { session.tip = tip } } label: {
            Text("\(pct)%")
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(isSelected ? Color(hex: 0x0B0907) : Color.theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color(hex: 0xEDE3D4) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.clear : Color.theme.rule, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: — Summary Line

    private func summaryLine(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .light))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Color.theme.textSecondary)
            Spacer()
            Text(String(format: "$%.2f", value))
                .font(.system(size: 9, weight: .light, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(Color.theme.accentSecondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
                .opacity(label == "Subtotal" ? 1 : 0)
        }
    }
}
