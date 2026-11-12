import SwiftData
import SwiftUI

/// One document: swipeable pages on top, details below. Editing arrives in M4.
struct DocumentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let document: Document

    @State private var selectedPage = 0
    @State private var fullScreenPage: PageImage?
    @State private var showingDeleteConfirmation = false
    @State private var deleteOnDisappear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageCarousel
                header
                aiPlaceholder
                recognizedText
            }
            .padding(Metrics.screenPadding)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Label("More actions", systemImage: "ellipsis")
                }
            }
        }
        .confirmationDialog("Delete this document?", isPresented: $showingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteOnDisappear = true
                dismiss()
            }
        } message: {
            Text("All of its pages will be deleted. This can't be undone.")
        }
        .fullScreenCover(item: $fullScreenPage) { page in
            PageViewer(page: page)
        }
        .onDisappear {
            // Delete after leaving the screen so it never shows a deleted document.
            if deleteOnDisappear {
                DocumentStore(context: modelContext, indexer: .shared).delete(document)
            }
        }
    }

    private var pageCarousel: some View {
        TabView(selection: $selectedPage) {
            ForEach(document.sortedPages) { page in
                Button {
                    fullScreenPage = page
                } label: {
                    PageImageView(data: page.imageData)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                        .padding(.bottom, 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(page.index + 1) of \(document.pageCount). Opens full screen.")
                .tag(page.index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: document.pageCount > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 400)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.title)
                .font(.title2.bold())
            HStack(spacing: 8) {
                if let category = document.category {
                    CategoryTag(category: category.style)
                } else {
                    StatusTag(text: "Not sorted yet")
                }
                Text(document.createdAt, format: .dateTime.month(.abbreviated).day().year())
                Text("·")
                Text(document.pageCount == 1 ? "1 page" : "\(document.pageCount) pages")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recognizedText: some View {
        if let text = document.ocrText {
            DisclosureGroup("Full text") {
                Text(text.isEmpty ? "No text was found on this document." : text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.top, 8)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Metrics.cornerRadius))
        } else {
            Label("Reading text…", systemImage: "text.viewfinder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var aiPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Waiting for AI", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.tint)
            Text("ScanIt will soon read this document, sort it, and pull out details like amounts and due dates.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Metrics.cornerRadius))
    }
}

/// Decodes a page image off the main thread and shows it fitted.
struct PageImageView: View {
    let data: Data?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: data) {
            image = await PageImageLoader.load(data)
        }
    }
}

enum PageImageLoader {
    static func load(_ data: Data?) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .userInitiated) {
            UIImage(data: data)?.preparingForDisplay()
        }.value
    }
}

/// Full-screen page with pinch and double-tap zoom.
struct PageViewer: View {
    let page: PageImage
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    ZoomableImageView(image: image)
                        .ignoresSafeArea()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { image = await PageImageLoader.load(page.imageData) }
    }
}

/// A UIScrollView-backed image view so zoomed pages can be panned.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomingScrollView {
        ZoomingScrollView(image: image)
    }

    func updateUIView(_ view: ZoomingScrollView, context: Context) {
        view.imageView.image = image
    }
}

final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()

    init(image: UIImage) {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        backgroundColor = .black
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == minimumZoomScale {
            imageView.frame = bounds
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let size = CGSize(width: bounds.width / 2.5, height: bounds.height / 2.5)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                            width: size.width, height: size.height), animated: true)
        }
    }
}
