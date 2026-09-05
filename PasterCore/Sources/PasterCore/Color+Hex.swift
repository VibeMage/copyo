import SwiftUI

extension Color {
    /// 解析 "#RRGGBB" / "#RRGGBBAA"
    public init?(hexString: String) {
        let trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let hex = String(trimmed.dropFirst())
        guard hex.count == 6 || hex.count == 8,
              let value = UInt64(hex, radix: 16) else { return nil }
        let r, g, b, a: Double
        if hex.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// 十六进制颜色串的生成侧，与上面 `Color(hexString:)` 的解析格式配套。
/// 放在 PasterCore 是因为 Mac 端算出来的来源色要以字符串形式同步给 iOS，两端必须用同一种写法。
public enum HexColor {
    /// 把 0...1 的 sRGB 分量格式化成 "#RRGGBB"（大写，与设计稿里的写法一致）
    public static func string(red: Double, green: Double, blue: Double) -> String {
        func channel(_ value: Double) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
    }
}
