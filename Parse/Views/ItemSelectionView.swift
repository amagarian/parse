import SwiftUI
import FirebaseFirestore

struct ItemSelectionView: View {
    @State var session: SplitSession
    @State private var userName: String
    @State private var selectedItemIds: Set<UUID> = []
    @State private var splitOverrides: [UUID: Int] = [:]
    @State private var showPayment = false
    @State private var hasEnteredName: Bool
    @State private var listenerHandle: (any ListenerRegistration)?
    @State private var isSaving = false
    @State private var confirmedSession: SplitSession?
    @State private var hostTotal: Double? = nil
    @State private var splitPickerItemId: UUID? = nil
    @State private var customSplitText: String = ""
    @Environment(\.dismiss) private var dismiss

    let isHost: Bool

    init(session: SplitSession, prefilledName: String = "", isHost: Bool = false) {
        _session = State(initialValue: session)
        _userName = State(initialValue: prefilledName)
        _hasEnteredName = State(initialValue: !prefilledName.isEmpty)
        self.isHost = isHost
    }

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
        .onAppear {
            startListening()
        }
        .onDisappear {
            listenerHandle?.remove()
            listenerHandle = nil
        }
        .navigationDestination(isPresented: $showPayment) {
            if let s = confirmedSession {
                PaymentSummaryView(session: s, userName: userName)
            }
        }
        .sheet(isPresented: Binding(
            get: { splitPickerItemId != nil },
            set: { if !$0 { splitPickerItemId = nil } }
        )) {
            splitPickerSheet
        }
    }

    // MARK: — Firestore

    private func startListening() {
        let sessionId = session.id.uuidString
        listenerHandle = FirestoreService.shared.listen(to: sessionId) { updated in
            session = updated
        }
    }

    /// Writes the current selection state to Firestore immediately so all
    /// other devices see the live toggle, not just after "Confirm".
    private func syncSelectionLive() {
        guard hasEnteredName, !userName.isEmpty else { return }
        Task {
            try? await FirestoreService.shared.updateClaims(
                sessionId: session.id.uuidString,
                items: sessionWithClaims.items
            )
        }
    }

    private func confirmAndSync() {
        guard !selectedItemIds.isEmpty else { return }
        isSaving = true
        let updated = sessionWithClaims
        Task {
            try? await FirestoreService.shared.updateClaims(
                sessionId: session.id.uuidString,
                items: updated.items
            )
            await MainActor.run {
                isSaving = false
                if isHost {
                    hostTotal = updated.totalForPerson(userName)
                    dismiss()
                } else {
                    confirmedSession = updated
                    showPayment = true
                }
            }
        }
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
                Task {
                    try? await FirestoreService.shared.addParticipant(
                        sessionId: session.id.uuidString,
                        name: trimmed
                    )
                }
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

                    Text("Tap & hold an item to split it")
                        .font(.system(size: 8, weight: .light))
                        .tracking(1.5)
                        .foregroundColor(Color.theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
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

                Button {
                    confirmAndSync()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(Color(hex: 0x0B0907))
                        } else {
                            Text(selectedItemIds.isEmpty ? "Select items to continue" : "Confirm My Items")
                                .font(.system(size: 11, weight: .light, design: .monospaced))
                                .tracking(2.5)
                                .textCase(.uppercase)
                                .foregroundColor(selectedItemIds.isEmpty ? Color.theme.textSecondary : Color(hex: 0x0B0907))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedItemIds.isEmpty
                        ? Color.theme.textSecondary.opacity(0.15)
                        : Color(hex: 0xEDE3D4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedItemIds.isEmpty || isSaving)
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
        let mySplit = splitOverrides[item.id]
        let hasAnySplit = mySplit != nil || !item.splitOverrides.isEmpty

        return HStack(spacing: 12) {
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 10, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(isSelected ? Color.theme.textPrimary : Color.theme.accent)

                    if hasAnySplit {
                        Text("partial")
                            .font(.system(size: 7, weight: .light, design: .monospaced))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.accentSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.theme.accentSecondary.opacity(0.4), lineWidth: 0.5)
                            )
                    }
                }

                if isSelected, let split = mySplit {
                    Text("Your share: 1/\(split)")
                        .font(.system(size: 8, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(Color.theme.accentSecondary)
                } else if !otherClaimers.isEmpty {
                    let splitDetails = otherClaimers.compactMap { name -> String? in
                        if let s = item.splitOverrides[name] { return "\(name) (1/\(s))" }
                        return nil
                    }
                    if !splitDetails.isEmpty {
                        Text(splitDetails.joined(separator: ", "))
                            .font(.system(size: 8, weight: .light))
                            .tracking(0.5)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                }
            }

            Spacer()

            if !otherClaimers.isEmpty && mySplit == nil {
                Text(otherClaimers.first ?? "")
                    .font(.system(size: 8, weight: .light))
                    .tracking(0.5)
                    .foregroundColor(Color.theme.textSecondary)
            }

            Text(item.formattedPrice)
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(Color.theme.accentSecondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25)) {
                if isSelected {
                    selectedItemIds.remove(item.id)
                    splitOverrides.removeValue(forKey: item.id)
                } else {
                    selectedItemIds.insert(item.id)
                }
            }
            syncSelectionLive()
        }
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if !isSelected {
                selectedItemIds.insert(item.id)
            }
            splitPickerItemId = item.id
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .padding(.horizontal, 22)
        }
    }

    // MARK: — Computed

    private var selectedSubtotal: Double {
        session.items
            .filter { selectedItemIds.contains($0.id) }
            .reduce(0) { total, item in
                if let split = splitOverrides[item.id] {
                    return total + item.price / Double(max(1, split))
                }
                return total + item.price
            }
    }

    private var sessionWithClaims: SplitSession {
        var updated = session
        for i in updated.items.indices {
            if selectedItemIds.contains(updated.items[i].id) {
                if !updated.items[i].claimedBy.contains(userName) {
                    updated.items[i].claimedBy.append(userName)
                }
                if let split = splitOverrides[updated.items[i].id] {
                    updated.items[i].splitOverrides[userName] = split
                } else {
                    updated.items[i].splitOverrides.removeValue(forKey: userName)
                }
            }
        }
        return updated
    }

    // MARK: — Split Picker

    private func applySplit(_ n: Int) {
        guard let id = splitPickerItemId else { return }
        splitOverrides[id] = n
        splitPickerItemId = nil
        customSplitText = ""
        syncSelectionLive()
    }

    private var splitPickerSheet: some View {
        let itemName = session.items.first(where: { $0.id == splitPickerItemId })?.name ?? "Item"
        let currentSplit = splitOverrides[splitPickerItemId ?? UUID()]
        return VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Split this item")
                    .font(.system(size: 9, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color.theme.textSecondary)
                Text(itemName)
                    .font(.system(size: 16, weight: .light, design: .serif))
                    .foregroundColor(Color.theme.textPrimary)
            }
            .padding(.top, 28)
            .padding(.bottom, 24)

            Text("How many people are sharing?")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(Color.theme.accentSecondary)
                .padding(.bottom, 16)

            HStack(spacing: 10) {
                ForEach([2, 3, 4], id: \.self) { n in
                    let isActive = currentSplit == n
                    Button { applySplit(n) } label: {
                        Text("1/\(n)")
                            .font(.system(size: 12, weight: .light, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(isActive ? Color(hex: 0x0B0907) : Color.theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isActive ? Color(hex: 0xEDE3D4) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isActive ? Color.clear : Color.theme.rule, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                HStack(spacing: 6) {
                    Text("1/")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(Color.theme.accent)
                    TextField("", text: $customSplitText)
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(Color.theme.textPrimary)
                        .keyboardType(.numberPad)
                        .frame(width: 24)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.theme.rule, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 22)

            if let n = Int(customSplitText), n >= 2 {
                Button { applySplit(n) } label: {
                    Text("Split 1/\(n)")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color(hex: 0x0B0907))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0xEDE3D4))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
            }

            Button {
                guard let id = splitPickerItemId else { return }
                splitOverrides.removeValue(forKey: id)
                splitPickerItemId = nil
                customSplitText = ""
                syncSelectionLive()
            } label: {
                Text("Even split (default)")
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.theme.rule, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)

            Spacer()
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.theme.background)
    }
}
