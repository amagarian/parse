import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

class QRCodeService {
    static let webBaseURL = "https://parseapp.io"

    // MARK: - Generate

    static func generateQRCode(from session: SplitSession) -> UIImage? {
        guard let urlString = sessionToURL(session) else { return nil }
        return generateQRCode(from: urlString)
    }

    static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("L", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scale: CGFloat = 20
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - URL Encoding

    /// Builds the QR URL pointing to the web UI.
    /// Includes `id` (session UUID for Firestore) and `d` (compact payload as offline fallback).
    static func sessionToURL(_ session: SplitSession) -> String? {
        guard let compact = session.toCompactString() else { return nil }
        guard let encoded = compact.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return "\(webBaseURL)/s?id=\(session.id.uuidString)&d=\(encoded)"
    }

    // MARK: - URL Decoding

    static func decodeSession(from string: String) -> SplitSession? {
        if let url = URL(string: string) {
            return decodeSessionFromURL(url)
        }
        return SplitSession.fromCompactString(string)
    }

    /// Decodes a session from a QR URL. Restores the original session UUID
    /// from the `id` param so Firestore listeners use the correct document ID.
    static func decodeSessionFromURL(_ url: URL) -> SplitSession? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }

        let idParam   = queryItems.first(where: { $0.name == "id" })?.value
        let dataParam = queryItems.first(where: { $0.name == "d" })?.value

        guard let dataParam else { return nil }
        guard var session = SplitSession.fromCompactString(dataParam) else { return nil }

        // Restore the host's original session UUID so Firestore doc ID matches
        if let idParam, let uuid = UUID(uuidString: idParam) {
            session.id = uuid
        }

        return session
    }
}
