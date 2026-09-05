import PasterCore
import SwiftData
import SwiftUI

/// 单个 Pinboard 的内容页（设计 03b）。
/// 标题 = 名称 + chevron，点开是重命名 / 图标 / 颜色 / 排序 / 全部复制 / 删除；
/// 副行「N 条 · 当前排序」；正文是与历史页同一套的双列瀑布流。
struct PinboardContentScreen: View {
    let board: Pinboard

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PinboardPreferences.contentSort, store: IOSSettings.defaults)
    private var contentSortRaw = PinboardContentSort.pinnedTime.rawValue

    @State private var columnWidth: CGFloat = 170
    @State private var showsRename = false
    @State private var showsNewPinboard = false
    @State private var showsDeleteConfirmation = false
    /// 删除流程一旦开始就不再从模型读任何值：`dismiss()` 只是发起 pop，
    /// 返回动画的两三百毫秒里视图还在树上，body 会重算，而那时对象可能已经失效。
    @State private var isDeleting = false
    @State private var deletingName = ""

    init(board: Pinboard) {
        self.board = board
    }

    private var contentSort: PinboardContentSort {
        PinboardContentSort(rawValue: contentSortRaw) ?? .pinnedTime
    }

    private var items: [ClipItem] {
        guard !isDeleting else { return [] }
        return contentSort.sort(board.items ?? [])
    }

    /// 标题与确认框都走它：删除中读快照，不碰模型
    private var displayName: String {
        isDeleting ? deletingName : board.name
    }

    /// 设计 03b 的副行：`6 条 · 按固定时间`
    private var subtitle: String {
        let count = items.count
        let countText = count == 1
            ? String(localized: "1 item")
            : String(format: String(localized: "%lld items"), count)
        return "\(countText) · \(contentSort.title)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(subtitle)
                    .font(PasterTheme.Fonts.footnote)
                    .foregroundStyle(PasterTheme.labelSecondary)
                    .padding(.bottom, PasterTheme.Metrics.gridGap)
                if items.isEmpty {
                    EmptyState(symbol: "pin",
                               title: String(localized: "Nothing pinned yet"),
                               message: String(localized: "Swipe a card right in History, or long-press it and pick this pinboard."))
                        .padding(.top, 80)
                } else {
                    grid
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, PasterTheme.Metrics.pageInset)
            .padding(.bottom, PasterTheme.Metrics.tabBarHeight + PasterTheme.Metrics.tabBarBottomInset)
        }
        .background(PasterTheme.bgGrouped)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // 设计 03b 的标题带 chevron、点开就是这个菜单。用系统的 title menu 而不是自绘 principal item：
        // principal item 会把返回按钮的「Pinboard」标签挤掉，只剩一个箭头。
        .toolbarTitleMenu { boardMenu }
        .overlay(alignment: .topTrailing) { demoMenuPreview }
        .renamePinboardAlert(isPresented: $showsRename, currentName: displayName) { newName in
            // 默认板设置按名字匹配，改名不跟着迁移的话这个板就悄悄不再是默认板了
            if IOSSettings.defaultPinboardName == board.name {
                IOSSettings.defaultPinboardName = newName
            }
            board.name = newName
            try? model.modelContext.save()
            model.toast.show(String(localized: "Renamed"), symbol: "pencil")
        }
        .newPinboardAlert(isPresented: $showsNewPinboard) { name in
            model.createPinboard(named: name,
                                 iconName: PinboardAppearance.defaultSymbol,
                                 colorHex: PinboardAppearance.nextColorHex(existingCount: model.pinboards().count))
            model.toast.show(String(localized: "Pinboard created"), symbol: "pin.fill")
        }
        .alert(String(format: String(localized: "Delete “%@”?"), displayName),
               isPresented: $showsDeleteConfirmation) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete"), role: .destructive) { deleteBoard() }
        } message: {
            Text(String(localized: "Its clips go back to History and are not deleted."))
        }
    }

    /// 与 `ClipDetailScreen` 的删除对齐：先退出、等返回动画走完再删。
    /// 同一个 runloop 里 `dismiss()` 之后立刻删，视图还在屏幕上就会读到已失效的模型；
    /// iPad 分栏里 `dismiss()` 更是空操作，只能靠 `isDeleting` 把读取全部挡掉
    /// （detail 列的复位由 `AppModel.delete(_ board:)` 负责）。
    private func deleteBoard() {
        deletingName = board.name
        isDeleting = true
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            model.delete(board)
            model.toast.show(String(localized: "Pinboard deleted"), symbol: "trash.fill")
        }
    }

    // MARK: - 网格

    private var grid: some View {
        MasonryGrid(items: items,
                    estimatedHeight: { ClipCard.estimatedHeight(for: $0, width: columnWidth, dense: false) }) { item in
            ClipCard(item: item)
                // 与历史页一致：轻点即复制
                .onTapGesture { model.copy(item) }
                .contextMenu { cardMenu(for: item) }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            columnWidth = max(80, (width - PasterTheme.Metrics.gridGap) / 2)
        }
    }

    @ViewBuilder
    private func cardMenu(for item: ClipItem) -> some View {
        Button {
            model.copy(item)
        } label: {
            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
        }
        Button {
            model.copyPlainText(item)
        } label: {
            Label(String(localized: "Copy as Plain Text"), systemImage: "doc.plaintext")
        }
        ShareLink(item: item.transferable,
                  preview: SharePreview(item.displayTitleLocalized)) {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
        }
        Divider()
        PinboardPickerMenu(boards: model.pinboards(),
                           current: board,
                           onSelect: { model.pin(item, to: $0) },
                           onCreate: { showsNewPinboard = true })
        Button {
            model.unpin(item)
        } label: {
            Label(String(localized: "Unpin"), systemImage: "pin.slash")
        }
        Divider()
        Button(role: .destructive) {
            model.delete(item)
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
    }

    // MARK: - 标题菜单

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                boardMenu
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    @ViewBuilder
    private var boardMenu: some View {
        Button {
            showsRename = true
        } label: {
            Label(PinboardMenuLabels.rename, systemImage: "pencil")
        }
        Menu {
            Picker(PinboardMenuLabels.icon, selection: iconBinding) {
                ForEach(PinboardAppearance.symbols, id: \.self) { symbol in
                    Label(symbol, systemImage: symbol).tag(symbol)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(PinboardMenuLabels.icon, systemImage: PinboardAppearance.symbol(for: board))
        }
        Menu {
            Picker(PinboardMenuLabels.color, selection: colorBinding) {
                ForEach(PinboardAppearance.palette, id: \.self) { hex in
                    Label {
                        Text(verbatim: hex)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color(hexString: hex) ?? PasterTheme.accent)
                    }
                    .tag(hex)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(PinboardMenuLabels.color, systemImage: "paintpalette")
        }
        Menu {
            Picker(PinboardMenuLabels.sortBy, selection: $contentSortRaw) {
                ForEach(PinboardContentSort.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(PinboardMenuLabels.sortBy, systemImage: "arrow.up.arrow.down")
        }
        Button {
            model.copyAllAsPlainText(items)
        } label: {
            Label(PinboardMenuLabels.copyAll, systemImage: "doc.plaintext")
        }
        Divider()
        Button(role: .destructive) {
            showsDeleteConfirmation = true
        } label: {
            Label(PinboardMenuLabels.deleteBoard, systemImage: "trash")
        }
    }

    // 两个 Binding 的 getter 会随菜单一起重算，删除流程里同样不能碰模型
    private var iconBinding: Binding<String> {
        Binding(get: { isDeleting ? PinboardAppearance.defaultSymbol : PinboardAppearance.symbol(for: board) },
                set: { board.iconName = $0 })
    }

    private var colorBinding: Binding<String> {
        Binding(get: { isDeleting ? PinboardAppearance.palette[0] : PinboardAppearance.colorHex(for: board) },
                set: { board.colorHex = $0 })
    }

    // MARK: - 截图辅助

    /// SwiftUI 的 `Menu` 没法用代码展开，`simctl` 也点不了屏幕，
    /// 所以带 `-demoMenu` 启动时按设计 03b 的样式画一张静态菜单，只为截图核对。
    @ViewBuilder
    private var demoMenuPreview: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoMenu") {
            PinboardMenuPreview(board: board)
                .padding(.trailing, 16)
                .padding(.top, 6)
        }
        #endif
    }
}

/// 标题菜单的文案。真菜单与截图用的静态菜单共用同一份，改文案不会只改到一边。
enum PinboardMenuLabels {
    static var rename: String { String(localized: "Rename") }
    static var icon: String { String(localized: "Icon") }
    static var color: String { String(localized: "Color") }
    static var sortBy: String { String(localized: "Sort By") }
    static var copyAll: String { String(localized: "Copy All as Plain Text") }
    static var deleteBoard: String { String(localized: "Delete Pinboard") }
}

#if DEBUG
/// 设计 3.11 的上下文菜单外观（宽 230、radius 14、行高 44、破坏项前 8pt 分隔块）。
/// 只在 `-demoMenu` 截图时出现，正常运行永远走系统 `Menu`。
private struct PinboardMenuPreview: View {
    let board: Pinboard

    private var entries: [(title: String, symbol: String)] {
        [(PinboardMenuLabels.rename, "pencil"),
         (PinboardMenuLabels.icon, PinboardAppearance.symbol(for: board)),
         (PinboardMenuLabels.color, "paintpalette"),
         (PinboardMenuLabels.sortBy, "arrow.up.arrow.down"),
         (PinboardMenuLabels.copyAll, "doc.plaintext")]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                row(title: entry.title, symbol: entry.symbol, destructive: false)
                if index < entries.count - 1 {
                    Rectangle()
                        .fill(PasterTheme.separator)
                        .frame(height: 0.5)
                }
            }
            Rectangle()
                .fill(PasterTheme.menuSeparator)
                .frame(height: 8)
            row(title: PinboardMenuLabels.deleteBoard, symbol: "trash", destructive: true)
        }
        .frame(width: 230)
        // 设计的 menu token 是「86% 不透明的近白/深灰」压在 blur 上，两层顺序不能反
        .background(PasterTheme.menu, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(PasterTheme.glassStroke, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 12)
    }

    private func row(title: String, symbol: String, destructive: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17))
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: symbol)
                .font(.system(size: 16))
        }
        .foregroundStyle(destructive ? PasterTheme.destructive : PasterTheme.label)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}
#endif
