import AppKit
import PasterCore

extension NSColor {
    /// 转成 sRGB 后写成 "#RRGGBB"，格式与 PasterCore 的 `Color(hexString:)` 配套。
    /// 采集时把来源应用的主题色算成字符串存进条目，iOS 端拿不到别的 App 的图标，只能靠这份同步过去的值。
    /// 图案色等无法转换到 sRGB 的颜色返回 nil。
    var srgbHexString: String? {
        guard let srgb = usingColorSpace(.sRGB) else { return nil }
        return HexColor.string(red: srgb.redComponent,
                               green: srgb.greenComponent,
                               blue: srgb.blueComponent)
    }
}
