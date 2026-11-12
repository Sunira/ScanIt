import CoreGraphics
import UIKit
import Testing
@testable import ScanIt

struct ViewfinderGeometryTests {
    @Test("Upright corners land on the right corners of the landscape sensor")
    func uprightToSensor() {
        // Portrait screen, Vision's origin bottom-left; the back camera's sensor is the
        // portrait image turned a quarter turn counterclockwise, origin top-left.
        #expect(ViewfinderGeometry.capturePoint(fromUpright: CGPoint(x: 0, y: 1)) == CGPoint(x: 0, y: 1))   // top-left
        #expect(ViewfinderGeometry.capturePoint(fromUpright: CGPoint(x: 1, y: 1)) == CGPoint(x: 0, y: 0))   // top-right
        #expect(ViewfinderGeometry.capturePoint(fromUpright: CGPoint(x: 1, y: 0)) == CGPoint(x: 1, y: 0))   // bottom-right
        #expect(ViewfinderGeometry.capturePoint(fromUpright: CGPoint(x: 0, y: 0)) == CGPoint(x: 1, y: 1))   // bottom-left
    }

    private func quad(x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) -> PageDetector.Quad {
        PageDetector.Quad(
            topLeft: CGPoint(x: x.lowerBound, y: y.upperBound), topRight: CGPoint(x: x.upperBound, y: y.upperBound),
            bottomRight: CGPoint(x: x.upperBound, y: y.lowerBound), bottomLeft: CGPoint(x: x.lowerBound, y: y.lowerBound))
    }

    @Test("The guide turns to match how the page is held")
    func cardOrientation() {
        // Upright frame is 3 wide × 4 tall, so a letter page spans more of x than of y.
        #expect(!ViewfinderGeometry.isPortrait(quad(x: 0.1...0.9, y: 0.35...0.65)))  // landscape card
        #expect(ViewfinderGeometry.isPortrait(quad(x: 0.2...0.8, y: 0.2...0.8)))     // portrait: 1.8 × 2.4
        #expect(!ViewfinderGeometry.isPortrait(quad(x: 0.0...1.0, y: 0.2...0.8)))    // landscape: 3 × 2.4
    }
}

struct ScanLookTests {
    @Test("Color is the default, and Photo leaves the picture alone")
    func photoIsUntouched() {
        #expect(ScanLook.defaultLook == .color)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        #expect(ScanLook.photo.applied(to: image) === image)
    }
}
