import AppKit
import SwiftUI

struct ThumbnailGridView: View {
    let photos: [Photo]
    let thumbnailSize: CGFloat
    let onSelect: (Photo) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(photos) { photo in
                    ThumbnailCell(photo: photo, size: thumbnailSize)
                        .onTapGesture { onSelect(photo) }
                }
            }
            .padding()
        }
    }
}

private struct ThumbnailCell: View {
    let photo: Photo
    let size: CGFloat
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: size, height: size)
            Text(photo.filename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: size)
        }
        .task(id: photo.url) {
            image = await ThumbnailLoader.shared.thumbnail(for: photo.url, maxPixelSize: size * 2)
        }
    }
}
