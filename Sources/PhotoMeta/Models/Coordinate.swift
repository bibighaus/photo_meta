import Foundation

/// A plain lat/lon pair. We avoid CLLocationCoordinate2D as a stored model
/// property because it isn't Hashable, and Photo needs to be Hashable/Identifiable
/// for use in SwiftUI lists and sets.
struct Coordinate: Hashable, Codable {
    var latitude: Double
    var longitude: Double
}
