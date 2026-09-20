import CopyoCore
import SwiftData
import SwiftUI

/// Pinboard 列表（设计 03）。
/// 大标题 + 右上排序 / 新建；分组卡片里每行 = 图标砖 + 名称 + 条目数 + chevron；底部脚注。
struct PinboardListScreen: View {
    @Environment(AppModel.self) private var model
    /// 按 sortIndex 取（板的固有顺序），显示顺序再按用户选的排序重排
    @Query(sort: \Pinboard.sortIndex) private var boards: [Pinboard]

    @AppStorage(PinboardPreferences.listSort, store: IOSSettings.defaults)
    private var listSortRaw = PinboardListSort.created.rawValue
    @AppStorage(IOSSettings.Key.defaultPinboardName, store: IOSSettings.defaults)
    private var defaultPinboardName = ""

    /// 轻点行推入内容页。用 state 驱动而不是 NavigationLink，`-demoScreen pinboard-content` 才能直接落进去
    @State private var pushedBoard: Pinboard?
    @State private var boardPendingDeletion: Pinboard?
    @State private var didApplyDemoRoute = false

    private var listSort: PinboardListSort {
        PinboardListSort(rawValue: listSortRaw) ?? .created
    }

    private var sortedBoards: [Pinboard] {
        listSort.sort(boards)
    }

    var body: some View {
        Group {
            if boards.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(CopyoTheme.bgGrouped)
        .navigationTitle(CopyoTab.pinboard.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .navigationDestination(item: $pushedBoard) { board in
            PinboardContentScreen(board: board)
        }
        .alert(deleteAlertTitle, isPresented: deleteAlertBinding, presenting: boardPendingDeletion) { board in
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete"), role: .destructive) { delete(board) }
        } message: { _ in
            Text(String(localized: "Its clips go back to History and are not deleted."))
        }
        .task { applyDemoRouteOnce() }
    }

    // MARK: - 列表

    private var list: some View {
        List {
            Section {
                ForEach(sortedBoards) { board in
                    row(for: board)
                }
            } footer: {
                Text(String(localized: "Pinboards are shared with your Mac. Swiping a card right pins it to the first pinboard; long-press to pick another."))
                    .font(CopyoTheme.Fonts.footnote)
                    .foregroundStyle(CopyoTheme.labelSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(for board: Pinboard) -> some View {
        Button {
            pushedBoard = board
        } label: {
            PinboardRow(board: board, isDefault: board.name == defaultPinboardName)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(CopyoTheme.bgCard)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                boardPendingDeletion = board
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                setDefault(board)
            } label: {
                Label(String(localized: "Set as Default"), systemImage: "pin.fill")
            }
            .tint(CopyoTheme.accent)
        }
    }

    private var emptyState: some View {
        EmptyState(symbol: "pin",
                   title: String(localized: "No pinboards"),
                   message: String(localized: "Pin a clip to keep it out of the history limit."),
                   actionTitle: String(localized: "New Pinboard"),
                   action: { model.presentsNewPinboard = true })
            .frame(maxHeight: .infinity)
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(String(localized: "Sort By"), selection: $listSortRaw) {
                    ForEach(PinboardListSort.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .disabled(boards.isEmpty)
        }
        // 设计 03 把排序与新建画成两个独立的玻璃圆钮；iOS 26 默认会把同侧按钮并进一个胶囊，
        // 用 ToolbarSpacer 拆开
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                model.presentsNewPinboard = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(String(localized: "New Pinboard"))
        }
    }

    // MARK: - 动作

    private func setDefault(_ board: Pinboard) {
        defaultPinboardName = board.name
        model.toast.show(String(format: String(localized: "“%@” is now the default"), board.name),
                         symbol: "pin.fill")
    }

    private func delete(_ board: Pinboard) {
        // 删掉的正好是默认板时把设置清掉，免得留一个指不到板的名字
        if board.name == defaultPinboardName { defaultPinboardName = "" }
        if pushedBoard?.persistentModelID == board.persistentModelID { pushedBoard = nil }
        boardPendingDeletion = nil
        model.delete(board)
        model.toast.show(String(localized: "Pinboard deleted"), symbol: "trash.fill")
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { boardPendingDeletion != nil },
                set: { if !$0 { boardPendingDeletion = nil } })
    }

    private var deleteAlertTitle: String {
        guard let board = boardPendingDeletion else { return "" }
        return String(format: String(localized: "Delete “%@”?"), board.name)
    }

    /// `-demoScreen pinboard-content` 直接推入第一个板，`pinboard-new` 直接弹新建 Alert
    private func applyDemoRouteOnce() {
        guard !didApplyDemoRoute else { return }
        didApplyDemoRoute = true
        switch model.demoRoute {
        case .pinboardContent:
            pushedBoard = sortedBoards.first
        case .pinboardNew:
            model.presentsNewPinboard = true
        default:
            break
        }
    }
}

/// 设计 3.7：行高 56、内距 16、间距 12；图标砖 32；名称 17；条目数 17 次级；chevron。
private struct PinboardRow: View {
    let board: Pinboard
    var isDefault: Bool

    /// chevron 的 14pt 不在系统样式表上，按行文字的 body 缩，两者才会一起长
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 12) {
            PinboardIconTile(board: board)
            Text(board.name)
                .font(CopyoTheme.Fonts.body)
                .foregroundStyle(CopyoTheme.label)
                .lineLimit(1)
                // 板名是用户自己起的，长度没有上限；放大档位下让它缩回来，
                // 而不是把右边的条目数和 chevron 挤出行外
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isDefault {
                // 「设为默认」是右滑动作，行上不给标记的话用户看不出改没改
                Image(systemName: "pin.fill")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(CopyoTheme.accent)
                    .accessibilityLabel(String(localized: "Default pinboard"))
            }
            let count = board.items?.count ?? 0
            Text("\(count)")
                .font(CopyoTheme.Fonts.body)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .monospacedDigit()
                // 光一个数字读出来是「照片，6」，听不出 6 指的是什么。
                // 复用内容页副行的同一套单复数文案
                .accessibilityLabel(count == 1
                                    ? String(localized: "1 item")
                                    : String(format: String(localized: "%lld items"), count))
            Image(systemName: "chevron.right")
                .font(.system(size: chevronSize, weight: .semibold))
                .foregroundStyle(CopyoTheme.labelTertiary)
                // 展开指示符：整行已经是 `Button`，旁白会自己报「按钮」
                .accessibilityHidden(true)
        }
        // 内距 + minHeight：这一行装着板名和条目数两处文字，写死 56 会在放大档位下把它们切掉。
        // 默认档位下 17pt 行高 22 连内距才 38，仍然被 56 顶成 56，逐像素不变
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}
