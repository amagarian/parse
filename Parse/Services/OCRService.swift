import Vision
import UIKit

class OCRService {
    struct TextBlock {
        let text: String
        let boundingBox: CGRect
    }

    static func recognizeText(in image: UIImage, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }

            let blocks: [TextBlock] = observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                return TextBlock(text: candidate.string, boundingBox: obs.boundingBox)
            }

            let lines = reconstructLines(from: blocks)

            DispatchQueue.main.async {
                completion(.success(lines))
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private static func reconstructLines(from blocks: [TextBlock]) -> [String] {
        guard !blocks.isEmpty else { return [] }

        let avgHeight = blocks.reduce(0.0) { $0 + $1.boundingBox.height } / CGFloat(blocks.count)
        let lineThreshold = max(avgHeight * 0.5, 0.005)

        let sorted = blocks.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        var lines: [[TextBlock]] = []
        var currentLine: [TextBlock] = [sorted[0]]
        var currentY = sorted[0].boundingBox.midY

        for i in 1..<sorted.count {
            let block = sorted[i]
            if abs(block.boundingBox.midY - currentY) <= lineThreshold {
                currentLine.append(block)
            } else {
                lines.append(currentLine)
                currentLine = [block]
                currentY = block.boundingBox.midY
            }
        }
        lines.append(currentLine)

        return lines.map { lineBlocks in
            lineBlocks
                .sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .map { $0.text }
                .joined(separator: " ")
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image. Please try again."
        case .recognitionFailed:
            return "Text recognition failed. Please try a clearer photo."
        }
    }
}
