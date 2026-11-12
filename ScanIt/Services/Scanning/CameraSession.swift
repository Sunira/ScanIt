import AVFoundation
import UIKit

/// The back camera behind the scan screen: a live preview, page detection on
/// preview frames, and a full-quality still only when the shutter is pressed
/// (there is no auto-capture). Capture work runs on `queue`, frame analysis on
/// `frameQueue`; each private var is only touched from the queue noted beside it.
final class CameraSession: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    /// The page's corners in each analyzed frame (upright Vision space, smoothed), or nil.
    let detections: AsyncStream<PageDetector.Quad?>

    private let detectionsContinuation: AsyncStream<PageDetector.Quad?>.Continuation
    private let queue = DispatchQueue(label: "com.sunira.scanit.camera")
    private let frameQueue = DispatchQueue(label: "com.sunira.scanit.camera.frames")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false                               // queue
    private var captures: [Int64: PhotoCaptureDelegate] = [:]      // queue
    private var lastDetection = ContinuousClock.now                // frameQueue
    private var isDetecting = false                                // frameQueue
    private var smoother = QuadSmoother()                          // frameQueue

    /// The most often preview frames are checked for a page; otherwise as fast as the detector keeps up.
    private static let detectionInterval = Duration.milliseconds(33)

    override init() {
        let (stream, continuation) = AsyncStream.makeStream(of: PageDetector.Quad?.self, bufferingPolicy: .bufferingNewest(1))
        detections = stream
        detectionsContinuation = continuation
        super.init()
    }

    static var isAvailable: Bool { AVCaptureDevice.default(for: .video) != nil }

    /// Asks for camera access if it hasn't been asked yet.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    func start() {
        queue.async { [self] in
            if !isConfigured { configure() }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Takes one full-quality still, or nil if the camera couldn't.
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else { return continuation.resume(returning: nil) }
                let settings = AVCapturePhotoSettings()
                settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
                settings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate { [self] image in
                    queue.async { self.captures[id] = nil }
                    continuation.resume(returning: image)
                }
                captures[id] = delegate  // AVFoundation holds its delegate weakly
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    private func configure() {
        isConfigured = true
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard
            let device = Self.backCamera(),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            if let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }) {
                photoOutput.maxPhotoDimensions = largest
            }
            // Stills come out portrait, like the screen; preview frames stay in sensor
            // orientation and are read as `.right` instead.
            if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }

    /// A multi-camera device when there is one, so the phone can switch lenses
    /// (macro on Pro models) as the page gets close.
    private static func backCamera() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices.first
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ContinuousClock.now
        guard !isDetecting, now - lastDetection >= Self.detectionInterval, let pixelBuffer = sampleBuffer.imageBuffer else { return }
        isDetecting = true
        defer { isDetecting = false }
        lastDetection = now
        // The back camera's buffers are landscape; `.right` reads them upright for a portrait phone.
        let detection = PageDetector.detectPage(in: pixelBuffer, orientation: .right)
        detectionsContinuation.yield(smoother.update(with: detection, at: ProcessInfo.processInfo.systemUptime))
    }
}

/// Receives one still and hands it back exactly once.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var completion: (@Sendable (UIImage?) -> Void)?

    init(completion: @escaping @Sendable (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = error == nil ? photo.fileDataRepresentation().flatMap(UIImage.init(data:)) : nil
        completion?(image)
        completion = nil
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // Only reached without a photo when the capture failed early.
        completion?(nil)
        completion = nil
    }
}
