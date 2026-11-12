import AVFoundation
import SwiftUI

/// The live camera feed, filling its space, with the detected page outlined.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var page: PageDetector.Quad?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.page = page
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        var page: PageDetector.Quad? {
            didSet { if page != oldValue { updateOutline() } }
        }

        private let outline = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            outline.strokeColor = UIColor.tintColor.cgColor
            outline.fillColor = UIColor.tintColor.withAlphaComponent(0.16).cgColor
            outline.lineWidth = 3
            outline.lineJoin = .round
            layer.addSublayer(outline)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.videoRotationAngle != 90, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            outline.frame = bounds
            updateOutline()
        }

        private func updateOutline() {
            guard let page else {
                outline.path = nil
                return
            }
            let points = [page.topLeft, page.topRight, page.bottomRight, page.bottomLeft].map {
                previewLayer.layerPointConverted(fromCaptureDevicePoint: ViewfinderGeometry.capturePoint(fromUpright: $0))
            }
            let path = UIBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach(path.addLine(to:))
            path.close()
            CATransaction.begin()
            CATransaction.setDisableActions(true)  // QuadSmoother already eases the motion
            outline.path = path.cgPath
            CATransaction.commit()
        }
    }
}

enum ViewfinderGeometry {
    /// Converts a point in upright Vision space (portrait, origin bottom-left) to
    /// AVFoundation's capture-device space (landscape sensor, origin top-left),
    /// which the preview layer knows how to place on screen.
    static func capturePoint(fromUpright point: CGPoint) -> CGPoint {
        CGPoint(x: 1 - point.y, y: 1 - point.x)
    }

    /// Whether a detected page stands taller than it is wide on screen. Vision's
    /// points are normalized per axis, so they're scaled back to the upright
    /// frame's shape (the `.photo` preset's 4:3 sensor, held portrait) first.
    static func isPortrait(_ quad: PageDetector.Quad, imageAspect: CGFloat = 3.0 / 4.0) -> Bool {
        func length(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot((a.x - b.x) * imageAspect, a.y - b.y)
        }
        let width = length(quad.topLeft, quad.topRight) + length(quad.bottomLeft, quad.bottomRight)
        let height = length(quad.topLeft, quad.bottomLeft) + length(quad.topRight, quad.bottomRight)
        return height > width
    }
}
