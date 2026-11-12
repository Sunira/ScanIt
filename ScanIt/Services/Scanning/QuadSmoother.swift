import CoreGraphics

/// Steadies the scan screen's live outline. Raw detections wobble by a few
/// pixels, can name the corners in a different order, and drop out for the odd
/// frame; this lines the corners up with the previous ones, eases each toward
/// the new position, keeps the last page through brief misses, and jumps
/// straight to a detection that is clearly somewhere else.
struct QuadSmoother: Sendable {
    /// How far to move toward each new detection (1 = no smoothing).
    var smoothing: CGFloat = 0.35
    /// A corner moving farther than this (normalized) means the page moved; follow it at once.
    var jumpDistance: CGFloat = 0.15
    /// How long to keep showing the last page after detections stop.
    var holdTime: Double = 0.4

    private(set) var page: PageDetector.Quad?
    private var lastSeen: Double = 0

    /// - Parameter time: seconds on any steady clock.
    @discardableResult
    mutating func update(with detection: PageDetector.Quad?, at time: Double) -> PageDetector.Quad? {
        guard let detection else {
            if time - lastSeen > holdTime { page = nil }
            return page
        }
        lastSeen = time
        if let page {
            let matched = detection.matchingCorners(of: page)
            self.page = page.largestCornerDistance(to: matched) < jumpDistance
                ? page.moved(toward: matched, by: smoothing)
                : matched
        } else {
            page = detection
        }
        return page
    }
}

/// Which way the corner guides stand. Only turns after the page has read the
/// other way for `delay`, so a nearly square page doesn't make them flicker.
struct GuideOrientation: Sendable {
    var delay: Double = 0.3

    private(set) var isPortrait: Bool

    init(isPortrait: Bool = false, delay: Double = 0.3) {
        self.isPortrait = isPortrait
        self.delay = delay
    }
    private var otherWaySince: Double?

    /// Sets the orientation at once (the manual turn button).
    mutating func set(portrait: Bool) {
        isPortrait = portrait
        otherWaySince = nil
    }

    @discardableResult
    mutating func update(pageIsPortrait: Bool, at time: Double) -> Bool {
        guard pageIsPortrait != isPortrait else {
            otherWaySince = nil
            return isPortrait
        }
        let since = otherWaySince ?? time
        otherWaySince = since
        if time - since >= delay { set(portrait: pageIsPortrait) }
        return isPortrait
    }
}

extension PageDetector.Quad {
    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    init(corners c: [CGPoint]) {
        self.init(topLeft: c[0], topRight: c[1], bottomRight: c[2], bottomLeft: c[3])
    }

    /// The same quad with its corners renamed (rotated in order) to sit closest to `other`'s.
    func matchingCorners(of other: Self) -> Self {
        let mine = corners
        let best = (0..<4).min { a, b in
            Self(corners: Self.rotated(mine, by: a)).totalCornerDistance(to: other)
                < Self(corners: Self.rotated(mine, by: b)).totalCornerDistance(to: other)
        } ?? 0
        return Self(corners: Self.rotated(mine, by: best))
    }

    func largestCornerDistance(to other: Self) -> CGFloat {
        zip(corners, other.corners).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
    }

    private func totalCornerDistance(to other: Self) -> CGFloat {
        zip(corners, other.corners).map { hypot($0.x - $1.x, $0.y - $1.y) }.reduce(0, +)
    }

    private static func rotated(_ points: [CGPoint], by n: Int) -> [CGPoint] {
        Array(points[n...] + points[..<n])
    }

    fileprivate func moved(toward other: Self, by t: CGFloat) -> Self {
        Self(corners: zip(corners, other.corners).map { a, b in
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        })
    }
}
