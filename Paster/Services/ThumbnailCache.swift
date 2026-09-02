import AppKit
import ImageIO
import PasterCore

/// 图片卡片缩略图缓存：避免每次渲染都从 externalStorage 读取并解码全分辨率图片。
@MainActor
enum ThumbnailCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 300
        return cache
    }()

    /// 卡片渲染尺寸 224pt 宽，448px 足够覆盖 2x Retina
    static func thumbnail(for item: ClipItem, maxPixelSize: CGFloat = 448) -> NSImage? {
        let key = (item.imageHash ?? String(describing: item.persistentModelID)) as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = item.imageData,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }

    static func removeAll() {
        cache.removeAllObjects()
    }
}
