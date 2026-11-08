import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @State private var thumbnailSize: CGFloat = 140
    @State private var showBatchEditor = false
    @State private var selectedTab: PhotoLibrary.Tab = .noMetadata

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if library.folderURL == nil {
                emptyState
            } else {
                tabBar
                Divider()
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
            HStack {
                Image(systemName: "photo")
                Slider(value: $thumbnailSize, in: 80...260)
                Image(systemName: "photo.fill")
            }
            .frame(width: 180)
        }
        .padding()
    }

    private var tabBar: some View {
        Picker("", selection: $selectedTab) {
            ForEach(PhotoLibrary.Tab.allCases) { tab in
                Text("\(tab.title) (\(library.visiblePhotos(for: tab).count))")
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
            let tabPhotos = library.visiblePhotos(for: selectedTab)
            if tabPhotos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No photos in \"\(selectedTab.title)\"")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ThumbnailGridView(photos: tabPhotos, thumbnailSize: thumbnailSize) { photo in
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
