import AppKit
import SwiftUI

/// A strip along the bottom showing the photos staged for metadata entry,
/// with a button to open the date/location editor for the whole batch.
struct BatchTrayView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Binding var showEditor: Bool

    var body: some View {
        HStack {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(library.selectedBatch) { photo in
                        BatchThumbnail(photo: photo)
                    }
                }
                .padding(.horizontal)
            }
            Divider()
            VStack {
                Text("\(library.selectedBatch.count) selected")
                Button("Add Date & Location…") { showEditor = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .fixedSize()
        }
        .padding(.vertical, 8)
    }
}

private struct BatchThumbnail: View {
    @EnvironmentObject private var library: PhotoLibrary
    let photo: Photo
    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 100)
            }
            Button {
                library.removeFromBatch(photo)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .task(id: photo.url) {
            image = await ThumbnailLoader.shared.thumbnail(for: photo.url, maxPixelSize: 200)
        }
    }
}
