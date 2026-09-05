import PasterCore
import SwiftData
import SwiftUI

/// 历史主屏（设计 01）。**当前是组件库展示页**：大标题 + 横幅 + 双列瀑布流 + 轻点复制 + 左右滑动。
/// 搜索、类型 chips、长按菜单、插入动效、空态文案由历史页代理在此基础上补齐，
/// 整文件替换也可以——外部只依赖 `HistoryScreen(kindFilter:)` 这个签名。
struct HistoryScreen: View {
    var kindFilter: ClipKind?

    @Environment(AppModel.self) private var model
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var items: [ClipItem]

    /// 单列宽度，用来估算卡片高度好分列；由下面的 onGeometryChange 量出来
    @State private var columnWidth: CGFloat = 170

    private var visibleItems: [ClipItem] {
        items.filter { KindPresentation.matches($0, filter: kindFilter ?? model.kindFilter) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PasterTheme.Metrics.gridGap) {
                if model.pasteBannerVisible {
                    PasteBanner(saved: model.pasteBannerSaved,
                                onPaste: { model.handlePasteControl(itemProviders: $0) },
                                onDismiss: { model.dismissPasteBanner() })
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if visibleItems.isEmpty {
                    EmptyState(symbol: "clock.arrow.circlepath",
                               title: String(localized: "No clips yet"),
                               message: String(localized: "Copy something on your Mac, or save from the share sheet."))
                    .padding(.top, 80)
                } else {
                    grid
                }
            }
            .padding(.horizontal, PasterTheme.Metrics.pageInset)
            .padding(.bottom, PasterTheme.Metrics.tabBarHeight + PasterTheme.Metrics.tabBarBottomInset)
        }
        .background(PasterTheme.bgGrouped)
        .navigationTitle(PasterTab.history.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SyncStatusPill(status: model.syncStatus.status, compact: true) {
                    model.selectedTab = .settings
                }
            }
        }
        .animation(PasterTheme.springAnimation, value: model.pasteBannerVisible)
    }

    private var grid: some View {
        MasonryGrid(items: visibleItems,
                    estimatedHeight: { ClipCard.estimatedHeight(for: $0, width: columnWidth, dense: false) }) { item in
            SwipeableCard(onDelete: { model.delete(item) },
                          onPin: { model.pinToDefault(item) },
                          pinEnabled: item.pinboard == nil) {
                ClipCard(item: item)
                    // 轻点即复制是这套设计的核心手势；详情页走长按菜单进
                    .onTapGesture { model.copy(item) }
                    .contextMenu {
                        Button {
                            model.copy(item)
                        } label: {
                            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                        }
                        NavigationLink {
                            ClipDetailScreen(item: item)
                        } label: {
                            Label(String(localized: "Open"), systemImage: "arrow.up.forward.square")
                        }
                        Button(role: .destructive) {
                            model.delete(item)
                        } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }
                    }
            }
        }
        // 用 onGeometryChange 量宽度而不是套 GeometryReader：后者会要求外面给一个固定高度，
        // 而瀑布流的高度只有布局跑完才知道，给错就会把最后几张卡片裁掉。
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            columnWidth = max(80, (width - PasterTheme.Metrics.gridGap) / 2)
        }
    }
}
