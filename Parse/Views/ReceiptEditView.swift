import SwiftUI

struct ReceiptEditView: View {
    @Binding var session: SplitSession
    var debugLines: [String] = []
    var debugParserLog: [(line: String, verdict: String)] = []
    @Environment(\.dismiss) private var dismiss
    @State private var editingItemId: UUID?
    @State private var newItemName = ""
    @State private var newItemPrice = ""
    @State private var isAddingItem = false
    @State private var navigateToHostSetup = false
    @State private var showDebug = false

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button { dismiss() } label: {
                        Text("← Back")
                            .font(.system(size: 9, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    Spacer()
                    if !debugLines.isEmpty {
                        Button { withAnimation { showDebug.toggle() } } label: {
                            Text(showDebug ? "Hide Raw" : "Raw Scan")
                                .font(.system(size: 9, weight: .light))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundColor(showDebug ? Color.theme.accent : Color.theme.textSecondary)
                        }
                        .padding(.trailing, 12)
                    }
                    Button {
                        withAnimation { isAddingItem = true }
                    } label: {
                        Text("Add Item")
                            .font(.system(size: 9, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)

                // Step label
                Text("Step 2 of 3 — Review Items")
                    .font(.system(size: 8, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 0) {
                        // Venue + date
                        HStack(alignment: .lastTextBaseline) {
                            Text(session.restaurantName.isEmpty ? "Receipt" : session.restaurantName)
                                .font(.system(size: 18, weight: .light, design: .serif))
                                .italic()
                                .foregroundColor(Color.theme.textPrimary)
                            Spacer()
                            Text(today)
                                .font(.system(size: 8, weight: .light))
                                .tracking(1)
                                .foregroundColor(Color.theme.textSecondary)
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 16)

                        // Debug panel
                        if showDebug && (!debugLines.isEmpty || !debugParserLog.isEmpty) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Raw OCR
                                if !debugLines.isEmpty {
                                    Text("Raw OCR — \(debugLines.count) lines")
                                        .font(.system(size: 7, weight: .light))
                                        .tracking(1.5)
                                        .textCase(.uppercase)
                                        .foregroundColor(Color.theme.accent)
                                        .padding(.horizontal, 22)
                                        .padding(.top, 10)
                                        .padding(.bottom, 4)
                                    ForEach(Array(debugLines.enumerated()), id: \.offset) { i, line in
                                        Text("\(i + 1): \(line)")
                                            .font(.system(size: 9, weight: .light, design: .monospaced))
                                            .foregroundColor(Color.theme.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 22)
                                            .padding(.vertical, 2)
                                    }
                                }
                                // Parser decisions
                                if !debugParserLog.isEmpty {
                                    Text("Parser decisions")
                                        .font(.system(size: 7, weight: .light))
                                        .tracking(1.5)
                                        .textCase(.uppercase)
                                        .foregroundColor(Color.theme.accent)
                                        .padding(.horizontal, 22)
                                        .padding(.top, 14)
                                        .padding(.bottom, 4)
                                    ForEach(Array(debugParserLog.enumerated()), id: \.offset) { i, entry in
                                        HStack(alignment: .top, spacing: 6) {
                                            Text(entry.verdict.hasPrefix("ITEM") ? "✓" : "✗")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(entry.verdict.hasPrefix("ITEM") ? Color.green : Color.red.opacity(0.7))
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(entry.line)
                                                    .font(.system(size: 8, weight: .light, design: .monospaced))
                                                    .foregroundColor(Color.theme.textSecondary)
                                                Text(entry.verdict)
                                                    .font(.system(size: 8, weight: .light, design: .monospaced))
                                                    .foregroundColor(entry.verdict.hasPrefix("ITEM") ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 22)
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                            .background(Color.theme.cardBackground.opacity(0.6))
                        }

                        // Item list
                        ForEach(Array(session.items.enumerated()), id: \.element.id) { index, item in
                            itemRow(item: item, index: index)
                        }

                        // Add item inline form
                        if isAddingItem {
                            addItemForm
                        }

                        // Subtotals
                        Group {
                            subtotalRow(label: "Subtotal", value: session.subtotal)

                            HStack {
                                Text("Tax")
                                    .font(.system(size: 9, weight: .light))
                                    .tracking(1)
                                    .textCase(.uppercase)
                                    .foregroundColor(Color.theme.textSecondary)
                                Spacer()
                                TextField("0.00", value: $session.tax, format: .currency(code: "USD"))
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 9, weight: .light, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(Color.theme.accentSecondary)
                                    .frame(width: 80)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.theme.rule).frame(height: 1)
                                    .padding(.horizontal, 22)
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Fees")
                                        .font(.system(size: 9, weight: .light))
                                        .tracking(1)
                                        .textCase(.uppercase)
                                        .foregroundColor(Color.theme.textSecondary)
                                    Text("surcharges · split evenly")
                                        .font(.system(size: 7, weight: .light))
                                        .tracking(0.5)
                                        .foregroundColor(Color.theme.textSecondary.opacity(0.6))
                                }
                                Spacer()
                                TextField("0.00", value: $session.fees, format: .currency(code: "USD"))
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 9, weight: .light, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(Color.theme.accentSecondary)
                                    .frame(width: 80)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.theme.rule).frame(height: 1)
                                    .padding(.horizontal, 22)
                            }

                            HStack {
                                Text("Tip")
                                    .font(.system(size: 9, weight: .light))
                                    .tracking(1)
                                    .textCase(.uppercase)
                                    .foregroundColor(Color.theme.textSecondary)
                                Spacer()
                                TextField("0.00", value: $session.tip, format: .currency(code: "USD"))
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 9, weight: .light, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(Color.theme.accentSecondary)
                                    .frame(width: 80)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.theme.rule).frame(height: 1)
                                    .padding(.horizontal, 22)
                            }
                        }

                        // Total
                        HStack(alignment: .lastTextBaseline) {
                            Text("Total")
                                .font(.system(size: 9, weight: .light))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(Color.theme.textSecondary)
                            Spacer()
                            Text(String(format: "$%.2f", session.total))
                                .font(.system(size: 28, weight: .light, design: .serif))
                                .foregroundColor(Color.theme.textPrimary)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 28)
                    }
                }

                Button {
                    navigateToHostSetup = true
                } label: {
                    Text("Create Split Link")
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
        .navigationDestination(isPresented: $navigateToHostSetup) {
            HostSetupView(session: $session)
        }
    }

    // MARK: — Item Row

    private func itemRow(item: ReceiptItem, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 8, weight: .light))
                .tracking(0.5)
                .foregroundColor(Color.theme.textSecondary)
                .frame(width: 20, alignment: .leading)

            if editingItemId == item.id {
                editableFields(index: index)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 10, weight: .light))
                            .tracking(0.5)
                            .foregroundColor(Color.theme.accent)
                        if item.quantity > 1 {
                            Text("×\(item.quantity)")
                                .font(.system(size: 8, weight: .light))
                                .foregroundColor(Color.theme.textSecondary)
                        }
                    }
                }

                Spacer()

                Text(item.formattedPrice)
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(Color.theme.accentSecondary)

                Menu {
                    Button { editingItemId = item.id } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        withAnimation {
                            session.items.remove(at: index)
                            recalcSubtotal()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10))
                        .foregroundColor(Color.theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
    }

    @ViewBuilder
    private func editableFields(index: Int) -> some View {
        HStack(spacing: 8) {
            TextField("Item name", text: $session.items[index].name)
                .font(.system(size: 10, weight: .light))
                .textFieldStyle(.plain)
                .foregroundColor(Color.theme.textPrimary)

            TextField("Price", value: $session.items[index].price, format: .currency(code: "USD"))
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundColor(Color.theme.accentSecondary)
                .frame(width: 70)
                .multilineTextAlignment(.trailing)

            Button("Done") {
                editingItemId = nil
                recalcSubtotal()
            }
            .font(.system(size: 9, weight: .light))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundColor(Color.theme.accent)
        }
    }

    // MARK: — Add Item Form

    private var addItemForm: some View {
        HStack(spacing: 12) {
            Text("＋")
                .font(.system(size: 10, weight: .light))
                .foregroundColor(Color.theme.textSecondary)
                .frame(width: 20)

            TextField("Item name", text: $newItemName)
                .font(.system(size: 10, weight: .light))
                .textFieldStyle(.plain)
                .foregroundColor(Color.theme.textPrimary)

            TextField("Price", text: $newItemPrice)
                .textFieldStyle(.plain)
                .keyboardType(.decimalPad)
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundColor(Color.theme.accentSecondary)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)

            Button("Add") { addNewItem() }
                .font(.system(size: 9, weight: .light))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Color.theme.accent)

            Button { isAddingItem = false; newItemName = ""; newItemPrice = "" } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(Color.theme.textSecondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
    }

    // MARK: — Subtotal Row

    private func subtotalRow(label: String, value: Double) -> some View {
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
        }
    }

    // MARK: — Helpers

    private func addNewItem() {
        let raw = newItemPrice.replacingOccurrences(of: "$", with: "")
        guard !newItemName.isEmpty, let price = Double(raw), price > 0 else { return }
        withAnimation {
            session.items.append(ReceiptItem(name: newItemName, price: price))
            newItemName = ""
            newItemPrice = ""
            isAddingItem = false
            recalcSubtotal()
        }
    }

    private func recalcSubtotal() {
        session.subtotal = session.items.reduce(0) { $0 + $1.price }
    }
    // Note: session.fees is intentionally excluded from the subtotal — it is
    // tracked separately and divided proportionally, not included in the items sum.
}
