import SwiftUI

/// 一键保存（设计 04b）。
///
/// 设计稿写的是「三种入口都靠同一个快捷指令」，那是 iOS 17 之前的做法。
/// iOS 18 起操作按钮和控制中心都能直接选到 App 自带的控件（CopyoWidgets 的 SaveClipboardControl），
/// 一步配置都不用；只有「轻点背面」在系统里仍然只能绑定快捷指令。
/// 所以这里按真实做法重写了步骤，快捷指令按钮只出现在轻点背面那一段。
///
/// 那条快捷指令的 iCloud 链接还没发布（见 `ShortcutLinks`）。没发布时按钮改成打开「快捷指令」
/// 新建页，步骤改成手工搭一条只含「保存剪贴板」的快捷指令——原来那版弹「尚未发布」，
/// 审核员点到就是一个做不完的功能（2.1）。
struct QuickSaveGuideScreen: View {
    @Environment(\.openURL) private var openURL

    @State private var entry: QuickSaveEntry

    /// `initialEntry` 只给截图路由用（`-demoScreen settings-quicksave-backtap`），
    /// 正常进入这一页一律从默认段开始。传进来的段在这台设备上不存在（iPad 上的轻点背面）时收回默认段
    init(initialEntry: QuickSaveEntry = .defaultEntry) {
        _entry = State(initialValue: QuickSaveEntry.available.contains(initialEntry)
                       ? initialEntry : .defaultEntry)
    }

    enum QuickSaveEntry: String, CaseIterable, Identifiable {
        case actionButton
        case backTap
        case controlCenter

        var id: String { rawValue }

        /// 这台设备上真正存在的入口。iPad 既没有操作按钮也没有轻点背面，
        /// 照样摆出三段就是在教用户找一个不存在的硬件（审核员拿 iPad 测一眼就能看出来）
        static var available: [QuickSaveEntry] {
            UIDevice.current.userInterfaceIdiom == .pad ? [.controlCenter] : allCases
        }

        /// 进页面时选中的段，也是设置总览「一键保存」那一行的右值
        static var defaultEntry: QuickSaveEntry {
            available.first ?? .controlCenter
        }

        var title: String {
            switch self {
            case .actionButton: String(localized: "Action Button")
            case .backTap: String(localized: "Back Tap")
            case .controlCenter: String(localized: "Control Center")
            }
        }

        var symbol: String {
            switch self {
            case .actionButton: "button.horizontal.top.press"
            case .backTap: "hand.tap.fill"
            case .controlCenter: "switch.2"
            }
        }
    }

    var body: some View {
        GuideScroll {
            GuideParagraph(text: String(localized: "One press saves whatever is on the clipboard right now. Copyo opens and shows “Saved”."))

            // 只剩一段时分段控件没有可选的东西，画出来反而像个坏掉的控件
            if QuickSaveEntry.available.count > 1 {
                QuickSaveSegmentedControl(selection: $entry)
            }

            if entry == .backTap {
                if let url = ShortcutLinks.saveClipboardURL {
                    GuidePrimaryButton(title: String(localized: "Add the “Save Clipboard” Shortcut"),
                                       symbol: "plus.square.on.square") {
                        openURL(url)
                    }
                } else {
                    GuidePrimaryButton(title: String(localized: "Open Shortcuts"),
                                       symbol: "square.stack.3d.up.fill") {
                        openURL(ShortcutLinks.createShortcutURL)
                    }
                }
            }

            GroupedCard {
                let steps = steps(for: entry)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 { HairlineSeparator() }
                    if entry == .actionButton, index == 1 {
                        // 设计 04b 步骤 2 右侧的手机示意图。纯自绘，不依赖任何平台能力，
                        // 是这一页唯一的图形元素。
                        // 顶对齐 + 上下 14：与步骤条目自己的上下内距同值，示意图的顶边对齐序号圆，
                        // 上下两条分隔线各留一截空（居中对齐时步骤文字会被拉到图的半腰，
                        // 图又正好把整行撑满、顶住两条线）
                        HStack(alignment: .top, spacing: 12) {
                            GuideStepRow(index + 1, title: step.title, detail: step.detail)
                            ActionButtonPhoneArt()
                                .padding(.vertical, 14)
                                .padding(.trailing, 16)
                        }
                    } else {
                        GuideStepRow(index + 1, title: step.title, detail: step.detail)
                    }
                }
            }

            GuideParagraph(text: footnote(for: entry), footnote: true)
        }
        .navigationTitle(String(localized: "Quick Save"))
    }

    // MARK: - 步骤

    private struct Step {
        var title: String
        var detail: String?
    }

    private func steps(for entry: QuickSaveEntry) -> [Step] {
        switch entry {
        case .actionButton:
            [
                Step(title: String(localized: "Open Settings › Action Button"),
                     detail: String(localized: "iPhone 15 Pro and later")),
                Step(title: String(localized: "Swipe to “Controls”, then tap “Choose a Control”"),
                     detail: nil),
                Step(title: String(localized: "Pick “Save Clipboard” under Copyo"),
                     detail: String(localized: "Press and hold the Action Button to save")),
            ]
        case .backTap:
            (ShortcutLinks.isPublished
                ? [
                    Step(title: String(localized: "Tap the button above to add the shortcut"),
                         detail: String(localized: "Only needed once")),
                ]
                : [
                    Step(title: String(localized: "Tap the button above and create a new shortcut"),
                         detail: String(localized: "Only needed once")),
                    Step(title: String(localized: "Add Copyo’s “Save Clipboard” action"),
                         detail: String(localized: "Search for Copyo in the action list")),
                ])
            + [
                Step(title: String(localized: "Open Settings › Accessibility › Touch › Back Tap"),
                     detail: nil),
                Step(title: String(localized: "Tap “Double Tap” and choose the shortcut"),
                     detail: String(localized: "Tap the back of your iPhone twice to save")),
            ]
        case .controlCenter:
            [
                Step(title: String(localized: "Open Control Center and press and hold an empty spot"),
                     detail: nil),
                Step(title: String(localized: "Tap “Add a Control” and search for Copyo"),
                     detail: nil),
                // iPad 的锁定屏幕没有可换的控件按钮，那句附注只对 iPhone 成立
                Step(title: String(localized: "Add “Save Clipboard”"),
                     detail: UIDevice.current.userInterfaceIdiom == .pad
                        ? nil : String(localized: "The Lock Screen buttons work the same way")),
            ]
        }
    }

    private func footnote(for entry: QuickSaveEntry) -> String {
        switch entry {
        case .actionButton, .controlCenter:
            String(localized: "The control comes with Copyo, so there is nothing to add first.")
        case .backTap:
            ShortcutLinks.isPublished
                ? String(localized: "Back Tap can only run a shortcut, which is why this one needs the shortcut above.")
                : String(localized: "Back Tap can only run a shortcut, so it needs one that runs “Save Clipboard”.")
        }
    }
}

/// 设计 04b 步骤 2 右侧的示意图：64 × 100 的机身 + 左侧一段橙色（#FF9F0A）操作按钮。
///
/// 整张图定尺不跟随辅助功能字号：机身、听筒条、按钮三段是按比例摆出来的一幅画，
/// 各自缩放只会把手机画歪。它整块 `accessibilityHidden`，放大也不带来任何信息。
private struct ActionButtonPhoneArt: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(CopyoTheme.fill)
            .frame(width: 64, height: 100)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(CopyoTheme.separator.opacity(0.6), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                // 顶部听筒条，让它一眼看得出是台手机
                Capsule()
                    .fill(CopyoTheme.labelTertiary)
                    .frame(width: 20, height: 3)
                    .padding(.top, 8)
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(CopyoTheme.warning)
                    .frame(width: 4, height: 22)
                    // 4pt 宽的侧键整条落在机身外、留约 2pt 缝，设计稿里它是贴在机身外侧的一段
                    .offset(x: -6, y: -14)
            }
            .accessibilityHidden(true)
    }
}

/// 设计 04b 的分段控件：高 36、radius 9、fill 底、选中段白底带阴影（深色 #636366），段内是 13pt 图标 + 文字。
/// 系统 `.segmented` 样式一个段里放不下图标加文字，只好自绘。
private struct QuickSaveSegmentedControl: View {
    @Binding var selection: QuickSaveGuideScreen.QuickSaveEntry

    /// 控件高 36 不在样式表上，按段内文字的 `.footnote`（13pt）缩——不跟着长会把放大后的文字上下切掉。
    /// 段内图标的 12 **在**表上（`.caption`），就走样式：`@ScaledMetric` 只留给落不到表上的尺寸。
    @ScaledMetric(relativeTo: .footnote) private var controlMinHeight: CGFloat = 36

    /// 选中段的底板。浅色是白；深色不能用 `bgCard`——#1C1C1E 与叠在黑底上的 fill 轨道
    /// 几乎同色，选中段整块消失，只剩字重差异。取系统 UISegmentedControl 深色选中段的 #636366
    private static let selectedFill = CopyoTheme.dynamic(light: CopyoTheme.rgb(0xFFFFFF),
                                                         dark: CopyoTheme.rgb(0x636366))

    var body: some View {
        HStack(spacing: 0) {
            ForEach(QuickSaveGuideScreen.QuickSaveEntry.available) { entry in
                let selected = entry == selection
                Button {
                    withAnimation(CopyoTheme.springAnimation) { selection = entry }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: entry.symbol)
                            .font(.system(.caption, weight: selected ? .semibold : .regular))
                            // 图标只是段标题的装饰，标题就在它右边
                            .accessibilityHidden(true)
                        Text(entry.title)
                            .font(.system(.footnote, weight: selected ? .semibold : .regular))
                            // 三段平分一屏，「Control Center」在放大档位下单行放不下：
                            // 只靠 0.85 的缩放会被截成「Control Ce…」，读不出这一段是什么。
                            // 允许折成两行，再配上全局统一的 0.8 下限，控件靠 minHeight 跟着长高。
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(CopyoTheme.label)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Self.selectedFill)
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .frame(minHeight: controlMinHeight)
        .background(CopyoTheme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
