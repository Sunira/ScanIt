import UIKit
import Vision

/// Reads the text on page images using Apple Vision, entirely on the device.
enum TextRecognizer {
    /// The text of every page, in order, separated by blank lines. Safe to call off the main thread.
    static func recognizeText(in pages: [Data]) async -> String {
        var texts: [String] = []
        for data in pages {
            guard let image = UIImage(data: data), let cgImage = image.cgImage else { continue }
            let text = await recognizeText(in: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
            if !text.isEmpty { texts.append(text) }
        }
        return texts.joined(separator: "\n\n")
    }

    static func recognizeText(in image: CGImage, orientation: CGImagePropertyOrientation = .up) async -> String {
        if let text = try? await recognizeDocument(image, orientation: orientation), !text.isEmpty {
            return text
        }
        return (try? await recognizeLines(image, orientation: orientation)) ?? ""
    }

    /// iOS 26 document recognition: keeps paragraph structure and reads handwriting.
    private static func recognizeDocument(_ image: CGImage, orientation: CGImagePropertyOrientation) async throws -> String {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        let observations = try await request.perform(on: image, orientation: orientation)
        return observations
            .map { $0.document.text.transcript }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Plain line-by-line recognition, used if document recognition isn't available.
    private static func recognizeLines(_ image: CGImage, orientation: CGImagePropertyOrientation) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: image, orientation: orientation)
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
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
