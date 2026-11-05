import AppKit
import ImageIO

/// Generates and caches downsampled thumbnails via ImageIO, which avoids
/// decoding full-resolution scans just to show a grid of small previews.
actor ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(for url: URL, maxPixelSize: CGFloat) -> NSImage? {
        let key = "\(url.path)|\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [String: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways as String: true,
            kCGImageSourceThumbnailMaxPixelSize as String: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform as String: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache.setObject(image, forKey: key)
        return image
    }
}
