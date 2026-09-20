import CopyoCore
import SwiftData
import SwiftUI
import UIKit

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
    /// 旁白的「分享」动作准备好的载荷（`nil` = 没在分享）。见 `ShareSheet` 上面的说明。
    /// 存**算好的** activityItems 而不是条目本身：拼载荷要写临时文件，
    /// 那次 I/O 属于「用户点了分享」这一下，不能留在 `.sheet` 的内容闭包里跟着视图更新反复跑
    @State private var sharePayload: SharePayload?

    /// 旁白「分享」的载荷。`.sheet(item:)` 要一个 `Identifiable`，就拿条目自己的标识当 id
    private struct SharePayload: Identifiable {
        let id: PersistentIdentifier
        let items: [Any]

        init(item: ClipItem) {
            id = item.persistentModelID
            items = PinboardContentScreen.activityItems(for: item)
        }
    }

    /// 当前动态字体相对默认档的倍率，交给 `ClipCard.estimatedHeight` 修正估高。
    /// 卡片里的字会跟着辅助功能字号放大，估高还按默认档算的话两列会一高一矮
    @ScaledMetric(relativeTo: .subheadline) private var typeScale: CGFloat = 1

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
                    .font(CopyoTheme.Fonts.footnote)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .padding(.bottom, CopyoTheme.Metrics.gridGap)
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
            .padding(.horizontal, CopyoTheme.Metrics.pageInset)
            .padding(.bottom, CopyoTheme.Metrics.tabBarHeight + CopyoTheme.Metrics.tabBarBottomInset)
        }
        .background(CopyoTheme.bgGrouped)
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
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
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
                    estimatedHeight: { ClipCard.estimatedHeight(for: $0,
                                                                width: columnWidth,
                                                                dense: false,
                                                                typeScale: typeScale) }) { item in
            // 与历史页一致：轻点即复制。
            //
            // 必须是**真按钮**，不能像原来那样往 `ClipCard` 上挂一个 `.onTapGesture`：
            // 裸手势不会给这张卡任何可激活性，旁白读完卡片内容就滑过去了，
            // 于是 Pinboard 里一条都复制不出来——这一屏对旁白用户是只读的。
            Button {
                model.copy(item)
            } label: {
                ClipCard(item: item)
            }
            .buttonStyle(.plain)
            .contextMenu { cardMenu(for: item) }
            // 长按菜单靠不住：`ClipCard` 已经是一个合成好的旁白元素，菜单项不一定会
            // 冒成转子里的自定义动作。把菜单里几条**不带子菜单**的动作原样挂一遍，
            // 转子里就点得到了。移到别的板要选板，只有子菜单能表达，仍然留给长按菜单。
            .accessibilityAction(named: String(localized: "Copy as Plain Text")) {
                model.copyPlainText(item)
            }
            .accessibilityAction(named: String(localized: "Share")) {
                sharePayload = SharePayload(item: item)
            }
            .accessibilityAction(named: String(localized: "Unpin")) {
                model.unpin(item)
            }
            .accessibilityAction(named: String(localized: "Delete")) {
                model.delete(item)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            columnWidth = max(80, (width - CopyoTheme.Metrics.gridGap) / 2)
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

    // MARK: - 旁白的分享

    /// 分享面板的载荷。优先级必须和 `ClipTransferable.transferRepresentation`
    /// （`CopyoIOS/UI/ClipDragPayload.swift`）逐条对上：**PNG → RTF → URL → 纯文本**。
    /// 长按菜单的「分享」走那份声明，转子的「分享」走这里。两边不一致的后果是
    /// 同一条富文本条目时而带格式、时而不带——而且只有旁白用户会踩到，没人会来报这个。
    ///
    /// 图片与富文本都写成临时文件再递 URL，而不是直接递 `UIImage` / `Data`：
    /// `UIActivityViewController` 的 activityItems 里没有地方声明「这段 Data 是 RTF」，
    /// 不说类型的话接收方只当它是一团字节，格式照样丢。文件 URL 靠扩展名带类型，
    /// 顺手把文件名也带上了——`ClipTransferable` 的 PNG 表示正是用 `.suggestedFileName` 起的名，
    /// 而原来这里递的是 `UIImage`，存进「文件」App 会拿到一个系统随手起的名字。
    ///
    /// **仅剩的一处差别是富文本的文件名。** `ClipTransferable` 的 RTF 表示没有 `.suggestedFileName`，
    /// 名字由系统定；这里按标题起。两边的内容和类型一致，只有名字不同——
    /// 为了对齐这一点而把名字也交回给系统，不值当。
    ///
    /// 写不成就退回原来的 `UIImage` / 纯文本——少一层格式，总好过分享面板弹不出来。
    private static func activityItems(for item: ClipItem) -> [Any] {
        if item.kind == .image, let data = item.imageData {
            if let url = temporaryFile(data, named: shareFileName(for: item), pathExtension: "png") {
                return [url]
            }
            if let image = item.thumbnail { return [image] }
        }
        if item.kind == .richText, let rtf = item.rtfData,
           let url = temporaryFile(rtf, named: shareFileName(for: item), pathExtension: "rtf") {
            return [url]
        }
        if let url = item.linkURL { return [url] }
        return [item.plainText ?? item.displayTitle]
    }

    /// 与 `ClipTransferable.suggestedName` 同一套：标题前 40 字，空标题（图片就是空串）回落 `Copyo`。
    /// 多一步换掉 `/` 与 `:`——它们在文件名里是路径分隔符，在剪贴板正文里却随处可见（URL、时刻）；
    /// `ClipTransferable` 不必管这个，CoreTransferable 自己会处理。
    private static func shareFileName(for item: ClipItem) -> String {
        let title = item.displayTitle.isEmpty ? "Copyo" : String(item.displayTitle.prefix(40))
        let cleaned = title.components(separatedBy: CharacterSet(charactersIn: "/:\n\r"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Copyo" : cleaned
    }

    /// 写进 tmp 并交出 URL。同名直接覆盖：反复分享同一条只会留下一个文件，
    /// tmp 目录本来就归系统回收，不必自己排清理。
    private static func temporaryFile(_ data: Data, named name: String, pathExtension: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(pathExtension)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
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
                            .foregroundStyle(Color(hexString: hex) ?? CopyoTheme.accent)
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

/// 系统分享面板。旁白的「分享」动作只能走它：`ShareLink` 必须被点一下才会弹，
/// 辅助功能自定义动作点不了它，只能自己把 `UIActivityViewController` 端出来。
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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
///
/// 这里的字号与行高**故意**写死、不跟随动态字体：它是设计稿那张图的复刻，
/// 存在的意义就是逐像素对稿。真菜单是系统 `Menu`，字号该怎么放大怎么放大。
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
                        .fill(CopyoTheme.separator)
                        .frame(height: 0.5)
                }
            }
            Rectangle()
                .fill(CopyoTheme.menuSeparator)
                .frame(height: 8)
            row(title: PinboardMenuLabels.deleteBoard, symbol: "trash", destructive: true)
        }
        .frame(width: 230)
        // 设计的 menu token 是「86% 不透明的近白/深灰」压在 blur 上，两层顺序不能反
        .background(CopyoTheme.menu, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(CopyoTheme.glassStroke, lineWidth: 0.5)
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
        .foregroundStyle(destructive ? CopyoTheme.destructive : CopyoTheme.label)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}
#endif
