import AppKit
import Foundation

@MainActor
final class PhotoLibrary: ObservableObject {
    @Published var folderURL: URL?
    @Published private(set) var photos: [Photo] = []
    @Published var selectedBatch: [Photo] = []
    @Published var previewPhoto: Photo?
    @Published var isScanning = false
    @Published var errorMessage: String?

    private static let allowedExtensions: Set<String> = ["jpg", "jpeg"]

    /// Photos that still need metadata, excluding any already staged in the
    /// current batch (so a photo doesn't appear both in the grid and the tray).
    var unprocessedPhotos: [Photo] {
        let batchURLs = Set(selectedBatch.map(\.url))
        return photos.filter { !$0.isProcessed && !batchURLs.contains($0.url) }
    }

    var processedPhotos: [Photo] {
        photos.filter(\.isProcessed)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        folderURL = url
        selectedBatch = []
        previewPhoto = nil
        Task { await scan() }
    }

    func scan() async {
        guard let folderURL else { return }
        isScanning = true
        defer { isScanning = false }

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            errorMessage = "Could not read the selected folder. If it's inside Desktop, Documents or Downloads, macOS may need you to grant file access."
            return
        }

        let imageURLs = entries.filter { Self.allowedExtensions.contains($0.pathExtension.lowercased()) }

        var results: [Photo] = []
        for url in imageURLs {
            let read = PhotoMetadataService.read(from: url)
            results.append(Photo(url: url, isProcessed: read.isProcessed, captureDate: read.captureDate, coordinate: read.coordinate))
        }
        results.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }

        photos = results
        // Keep any still-unprocessed staged photos in the batch; drop ones that
        // disappeared or were processed by something else in the meantime.
        selectedBatch = selectedBatch.compactMap { staged in
            results.first(where: { $0.url == staged.url && !$0.isProcessed })
        }
    }

    func addToBatch(_ photo: Photo) {
        if !selectedBatch.contains(where: { $0.url == photo.url }) {
            selectedBatch.append(photo)
        }
        if previewPhoto?.url == photo.url {
            previewPhoto = nil
        }
    }

    func removeFromBatch(_ photo: Photo) {
        selectedBatch.removeAll { $0.url == photo.url }
    }

    func skipPreview() {
        previewPhoto = nil
    }

    func apply(date: Date, coordinate: Coordinate?, to targets: [Photo]) async {
        var failures: [String] = []
        for photo in targets {
            do {
                try PhotoMetadataService.write(date: date, coordinate: coordinate, to: photo.url)
            } catch {
                failures.append("\(photo.filename): \(error.localizedDescription)")
            }
        }
        selectedBatch.removeAll { staged in targets.contains { $0.url == staged.url } }
        await scan()
        if !failures.isEmpty {
            errorMessage = "Some photos could not be updated:\n" + failures.joined(separator: "\n")
        }
    }
}
