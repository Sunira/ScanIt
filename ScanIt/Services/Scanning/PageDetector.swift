import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// Finds the page in a photo and crops (and straightens) it, dropping the
/// table, hands or background around it. Conservative on purpose: if it isn't
/// confident it found a page-shaped rectangle, it leaves the image alone.
enum PageDetector {
    /// Returns the trimmed page, or nil when there's nothing worth trimming.
    static func trimmed(_ image: UIImage) -> UIImage? {
        guard let quad = detectPage(in: image) else { return nil }
        return crop(image, to: quad)
    }

    /// The page's corners, if Vision is confident it found one.
    static func detectPage(in image: UIImage) -> Quad? {
        image.cgImage.flatMap(detectPage(in:))
    }

    /// Crops to any four corners and straightens the result (used by manual cropping too).
    static func crop(_ image: UIImage, to quad: Quad) -> UIImage? {
        image.cgImage.flatMap { perspectiveCorrected($0, quad: quad) }
    }

    /// Corners in Vision's normalized space (0–1, origin bottom-left).
    struct Quad: Equatable, Sendable {
        var topLeft, topRight, bottomRight, bottomLeft: CGPoint

        /// Shoelace area, in normalized units (1 = the whole image).
        var area: CGFloat {
            let points = [topLeft, topRight, bottomRight, bottomLeft]
            var sum: CGFloat = 0
            for i in points.indices {
                let a = points[i], b = points[(i + 1) % points.count]
                sum += a.x * b.y - b.x * a.y
            }
            return abs(sum) / 2
        }
    }

    /// Picks the page from Vision's candidates: the largest confident one that
    /// isn't simply the whole frame (in which case there's nothing to trim).
    static func bestCandidate(_ candidates: [(quad: Quad, confidence: Float)], minimumConfidence: Float = 0.75) -> Quad? {
        candidates
            .filter { $0.confidence >= minimumConfidence && $0.quad.area >= 0.2 && $0.quad.area <= 0.97 }
            .max { $0.quad.area < $1.quad.area }?
            .quad
    }

    /// The same detection on a live camera frame (the scan screen's overlay uses it).
    static func detectPage(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Quad? {
        detectPage(with: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation))
    }

    private static func detectPage(in cgImage: CGImage) -> Quad? {
        detectPage(with: VNImageRequestHandler(cgImage: cgImage, orientation: .up))
    }

    /// Apple's document segmentation (the model behind VisionKit's scanner) first,
    /// since it copes with low contrast and busy tables; plain edge-based
    /// rectangle detection only when it finds nothing.
    private static func detectPage(with handler: VNImageRequestHandler) -> Quad? {
        let document = VNDetectDocumentSegmentationRequest()
        if (try? handler.perform([document])) != nil,
           let quad = bestCandidate(candidates(from: document.results), minimumConfidence: 0.5) {
            return quad
        }

        let request = VNDetectRectanglesRequest()
        // Letter and A4 pages are about 0.7 (short side / long side); allow tall receipts and near-square forms.
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.25
        request.minimumConfidence = 0.6
        request.quadratureTolerance = 20
        request.maximumObservations = 6

        guard (try? handler.perform([request])) != nil else { return nil }
        return bestCandidate(candidates(from: request.results))
    }

    private static func candidates(from observations: [VNRectangleObservation]?) -> [(quad: Quad, confidence: Float)] {
        (observations ?? []).map {
            (quad: Quad(topLeft: $0.topLeft, topRight: $0.topRight, bottomRight: $0.bottomRight, bottomLeft: $0.bottomLeft),
             confidence: $0.confidence)
        }
    }

    private static func perspectiveCorrected(_ cgImage: CGImage, quad: Quad) -> UIImage? {
        let input = CIImage(cgImage: cgImage)
        let size = input.extent.size
        // Core Image and Vision both put the origin at the bottom-left, so scaling is enough.
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = input
        filter.topLeft = point(quad.topLeft)
        filter.topRight = point(quad.topRight)
        filter.bottomRight = point(quad.bottomRight)
        filter.bottomLeft = point(quad.bottomLeft)

        guard
            let output = filter.outputImage,
            let result = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
    }
}
