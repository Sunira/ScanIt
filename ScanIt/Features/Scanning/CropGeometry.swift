import CoreGraphics

/// Pure geometry for the crop screen, kept separate so it can be unit-tested.
/// Screen corners are normalized (0–1) with the origin at the top-left, in the
/// order top-left, top-right, bottom-right, bottom-left.
enum CropGeometry {
    static let fullFrame: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1),
    ]

    /// Vision / Core Image put the origin at the bottom-left.
    static func quad(fromScreen corners: [CGPoint]) -> PageDetector.Quad {
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        return PageDetector.Quad(
            topLeft: flip(corners[0]), topRight: flip(corners[1]),
            bottomRight: flip(corners[2]), bottomLeft: flip(corners[3])
        )
    }

    static func screenCorners(from quad: PageDetector.Quad) -> [CGPoint] {
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        return [flip(quad.topLeft), flip(quad.topRight), flip(quad.bottomRight), flip(quad.bottomLeft)]
    }

    static func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
    }

    /// Where the finger sits relative to the corner it grabbed, so the corner
    /// doesn't jump to the finger's centre when a drag starts.
    static func offset(from finger: CGPoint, to corner: CGPoint) -> CGPoint {
        CGPoint(x: corner.x - finger.x, y: corner.y - finger.y)
    }

    /// The corner's position for a finger at `finger`, keeping the offset from drag start.
    static func dragged(finger: CGPoint, offset: CGPoint) -> CGPoint {
        clamped(CGPoint(x: finger.x + offset.x, y: finger.y + offset.y))
    }

    /// The size an image of `imageSize` takes when fitted inside `bounds`.
    static func fittedSize(_ imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    static func isFullFrame(_ corners: [CGPoint]) -> Bool {
        zip(corners, fullFrame).allSatisfy { abs($0.x - $1.x) < 0.001 && abs($0.y - $1.y) < 0.001 }
    }
}
