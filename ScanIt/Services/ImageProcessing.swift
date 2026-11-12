import UIKit
import PDFKit

/// Resizing and compressing page images. Safe to call off the main thread.
enum ImageProcessing {
    /// Longest side of a stored page, in pixels. Sharp enough to read and print.
    static let pageMaxDimension: CGFloat = 2400
    /// Longest side of a list thumbnail, in pixels.
    static let thumbnailMaxDimension: CGFloat = 240

    /// Returns the image scaled down so its longest side is at most `maxDimension` pixels,
    /// drawn upright (EXIF orientation applied).
    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale,
                               height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > 0 else { return image }
        let factor = min(1, maxDimension / longest)
        let newSize = CGSize(width: (pixelSize.width * factor).rounded(),
                             height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Compressed data for a stored page: HEIC when available, otherwise JPEG.
    static func encodePage(_ image: UIImage) -> Data? {
        let page = resized(image, maxDimension: pageMaxDimension)
        return page.heicData() ?? page.jpegData(compressionQuality: 0.8)
    }

    /// Small JPEG for the Documents list.
    static func thumbnail(_ image: UIImage) -> Data? {
        resized(image, maxDimension: thumbnailMaxDimension).jpegData(compressionQuality: 0.7)
    }

    /// Turns an image a quarter turn at a time (positive = clockwise), keeping it `.up`.
    static func rotated(_ image: UIImage, quarterTurns: Int) -> UIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return image }
        let size = turns % 2 == 1 ? CGSize(width: image.size.height, height: image.size.width) : image.size

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: CGFloat(turns) * .pi / 2)  // UIKit's y axis points down, so positive is clockwise
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }
}

/// Turns PDF pages into images.
enum PDFRendering {
    /// Very long PDFs are cut off at this many pages to keep the app responsive.
    static let maxPages = 50

    static func renderPages(from data: Data,
                            maxDimension: CGFloat = ImageProcessing.pageMaxDimension) -> [UIImage]? {
        guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else { return nil }
        var images: [UIImage] = []
        for index in 0..<min(pdf.pageCount, maxPages) {
            guard let page = pdf.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let longest = max(bounds.width, bounds.height)
            guard longest > 0 else { continue }
            let factor = min(maxDimension / longest, 3)
            let size = CGSize(width: bounds.width * factor, height: bounds.height * factor)
            images.append(page.thumbnail(of: size, for: .mediaBox))
        }
        return images
    }
}
