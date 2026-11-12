import SwiftUI

/// Review the pages of a scan: swipe through them, then crop, rotate, retake or delete
/// the one on screen, add more pages, or save.
struct ScanReviewView: View {
    @Binding var pages: [ScannedPage]
    let look: ScanLook
    var onAddPage: () -> Void
    var onRetake: (UUID) -> Void
    var onSave: () -> Void

    @State private var selection: UUID?
    @State private var cropping: ScannedPage?
    @State private var showingDeleteConfirmation = false

    private var current: ScannedPage? {
        pages.first { $0.id == selection } ?? pages.first
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $selection) {
                ForEach(pages) { page in
                    Image(uiImage: page.image)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .tag(Optional(page.id))
                        .accessibilityLabel("Page \((pages.firstIndex { $0.id == page.id } ?? 0) + 1) of \(pages.count)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            actions
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { selection = selection ?? pages.last?.id }
        .onChange(of: pages.count) { _, count in
            if count == 0 { onAddPage() }
        }
        .fullScreenCover(item: $cropping) { page in
            PageCropView(image: page.original) { cropped in
                apply(cropped: cropped, to: page.id)
            }
        }
        .confirmationDialog("Delete this page?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete page", role: .destructive, action: deleteCurrent)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                onAddPage()
            } label: {
                Label("Add page", systemImage: "plus")
            }
            .frame(minHeight: 44)
            Spacer()
            if let index = pages.firstIndex(where: { $0.id == current?.id }) {
                Text("Page \(index + 1) of \(pages.count)").font(.headline)
            }
            Spacer()
            Button("Save", action: onSave)
                .fontWeight(.semibold)
                .frame(minHeight: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var actions: some View {
        HStack {
            action("Crop", "crop") { cropping = current }
            action("Rotate", "rotate.right", rotateCurrent)
            action("Retake", "camera") { if let id = current?.id { onRetake(id) } }
            action("Delete", "trash") { showingDeleteConfirmation = true }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func action(_ title: String, _ symbol: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 20))
                Text(title).font(.caption)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Editing

    private func apply(cropped: UIImage, to id: UUID) {
        let look = look
        Task {
            let image = await Task.detached(priority: .userInitiated) { look.applied(to: cropped) }.value
            if let index = pages.firstIndex(where: { $0.id == id }) {
                pages[index].image = image
            }
        }
    }

    private func rotateCurrent() {
        guard let page = current else { return }
        Task {
            let rotated = await Task.detached(priority: .userInitiated) {
                (original: ImageProcessing.rotated(page.original, quarterTurns: 1),
                 image: ImageProcessing.rotated(page.image, quarterTurns: 1))
            }.value
            if let index = pages.firstIndex(where: { $0.id == page.id }) {
                pages[index].original = rotated.original
                pages[index].image = rotated.image
            }
        }
    }

    private func deleteCurrent() {
        guard let id = current?.id, let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages.remove(at: index)
        selection = pages.isEmpty ? nil : pages[min(index, pages.count - 1)].id
    }
}
