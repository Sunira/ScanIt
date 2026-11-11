import UIKit

/// Generated images and PDFs for tests.
enum TestImages {
    static func solid(_ color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func pdf(pages: Int) -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { context in
            for number in 1...pages {
                context.beginPage()
                ("Page \(number)" as NSString).draw(at: CGPoint(x: 72, y: 72),
                                                     withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
    }
}
