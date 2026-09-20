import CopyoCore
import SwiftData
import SwiftUI

/// iPad 侧栏（设计 09 / spec 3.14）。
///
/// 结构：标题 + 搜索 → 历史与五个分类 → PINBOARD 分组 → 底部设置。
/// 标题、搜索、设置三段用 safeAreaInset 钉在 List 上下，中间的行留给 `List(selection:)`，
/// 这样选中态是系统侧栏的原生高亮，不必自己画一套（底部的设置行不在 List 里，只好手工描一遍）。
struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    /// 分栏可见性。标题右侧的 sidebar.left 按钮用它收起 / 展开侧栏；
    /// 给 nil 默认值是为了保住 `SidebarView(selection:)` 这个既有签名。
    var columnVisibility: Binding<NavigationSplitViewVisibility>?

    @Environment(AppModel.self) private var model
    /// 计数的失效源。`@Query` 挂在这儿，库一变 body 就重算，计数随之刷新；
    /// 而取 1 条还是取全部，对「要不要重算」这件事没有区别——
    /// 原来这里是一个无条件的 `@Query`，条目上万时侧栏每次 body 都要把上万个
    /// `ClipItem` 实例化一遍，只为了数六个数。
    @Query private var changeProbe: [ClipItem]
    @Query(sort: \Pinboard.sortIndex) private var boards: [Pinboard]

    @FocusState private var searchFocused: Bool

    /// 标题右侧「收起侧栏」按钮的点击区。跟着按钮里那个 17pt 字形一起放大，
    /// 否则大字号档位下图标会顶出这个框
    @ScaledMetric(relativeTo: .body) private var toggleTile: CGFloat = 28
    /// 搜索框高度（设计 3.14 给的 36）。跟着框里 15pt 的文字走，两者才会同步长高
    @ScaledMetric(relativeTo: .subheadline) private var searchFieldHeight: CGFloat = 36
    /// PINBOARD 分组头上 `+` 的点击区，跟着那个 15pt 字形走
    @ScaledMetric(relativeTo: .subheadline) private var addTile: CGFloat = 28

    init(selection: Binding<SidebarSelection?>,
         columnVisibility: Binding<NavigationSplitViewVisibility>? = nil) {
        _selection = selection
        self.columnVisibility = columnVisibility
        var probe = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)])
        probe.fetchLimit = 1
        _changeProbe = Query(probe)
    }

    // MARK: - 计数

    /// 每个分类一次 `COUNT(*)`，条件与历史页的 `@Query` 同源（`ClipQuery.predicate`）。
    /// 同源是硬要求：侧栏写「文本 128」而历史页只列出 96 条，用户会以为数据丢了；
    /// 「富文本算进文本」这条规则只写一遍，就不会有第二处慢慢走偏。
    ///
    /// 六次计数查询听起来比「遍历一遍全都数出来」多，但那一遍遍历的前提是先把整库读进内存；
    /// 计数走的是库内聚合，不实例化任何模型对象。
    private func count(for kind: ClipKind?) -> Int {
        let descriptor = FetchDescriptor<ClipItem>(predicate: ClipQuery.predicate(kind: kind, query: ""))
        return (try? model.modelContext.fetchCount(descriptor)) ?? 0
    }

    var body: some View {
        @Bindable var model = model

        List(selection: $selection) {
            Section {
                SidebarRow(symbol: CopyoTab.history.symbol,
                           symbolColor: CopyoTheme.accent,
                           title: CopyoTab.history.title,
                           count: count(for: nil),
                           isSelected: isHistoryAllSelected)
                .tag(SidebarSelection.history(nil))

                ForEach(KindPresentation.regularFilters, id: \.self) { kind in
                    SidebarRow(symbol: KindPresentation.symbol(kind),
                               symbolColor: CopyoTheme.accent,
                               title: KindPresentation.label(kind),
                               count: count(for: kind),
                               isSelected: selection == .history(kind))
                    .tag(SidebarSelection.history(kind))
                }
            }

            Section {
                ForEach(boards) { board in
                    SidebarRow(symbol: board.iconName ?? "pin.fill",
                               symbolColor: Color(hexString: board.colorHex ?? "") ?? CopyoTheme.accent,
                               title: board.name,
                               count: board.items?.count ?? 0,
                               isSelected: selection == .pinboard(board.persistentModelID))
                    .tag(SidebarSelection.pinboard(board.persistentModelID))
                }
            } header: {
                pinboardHeader
            }
        }
        .listStyle(.sidebar)
        // 选中态由 SidebarRow 自己画 accent 实色底（设计 09），
        // 把系统那层浅灰高亮的色相清成透明，避免两层叠在一起
        .tint(.clear)
        // 这是行高的**下限**不是定高，行内容自己会把行撑高，
        // 所以它不必跟着辅助功能字号缩放——真正要缩放的是 `SidebarRow` 里那一条
        .environment(\.defaultMinListRowHeight, SidebarMetrics.rowHeight)
        .scrollContentBackground(.hidden)
        .background(CopyoTheme.sidebarBg)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { settingsRow }
        .toolbar(.hidden, for: .navigationBar)
        .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 340)
        .background { shortcuts }
        .onChange(of: selection) { _, new in
            guard let new else { return }
            model.selectSidebar(new)
        }
        .onChange(of: model.sidebarSearchText) { _, text in
            // 搜索是历史页的能力：一开始打字就把选中项拉回历史，否则关键词落在设置页上没人用
            guard !text.isEmpty, selection?.tab != .history else { return }
            model.selectSidebar(.history(model.kindFilter))
        }
        .task {
            // 先看启动参数，没有再跟标签栏对齐——分栏可能是从 Slide Over 退出后才出现的
            if !model.applyDemoSidebarSelection() {
                model.syncSidebarSelectionWithTab()
            }
            // 截图：`-demoScreen pinboard-new` 在 iPad 上也落到新建 Alert（宿主在 RootView）
            if model.demoRoute == .pinboardNew {
                model.presentsNewPinboard = true
            }
        }
    }

    private var isHistoryAllSelected: Bool { selection == .history(nil) }

    // MARK: - 标题与搜索

    private var header: some View {
        @Bindable var model = model
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(verbatim: "Copyo")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(CopyoTheme.label)
                Spacer(minLength: 0)
                if let columnVisibility {
                    Button {
                        withAnimation(CopyoTheme.springAnimation) {
                            columnVisibility.wrappedValue = columnVisibility.wrappedValue == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.body)
                            .foregroundStyle(CopyoTheme.labelSecondary)
                            // 28×28 是点击区的下限而不是上限：写死 `width/height` 的话，
                            // 辅助功能大字号下字形会长出这个框、压到左边的标题上
                            .frame(minWidth: toggleTile, minHeight: toggleTile)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Toggle Sidebar"))
                }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                TextField(String(localized: "Search"), text: $model.sidebarSearchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .focused($searchFocused)
                    .submitLabel(.search)
                if model.sidebarSearchText.isEmpty {
                    // ⌘F 由侧栏接管（regular 宽度下历史页不再自己抢），这里给个提示
                    Text(verbatim: "⌘F")
                        .font(.caption2)
                        .foregroundStyle(CopyoTheme.labelTertiary)
                } else {
                    Button {
                        model.sidebarSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(CopyoTheme.labelTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Clear Search"))
                }
            }
            // 装文字的盒子只能给下限：字号放大后还钉死 36 就是把输入的字裁掉一截，
            // 那比「不跟着放大」更像坏了
            .padding(.vertical, 6)
            .frame(minHeight: searchFieldHeight)
            .padding(.horizontal, 10)
            .background(CopyoTheme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, SidebarMetrics.inset)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(CopyoTheme.sidebarBg)
    }

    // MARK: - PINBOARD 分组头

    private var pinboardHeader: some View {
        HStack(spacing: 8) {
            // 「PINBOARD」在中英文设计稿里都是这个大写词，不进本地化
            Text(verbatim: "PINBOARD")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(CopyoTheme.labelSecondary)
            Spacer(minLength: 0)
            Button {
                model.presentsNewPinboard = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(CopyoTheme.accent)
                    .frame(minWidth: addTile, minHeight: addTile)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "New Pinboard"))
        }
        .textCase(nil)
        .padding(.top, 6)
    }

    // MARK: - 底部设置

    private var settingsRow: some View {
        let selected = selection == .settings
        return Button {
            model.selectSidebar(.settings)
        } label: {
            // 设计 3.14：底部的设置行整行是 label.secondary，不跟上面的分类一样用蓝图标
            SidebarRow(symbol: CopyoTab.settings.symbol,
                       symbolColor: CopyoTheme.labelSecondary,
                       title: CopyoTab.settings.title,
                       count: nil,
                       isSelected: selected,
                       unselectedTitleColor: CopyoTheme.labelSecondary)
                .padding(.horizontal, 10)
                .background {
                    // 这一行在 List 之外，系统高亮够不到，选中底跟上面的行走同一套
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(CopyoTheme.accent)
                    }
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SidebarMetrics.inset)
        .padding(.bottom, 18)
        .padding(.top, 6)
        .background(CopyoTheme.sidebarBg)
    }

    // MARK: - 硬件键盘

    /// ⌘1/2/3 切侧栏、⌘F 聚焦搜索。按钮只是快捷键的载体，不占位置也不进无障碍。
    private var shortcuts: some View {
        ZStack {
            Button(String(localized: "Show History")) {
                model.selectSidebar(.history(nil))
            }
            .keyboardShortcut("1", modifiers: .command)

            Button(String(localized: "Show Pinboards")) {
                if let board = model.firstPinboardSelection { model.selectSidebar(board) }
            }
            .keyboardShortcut("2", modifiers: .command)

            Button(String(localized: "Show Settings")) {
                model.selectSidebar(.settings)
            }
            .keyboardShortcut("3", modifiers: .command)

            Button(String(localized: "Search")) {
                searchFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - 新建 Pinboard

}

// MARK: - 行

private enum SidebarMetrics {
    /// 设计 3.14：侧栏左右内距 14。标题 / 搜索 / 底部设置这些不在 List 里的部件用它。
    static let inset: CGFloat = 14
    /// 行内容的左右内距。系统侧栏自己还会再让出几点，18 之后图标正好落在设计的 24 上，
    /// 与搜索框里的放大镜对齐；用 List 默认内距会比设计右移十几点。
    static let rowInset: CGFloat = 18
    static let rowHeight: CGFloat = 38
    static let iconTile: CGFloat = 28
}

/// 一行：裸图标 + 名称 + 右侧计数。高 38 起、gap 10（设计 3.14）。
///
/// 设计 09 的侧栏里所有行都是**裸的彩色图标**，没有图标砖——砖只出现在 iPhone 的 Pinboard 列表（03）。
/// 选中态是 accent 实色底 + 白字 Semibold + 计数 80% 白，不是系统那层浅灰高亮。
private struct SidebarRow: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let count: Int?
    let isSelected: Bool
    var unselectedTitleColor: Color = CopyoTheme.label

    /// 图标列宽。跟着 17pt 的图标一起放大，否则大字号下图标会挤进标题
    @ScaledMetric(relativeTo: .body) private var iconTile: CGFloat = SidebarMetrics.iconTile
    /// 行高（设计 3.14 的 38）。跟标题那档 15pt 一起放大
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = SidebarMetrics.rowHeight

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(isSelected ? Color.white : symbolColor)
                .frame(width: iconTile)
            Text(title)
                .font(.system(.subheadline, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : unselectedTitleColor)
                .lineLimit(1)
                // Pinboard 的名字是用户自己起的，可以很长，而侧栏最宽只有 340pt，大字号下一定放不下。
                // 缩到 80%（全项目统一的下限，法语那轮定下来的）还读得出，硬截断就只剩开头几个字
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            if let count {
                Text(count.formatted())
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : CopyoTheme.labelSecondary)
            }
        }
        // 装文字的盒子只给下限：钉死 38 的话，字号一放大整行文字就被裁掉上下两截
        .padding(.vertical, 4)
        .frame(minHeight: rowHeight)
        .listRowInsets(EdgeInsets(top: 2, leading: SidebarMetrics.rowInset,
                                  bottom: 2, trailing: SidebarMetrics.rowInset))
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? CopyoTheme.accent : Color.clear)
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
        )
        .listRowSeparator(.hidden)
    }
}
