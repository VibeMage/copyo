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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: saved ? "checkmark.circle.fill" : "doc.on.clipboard")
                .font(.system(size: 24))
                .foregroundStyle(saved ? PasterTheme.success : PasterTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(saved ? String(localized: "Saved") : String(localized: "New clipboard content"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PasterTheme.label)
                if !saved {
                    Text(String(localized: "Paste to save it to your history"))
                        .font(.system(size: 12))
                        .foregroundStyle(PasterTheme.labelSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !saved {
                PasteControlButton(onPaste: onPaste)
                    .frame(width: 92, height: 34)
                Button(action: onDismiss) {
                    // 设计 3.5：28 × 28 的 fill 圆底 + 18pt 的 ×，不是一个裸叉
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PasterTheme.labelSecondary)
                        .frame(width: 28, height: 28)
                        .background(PasterTheme.fill, in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Dismiss"))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(PasterTheme.bgCard, in: RoundedRectangle(cornerRadius: PasterTheme.Radius.banner, style: .continuous))
        // 设计 3.5 的 `0 1px 3px rgba(0,0,0,.08)`：白横幅贴在浅灰背景上，没有投影就浮不起来
        .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: PasterTheme.Radius.banner, style: .continuous)
                .strokeBorder(PasterTheme.separator.opacity(0.5), lineWidth: 0.5)
        )
        .animation(PasterTheme.springAnimation, value: saved)
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
