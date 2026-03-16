import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

class QRCodeService {
    static let appClipDomain = "amagarian.github.io"
    static let appClipBaseURL = "https://\(appClipDomain)"

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

    static func sessionToURL(_ session: SplitSession) -> String? {
        guard let compact = session.toCompactString() else { return nil }
        guard let encoded = compact.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return "\(appClipBaseURL)/s?d=\(encoded)"
    }

    static func decodeSession(from string: String) -> SplitSession? {
        if let url = URL(string: string) {
            return decodeSessionFromURL(url)
        }
        return SplitSession.fromCompactString(string)
    }

    static func decodeSessionFromURL(_ url: URL) -> SplitSession? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataParam = queryItems.first(where: { $0.name == "d" })?.value else {
            return nil
        }
        return SplitSession.fromCompactString(dataParam)
    }
}
