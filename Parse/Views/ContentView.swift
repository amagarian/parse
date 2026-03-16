import SwiftUI

struct ContentView: View {
    @State private var capturedImage: UIImage?
    @State private var session = SplitSession()
    @State private var isProcessing = false
    @State private var ocrError: String?
    @State private var showCamera = false
    @State private var navigateToEdit = false
    @State private var navigateToItemSelection = false
    @State private var showScanner = false
    @State private var scannedSession: SplitSession?
    @Binding var deepLinkedSession: SplitSession?

    var body: some View {
        NavigationStack {
            homeView
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $navigateToEdit) {
                    ReceiptEditView(session: $session)
                }
                .navigationDestination(isPresented: $navigateToItemSelection) {
                    if let scanned = scannedSession {
                        ItemSelectionView(session: scanned)
                    }
                }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(capturedImage: $capturedImage)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScanQRView(scannedSession: $scannedSession)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                showCamera = false
                processImage(image)
            }
        }
        .onChange(of: scannedSession) { _, newSession in
            if newSession != nil {
                showScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToItemSelection = true
                }
            }
        }
        .onChange(of: deepLinkedSession) { _, newSession in
            if let s = newSession {
                scannedSession = s
                deepLinkedSession = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToItemSelection = true
                }
            }
        }
    }

    // MARK: — Home / Onboarding

    private var homeView: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Color.theme.accent.opacity(0.07), .clear],
                center: .center, startRadius: 0, endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Mark + wordmark
                VStack(spacing: 14) {
                    ParseMark(size: 52)

                    Text("parse")
                        .font(.system(size: 54, weight: .light, design: .serif))
                        .tracking(-1.5)
                        .foregroundColor(Color.theme.textPrimary)

                    Text("Scan. Split. Settle.")
                        .font(.system(size: 9, weight: .light))
                        .tracking(3.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color.theme.textSecondary)
                }

                Spacer().frame(height: 52)

                // Steps
                VStack(spacing: 0) {
                    stepRow(num: "01", title: "Scan the receipt",
                            desc: "Point your camera. We read every line.")
                    stepRow(num: "02", title: "Share with the table",
                            desc: "Friends scan a QR and claim their dishes.")
                    stepRow(num: "03", title: "Everyone pays their share",
                            desc: "Venmo requests sent automatically.")
                }
                .padding(.horizontal, 32)

                Spacer()

                // CTAs
                VStack(spacing: 0) {
                    if isProcessing {
                        VStack(spacing: 14) {
                            ProgressView().tint(Color.theme.accent)
                            Text("Reading receipt…")
                                .font(.system(size: 10, weight: .light))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundColor(Color.theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        Button { showCamera = true } label: {
                            Text("Get Started")
                                .font(.system(size: 11, weight: .light, design: .monospaced))
                                .tracking(2.5)
                                .textCase(.uppercase)
                                .foregroundColor(Color(hex: 0x0B0907))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: 0xEDE3D4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button { showScanner = true } label: {
                            Text("Join a Split")
                                .font(.system(size: 10, weight: .light))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .foregroundColor(Color.theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }

                    if let error = ocrError {
                        Text(error)
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(.red.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    private func stepRow(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(num)
                .font(.system(size: 8, weight: .light))
                .tracking(1.5)
                .foregroundColor(Color.theme.textSecondary)
                .frame(width: 20, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .light))
                    .tracking(0.3)
                    .foregroundColor(Color.theme.textPrimary)
                Text(desc)
                    .font(.system(size: 10, weight: .light))
                    .tracking(0.3)
                    .foregroundColor(Color.theme.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.theme.rule).frame(height: 1)
        }
    }

    // MARK: — OCR Processing

    private func processImage(_ image: UIImage) {
        isProcessing = true
        ocrError = nil

        OCRService.recognizeText(in: image) { result in
            isProcessing = false
            switch result {
            case .success(let lines):
                let parsed = ReceiptParser.parse(lines: lines)
                session.items = parsed.items
                session.subtotal = parsed.subtotal ?? parsed.items.reduce(0) { $0 + $1.price }
                session.tax = parsed.tax ?? 0
                session.tip = parsed.tip ?? 0
                session.restaurantName = parsed.restaurantName ?? ""

                if session.items.isEmpty {
                    ocrError = "Couldn't parse items. Try again or add manually."
                }
                navigateToEdit = true

            case .failure(let error):
                ocrError = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView(deepLinkedSession: .constant(nil))
}
