import CryptoKit
import Foundation

/// 内容哈希：图片去重与跨设备同步的内容指纹都基于它。
public enum ContentHash {
    /// 十六进制小写的 SHA-256
    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
