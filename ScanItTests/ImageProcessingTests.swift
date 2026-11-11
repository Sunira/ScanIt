import Testing
import UIKit
@testable import ScanIt

struct ImageProcessingTests {
    @Test func scalesLargeImagesDownToTheLimit() {
        let image = TestImages.solid(.red, size: CGSize(width: 3000, height: 1500))
        let resized = ImageProcessing.resized(image, maxDimension: 2400)
        #expect(resized.size.width * resized.scale == 2400)
        #expect(resized.size.height * resized.scale == 1200)
    }

    @Test func leavesSmallImagesAtTheirSize() {
        let image = TestImages.solid(.red, size: CGSize(width: 800, height: 600))
        let resized = ImageProcessing.resized(image, maxDimension: 2400)
        #expect(resized.size.width * resized.scale == 800)
    }

    @Test func encodesPagesAndThumbnails() throws {
        let image = TestImages.solid(.blue, size: CGSize(width: 1200, height: 1600))
        #expect(ImageProcessing.encodePage(image) != nil)

        let thumbnail = try #require(ImageProcessing.thumbnail(image).flatMap(UIImage.init(data:)))
        #expect(max(thumbnail.size.width, thumbnail.size.height) * thumbnail.scale <= ImageProcessing.thumbnailMaxDimension)
    }

    @Test func rendersEveryPDFPage() throws {
        let pages = try #require(PDFRendering.renderPages(from: TestImages.pdf(pages: 3)))
        #expect(pages.count == 3)
    }

    @Test func rejectsDataThatIsNotAPDF() {
        #expect(PDFRendering.renderPages(from: Data("not a pdf".utf8)) == nil)
    }
}
