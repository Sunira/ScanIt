import CoreGraphics
import Testing
@testable import ScanIt

struct PageDetectorTests {
    private func quad(inset: CGFloat) -> PageDetector.Quad {
        PageDetector.Quad(
            topLeft: CGPoint(x: inset, y: 1 - inset), topRight: CGPoint(x: 1 - inset, y: 1 - inset),
            bottomRight: CGPoint(x: 1 - inset, y: inset), bottomLeft: CGPoint(x: inset, y: inset)
        )
    }

    @Test("Area of a centered rectangle")
    func area() {
        #expect(abs(quad(inset: 0.25).area - 0.25) < 0.0001)
    }

    @Test("Picks the largest confident page-sized rectangle")
    func picksLargest() {
        let small = quad(inset: 0.3), large = quad(inset: 0.1)
        #expect(PageDetector.bestCandidate([(small, 0.9), (large, 0.9)]) == large)
    }

    @Test("Leaves the image alone when unsure or when the page already fills the frame")
    func conservative() {
        #expect(PageDetector.bestCandidate([(quad(inset: 0.1), 0.5)]) == nil)      // low confidence
        #expect(PageDetector.bestCandidate([(quad(inset: 0.005), 0.99)]) == nil)    // nothing to trim
        #expect(PageDetector.bestCandidate([(quad(inset: 0.4), 0.99)]) == nil)     // too small to be the page
        #expect(PageDetector.bestCandidate([]) == nil)
    }
}

struct QuadSmootherTests {
    private func quad(_ x: CGFloat) -> PageDetector.Quad {
        PageDetector.Quad(topLeft: CGPoint(x: x, y: 0.9), topRight: CGPoint(x: x + 0.5, y: 0.9),
                          bottomRight: CGPoint(x: x + 0.5, y: 0.1), bottomLeft: CGPoint(x: x, y: 0.1))
    }

    @Test func easesTowardSmallMovesAndJumpsOnLargeOnes() {
        var smoother = QuadSmoother()
        smoother.update(with: quad(0.1), at: 0)
        let eased = smoother.update(with: quad(0.15), at: 0.05)
        #expect(eased != nil && eased!.topLeft.x > 0.1 && eased!.topLeft.x < 0.15)
        #expect(smoother.update(with: quad(0.4), at: 0.1) == quad(0.4))
    }

    @Test func keepsThePageThroughBriefMisses() {
        var smoother = QuadSmoother()
        smoother.update(with: quad(0.1), at: 0)
        #expect(smoother.update(with: nil, at: 0.2) != nil)
        #expect(smoother.update(with: nil, at: 1.0) == nil)
    }

    @Test func guidesOnlyTurnAfterTheDelay() {
        var guides = GuideOrientation(isPortrait: true)
        let early = guides.update(pageIsPortrait: false, at: 0)
        let stillEarly = guides.update(pageIsPortrait: false, at: 0.1)
        let turned = guides.update(pageIsPortrait: false, at: 0.4)
        #expect(early && stillEarly)
        #expect(!turned)
    }
}

struct LiveSensitivityTests {
    private func quad(inset: CGFloat) -> PageDetector.Quad {
        PageDetector.Quad(topLeft: CGPoint(x: inset, y: 1 - inset), topRight: CGPoint(x: 1 - inset, y: 1 - inset),
                          bottomRight: CGPoint(x: 1 - inset, y: inset), bottomLeft: CGPoint(x: inset, y: inset))
    }

    @Test func liveOutlineFindsAPageHeldFarAway() {
        let far = quad(inset: 0.35)  // fills about 9% of the frame
        let live = PageDetector.Sensitivity.live
        #expect(PageDetector.bestCandidate([(far, 0.6)], minimumConfidence: live.rectangleConfidence,
                                           minimumArea: live.minimumArea) == far)
        #expect(PageDetector.bestCandidate([(far, 0.6)]) == nil)  // trimming stays cautious
    }
}
