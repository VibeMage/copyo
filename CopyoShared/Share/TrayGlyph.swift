import SwiftUI

/// 设计稿里的「开口托盘 + 向下箭头」（`P.tray`：`M4 15v5h16v-5` / `M12 3v10` / `M8 9l4 4 4-4`）。
///
/// SF Symbols 里最接近的 `tray.and.arrow.down` 是一只封口的收件盒，`square.and.arrow.down` 又多了一圈方框，
/// 两个都不是设计画的那只 U 形托盘，所以按 24 网格原样描出来。
/// 分享面板的「保存」按钮（设计 06）与引导第二页的插图（设计 05b）共用这一个形状。
///
/// 只给路径不给描边：线宽由调用方按「网格线宽 × 边长 / 24」自己算——
/// 设计在 18pt 的按钮图标上用 2.2、在 64pt 的插图上用 1.5，比例并不一样。
struct TrayGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        // 以 rect 为中心摆 24 × 24 的网格，非正方形的 rect 也不变形
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()
        // 托盘：左壁、底、右壁
        path.move(to: point(4, 15))
        path.addLine(to: point(4, 20))
        path.addLine(to: point(20, 20))
        path.addLine(to: point(20, 15))
        // 箭杆
        path.move(to: point(12, 3))
        path.addLine(to: point(12, 13))
        // 箭头
        path.move(to: point(8, 9))
        path.addLine(to: point(12, 13))
        path.addLine(to: point(16, 9))
        return path
    }
}
