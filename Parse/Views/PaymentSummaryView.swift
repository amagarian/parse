import SwiftUI

struct PaymentSummaryView: View {
    let session: SplitSession
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var showVenmoAlert = false

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav
                HStack {
                    HStack(spacing: 7) {
                        ParseMark(size: 14)
                        Text("parse")
                            .font(.system(size: 17, weight: .light, design: .serif))
                            .tracking(-0.5)
                            .foregroundColor(Color.theme.textPrimary)
                    }
                    Spacer()
                    Button { shareSheet() } label: {
                        Text("Share")
                            .font(.system(size: 9, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)

                // Step label
                Text("Split Summary")
                    .font(.system(size: 8, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 4)

                ScrollView {
                    VStack(spacing: 0) {
                        // Large amount header
                        VStack(spacing: 6) {
                            Text("Your share")
                                .font(.system(size: 8, weight: .light))
                                .tracking(2.5)
                                .textCase(.uppercase)
                                .foregroundColor(Color.theme.textSecondary)

                            Text(formattedTotal)
                                .font(.system(size: 52, weight: .light, design: .serif))
                                .tracking(-1.5)
                                .foregroundColor(Color.theme.textPrimary)

                            Text("\(userName) · \(session.restaurantName.isEmpty ? "Your split" : session.restaurantName)")
                                .font(.system(size: 13, weight: .light, design: .serif))
                                .italic()
                                .foregroundColor(Color.theme.accentSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 22)

                        // Items breakdown
                        ForEach(userItems) { item in
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 10, weight: .light))
                                    .tracking(0.4)
                                    .foregroundColor(Color.theme.accentSecondary)

                                if item.claimedBy.count > 1 {
                                    Text("÷\(item.claimedBy.count)")
                                        .font(.system(size: 8, weight: .light))
                                        .foregroundColor(Color.theme.textSecondary)
                                }

                                Spacer()

                                Text(String(format: "$%.2f", item.pricePerClaimant))
                                    .font(.system(size: 10, weight: .light, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(Color.theme.accentSecondary)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.theme.rule).frame(height: 1)
                                    .padding(.horizontal, 22)
                            }
                            .overlay(alignment: .top) {
                                Rectangle().fill(Color.theme.rule).frame(height: 1)
                                    .padding(.horizontal, 22)
                                    .opacity(userItems.first?.id == item.id ? 1 : 0)
                            }
                        }

                        // Subtotal / Tax / Tip rows
                        Group {
                            splitRow(label: "Items subtotal",
                                     value: String(format: "$%.2f", itemsSubtotal))
                            splitRow(label: "Tax (\(String(format: "%.1f%%", session.taxRate * 100)))",
                                     value: String(format: "$%.2f", proportionalTax))
                            splitRow(label: "Tip (\(String(format: "%.1f%%", session.tipRate * 100)))",
                                     value: String(format: "$%.2f", proportionalTip))
                        }

                        // You owe total
                        HStack(alignment: .lastTextBaseline) {
                            Text("You owe")
                                .font(.system(size: 9, weight: .light))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(Color.theme.textSecondary)
                            Spacer()
                            Text(formattedTotal)
                                .font(.system(size: 22, weight: .light, design: .serif))
                                .foregroundColor(Color.theme.textPrimary)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        if session.venmoUsername.isEmpty {
                            openVenmo()
                        } else {
                            showVenmoAlert = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Venmo")
                                .font(.system(size: 12, weight: .light, design: .monospaced))
                                .tracking(0.5)
                                .foregroundColor(Color(hex: 0x0B0907))
                            Text("·")
                                .foregroundColor(Color(hex: 0x0B0907).opacity(0.3))
                            Text(session.venmoUsername.isEmpty
                                 ? "Open Venmo"
                                 : "Pay @\(session.venmoUsername)")
                                .font(.system(size: 16, weight: .light, design: .serif))
                                .foregroundColor(Color(hex: 0x0B0907))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: 0xEDE3D4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.system(size: 10, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .alert("Open Venmo?", isPresented: $showVenmoAlert) {
            Button("Open Venmo") { openVenmo() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Send \(formattedTotal) to @\(session.venmoUsername) for \(session.restaurantName.isEmpty ? "dinner" : session.restaurantName)")
        }
    }

    // MARK: — Split Row

    private func splitRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .light))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Color.theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .light, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(Color.theme.accentSecondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
    }

    // MARK: — Computed

    private var userItems: [ReceiptItem] {
        session.itemsForPerson(userName)
    }

    private var itemsSubtotal: Double {
        userItems.reduce(0) { $0 + $1.pricePerClaimant }
    }

    private var proportionalTax: Double { itemsSubtotal * session.taxRate }
    private var proportionalTip: Double { itemsSubtotal * session.tipRate }
    private var totalOwed: Double { session.totalForPerson(userName) }
    private var formattedTotal: String { String(format: "$%.2f", totalOwed) }

    // MARK: — Actions

    private func openVenmo() {
        let amount = String(format: "%.2f", totalOwed)
        let note = session.restaurantName.isEmpty
            ? "Dinner split via Parse"
            : "\(session.restaurantName) - split via Parse"

        var urlString = "venmo://paycharge?txn=pay&amount=\(amount)"
        if !session.venmoUsername.isEmpty {
            urlString += "&recipients=\(session.venmoUsername)"
        }
        urlString += "&note=\(note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? note)"

        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://venmo.com/") {
            UIApplication.shared.open(webURL)
        }
    }

    private func shareSheet() {
        let text = "My share at \(session.restaurantName.isEmpty ? "dinner" : session.restaurantName): \(formattedTotal)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
}
