import SwiftUI

struct ShareSessionView: View {
    let session: SplitSession
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var showCopied = false
    @State private var showQRFullscreen = false

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button { dismiss() } label: {
                        Text("← Review")
                            .font(.system(size: 9, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        copyLink()
                    } label: {
                        Text(showCopied ? "Copied" : "Copy Link")
                            .font(.system(size: 9, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(showCopied ? Color.theme.accent : Color.theme.textSecondary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)

                // Step label
                Text("Step 3 of 3 — Share")
                    .font(.system(size: 8, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 0) {
                        // Intro
                        Text("Pass your phone\nor share the link.")
                            .font(.system(size: 22, weight: .light, design: .serif))
                            .italic()
                            .tracking(-0.3)
                            .foregroundColor(Color.theme.textPrimary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 20)

                        // QR card
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.theme.rule, lineWidth: 1)
                                )

                            RadialGradient(
                                colors: [Color.theme.accent.opacity(0.05), .clear],
                                center: .center, startRadius: 0, endRadius: 120
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            VStack(spacing: 14) {
                                if let qrImage {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 110, height: 110)
                                        .opacity(0.8)
                                } else {
                                    ProgressView().tint(Color.theme.accent)
                                        .frame(width: 110, height: 110)
                                }

                                Text("Tap to enlarge · Scan to claim items")
                                    .font(.system(size: 8, weight: .light))
                                    .tracking(2)
                                    .textCase(.uppercase)
                                    .foregroundColor(Color.theme.textSecondary)

                                if !session.restaurantName.isEmpty {
                                    Text("\(session.restaurantName) · \(String(format: "$%.2f", session.total)) total")
                                        .font(.system(size: 12, weight: .light, design: .serif))
                                        .foregroundColor(Color.theme.accentSecondary)
                                }
                            }
                            .padding(24)
                        }
                        .onTapGesture { showQRFullscreen = true }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 20)

                        // Friend status
                        VStack(spacing: 0) {
                            if !session.hostName.isEmpty {
                                friendRow(
                                    initial: String(session.hostName.prefix(1)).uppercased(),
                                    name: session.hostName,
                                    detail: "Organiser",
                                    joined: true
                                )
                            }

                            let claimants = session.allClaimants
                            if claimants.isEmpty {
                                friendRow(initial: "—", name: "Waiting…", detail: "Not yet joined", joined: false)
                            } else {
                                ForEach(claimants, id: \.self) { name in
                                    let amount = session.totalForPerson(name)
                                    friendRow(
                                        initial: String(name.prefix(1)).uppercased(),
                                        name: name,
                                        detail: String(format: "Claimed $%.2f", amount),
                                        joined: true
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 28)
                    }
                }

                // Send Venmo CTA
                Button {
                    openVenmoForAll()
                } label: {
                    Text("Send Venmo Requests")
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
        .onAppear {
            qrImage = QRCodeService.generateQRCode(from: session)
        }
        .fullScreenCover(isPresented: $showQRFullscreen) {
            qrFullscreenView
        }
    }

    // MARK: — QR Fullscreen

    private var qrFullscreenView: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.theme.cardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.theme.rule))
                        )
                }

                VStack(spacing: 6) {
                    Text("Scan to claim items")
                        .font(.system(size: 9, weight: .light))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color.theme.textSecondary)

                    if !session.restaurantName.isEmpty {
                        Text("\(session.restaurantName) · \(String(format: "$%.2f", session.total)) total")
                            .font(.system(size: 13, weight: .light, design: .serif))
                            .italic()
                            .foregroundColor(Color.theme.accentSecondary)
                    }
                }

                Spacer()

                Button { showQRFullscreen = false } label: {
                    Text("Done")
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(Color.theme.textSecondary)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.rule))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: — Friend Row

    private func friendRow(initial: String, name: String, detail: String, joined: Bool) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: 0x231E19))
                    .overlay(Circle().stroke(Color.theme.rule, lineWidth: 1))
                    .frame(width: 26, height: 26)
                Text(initial)
                    .font(.system(size: 9, weight: .light))
                    .foregroundColor(Color.theme.accentSecondary)
            }

            Text(name)
                .font(.system(size: 10, weight: .light))
                .tracking(0.4)
                .foregroundColor(Color.theme.accent)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(joined ? Color.theme.accentSecondary : .clear)
                    .overlay(
                        Circle().stroke(joined ? Color.clear : Color.theme.textSecondary, lineWidth: 1)
                    )
                    .frame(width: 6, height: 6)

                Text(detail)
                    .font(.system(size: 8, weight: .light))
                    .tracking(1)
                    .foregroundColor(Color.theme.textSecondary)
            }
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
                .opacity(0)
        }
    }

    // MARK: — Actions

    private func copyLink() {
        if let urlString = QRCodeService.sessionToURL(session) {
            UIPasteboard.general.string = urlString
            withAnimation {
                showCopied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showCopied = false }
            }
        }
    }

    private func openVenmoForAll() {
        let note = session.restaurantName.isEmpty
            ? "Dinner split via Parse"
            : "\(session.restaurantName) - split via Parse"

        var components = URLComponents(string: "venmo://paycharge")!
        components.queryItems = [
            URLQueryItem(name: "txn", value: "charge"),
            URLQueryItem(name: "note", value: note),
        ]
        if let url = components.url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://venmo.com/") {
            UIApplication.shared.open(webURL)
        }
    }
}
