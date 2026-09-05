import PasterCore
import SwiftUI

/// 详情页（设计 02 / 02b）。桩：只显示卡片与来源信息，动作栏与元信息表由详情页代理补。
struct ClipDetailScreen: View {
    let item: ClipItem

    @Environment(AppModel.self) private var model

    init(item: ClipItem) {
        self.item = item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ClipCard(item: item)
                Text(verbatim: "\(item.sourceDisplayName) · \(item.absoluteTime)")
                    .font(PasterTheme.Fonts.footnote)
                    .foregroundStyle(PasterTheme.labelSecondary)
                Text(String(localized: "Detail screen placeholder"))
                    .font(PasterTheme.Fonts.footnote)
                    .foregroundStyle(PasterTheme.labelTertiary)
            }
            .padding(PasterTheme.Metrics.pageInset)
        }
        .background(PasterTheme.bgGrouped)
        .navigationTitle(item.displayTitleLocalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.copy(item)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}
