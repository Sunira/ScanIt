import CoreGraphics
import Testing
import UIKit
@testable import ScanIt

struct CropGeometryTests {
    @Test("Screen corners and Vision quads round-trip")
    func roundTrip() {
        let corners = [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.9, y: 0.15), CGPoint(x: 0.85, y: 0.8), CGPoint(x: 0.12, y: 0.9)]
        let quad = CropGeometry.quad(fromScreen: corners)
        #expect(quad.topLeft == CGPoint(x: 0.1, y: 0.8))   // y flipped: Vision's origin is bottom-left
        let back = CropGeometry.screenCorners(from: quad)
        #expect(zip(back, corners).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 })
    }

    @Test("Corners can't be dragged off the image")
    func clamps() {
        #expect(CropGeometry.clamped(CGPoint(x: -0.2, y: 1.3)) == CGPoint(x: 0, y: 1))
    }

    @Test("Fits a landscape photo into a portrait space")
    func fitted() {
        #expect(CropGeometry.fittedSize(CGSize(width: 300, height: 200), in: CGSize(width: 150, height: 400)) == CGSize(width: 150, height: 100))
    }

    @Test("A dragged corner keeps its offset from the finger and stays on the image")
    func drag() {
        let offset = CropGeometry.offset(from: CGPoint(x: 0.12, y: 0.18), to: CGPoint(x: 0.1, y: 0.2))
        let moved = CropGeometry.dragged(finger: CGPoint(x: 0.52, y: 0.58), offset: offset)
        #expect(abs(moved.x - 0.5) < 1e-9 && abs(moved.y - 0.6) < 1e-9)
        #expect(CropGeometry.dragged(finger: CGPoint(x: 1.1, y: -0.1), offset: offset) == CGPoint(x: 1, y: 0.0))
    }

    @Test("Recognizes an untouched full frame")
    func fullFrame() {
        #expect(CropGeometry.isFullFrame(CropGeometry.fullFrame))
        #expect(!CropGeometry.isFullFrame([CGPoint(x: 0.1, y: 0)] + CropGeometry.fullFrame.dropFirst()))
    }
}

struct ManualCropTests {
    @Test("Cropping to a rectangle keeps just that part")
    func cropsToQuad() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            UIColor.white.setFill()
            context.fill(CGRect(x: 100, y: 75, width: 200, height: 150))
        }
        let corners = [CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.25), CGPoint(x: 0.75, y: 0.75), CGPoint(x: 0.25, y: 0.75)]
        let cropped = try #require(PageDetector.crop(image, to: CropGeometry.quad(fromScreen: corners)))
        #expect(abs(cropped.size.width - 200) <= 2)
        #expect(abs(cropped.size.height - 150) <= 2)
    }
}
