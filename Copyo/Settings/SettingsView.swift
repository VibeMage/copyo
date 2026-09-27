import AppKit
import Observation
import SwiftUI

/// 设置窗口的根视图：居中分段控件 + 当前页（第八节第 9 条：分段控件替换 `TabView`）。
///
/// 选中哪一页不放在 `@State` 里，而是由窗口控制器持有的 `SettingsSelection` 提供：
/// 窗口开着时再点面板顶栏的同步格，要能当场切到「同步」页，`@State` 从外面够不着。
struct SettingsView: View {
    @Bindable var selection: SettingsSelection

    var body: some View {
        VStack(spacing: 0) {
            SettingsSegmentedControl(selection: $selection.tab)
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: SettingsLayout.width, height: SettingsLayout.contentHeight)
        .background(CopyoTheme.bgGrouped)
    }

    @ViewBuilder
    private var page: some View {
        switch selection.tab {
        case .general: GeneralSettingsView()
        case .sync: SyncSettingsView()
        case .shortcuts: ShortcutsSettingsView()
        case .history: HistorySettingsView()
        case .about: AboutView()
        }
    }
}

/// 当前选中的设置页。窗口控制器持有一份，`show(tab:)` 直接改它。
@Observable
final class SettingsSelection {
    var tab: SettingsTab

    init(tab: SettingsTab = SettingsTab.launchArgument ?? .general) {
        self.tab = tab
    }
}

// MARK: - 标签页与窗口尺寸

/// 设置窗口的五页，顺序按设计稿 `通用 / 同步 / 快捷键 / 历史 / 关于`（第八节第 9 条）。
/// rawValue 就是 `-settingsTab <0-4>` 的编号：顺序改了，编号含义跟着变，商店截图 04 需重拍（6.6）。
enum SettingsTab: Int, CaseIterable, Identifiable {
    case general, sync, shortcuts, history, about

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .sync: String(localized: "Sync")
        case .shortcuts: String(localized: "Shortcuts")
        // 第八节第 9 条：这一页统一叫「历史」
        case .history: String(localized: "History")
        case .about: String(localized: "About")
        }
    }

    /// 截图辅助：`-settingsTab <0-4>` 指定初始页
    static var launchArgument: SettingsTab? {
        let args = ProcessInfo.processInfo.arguments
        guard let flagIndex = args.firstIndex(of: "-settingsTab"),
              args.indices.contains(flagIndex + 1),
              let raw = Int(args[flagIndex + 1]) else { return nil }
        return SettingsTab(rawValue: raw)
    }
}

enum SettingsLayout {
    /// 窗口外框固定 540 × 460（第八节第 9 条）。
    ///
    /// 宽度不再按标签标题实算：那套算法是为了躲 `TabView` 标签栏放不下时折叠成 » 菜单，
    /// 换成居中分段控件后不存在折叠，法语最长的 Synchronisation 也在 540 以内（法语截图验收）。
    static let width: CGFloat = 540
    static let windowHeight: CGFloat = 460
    static let styleMask: NSWindow.StyleMask = [.titled, .closable]

    /// 460 是连标题栏在内的窗口总高；SwiftUI 内容区要扣掉系统标题栏，由 AppKit 按样式算，不写死 28
    static var contentHeight: CGFloat {
        NSWindow.contentRect(forFrameRect: NSRect(x: 0, y: 0, width: width, height: windowHeight),
                             styleMask: styleMask).height
    }
}

// MARK: - 分段控件

/// 居中的分段控件，照 gen_v2.py `seg()` 自绘：容器 `padding 3`、圆角 8、底 `fill`、项间距 2；
/// 每项高 24、`padding 0 12`、圆角 6、12pt；选中 = 底 `bgCard` + 600 + 1pt 投影。
///
/// 不用原生 `Picker(.segmented)`：macOS 26 的原生分段是胶囊玻璃样式，与设计稿差得远，
/// 而且在 14–25 与 26 上长得不一样，截图验收没法用同一张稿对。
struct SettingsSegmentedControl: View {
    @Binding var selection: SettingsTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                segment(tab)
            }
        }
        .padding(3)
        .background(CopyoTheme.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func segment(_ tab: SettingsTab) -> some View {
        let isOn = selection == tab
        return Button {
            selection = tab
        } label: {
            Text(tab.title)
                .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(CopyoTheme.bgCard)
                            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
