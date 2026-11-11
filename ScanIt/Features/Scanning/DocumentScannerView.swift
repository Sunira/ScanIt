import SwiftUI
import VisionKit

enum ScanOutcome {
    case finished([UIImage])
    case cancelled
    case failed(Error)
}

/// Apple's document camera: finds page edges, straightens pages, and supports several pages per scan.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onFinish: @MainActor (ScanOutcome) -> Void

    /// False in the Simulator and on devices without a camera.
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        let onFinish: @MainActor (ScanOutcome) -> Void

        init(onFinish: @escaping @MainActor (ScanOutcome) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onFinish(.finished(images))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(.cancelled)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onFinish(.failed(error))
        }
    }
}
