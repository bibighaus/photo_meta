import Foundation

struct Photo: Identifiable, Hashable {
    let url: URL
    var isProcessed: Bool
    var captureDate: Date?
    var coordinate: Coordinate?

    var id: URL { url }
    var filename: String { url.lastPathComponent }
}
