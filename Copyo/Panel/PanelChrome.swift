import AppKit
import SwiftUI

// 面板里反复出现的小件：玻璃外壳、键帽、提示、筛选胶囊、空态插画、弹出菜单。
// 数值取自 art/macos-design/2026-09-27/gen_v2.py，令牌在 CopyoTheme.Dense。

// MARK: - 玻璃

/// 面板、预览窗、轻提示共用的玻璃外壳（第八节第 32(c) 条）：macOS 26 起用系统玻璃，
/// 14–25 用 NSVisualEffectView；设计稿那组 rgba 只是视觉目标。减弱透明度时一律降级成实色（第 24 条）。
struct GlassBackground: View {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if reduceTransparency {
                shape.fill(CopyoTheme.glassSolid)
            } else if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: shape)
            } else {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    .clipShape(shape)
            }
        }
        .overlay(shape.strokeBorder(CopyoTheme.glassRing, lineWidth: 0.5))
    }
}

// MARK: - 键帽与提示

struct KeyCap: View {
    let text: String
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(verbatim: text)
            .font(CopyoTheme.Dense.Font.keycap)
            // 增强对比度时 meta 一档提到 label（第八节第 24 条）
            .foregroundStyle(contrast == .increased ? CopyoTheme.label : CopyoTheme.labelMeta)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(CopyoTheme.fill2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// 底部提示条的一项：键帽 + 说明
struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            KeyCap(text: keys)
            Text(label)
                .font(CopyoTheme.Dense.Font.hint)
                .foregroundStyle(CopyoTheme.labelSecondary)
        }
    }
}

// MARK: - 胶囊

/// 筛选胶囊（26 高、圆角 8）。选中是实心 accent + 白字；未选中 fill 底，悬停换 fill2（第 7 条）。
struct FilterChip: View {
    let title: String
    var isOn = false
    var showsChevron = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: isOn ? .semibold : .medium))
                    .lineLimit(1)
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isOn ? Color.white.opacity(0.85) : CopyoTheme.labelSecondary)
                }
            }
            .foregroundStyle(isOn ? Color.white : CopyoTheme.label)
            .padding(.leading, 11)
            .padding(.trailing, showsChevron ? 9 : 11)
            .frame(height: CopyoTheme.Dense.chipHeight)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .clipCardPointer()   // 4.3：胶囊是可点元素，手型光标
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var background: Color {
        if isOn { return CopyoTheme.accent }
        return hovering ? CopyoTheme.fill2 : CopyoTheme.fill
    }
}

/// 顶栏右侧 32 × 32 的图标按钮（同步格、齿轮）
struct PanelIconButton<Icon: View>: View {
    let help: String
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            icon()
                .frame(width: 32, height: 32)
                .background(hovering ? CopyoTheme.fill : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .clipCardPointer()
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - 空态插画

/// 空态插画：骨白卡 + 红蓝错位套印 + 三条墨色内容条（gen_v2.py 的 PLATE）。
/// macOS 上品牌红蓝只出现在 App 图标与这里（第八节第 27 条）。
struct EmptyPlate: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CopyoTheme.Brand.bone)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(CopyoTheme.Brand.red.opacity(0.9))
                .frame(width: 52, height: 8)
                .offset(x: 20, y: 24)
            RoundedRectangle(cornerRadius: 2)
                .fill(CopyoTheme.Brand.blue.opacity(0.85))
                .frame(width: 52, height: 8)
                .offset(x: 24, y: 28)
                .blendMode(.multiply)
            bar(width: 36, y: 52)
            bar(width: 52, y: 64)
            bar(width: 24, y: 76)
        }
        .frame(width: 96, height: 96, alignment: .topLeading)
        .compositingGroup()
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, y: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(CopyoTheme.Brand.ink)
            .frame(width: width, height: 8)
            .offset(x: 22, y: y)
    }
}

// MARK: - 弹出菜单

/// 用闭包驱动的 NSMenu。⌘P、悬停动作簇的图钉、Pinboard 胶囊都要在某个点弹一张菜单，
/// SwiftUI 的 `Menu` 没法由键盘触发，也没法指定弹出位置。
/// 菜单在本进程里跟踪鼠标，不会让面板失去 key，所以不需要任何「抑制自动收起」的补丁。
@MainActor
final class PopupMenu: NSObject {
    enum Entry {
        case item(title: String, symbol: String? = nil, checked: Bool = false, destructive: Bool = false, action: () -> Void)
        case separator
    }

    private var actions: [() -> Void] = []

    /// - Parameter screenPoint: 菜单左上角的屏幕坐标
    static func show(_ entries: [Entry], at screenPoint: NSPoint) {
        let owner = PopupMenu()
        let menu = NSMenu()
        menu.autoenablesItems = false
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())
            case let .item(title, symbol, checked, destructive, action):
                let item = NSMenuItem(title: title, action: #selector(run(_:)), keyEquivalent: "")
                item.target = owner
                item.tag = owner.actions.count
                owner.actions.append(action)
                item.state = checked ? .on : .off
                if let symbol {
                    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                }
                if destructive {
                    item.attributedTitle = NSAttributedString(string: title,
                                                              attributes: [.foregroundColor: NSColor.systemRed])
                }
                menu.addItem(item)
            }
        }
        // popUp 是同步跟踪的，返回时 owner 仍被这个栈帧持有
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
        withExtendedLifetime(owner) {}
    }

    @objc private func run(_ sender: NSMenuItem) {
        actions[sender.tag]()
    }
}
