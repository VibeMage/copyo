import PasterCore
import SwiftUI

/// 条目详情页（设计 02 文本 / 02b 颜色，其余类型按 design-spec 3.13 的同一骨架推导）。
///
/// 骨架三段：淡染预览块（角标 + 「来源 · 相对时间」+ 正文）→ inset grouped 信息组 → 底部浮动玻璃工具栏。
/// 工具栏做成 `safeAreaInset` 而不是 `.toolbar(.bottomBar)`：设计稿里它是一枚离地 26pt 的胶囊，
/// 系统底部栏是贴边通栏的，形状对不上。
struct ClipDetailScreen: View {
    let item: ClipItem

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var showsDeleteAlert = false

    init(item: ClipItem) {
        self.item = item
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ClipDetailPreview(item: item)
                ClipDetailInfoGroup(item: item,
                                    boards: model.pinboards(),
                                    onPin: { model.pin(item, to: $0) },
                                    onUnpin: { model.unpin(item) })
            }
            .padding(.horizontal, PasterTheme.Metrics.pageInset)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(PasterTheme.bgGrouped)
        .navigationTitle(KindPresentation.label(item.kind))
        .navigationBarTitleDisplayMode(.inline)
        // 详情是全屏的一件事，浮动标签栏留在这儿会和底部工具栏叠成两条胶囊
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    menuContent
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "More"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            ClipDetailActionBar(item: item,
                                onCopy: { model.copy(item) },
                                onCopyPlainText: { model.copyPlainText(item) },
                                onTogglePin: togglePin,
                                onDelete: { showsDeleteAlert = true })
        }
        .alert(String(localized: "Delete this clip?"), isPresented: $showsDeleteAlert) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Delete"), role: .destructive, action: performDelete)
        } message: {
            Text(String(localized: "It will be removed from Paster on all your devices."))
        }
    }

    // MARK: - 右上更多菜单

    @ViewBuilder
    private var menuContent: some View {
        Button {
            model.copyPlainText(item)
        } label: {
            Label(String(localized: "Copy as Plain Text"), systemImage: "doc.plaintext")
        }

        ShareLink(item: item.transferable, preview: SharePreview(item.displayTitleLocalized)) {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
        }

        let boards = model.pinboards()
        if boards.isEmpty {
            Button {
                model.pinToDefault(item)
            } label: {
                Label(String(localized: "Pin"), systemImage: "pin")
            }
        } else {
            PinboardPickerMenu(boards: boards,
                               current: item.pinboard,
                               onSelect: { model.pin(item, to: $0) },
                               onUnpin: item.pinboard == nil ? nil : { model.unpin(item) })
        }

        Divider()

        Button(role: .destructive) {
            showsDeleteAlert = true
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
    }

    // MARK: - 动作

    private func togglePin() {
        if item.pinboard == nil {
            model.pinToDefault(item)
        } else {
            model.unpin(item)
        }
    }

    /// 先退出再删。删掉的 SwiftData 对象仍会被这一帧的 body 读到，
    /// 顺序反过来会在返回动画期间访问失效对象。
    private func performDelete() {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            model.delete(item)
        }
    }
}
