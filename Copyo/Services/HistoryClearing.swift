import CopyoCore
import Foundation
import SwiftData

/// 「清空历史」的删除逻辑，菜单栏的 `NSAlert` 与设置 · 历史页的 `.confirmationDialog` 共用这一份。
///
/// 两个入口的确认框保留各自的原生形态（第八节第 21 条），但删什么、删完清不清缩略图缓存
/// 只能有一处说了算（7.5.15）：此前两份各写一遍，设置页那份在 fetch 失败时连缓存都不清，
/// 已经悄悄分叉过一次。
enum HistoryClearing {
    /// 删掉所有没固定到 Pinboard 的条目。已固定的条目与 Pinboard 本身都保留——
    /// 要连它们一起删走「删除所有数据」。
    @MainActor
    static func clearUnpinned(in context: ModelContext) {
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.pinboard == nil })
        if let items = try? context.fetch(descriptor) {
            for item in items {
                context.delete(item)
            }
            try? context.save()
        }
        // 条目删了，缩略图就不该还留在内存里；fetch 失败时也照清，代价最多是重新解码一次
        ThumbnailCache.removeAll()
    }
}
