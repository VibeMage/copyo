import PasterCore
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
    @Query private var items: [ClipItem]
    @Query(sort: \Pinboard.sortIndex) private var boards: [Pinboard]

    @FocusState private var searchFocused: Bool
    @State private var newBoardName = ""

    init(selection: Binding<SidebarSelection?>,
         columnVisibility: Binding<NavigationSplitViewVisibility>? = nil) {
        _selection = selection
        self.columnVisibility = columnVisibility
    }

    // MARK: - 计数

    /// 一次遍历数完所有类型，六个分类各查一次库不值当
    private var countsByKind: [ClipKind: Int] {
        var result: [ClipKind: Int] = [:]
        for item in items {
            result[item.kind, default: 0] += 1
        }
        return result
    }

    /// 「文本」把富文本一并算进来，口径与 `KindPresentation.matches` 一致
    private func count(for kind: ClipKind, in counts: [ClipKind: Int]) -> Int {
        if kind == .text { return (counts[.text] ?? 0) + (counts[.richText] ?? 0) }
        return counts[kind] ?? 0
    }

    var body: some View {
        @Bindable var model = model
        let counts = countsByKind

        List(selection: $selection) {
            Section {
                SidebarRow(title: PasterTab.history.title,
                           count: items.count,
                           isSelected: isHistoryAllSelected) {
                    SidebarIconTile(symbol: PasterTab.history.symbol,
                                    color: PasterTheme.accent,
                                    filled: true)
                }
                .tag(SidebarSelection.history(nil))

                ForEach(KindPresentation.regularFilters, id: \.self) { kind in
                    SidebarRow(title: KindPresentation.label(kind),
                               count: count(for: kind, in: counts),
                               isSelected: selection == .history(kind)) {
                        Image(systemName: KindPresentation.symbol(kind))
                            .font(.system(size: 17))
                            .foregroundStyle(PasterTheme.accent)
                            .frame(width: SidebarMetrics.iconTile)
                    }
                    .tag(SidebarSelection.history(kind))
                }
            }

            Section {
                ForEach(boards) { board in
                    SidebarRow(title: board.name,
                               count: board.items?.count ?? 0,
                               isSelected: selection == .pinboard(board.persistentModelID)) {
                        SidebarIconTile(symbol: board.iconName ?? "pin.fill",
                                        color: Color(hexString: board.colorHex ?? "") ?? PasterTheme.accent)
                    }
                    .tag(SidebarSelection.pinboard(board.persistentModelID))
                }
            } header: {
                pinboardHeader
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, SidebarMetrics.rowHeight)
        .scrollContentBackground(.hidden)
        .background(PasterTheme.sidebarBg)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { settingsRow }
        .toolbar(.hidden, for: .navigationBar)
        .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 340)
        .background { shortcuts }
        .alert(String(localized: "New Pinboard"), isPresented: $model.presentsNewPinboardAlert) {
            TextField(String(localized: "Name"), text: $newBoardName)
            Button(String(localized: "Cancel"), role: .cancel) { newBoardName = "" }
            Button(String(localized: "Create")) { createBoard() }
        }
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
            // 截图：`-demoScreen pinboard-new` 在 iPad 上落到侧栏的新建 Alert
            if model.demoRoute == .pinboardNew {
                model.presentsNewPinboardAlert = true
            }
        }
    }

    private var isHistoryAllSelected: Bool { selection == .history(nil) }

    // MARK: - 标题与搜索

    private var header: some View {
        @Bindable var model = model
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(verbatim: "Paster")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PasterTheme.label)
                Spacer(minLength: 0)
                if let columnVisibility {
                    Button {
                        withAnimation(PasterTheme.springAnimation) {
                            columnVisibility.wrappedValue = columnVisibility.wrappedValue == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 17))
                            .foregroundStyle(PasterTheme.labelSecondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Toggle Sidebar"))
                }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(PasterTheme.labelSecondary)
                TextField(String(localized: "Search"), text: $model.sidebarSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                    .submitLabel(.search)
                if model.sidebarSearchText.isEmpty {
                    // ⌘F 由侧栏接管（regular 宽度下历史页不再自己抢），这里给个提示
                    Text(verbatim: "⌘F")
                        .font(.system(size: 11))
                        .foregroundStyle(PasterTheme.labelTertiary)
                } else {
                    Button {
                        model.sidebarSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(PasterTheme.labelTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Clear Search"))
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 10)
            .background(PasterTheme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, SidebarMetrics.inset)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(PasterTheme.sidebarBg)
    }

    // MARK: - PINBOARD 分组头

    private var pinboardHeader: some View {
        HStack(spacing: 8) {
            // 「PINBOARD」在中英文设计稿里都是这个大写词，不进本地化
            Text(verbatim: "PINBOARD")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PasterTheme.labelSecondary)
            Spacer(minLength: 0)
            Button {
                newBoardName = ""
                model.presentsNewPinboardAlert = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PasterTheme.accent)
                    .frame(width: 28, height: 28)
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
            SidebarRow(title: PasterTab.settings.title, count: nil, isSelected: selected) {
                Image(systemName: PasterTab.settings.symbol)
                    .font(.system(size: 17))
                    .frame(width: SidebarMetrics.iconTile)
            }
            // 设计 3.14：底部的设置行整行是 label.secondary，不跟上面的分类一样用蓝图标
            .foregroundStyle(PasterTheme.labelSecondary)
            .padding(.horizontal, 10)
            .background {
                // 这一行在 List 之外，系统的侧栏高亮够不到，选中时自己补一层
                if selected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PasterTheme.fill2)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SidebarMetrics.inset)
        .padding(.bottom, 18)
        .padding(.top, 6)
        .background(PasterTheme.sidebarBg)
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

    private func createBoard() {
        let trimmed = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let board = model.createPinboard(named: trimmed.isEmpty ? String(localized: "New Pinboard") : trimmed)
        newBoardName = ""
        model.selectSidebar(.pinboard(board.persistentModelID))
    }
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

/// 一行：图标 + 名称 + 右侧计数。高 38、gap 10（设计 3.14）。
private struct SidebarRow<Icon: View>: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: 10) {
            icon()
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let count {
                Text(count.formatted())
                    .font(.system(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(PasterTheme.labelSecondary)
            }
        }
        .frame(height: SidebarMetrics.rowHeight)
        .listRowInsets(EdgeInsets(top: 2, leading: SidebarMetrics.rowInset,
                                  bottom: 2, trailing: SidebarMetrics.rowInset))
    }
}

/// 图标砖：28 × 28、radius 8、主题色 15% 底 + 同色图标（设计 3.7）。
/// `filled` 是实色底 + 白图标，给「历史」行用。
private struct SidebarIconTile: View {
    let symbol: String
    let color: Color
    var filled = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(filled ? color : color.opacity(0.15))
            .frame(width: SidebarMetrics.iconTile, height: SidebarMetrics.iconTile)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(filled ? Color.white : color)
            }
    }
}
