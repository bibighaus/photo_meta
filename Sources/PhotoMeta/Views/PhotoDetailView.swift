import AppKit
import SwiftUI

/// Shown when the user taps a thumbnail: a larger preview with the choice to
/// add the photo to the working batch or skip it and keep browsing.
struct PhotoDetailView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss
    let photo: Photo
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 16) {
            Text(photo.filename)
                .font(.headline)
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            }
            .frame(minWidth: 500, minHeight: 400)
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
        .frame(minWidth: 600, minHeight: 550)
        .task(id: photo.url) {
            image = await ThumbnailLoader.shared.thumbnail(for: photo.url, maxPixelSize: 1600)
        }
    }
}
