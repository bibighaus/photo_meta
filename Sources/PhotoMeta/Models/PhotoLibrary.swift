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

    enum Tab: CaseIterable, Identifiable {
        case noMetadata
        case dateOnly
        case locationOnly
        case both

        var id: Self { self }

        var title: String {
            switch self {
            case .noMetadata: return "No Meta Data"
            case .dateOnly: return "Date Updated"
            case .locationOnly: return "Location Updated"
            case .both: return "Date and Location Updated"
            }
        }

        fileprivate func matches(_ photo: Photo) -> Bool {
            switch self {
            case .noMetadata: return !photo.hasDateSet && !photo.hasLocationSet
            case .dateOnly: return photo.hasDateSet && !photo.hasLocationSet
            case .locationOnly: return !photo.hasDateSet && photo.hasLocationSet
            case .both: return photo.hasDateSet && photo.hasLocationSet
            }
        }
    }

    /// Photos belonging to a tab, excluding any already staged in the current
    /// batch (so a photo doesn't appear both in the grid and the tray).
    func visiblePhotos(for tab: Tab) -> [Photo] {
        let batchURLs = Set(selectedBatch.map(\.url))
        return photos.filter { tab.matches($0) && !batchURLs.contains($0.url) }
    }

    /// Photos with a date and/or location already set, offered as sources to
    /// copy from in the batch editor.
    var taggedPhotos: [Photo] {
        photos.filter { $0.hasDateSet || $0.hasLocationSet }
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
            results.append(Photo(
                url: url,
                hasDateSet: read.hasDateSet,
                hasLocationSet: read.hasLocationSet,
                captureDate: read.captureDate,
                coordinate: read.coordinate
            ))
        }
        results.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }

        photos = results
        // Refresh staged photos with their latest metadata; drop any that
        // disappeared from the folder.
        selectedBatch = selectedBatch.compactMap { staged in
            results.first(where: { $0.url == staged.url })
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

    enum Transform {
        case rotateClockwise
        case rotateCounterclockwise
        case mirrorLeftRight
    }

    func applyTransform(_ transform: Transform, to photo: Photo) async {
        do {
            switch transform {
            case .rotateClockwise:
                try PhotoMetadataService.rotate(photo.url, direction: .clockwise)
            case .rotateCounterclockwise:
                try PhotoMetadataService.rotate(photo.url, direction: .counterclockwise)
            case .mirrorLeftRight:
                try PhotoMetadataService.mirrorLeftRight(photo.url)
            }
        } catch {
            errorMessage = "Could not rotate or mirror \(photo.filename): \(error.localizedDescription)"
        }
    }

    /// Writes whichever of `date` / `coordinate` is non-nil to every target
    /// photo, leaving the other field untouched on disk.
    func apply(date: Date?, coordinate: Coordinate?, to targets: [Photo]) async {
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
