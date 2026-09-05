import PasterCore
import SwiftUI

/// 单个 Pinboard 的内容（设计 03b）。桩：双列瀑布流复用历史页的卡片组件。
struct PinboardContentScreen: View {
    let board: Pinboard

    @Environment(AppModel.self) private var model

    init(board: Pinboard) {
        self.board = board
    }

    private var items: [ClipItem] {
        (board.items ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            MasonryGrid(items: items,
                        estimatedHeight: { ClipCard.estimatedHeight(for: $0, width: 170, dense: false) }) { item in
                ClipCard(item: item)
                    .onTapGesture { model.copy(item) }
            }
            .padding(PasterTheme.Metrics.pageInset)
        }
        .background(PasterTheme.bgGrouped)
        .navigationTitle(board.name)
    }
}
