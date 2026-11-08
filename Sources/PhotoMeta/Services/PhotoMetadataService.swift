import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoMetadataError: Error, LocalizedError {
    case cannotOpenSource
    case cannotCreateDestination
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .cannotOpenSource: return "Could not read the image file."
        case .cannotCreateDestination: return "Could not prepare the image for writing."
        case .writeFailed: return "Failed to write metadata to the image."
        }
    }
}

/// Reads and writes capture date / GPS location directly in a JPEG's EXIF, TIFF
/// and IPTC metadata using ImageIO. The encoded pixel data is copied through
/// unchanged (CGImageDestinationAddImageFromSource) so this never re-compresses
/// or degrades the scanned image; only the metadata dictionary changes.
enum PhotoMetadataService {
    /// Written into IPTC Keywords once this app has set a photo's date or
    /// location, tracked independently so a photo that only has a date set
    /// can still be found later to add a location (and vice versa) — even
    /// if the photo already had some unrelated EXIF date/GPS from the
    /// scanner that this app itself never wrote.
    static let dateSetMarker = "photometa:date-set"
    static let locationSetMarker = "photometa:location-set"

    struct ReadResult {
        var hasDateSet: Bool
        var hasLocationSet: Bool
        var captureDate: Date?
        var coordinate: Coordinate?
    }

    private static let exifDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy:MM:dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        return df
    }()

    private static let utcDateStampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy:MM:dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        return df
    }()

    private static let utcTimeStampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        return df
    }()

    static func read(from url: URL) -> ReadResult {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return ReadResult(hasDateSet: false, hasLocationSet: false, captureDate: nil, coordinate: nil)
        }
        return parse(props)
    }

    private static func parse(_ props: [String: Any]) -> ReadResult {
        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            date = exifDateFormatter.date(from: raw)
        }
        if date == nil,
           let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let raw = tiff[kCGImagePropertyTIFFDateTime as String] as? String {
            date = exifDateFormatter.date(from: raw)
        }

        var coordinate: Coordinate?
        if let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
           let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
           let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
            let signedLat = latRef.uppercased() == "S" ? -lat : lat
            let signedLon = lonRef.uppercased() == "W" ? -lon : lon
            coordinate = Coordinate(latitude: signedLat, longitude: signedLon)
        }

        var hasDateSet = false
        var hasLocationSet = false
        if let iptc = props[kCGImagePropertyIPTCDictionary as String] as? [String: Any],
           let keywords = iptc[kCGImagePropertyIPTCKeywords as String] as? [String] {
            hasDateSet = keywords.contains(dateSetMarker)
            hasLocationSet = keywords.contains(locationSetMarker)
        }

        return ReadResult(hasDateSet: hasDateSet, hasLocationSet: hasLocationSet, captureDate: date, coordinate: coordinate)
    }

    /// Writes whichever of `date` / `coordinate` is non-nil, leaving the other
    /// untouched — so a batch can add just a location to photos that already
    /// have a date (or vice versa) without disturbing the field it didn't ask
    /// to change.
    static func write(date: Date?, coordinate: Coordinate?, to url: URL) throws {
        guard date != nil || coordinate != nil else { return }

        try rewrite(url) { properties in
            var iptc = (properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any]) ?? [:]
            var keywords = (iptc[kCGImagePropertyIPTCKeywords as String] as? [String]) ?? []

            if let date {
                let dateString = exifDateFormatter.string(from: date)

                var exif = (properties[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
                exif[kCGImagePropertyExifDateTimeOriginal as String] = dateString
                exif[kCGImagePropertyExifDateTimeDigitized as String] = dateString
                properties[kCGImagePropertyExifDictionary as String] = exif

                var tiff = (properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
                tiff[kCGImagePropertyTIFFDateTime as String] = dateString
                properties[kCGImagePropertyTIFFDictionary as String] = tiff

                if !keywords.contains(dateSetMarker) {
                    keywords.append(dateSetMarker)
                }
            }

            if let coordinate {
                var gps = (properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]) ?? [:]
                gps[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
                gps[kCGImagePropertyGPSLatitudeRef as String] = coordinate.latitude >= 0 ? "N" : "S"
                gps[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
                gps[kCGImagePropertyGPSLongitudeRef as String] = coordinate.longitude >= 0 ? "E" : "W"
                if let date {
                    gps[kCGImagePropertyGPSDateStamp as String] = utcDateStampFormatter.string(from: date)
                    gps[kCGImagePropertyGPSTimeStamp as String] = utcTimeStampFormatter.string(from: date)
                }
                properties[kCGImagePropertyGPSDictionary as String] = gps

                if !keywords.contains(locationSetMarker) {
                    keywords.append(locationSetMarker)
                }
            }

            iptc[kCGImagePropertyIPTCKeywords as String] = keywords
            properties[kCGImagePropertyIPTCDictionary as String] = iptc
        }
    }

    enum RotationDirection {
        case clockwise
        case counterclockwise
    }

    /// Rotates the photo a quarter turn by updating its EXIF orientation tag,
    /// so this stays lossless — the encoded pixel data is never touched.
    static func rotate(_ url: URL, direction: RotationDirection) throws {
        let delta = direction == .clockwise ? 90 : -90
        try transformOrientation(url) { mirrored, rotation in
            (mirrored, rotation + delta)
        }
    }

    /// Flips the photo left-to-right (reflects it across a vertical line
    /// through its center) by updating its EXIF orientation tag.
    static func mirrorLeftRight(_ url: URL) throws {
        try transformOrientation(url) { mirrored, rotation in
            (!mirrored, rotation)
        }
    }

    /// EXIF orientation 1-8 decomposed into "mirror horizontally, then rotate
    /// clockwise by this many degrees" so quarter turns and flips can be
    /// composed with simple arithmetic instead of an 8x8 transition table.
    private static func decomposeOrientation(_ orientation: Int) -> (mirrored: Bool, rotation: Int) {
        switch orientation {
        case 1: return (false, 0)
        case 2: return (true, 0)
        case 3: return (false, 180)
        case 4: return (true, 180)
        case 5: return (true, 270)
        case 6: return (false, 90)
        case 7: return (true, 90)
        case 8: return (false, 270)
        default: return (false, 0)
        }
    }

    private static func composeOrientation(mirrored: Bool, rotation: Int) -> Int {
        let normalized = ((rotation % 360) + 360) % 360
        switch (mirrored, normalized) {
        case (false, 0): return 1
        case (true, 0): return 2
        case (false, 180): return 3
        case (true, 180): return 4
        case (true, 270): return 5
        case (false, 90): return 6
        case (true, 90): return 7
        case (false, 270): return 8
        default: return 1
        }
    }

    private static func transformOrientation(_ url: URL, _ transform: (Bool, Int) -> (Bool, Int)) throws {
        try rewrite(url) { properties in
            let currentOrientation = (properties[kCGImagePropertyOrientation as String] as? Int) ?? 1
            let (mirrored, rotation) = decomposeOrientation(currentOrientation)
            let (newMirrored, newRotation) = transform(mirrored, rotation)
            properties[kCGImagePropertyOrientation as String] = composeOrientation(mirrored: newMirrored, rotation: newRotation)
        }
    }

    /// Reads a JPEG's properties, lets `mutate` change them, then writes the
    /// image back out with the original encoded pixel data copied through
    /// unchanged. Writes to a temp sibling file first and swaps it in
    /// atomically, so a failed or interrupted write never corrupts the
    /// original scan.
    private static func rewrite(_ url: URL, mutate: (inout [String: Any]) -> Void) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PhotoMetadataError.cannotOpenSource
        }
        let type = CGImageSourceGetType(source) ?? (UTType.jpeg.identifier as CFString)

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        mutate(&properties)

        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)_\(url.lastPathComponent)")

        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, type, 1, nil) else {
            throw PhotoMetadataError.cannotCreateDestination
        }
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PhotoMetadataError.writeFailed
        }

        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }
}
