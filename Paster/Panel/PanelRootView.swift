import AppKit
import SwiftData
import SwiftUI

/// 底部面板主视图：顶栏（Pinboard 标签 + 搜索）+ 横向卡片流 + 预览浮层。
struct PanelRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var allItems: [ClipItem]
    @Query(sort: \Pinboard.sortIndex) private var pinboards: [Pinboard]

    // 截图辅助：-demoSearch <词> 预置搜索词；-demoPreview 启动即打开预览
    static let initialSearch: String = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-demoSearch"), args.indices.contains(i + 1) {
            return args[i + 1]
        }
        return ""
    }()
    static let initialPreview = ProcessInfo.processInfo.arguments.contains("-demoPreview")

    @State private var search = Self.initialSearch
    @State private var selectedPinboardID: PersistentIdentifier?
    @State private var selectedIndex = 0
    @State private var showPreview = Self.initialPreview
    @State private var showNewPinboardAlert = false
    @State private var newPinboardName = ""
    /// 从卡片右键菜单发起「新建 Pinboard」时要顺带固定的条目
    @State private var pendingPinItem: ClipItem?
    @FocusState private var searchFocused: Bool

    let onPaste: (ClipItem, _ asPlainText: Bool) -> Void
    let onClose: () -> Void

    private var visibleItems: [ClipItem] {
        let query = search
        let pinboardID = selectedPinboardID
        // 单次遍历完成分组 + 搜索过滤；localizedCaseInsensitiveContains 避免为每条记录分配小写副本
        return allItems.filter { item in
            if let pinboardID, item.pinboard?.persistentModelID != pinboardID {
                return false
            }
            guard !query.isEmpty else { return true }
            if item.plainText?.localizedCaseInsensitiveContains(query) == true { return true }
            if item.sourceAppName?.localizedCaseInsensitiveContains(query) == true { return true }
            return item.filePaths.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var selectedItem: ClipItem? {
        visibleItems[safe: selectedIndex]
    }

    var body: some View {
        let items = visibleItems
        return ZStack {
            // 截图辅助：-opaquePanel 用纯色底替代毛玻璃（无背景捕获时毛玻璃会渲染成灰条）
            if ProcessInfo.processInfo.arguments.contains("-opaquePanel") {
                Color(red: 0.078, green: 0.066, blue: 0.098)
                    .ignoresSafeArea()
            } else {
                VisualEffectView(material: .hudWindow)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
                headerBar
                cardStrip(items)
            }
            if showPreview, let item = items[safe: selectedIndex] {
                PreviewOverlay(item: item) {
                    showPreview = false
                }
            }
        }
        .onAppear { searchFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .pasterPanelDidShow)) { _ in
            // 面板每次呼出时重置状态（截图模式下重置到注入的演示状态）
            search = Self.initialSearch
            selectedIndex = 0
            showPreview = Self.initialPreview
            searchFocused = true
        }
        .onChange(of: search) { _, _ in
            selectedIndex = 0
        }
        .onChange(of: selectedPinboardID) { _, _ in
            selectedIndex = 0
        }
        .onChange(of: searchFocused) { _, focused in
            // 点击卡片/标签会让搜索框失焦，导致所有键盘快捷键失效；alert 弹出期间除外
            if !focused && !showNewPinboardAlert {
                Task { @MainActor in searchFocused = true }
            }
        }
        .onChange(of: showNewPinboardAlert) { _, showing in
            let controller = AppDelegate.shared?.panelController
            if showing {
                controller?.suppressAutoHide = true
            } else {
                controller?.suppressAutoHide = false
                controller?.makePanelKey()
                Task { @MainActor in searchFocused = true }
            }
        }
        .alert("New Pinboard", isPresented: $showNewPinboardAlert) {
            TextField("Name", text: $newPinboardName)
            Button("Create") { createPinboard() }
            Button("Cancel", role: .cancel) {
                newPinboardName = ""
                pendingPinItem = nil
            }
        } message: {
            Text("Pinboards keep the clips you use most within reach")
        }
    }

    // MARK: - 顶栏

    private var headerBar: some View {
        HStack(spacing: 8) {
            tabButton(title: String(localized: "History"), id: nil)
            ForEach(pinboards) { pinboard in
                tabButton(title: pinboard.name, id: pinboard.persistentModelID)
                    .contextMenu {
                        Button("Delete Pinboard", role: .destructive) {
                            deletePinboard(pinboard)
                        }
                    }
            }
            Button {
                openNewPinboardAlert(pinning: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help("New Pinboard")

            Spacer()

            searchField

#if APPSTORE
            // 沙盒版的同步目录必须在设置里手动选，而设置此前只能靠右键菜单栏图标
            // 才能打开——LSUIElement 应用没有应用菜单，⌘, 也不生效。
            Button {
                onClose()
                AppDelegate.shared?.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Settings")
#endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tabButton(title: String, id: PersistentIdentifier?) -> some View {
        let isSelected = selectedPinboardID == id
        return Button {
            selectedPinboardID = id
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.primary.opacity(0.14) : Color.clear,
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Type to search", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit { pasteSelected(asPlainText: false) }
                .onKeyPress(phases: .down) { press in
                    handleKeyPress(press)
                }
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 240)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 卡片流

    private func cardStrip(_ items: [ClipItem]) -> some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, item in
                                card(for: item, at: index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if let id = items[safe: newIndex]?.persistentModelID {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func card(for item: ClipItem, at index: Int) -> some View {
        CardView(item: item, isSelected: index == selectedIndex)
            .id(item.persistentModelID)
            .onTapGesture(count: 2) {
                onPaste(item, false)
            }
            .onTapGesture {
                selectedIndex = index
            }
            .onDrag { dragProvider(for: item) }
            .contextMenu {
                Button("Paste") { onPaste(item, false) }
                Button("Paste as Plain Text") { onPaste(item, true) }
                Button("Copy Only") { copyOnly(item) }
                Divider()
                if pinboards.isEmpty {
                    Button("Pin to Pinboard…") {
                        openNewPinboardAlert(pinning: item)
                    }
                } else {
                    Menu("Pin to") {
                        ForEach(pinboards) { pinboard in
                            Button(pinboard.name) {
                                item.pinboard = pinboard
                                saveContext()
                            }
                        }
                        Divider()
                        Button("New Pinboard…") {
                            openNewPinboardAlert(pinning: item)
                        }
                    }
                }
                if item.pinboard != nil {
                    Button("Unpin") {
                        item.pinboard = nil
                        saveContext()
                    }
                }
                Divider()
                Button("Delete", role: .destructive) {
                    delete(item)
                }
            }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(search.isEmpty ? "No clipboard history yet" : "Nothing matches “\(search)”")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if search.isEmpty {
                Text("Anything you copy shows up here automatically")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 键盘处理

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow:
            moveSelection(-1)
            return .handled
        case .rightArrow:
            moveSelection(1)
            return .handled
        case .upArrow, .downArrow:
            return .handled
        case .escape:
            handleEscape()
            return .handled
        case .space where search.isEmpty:
            if selectedItem != nil { showPreview.toggle() }
            return .handled
        case .delete where press.modifiers.contains(.command):
            deleteSelected()
            return .handled
        case .return where press.modifiers.contains(.option):
            pasteSelected(asPlainText: true)
            return .handled
        default:
            return .ignored
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !visibleItems.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + delta), visibleItems.count - 1)
        if showPreview { showPreview = false }
    }

    private func handleEscape() {
        if showPreview {
            showPreview = false
        } else if !search.isEmpty {
            search = ""
        } else {
            onClose()
        }
    }

    private func pasteSelected(asPlainText: Bool) {
        guard let item = selectedItem else { return }
        onPaste(item, asPlainText)
    }

    private func deleteSelected() {
        guard let item = selectedItem else { return }
        delete(item)
    }

    // MARK: - 操作

    private func saveContext() {
        // 面板挂在 LSUIElement 应用里，autosave 时机不可靠，操作后显式落盘
        try? modelContext.save()
    }

    private func delete(_ item: ClipItem) {
        modelContext.delete(item)
        saveContext()
        if selectedIndex >= max(0, visibleItems.count - 1) {
            selectedIndex = max(0, visibleItems.count - 2)
        }
    }

    private func copyOnly(_ item: ClipItem) {
        AppDelegate.shared?.pasteService.copyToPasteboard(item)
        onClose()
    }

    private func openNewPinboardAlert(pinning item: ClipItem?) {
        pendingPinItem = item
        newPinboardName = ""
        showNewPinboardAlert = true
    }

    private func createPinboard() {
        defer { pendingPinItem = nil }
        let name = newPinboardName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let pinboard = Pinboard(name: name, sortIndex: (pinboards.last?.sortIndex ?? -1) + 1)
        modelContext.insert(pinboard)
        // 从卡片右键菜单发起时，创建后顺带完成固定
        pendingPinItem?.pinboard = pinboard
        saveContext()
        newPinboardName = ""
    }

    private func deletePinboard(_ pinboard: Pinboard) {
        if selectedPinboardID == pinboard.persistentModelID {
            selectedPinboardID = nil
        }
        modelContext.delete(pinboard)
        saveContext()
    }

    private func dragProvider(for item: ClipItem) -> NSItemProvider {
        switch item.kind {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
        case .file:
            if let path = item.filePaths.first {
                let url = URL(fileURLWithPath: path)
#if APPSTORE
                // 沙盒里这些路径通常读不了。NSItemProvider(contentsOf:) 是惰性的，
                // 照样会声称能提供 public.data，接收方真去取字节时才拿到 nil ——
                // 拖拽看起来成功了，落地却是空的。读不了就只登记 file-url，
                // 让需要字节的目标当场拒绝，而不是静默吞掉内容。
                guard FileManager.default.isReadableFile(atPath: path) else {
                    return NSItemProvider(object: url as NSURL)
                }
#endif
                if let provider = NSItemProvider(contentsOf: url) {
                    return provider
                }
            }
        default:
            return NSItemProvider(object: (item.plainText ?? "") as NSString)
        }
        return NSItemProvider()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
