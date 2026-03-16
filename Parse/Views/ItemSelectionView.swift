import SwiftUI

struct ItemSelectionView: View {
    @State var session: SplitSession
    @State private var userName = ""
    @State private var selectedItemIds: Set<UUID> = []
    @State private var showPayment = false
    @State private var hasEnteredName = false

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            if !hasEnteredName {
                nameEntryView
            } else {
                claimView
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: — Screen 1: Name Entry

    private var nameEntryView: some View {
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
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            Spacer()

            VStack(spacing: 20) {
                Text("What's your name?")
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .tracking(-0.5)
                    .foregroundColor(Color.theme.textPrimary)
                    .multilineTextAlignment(.center)

                if !session.restaurantName.isEmpty {
                    Text(session.restaurantName)
                        .font(.system(size: 9, weight: .light))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color.theme.textSecondary)
                }

                TextField("Your name", text: $userName)
                    .font(.system(size: 16, weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.theme.textPrimary)
                    .padding(.vertical, 14)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.theme.rule).frame(height: 1)
                    }
                    .padding(.horizontal, 40)
            }

            Spacer()

            let trimmed = userName.trimmingCharacters(in: .whitespaces)
            Button {
                guard !trimmed.isEmpty else { return }
                withAnimation { hasEnteredName = true }
            } label: {
                Text("Continue")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(trimmed.isEmpty ? Color.theme.textSecondary : Color(hex: 0x0B0907))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(trimmed.isEmpty
                        ? Color.theme.textSecondary.opacity(0.15)
                        : Color(hex: 0xEDE3D4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(trimmed.isEmpty)
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
    }

    // MARK: — Screen 2: Claim Items

    private var claimView: some View {
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
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            // Claim intro
            VStack(alignment: .leading, spacing: 4) {
                Text("Hi \(userName) — tap what you had.")
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .tracking(-0.3)
                    .foregroundColor(Color.theme.textPrimary)

                if !session.restaurantName.isEmpty {
                    Text(session.restaurantName)
                        .font(.system(size: 9, weight: .light))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color.theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)

            // Items list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(session.items) { item in
                        claimItemRow(item: item)
                    }
                }
                .padding(.bottom, 120)
            }

            // Bottom summary + CTA
            VStack(spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your share")
                            .font(.system(size: 8, weight: .light))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    Spacer()
                    Text(String(format: "$%.2f", selectedSubtotal))
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundColor(Color.theme.textPrimary)
                }
                .padding(16)
                .background(Color.theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.rule, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                NavigationLink(isActive: $showPayment) {
                    PaymentSummaryView(session: sessionWithClaims, userName: userName)
                } label: {
                    EmptyView()
                }
                .hidden()

                Button {
                    guard !selectedItemIds.isEmpty else { return }
                    showPayment = true
                } label: {
                    Text(selectedItemIds.isEmpty ? "Select items to continue" : "Confirm My Items")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(selectedItemIds.isEmpty ? Color.theme.textSecondary : Color(hex: 0x0B0907))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedItemIds.isEmpty
                            ? Color.theme.textSecondary.opacity(0.15)
                            : Color(hex: 0xEDE3D4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedItemIds.isEmpty)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
            .padding(.top, 16)
            .background(
                Color.theme.background
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.theme.rule).frame(height: 1)
                    }
            )
        }
    }

    // MARK: — Claim Item Row

    private func claimItemRow(item: ReceiptItem) -> some View {
        let isSelected = selectedItemIds.contains(item.id)
        let otherClaimers = item.claimedBy.filter { $0 != userName }

        return Button {
            withAnimation(.spring(response: 0.25)) {
                if isSelected {
                    selectedItemIds.remove(item.id)
                } else {
                    selectedItemIds.insert(item.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Circular check
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.theme.accentSecondary : .clear)
                        .overlay(
                            Circle().stroke(
                                isSelected ? Color.theme.accentSecondary : Color.theme.textSecondary,
                                lineWidth: 1
                            )
                        )
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(Color.theme.background)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(item.name)
                    .font(.system(size: 10, weight: .light))
                    .tracking(0.5)
                    .foregroundColor(isSelected ? Color.theme.textPrimary : Color.theme.accent)

                Spacer()

                if !otherClaimers.isEmpty {
                    Text(otherClaimers.first ?? "")
                        .font(.system(size: 8, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(Color.theme.textSecondary)
                }

                Text(item.formattedPrice)
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(isSelected ? Color.theme.accentSecondary : Color.theme.accentSecondary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
    }

    // MARK: — Computed

    private var selectedSubtotal: Double {
        session.items
            .filter { selectedItemIds.contains($0.id) }
            .reduce(0) { $0 + $1.price }
    }

    private var sessionWithClaims: SplitSession {
        var updated = session
        for i in updated.items.indices {
            if selectedItemIds.contains(updated.items[i].id) {
                if !updated.items[i].claimedBy.contains(userName) {
                    updated.items[i].claimedBy.append(userName)
                }
            }
        }
        return updated
    }
}
