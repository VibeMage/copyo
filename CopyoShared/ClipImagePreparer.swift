import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

/// 把分享面板 / 快捷指令交过来的图片整成「可以直接入库的 PNG」。
///
/// 分享扩展的内存上限只有约 120MB，用户随手分享一张单反直出的图就能把进程撑爆，
/// 所以一律走 ImageIO 的缩略图路径（不整张解码），最长边压到 2048，
/// 并且每一步都包在 `autoreleasepool` 里——CGImage 的临时对象不主动回收，
/// 连着处理几张就会在 autorelease pool 排到扩展被杀。
public enum ClipImagePreparer {

    /// 入库图片的最长边。2048 足够在 iPad 上全屏预览，也还原得回大部分截图的可读性。
    public static let maxPixelSize = 2048

    public struct Prepared: Sendable {
        public let png: Data
        public let pixelWidth: Int
        public let pixelHeight: Int
    }

    public static func prepare(data: Data) -> Prepared? {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return prepare(source: source, originalData: data)
        }
    }

    public static func prepare(fileURL: URL) -> Prepared? {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
            return prepare(source: source, originalData: nil)
        }
    }

    /// `NSItemProvider` 只肯给 UIImage 时的路径（已经解码进内存了，只能就地缩）
    public static func prepare(image: UIImage) -> Prepared? {
        autoreleasepool {
            guard let cgImage = image.cgImage else {
                // CIImage 撑起来的 UIImage 没有 cgImage，退回让 UIKit 重画一遍
                return prepare(byRedrawing: image)
            }
            guard max(cgImage.width, cgImage.height) > maxPixelSize else {
                return encodePNG(cgImage)
            }
            return prepare(byRedrawing: image)
        }
    }

    // MARK: - 内部

    private static func prepare(source: CGImageSource, originalData: Data?) -> Prepared? {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let longestSide = max(width, height)
        let isPNG = CGImageSourceGetType(source) as String? == UTType.png.identifier

        // 已经是不超限的 PNG 就原样存：重编码一遍既费内存又可能变大
        if let originalData, isPNG, longestSide > 0, longestSide <= maxPixelSize {
            return Prepared(png: originalData, pixelWidth: width, pixelHeight: height)
        }

        // 元数据取不到时 longestSide 是 0，`max(min(0, 2048), 1)` 会算成 1，
        // CGImageSourceCreateThumbnailAtIndex 会老老实实返回一张 1×1 的图，
        // 调用方还以为保存成功——用户看到「已保存」，历史里却是一个白点。
        // 取不到就按上限走，让 ImageIO 自己按原图尺寸裁。
        let thumbnailMaxPixelSize = longestSide > 0 ? min(longestSide, maxPixelSize) : maxPixelSize
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        // 再兜一道：退化成 1×1 说明这条路径根本没拿到真实像素，
        // 返回 nil 让调用方走「读不出内容」，别静默存下一张白点
        guard cgImage.width > 1 || cgImage.height > 1 else { return nil }
        return encodePNG(cgImage)
    }

    private static func prepare(byRedrawing image: UIImage) -> Prepared? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let longestSide = max(size.width, size.height)
        let scale = longestSide > CGFloat(maxPixelSize) ? CGFloat(maxPixelSize) / longestSide : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.preferred()
        // scale = 1：目标尺寸就是像素尺寸，否则 3x 的屏幕会画出三倍大的图
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let data = renderer.pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard !data.isEmpty else { return nil }
        return Prepared(png: data, pixelWidth: Int(target.width), pixelHeight: Int(target.height))
    }

    private static func encodePNG(_ cgImage: CGImage) -> Prepared? {
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer,
                                                                 UTType.png.identifier as CFString,
                                                                 1,
                                                                 nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return Prepared(png: buffer as Data, pixelWidth: cgImage.width, pixelHeight: cgImage.height)
    }
}
