import SwiftUI

@main
struct ParseApp: App {
    @State private var deepLinkedSession: SplitSession?

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
