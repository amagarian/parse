import SwiftUI
import FirebaseCore

@main
struct ParseApp: App {
    @State private var deepLinkedSession: SplitSession?

    init() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkedSession: $deepLinkedSession)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    deepLinkedSession = QRCodeService.decodeSessionFromURL(url)
                }
        }
    }
}
