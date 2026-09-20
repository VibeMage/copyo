import CopyoCore
import SwiftUI

/// 硬件键盘按空格时的快速预览（设计四节的「空格 Quick Look」）。
///
/// 没有走 `.quickLookPreview`：那个要一个真实的文件 URL，
/// 而历史条目大多只是内存里的一段文字或一份 PNG，为了预览先落盘不值当。
struct ClipPreviewSheet: View {
    let item: ClipItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        KindBadge(item: item)
                        Text(verbatim: "\(item.sourceDisplayName) · \(item.absoluteTime)")
                            .font(CopyoTheme.Fonts.meta)
                            .foregroundStyle(CopyoTheme.labelSecondary)
                    }
                    body(for: item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CopyoTheme.Metrics.pageInset)
            }
            .background(CopyoTheme.bgGrouped)
            .navigationTitle(item.displayTitleLocalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func body(for item: ClipItem) -> some View {
        switch item.kind {
        case .image:
            if let image = item.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous))
                    // 没有标签的 `Image` 旁白会整个跳过，这一屏就只剩标题可读了
                    .accessibilityLabel(String(localized: "Image"))
                if let meta = item.imageMetadata {
                    Text(meta)
                        .font(CopyoTheme.Fonts.footnote)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
            }
        case .color:
            RoundedRectangle(cornerRadius: CopyoTheme.Radius.inner, style: .continuous)
                .fill(item.colorValue ?? CopyoTheme.fill)
                // 纯色块，不是文字盒子，160 保持写死
                .frame(height: 160)
            Text(item.displayBody)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
        default:
            // 和详情页同一套分块：这一屏同样是普通 `ScrollView`，一条十万字的条目
            // 按空格就是一次整串排版。不改成「只取前 N 字」的截断——
            // 快速预览是用来判断「是不是这一条」的，悄悄少掉后半段而又不告诉用户，
            // 比多写一行分块糟得多。
            ChunkedText(text: item.displayBody)
                .font(item.isMono ? CopyoTheme.Fonts.cardMono(dense: false) : CopyoTheme.Fonts.body)
                .foregroundStyle(CopyoTheme.label)
                .textSelection(.enabled)
        }
    }
}
