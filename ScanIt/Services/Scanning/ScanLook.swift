import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// How a scan is processed after the shutter, chosen on the scan screen before
/// each picture. Photo keeps the page as photographed; Color is the brighter,
/// flatter "document" look that VisionKit's scanner used to apply on its own.
enum ScanLook: String, CaseIterable, Sendable {
    case photo, color

    static let defaultLook = ScanLook.photo

    var title: String {
        switch self {
        case .photo: "Photo"
        case .color: "Color"
        }
    }

    /// The processed picture. Photo returns the image untouched.
    func applied(to image: UIImage) -> UIImage {
        switch self {
        case .photo:
            return image
        case .color:
            guard let cgImage = image.cgImage else { return image }
            let filter = CIFilter.documentEnhancer()
            filter.inputImage = CIImage(cgImage: cgImage)
            filter.amount = 1
            guard
                let output = filter.outputImage,
                let result = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: output.extent)
            else { return image }
            return UIImage(cgImage: result, scale: 1, orientation: .up)
        }
    }
}
