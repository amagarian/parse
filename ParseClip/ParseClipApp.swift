import SwiftUI
import FirebaseCore

@main
struct ParseClipApp: App {
    @State private var session: SplitSession?

    init() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if let session {
                    ItemSelectionView(session: session)
                } else {
                    loadingView
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                session = QRCodeService.decodeSessionFromURL(url)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()

            ParseMark(size: 52)
                .padding(.bottom, 20)

            Text("parse")
                .font(.system(size: 28, weight: .light))
                .tracking(8)
                .textCase(.uppercase)
                .foregroundColor(Color.theme.textPrimary)

            Rectangle()
                .fill(Color.theme.rule)
                .frame(height: 1)
                .padding(.horizontal, 48)
                .padding(.vertical, 32)

            Text("Waiting for bill data…")
                .font(.system(size: 13))
                .tracking(1)
                .foregroundColor(Color.theme.textSecondary)
                .padding(.bottom, 16)

            ProgressView()
                .tint(Color.theme.accent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
    }
}
