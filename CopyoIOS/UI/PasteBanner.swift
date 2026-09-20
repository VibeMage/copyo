import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 设计 01c：关掉「回到前台自动读取」或系统弹窗被拒时，历史页顶部显示的横幅。
///
/// 右边是系统的 `UIPasteControl`——用户亲手点它等于一次性授权，不需要「从其他 App 粘贴」权限，
/// 所以这条兜底路径在任何设置下都走得通。
struct PasteBanner: View {
    /// 已存下内容，原位换文案再收起
    var saved: Bool
    var onPaste: ([NSItemProvider]) -> Void
    var onDismiss: () -> Void

    /// 24 与 28 都不在系统文本样式的默认点数上。两者按**同一个** title2 缩——
    /// 只缩图标不缩它那 28 的留白，字号调大后图标就会撑出留白、顶进右边的文案里。
    @ScaledMetric(relativeTo: .title2) private var leadingSymbolSize: CGFloat = 24
    @ScaledMetric(relativeTo: .title2) private var leadingSymbolWidth: CGFloat = 28

    /// 系统粘贴按钮的标题（「粘贴」/「Paste」/「Coller」）是 UIKit 按当前语言和动态字体自己画的，
    /// 外面这只盒子写死 92 × 34 就跟不上：按钮会画到盒子外面，压住旁边的关闭键。
    /// 按 subheadline（按钮文字的量级）一起放大。
    @ScaledMetric(relativeTo: .subheadline) private var pasteButtonWidth: CGFloat = 92
    @ScaledMetric(relativeTo: .subheadline) private var pasteButtonHeight: CGFloat = 34

    /// 设计 3.5 的 18pt 叉 + 28 圆底：圆底要跟着叉一起长，否则叉会戳出圆外
    @ScaledMetric(relativeTo: .body) private var dismissSymbolSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var dismissDiameter: CGFloat = 28

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: saved ? "checkmark.circle.fill" : "doc.on.clipboard")
                .font(.system(size: leadingSymbolSize))
                .foregroundStyle(saved ? CopyoTheme.success : CopyoTheme.accent)
                .frame(width: leadingSymbolWidth)
                // 右边那行字已经把状态说完了，旁白不必在这枚图标上停一次
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(saved ? String(localized: "Saved") : String(localized: "New clipboard content"))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(CopyoTheme.label)
                if !saved {
                    Text(String(localized: "Paste to save it to your history"))
                        .font(.caption)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !saved {
                PasteControlButton(onPaste: onPaste)
                    .frame(width: pasteButtonWidth, height: pasteButtonHeight)
                Button(action: onDismiss) {
                    // 设计 3.5：28 × 28 的 fill 圆底 + 18pt 的 ×，不是一个裸叉
                    Image(systemName: "xmark")
                        .font(.system(size: dismissSymbolSize, weight: .semibold))
                        .foregroundStyle(CopyoTheme.labelSecondary)
                        .frame(width: dismissDiameter, height: dismissDiameter)
                        .background(CopyoTheme.fill, in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Dismiss"))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(CopyoTheme.bgCard, in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.banner, style: .continuous))
        // 设计 3.5 的 `0 1px 3px rgba(0,0,0,.08)`：白横幅贴在浅灰背景上，没有投影就浮不起来
        .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: CopyoTheme.Radius.banner, style: .continuous)
                .strokeBorder(CopyoTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
        .animation(CopyoTheme.springAnimation, value: saved)
    }
}

/// 系统粘贴按钮。内容通过 `paste(itemProviders:)` 回到 responder 链，所以宿主视图
/// 必须是 `UIPasteConfigurationSupporting`（UIView 本身就是），并声明能接受哪些类型。
struct PasteControlButton: UIViewRepresentable {
    var onPaste: ([NSItemProvider]) -> Void

    func makeUIView(context: Context) -> PasteReceiverView {
        let host = PasteReceiverView()
        host.onPaste = onPaste

        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconAndLabel
        configuration.cornerStyle = .capsule
        let control = UIPasteControl(configuration: configuration)
        // target 是属性不是 init 参数；不设的话粘贴事件会顺着 responder 链跑到别处
        control.target = host
        control.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(control)
        NSLayoutConstraint.activate([
            control.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            control.centerYAnchor.constraint(equalTo: host.centerYAnchor),
        ])
        return host
    }

    func updateUIView(_ uiView: PasteReceiverView, context: Context) {
        uiView.onPaste = onPaste
    }
}

/// `UIPasteControl` 的 target。系统把粘贴内容以 itemProvider 的形式送到这里，
/// 全程不经过 `UIPasteboard.general`，因此不触发任何权限提示。
final class PasteReceiverView: UIView {
    var onPaste: (([NSItemProvider]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let configuration = UIPasteConfiguration(forAccepting: NSString.self)
        configuration.addAcceptableTypeIdentifiers([UTType.image.identifier, UTType.url.identifier])
        pasteConfiguration = configuration
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func paste(itemProviders: [NSItemProvider]) {
        onPaste?(itemProviders)
    }
}
