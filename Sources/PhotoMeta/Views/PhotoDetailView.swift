import AppKit
import SwiftUI

/// Shown when the user taps a thumbnail: a larger preview with the choice to
/// add the photo to the working batch or skip it and keep browsing.
struct PhotoDetailView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss
    let photo: Photo
    @State private var image: NSImage?
    @State private var isTransforming = false

    var body: some View {
        VStack(spacing: 16) {
            Text(photo.filename)
                .font(.headline)
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(isTransforming ? 0.5 : 1)
                } else {
                    ProgressView()
                }
            }
            .frame(minWidth: 500, minHeight: 400)

            HStack(spacing: 12) {
                Button {
                    rotate(.rotateCounterclockwise)
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                }
                Button {
                    rotate(.rotateClockwise)
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                }
                Button {
                    rotate(.mirrorAcrossHorizontalAxis)
                } label: {
                    Label("Mirror Top/Bottom", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                }
            }
            .disabled(isTransforming)

            HStack {
                Button("Skip") {
                    library.skipPreview()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add to Batch") {
                    library.addToBatch(photo)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 600)
        .task(id: photo.url) {
            image = await ThumbnailLoader.shared.thumbnail(for: photo.url, maxPixelSize: 1600)
        }
    }

    private func rotate(_ transform: PhotoLibrary.Transform) {
        isTransforming = true
        Task {
            await library.applyTransform(transform, to: photo)
            image = await ThumbnailLoader.shared.thumbnail(for: photo.url, maxPixelSize: 1600)
            isTransforming = false
        }
    }
}
