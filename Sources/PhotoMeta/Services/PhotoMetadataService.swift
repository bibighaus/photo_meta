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
    /// Written into IPTC Keywords once a photo has gone through this app's
    /// workflow, so future folder scans know to skip it even if the photo
    /// already had some unrelated EXIF date/GPS from the scanner.
    static let processedMarker = "photometa:processed"

    struct ReadResult {
        var isProcessed: Bool
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
            return ReadResult(isProcessed: false, captureDate: nil, coordinate: nil)
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

        var isProcessed = false
        if let iptc = props[kCGImagePropertyIPTCDictionary as String] as? [String: Any],
           let keywords = iptc[kCGImagePropertyIPTCKeywords as String] as? [String] {
            isProcessed = keywords.contains(processedMarker)
        }

        return ReadResult(isProcessed: isProcessed, captureDate: date, coordinate: coordinate)
    }

    static func write(date: Date, coordinate: Coordinate?, to url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PhotoMetadataError.cannotOpenSource
        }
        let type = CGImageSourceGetType(source) ?? (UTType.jpeg.identifier as CFString)

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
        let dateString = exifDateFormatter.string(from: date)

        var exif = (properties[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        exif[kCGImagePropertyExifDateTimeOriginal as String] = dateString
        exif[kCGImagePropertyExifDateTimeDigitized as String] = dateString
        properties[kCGImagePropertyExifDictionary as String] = exif

        var tiff = (properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        tiff[kCGImagePropertyTIFFDateTime as String] = dateString
        properties[kCGImagePropertyTIFFDictionary as String] = tiff

        if let coordinate {
            var gps = (properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]) ?? [:]
            gps[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
            gps[kCGImagePropertyGPSLatitudeRef as String] = coordinate.latitude >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
            gps[kCGImagePropertyGPSLongitudeRef as String] = coordinate.longitude >= 0 ? "E" : "W"
            gps[kCGImagePropertyGPSDateStamp as String] = utcDateStampFormatter.string(from: date)
            gps[kCGImagePropertyGPSTimeStamp as String] = utcTimeStampFormatter.string(from: date)
            properties[kCGImagePropertyGPSDictionary as String] = gps
        }

        var iptc = (properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any]) ?? [:]
        var keywords = (iptc[kCGImagePropertyIPTCKeywords as String] as? [String]) ?? []
        if !keywords.contains(processedMarker) {
            keywords.append(processedMarker)
        }
        iptc[kCGImagePropertyIPTCKeywords as String] = keywords
        properties[kCGImagePropertyIPTCDictionary as String] = iptc

        // Write to a temp sibling file first, then atomically swap it in, so a
        // failed or interrupted write never corrupts the original scan.
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
