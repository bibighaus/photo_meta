import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @State private var thumbnailSize: CGFloat = 140
    @State private var showBatchEditor = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if library.folderURL == nil {
                emptyState
            } else {
                mainContent
            }
        }
        .sheet(item: $library.previewPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
        .sheet(isPresented: $showBatchEditor) {
            BatchMetadataView()
        }
        .alert("Error", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    private var toolbar: some View {
        HStack {
            Button("Choose Folder…") { library.chooseFolder() }
            if let folderURL = library.folderURL {
                Text(folderURL.lastPathComponent)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if library.isScanning {
                ProgressView().controlSize(.small)
            }
            Label("\(library.unprocessedPhotos.count) to process", systemImage: "photo.stack")
                .foregroundStyle(.secondary)
            HStack {
                Image(systemName: "photo")
                Slider(value: $thumbnailSize, in: 80...260)
                Image(systemName: "photo.fill")
            }
            .frame(width: 180)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Choose a folder of scanned photos to get started")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if library.unprocessedPhotos.isEmpty && library.selectedBatch.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("All photos in this folder already have metadata")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ThumbnailGridView(photos: library.unprocessedPhotos, thumbnailSize: thumbnailSize) { photo in
                    library.previewPhoto = photo
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !library.selectedBatch.isEmpty {
                Divider()
                BatchTrayView(showEditor: $showBatchEditor)
                    .frame(height: 160)
            }
        }
    }
}
