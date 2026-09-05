import SwiftUI

/// 一键保存（设计 04b）。
///
/// 设计稿写的是「三种入口都靠同一个快捷指令」，那是 iOS 17 之前的做法。
/// iOS 18 起操作按钮和控制中心都能直接选到 App 自带的控件（PasterWidgets 的 SaveClipboardControl），
/// 一步配置都不用；只有「轻点背面」在系统里仍然只能绑定快捷指令。
/// 所以这里按真实做法重写了步骤，快捷指令按钮只出现在轻点背面那一段。
struct QuickSaveGuideScreen: View {
    @Environment(\.openURL) private var openURL

    @State private var entry: QuickSaveEntry = .actionButton
    @State private var showsUnpublishedAlert = false

    enum QuickSaveEntry: String, CaseIterable, Identifiable {
        case actionButton
        case backTap
        case controlCenter

        var id: String { rawValue }

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
            GuideParagraph(text: String(localized: "One press saves whatever is on the clipboard right now. Paster opens and shows “Saved”."))

            QuickSaveSegmentedControl(selection: $entry)

            if entry == .backTap {
                GuidePrimaryButton(title: String(localized: "Add the “Save Clipboard” Shortcut"),
                                   symbol: "plus.square.on.square") {
                    if let url = ShortcutLinks.saveClipboardURL {
                        openURL(url)
                    } else {
                        showsUnpublishedAlert = true
                    }
                }
            }

            GroupedCard {
                let steps = steps(for: entry)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 { HairlineSeparator() }
                    GuideStepRow(index + 1, title: step.title, detail: step.detail)
                }
            }

            GuideParagraph(text: footnote(for: entry), footnote: true)
        }
        .navigationTitle(String(localized: "Quick Save"))
        .alert(String(localized: "Shortcut link not published yet"), isPresented: $showsUnpublishedAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "The shortcut ships with the App Store release. Until then use the Action Button or Control Center — neither one needs a shortcut."))
        }
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
                Step(title: String(localized: "Pick “Save Clipboard” under Paster"),
                     detail: String(localized: "Press and hold the Action Button to save")),
            ]
        case .backTap:
            [
                Step(title: String(localized: "Tap the button above to add the shortcut"),
                     detail: String(localized: "Only needed once")),
                Step(title: String(localized: "Open Settings › Accessibility › Touch › Back Tap"),
                     detail: nil),
                Step(title: String(localized: "Tap “Double Tap” and choose the shortcut"),
                     detail: String(localized: "Tap the back of your iPhone twice to save")),
            ]
        case .controlCenter:
            [
                Step(title: String(localized: "Open Control Center and press and hold an empty spot"),
                     detail: nil),
                Step(title: String(localized: "Tap “Add a Control” and search for Paster"),
                     detail: nil),
                Step(title: String(localized: "Add “Save Clipboard”"),
                     detail: String(localized: "The Lock Screen buttons work the same way")),
            ]
        }
    }

    private func footnote(for entry: QuickSaveEntry) -> String {
        switch entry {
        case .actionButton, .controlCenter:
            String(localized: "The control comes with Paster, so there is nothing to add first.")
        case .backTap:
            String(localized: "Back Tap can only run a shortcut, which is why this one needs the shortcut above.")
        }
    }
}

/// 设计 04b 的分段控件：高 36、radius 9、fill 底、选中段白底带阴影，段内是 13pt 图标 + 文字。
/// 系统 `.segmented` 样式一个段里放不下图标加文字，只好自绘。
private struct QuickSaveSegmentedControl: View {
    @Binding var selection: QuickSaveGuideScreen.QuickSaveEntry

    var body: some View {
        HStack(spacing: 0) {
            ForEach(QuickSaveGuideScreen.QuickSaveEntry.allCases) { entry in
                let selected = entry == selection
                Button {
                    withAnimation(PasterTheme.springAnimation) { selection = entry }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: entry.symbol)
                            .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        Text(entry.title)
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(PasterTheme.label)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(PasterTheme.bgCard)
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
        .frame(height: 36)
        .background(PasterTheme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
