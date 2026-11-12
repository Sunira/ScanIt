import SwiftUI

/// Manual crop: drag the four corners onto the page's corners. The result is
/// straightened, so a page photographed at an angle comes out square.
struct PageCropView: View {
    let image: UIImage
    var onCrop: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var corners = CropGeometry.fullFrame
    @State private var detectedCorners: [CGPoint]?
    @State private var preview: UIImage?  // screen-sized copy, so dragging doesn't redraw the full photo
    @State private var isDetecting = true
    @State private var isCropping = false
    /// Finger-to-corner offset (normalized) for the handle being dragged.
    @State private var dragOffset: CGPoint?

    private static let cornerNames = ["Top-left", "Top-right", "Bottom-right", "Bottom-left"]
    private static let editorSpace = "cropEditor"

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geometry in
                let size = CropGeometry.fittedSize(image.size, in: geometry.size)
                editor(size: size)
                    .frame(width: size.width, height: size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .padding(28)  // room for the handles at the image's edges
            hint
            bottomBar
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            let source = image
            preview = await Task.detached(priority: .userInitiated) {
                ImageProcessing.resized(source, maxDimension: 1600)
            }.value
        }
        .task { await detect() }
    }

    // MARK: Sections

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Cancel cropping")
            Spacer()
            Text("Crop").font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func editor(size: CGSize) -> some View {
        let points = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        return ZStack(alignment: .topLeading) {
            Image(uiImage: preview ?? image)
                .resizable()
                .frame(width: size.width, height: size.height)
                .accessibilityHidden(true)

            // Dim everything outside the crop.
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addLines(points)
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            Path { path in
                path.addLines(points)
                path.closeSubpath()
            }
            .stroke(Color.white, lineWidth: 2)
            .allowsHitTesting(false)

            ForEach(corners.indices, id: \.self) { index in
                handle(index, size: size)
                    .position(points[index])
            }
        }
        .coordinateSpace(.named(Self.editorSpace))
    }

    private func handle(_ index: Int, size: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 3))
            .frame(width: 24, height: 24)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .gesture(
                // Measured in the editor's fixed space: the handle itself moves with the
                // finger, so its own local space would feed the drag back into itself.
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.editorSpace))
                    .onChanged { value in
                        let finger = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                        let offset = dragOffset ?? CropGeometry.offset(from: finger, to: corners[index])
                        if dragOffset == nil { dragOffset = offset }
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            corners[index] = CropGeometry.dragged(finger: finger, offset: offset)
                        }
                    }
                    .onEnded { _ in dragOffset = nil }
            )
            .accessibilityLabel("\(Self.cornerNames[index]) corner")
            .accessibilityHint("Drag onto the page's corner")
    }

    private var hint: some View {
        Text(isDetecting ? "Looking for the page's edges…" : "Drag the corners onto the page's corners.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
            .frame(minHeight: 24)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) { corners = detectedCorners ?? corners }
                } label: {
                    Label("Auto", systemImage: "wand.and.stars")
                }
                .buttonStyle(.glass)
                .disabled(detectedCorners == nil)

                Button {
                    withAnimation(.snappy) { corners = CropGeometry.fullFrame }
                } label: {
                    Label("Full photo", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.glass)
            }

            Button(isCropping ? "Cropping…" : "Crop") {
                Task { await crop() }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(isCropping)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Work

    private func detect() async {
        let source = image
        let quad = await Task.detached(priority: .userInitiated) {
            PageDetector.detectPage(in: source)
        }.value
        isDetecting = false
        guard let quad else { return }
        let found = CropGeometry.screenCorners(from: quad)
        detectedCorners = found
        // Only jump to the detected edges if the user hasn't started dragging.
        if CropGeometry.isFullFrame(corners) {
            withAnimation(.snappy) { corners = found }
        }
    }

    private func crop() async {
        if CropGeometry.isFullFrame(corners) {
            onCrop(image)
            dismiss()
            return
        }
        isCropping = true
        let source = image
        let quad = CropGeometry.quad(fromScreen: corners)
        let result = await Task.detached(priority: .userInitiated) {
            PageDetector.crop(source, to: quad)
        }.value
        isCropping = false
        if let result { onCrop(result) }
        dismiss()
    }
}
