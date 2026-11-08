import AppKit
import SwiftUI

/// Sheet listing already-processed photos so the user can copy that photo's
/// date/location into the batch editor instead of entering it from scratch.
struct CopyMetadataPickerView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss
    let onPick: (Photo) -> Void

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 120), spacing: 12)]

    var body: some View {
        VStack {
            Text("Choose a Photo to Copy From")
                .font(.headline)
                .padding(.top)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(library.taggedPhotos) { photo in
                        VStack(spacing: 4) {
                            CopySourceThumbnail(photo: photo)
                            if let date = photo.captureDate {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            HStack(spacing: 4) {
                                if photo.hasDateSet {
                                    Image(systemName: "calendar")
                                }
                                if photo.hasLocationSet {
                                    Image(systemName: "mappin.and.ellipse")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onPick(photo)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            Button("Cancel", role: .cancel) { dismiss() }
                .padding(.bottom)
        }
        .frame(width: 500, height: 500)
    }
}

private struct CopySourceThumbnail: View {
    let photo: Photo
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 120)
            }
        }
        .task(id: photo.url) {
            image = await ThumbnailLoader.shared.thumbnail(for: photo.url, maxPixelSize: 240)
        }
    }
}
