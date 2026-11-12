import SwiftUI

/// One page captured on the scan screen.
struct ScannedPage: Identifiable, Sendable {
    let id = UUID()
    /// The full photo, upright. Cropping starts from this.
    var original: UIImage
    /// The page as it will be saved: trimmed, straightened and with the chosen look applied.
    var image: UIImage
}

/// A live viewfinder that outlines the page it finds. Nothing is captured until the
/// shutter is pressed; each picture is trimmed to the page and added to the scan.
/// Tap the page stack to review, crop, rotate, retake or delete pages.
struct DocumentScanner: View {
    var onFinish: ([UIImage]) -> Void
    var onCancel: () -> Void

    static var isSupported: Bool { CameraSession.isAvailable }

    @AppStorage("scanLook") private var lookRaw = ScanLook.defaultLook.rawValue
    @Environment(\.openURL) private var openURL
    @State private var camera = CameraSession()
    @State private var access: CameraAccess = .checking
    @State private var detectedPage: PageDetector.Quad?
    @State private var guides = GuideOrientation(isPortrait: true)  // follows the page; documents come both ways
    @State private var pages: [ScannedPage] = []
    @State private var retaking: UUID?
    @State private var showingReview = false
    @State private var isCapturing = false
    @State private var shotCount = 0
    @State private var flashOpacity = 0.0

    private enum CameraAccess { case checking, granted, denied }

    private var look: Binding<ScanLook> {
        Binding {
            ScanLook(rawValue: lookRaw) ?? .defaultLook
        } set: {
            lookRaw = $0.rawValue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch access {
                case .checking: Color.clear
                case .granted: viewfinder
                case .denied: deniedMessage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if access == .granted {
                controls
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .medium), trigger: shotCount)
        .fullScreenCover(isPresented: $showingReview) {
            ScanReviewView(pages: $pages, look: look.wrappedValue,
                           onAddPage: { showingReview = false },
                           onRetake: { id in
                               retaking = id
                               showingReview = false
                           },
                           onSave: finish)
        }
        .onChange(of: showingReview) { _, showing in
            if showing { camera.stop() } else if access == .granted { camera.start() }
        }
        .task {
            guard await CameraSession.requestAccess() else {
                access = .denied
                return
            }
            access = .granted
            camera.start()
            for await page in camera.detections {
                detectedPage = page
                if let page {
                    guides.update(pageIsPortrait: ViewfinderGeometry.isPortrait(page),
                                  at: ProcessInfo.processInfo.systemUptime)
                }
            }
        }
        .onDisappear { camera.stop() }
    }

    // MARK: Sections

    private var topBar: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            Spacer()
            if access == .granted {
                Picker("Look", selection: look) {
                    ForEach(ScanLook.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }
            Spacer()
            Color.clear.frame(width: 60, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var viewfinder: some View {
        ZStack {
            CameraPreview(session: camera.session, page: detectedPage)

            CornerGuides()
                .stroke(Color.white.opacity(detectedPage == nil ? 0.9 : 0.4),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .aspectRatio(guides.isPortrait ? 8.5 / 11 : 11 / 8.5, contentMode: .fit)
                .padding(24)
                .animation(.easeInOut(duration: 0.2), value: detectedPage == nil)
                .animation(.easeInOut(duration: 0.2), value: guides.isPortrait)

            VStack(spacing: 6) {
                Spacer()
                Text(hint)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(detectedPage == nil ? "Looking for the page" : "Page found")
                    .font(.caption.weight(.medium))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.8), radius: 6)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            turnGuidesButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)

            Color.white
                .opacity(flashOpacity)
                .allowsHitTesting(false)

            if isCapturing {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Viewfinder")
    }

    private var hint: String {
        if retaking != nil { return "Retake this page" }
        return pages.isEmpty ? "Line up the page" : "Scan the next page, or tap Done"
    }

    /// Turns the guides by hand, for when the page isn't being picked up yet.
    /// The next detection takes over again.
    private var turnGuidesButton: some View {
        Button {
            guides.set(portrait: !guides.isPortrait)
        } label: {
            Image(systemName: "rectangle.portrait.rotate")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.black.opacity(0.5)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Turn the guides")
        .accessibilityValue(guides.isPortrait ? "Vertical page" : "Horizontal page")
    }

    private var controls: some View {
        HStack {
            pageStack
                .frame(maxWidth: .infinity, alignment: .leading)
            Shutter(isBusy: isCapturing, action: capture)
            Group {
                if retaking != nil {
                    Button("Cancel retake") {
                        retaking = nil
                        showingReview = true
                    }
                } else {
                    Button("Done", action: finish)
                        .fontWeight(.semibold)
                        .disabled(pages.isEmpty || isCapturing)
                        .opacity(pages.isEmpty ? 0.4 : 1)
                }
            }
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// The latest page with a count; tapping it opens the review screen.
    @ViewBuilder
    private var pageStack: some View {
        if let last = pages.last, retaking == nil {
            Button {
                showingReview = true
            } label: {
                Image(uiImage: last.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.8), lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        Text("\(pages.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                            .offset(x: 8, y: -8)
                    }
                    .frame(minWidth: 52, minHeight: 66)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pages.count == 1 ? "1 page scanned" : "\(pages.count) pages scanned")
            .accessibilityHint("Review the pages")
        }
    }

    private var deniedMessage: some View {
        VStack(spacing: 16) {
            Text("ScanIt needs the camera to scan documents")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Turn on Camera for ScanIt in Settings.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    // MARK: Capture

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        shotCount += 1
        withAnimation(.easeOut(duration: 0.05)) { flashOpacity = 0.7 }
        withAnimation(.easeIn(duration: 0.3).delay(0.05)) { flashOpacity = 0 }

        let chosenLook = look.wrappedValue
        Task {
            defer { isCapturing = false }
            guard let photo = await camera.capturePhoto() else { return }
            let page = await Task.detached(priority: .userInitiated) {
                let upright = ImageProcessing.resized(photo, maxDimension: 3200)
                let trimmed = PageDetector.trimmed(upright) ?? upright
                return ScannedPage(original: upright, image: chosenLook.applied(to: trimmed))
            }.value

            if let id = retaking, let index = pages.firstIndex(where: { $0.id == id }) {
                pages[index] = page
                retaking = nil
                showingReview = true
            } else {
                pages.append(page)
            }
        }
    }

    private func finish() {
        guard !pages.isEmpty else { return }
        camera.stop()
        onFinish(pages.map(\.image))
    }
}

// MARK: - Pieces

/// The round shutter button.
private struct Shutter: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4)
                Circle().fill(.white).padding(8)
            }
            .frame(width: 76, height: 76)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
        .accessibilityLabel("Take picture")
    }
}

/// The four L-shaped corners that show where to hold the page.
private struct CornerGuides: Shape {
    var length: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        let l = min(length, rect.width / 3, rect.height / 3)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return path
    }
}
