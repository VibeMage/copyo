import CopyoCore
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 采集通道 A：回到前台读一次剪贴板。
///
/// iOS 上没有后台监听：系统只允许应用在前台、且用户在「从其他 App 粘贴」里选了「允许」时静默读取。
/// 设为「询问」会弹系统确认框，用户拒绝就读到 nil——这时退回横幅（通道 A 的兜底，走 UIPasteControl）。
@MainActor
final class PasteboardCapture {

    enum Outcome {
        /// changeCount 没变，剪贴板还是上次那份
        case unchanged
        case saved(ClipItem)
        /// 命中去重：内容已经在历史里，被提到了最前
        case duplicate(ClipItem)
        /// 需要显示横幅：用户关了自动读取，或系统弹窗被拒绝
        case needsBanner
        /// 剪贴板里没有能存的东西
        case empty
        case failed(Error)
    }

    private let context: ModelContext

    /// 每次采集的结果都会回调一次，AppModel 据此发轻提示 / 亮横幅
    var onOutcome: ((Outcome) -> Void)?

    /// 正在回调的这条结果是不是**用户明确动作**触发的（一键保存、横幅上的粘贴按钮）。
    /// 通道 A 的例行采集读到空剪贴板或重复内容时不该打扰用户；
    /// 通道 C 必须给反馈——用户刚按下控件，屏幕上什么都不发生就等于失败。
    private(set) var lastOutcomeWasExplicit = false

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 通道 A：回到前台

    @discardableResult
    func checkOnForeground() -> Outcome {
        let changeCount = UIPasteboard.general.changeCount
        // 首次运行没有记账。这时**只记账不读取**——`nil != changeCount` 恒为真，
        // 照原样放行的话安装后第一次打开就会去读剪贴板（弹系统「想从 X 粘贴」，
        // 或在「允许」下静默把用户手上不相干的内容存进历史）。
        // IOSSettings 里 lastPasteboardChangeCount 的注释写的就是这条契约。
        guard let lastChangeCount = IOSSettings.lastPasteboardChangeCount else {
            IOSSettings.lastPasteboardChangeCount = changeCount
            return finish(.unchanged)
        }
        guard lastChangeCount != changeCount else {
            return finish(.unchanged)
        }
        guard IOSSettings.autoReadOnForeground else {
            // 这里**不**更新 changeCount：用户点横幅上的粘贴按钮时还要靠它判断是不是同一份内容
            return finish(.needsBanner)
        }
        return capture(changeCount: changeCount)
    }

    // MARK: - 通道 C：一键保存把 App 拉到前台后

    /// 用户主动按了按钮，即使关了「回到前台自动读取」也照读；
    /// changeCount 相同也照读一遍，用户可能就是想把手上这份再存一次。
    @discardableResult
    func captureNow() -> Outcome {
        lastOutcomeWasExplicit = true
        defer { lastOutcomeWasExplicit = false }
        return capture(changeCount: UIPasteboard.general.changeCount)
    }

    // MARK: - 横幅上的系统粘贴按钮

    /// UIPasteControl 交回来的 itemProvider。走这条路不需要任何权限——
    /// 用户亲手点了系统按钮，等于一次性授权。
    func save(itemProviders: [NSItemProvider]) async -> Outcome {
        // 无论存没存成，这一份剪贴板都算「已经处理过」：
        // UIPasteControl 走的是 itemProvider 通道，UIPasteboard 的 changeCount 一点没变，
        // 不记账的话下次回前台还会当成新内容再弹一次横幅（或再弹一次系统授权框）。
        defer { markSeen() }
        lastOutcomeWasExplicit = true
        defer { lastOutcomeWasExplicit = false }
        for provider in itemProviders {
            if provider.canLoadObject(ofClass: UIImage.self),
               let image = await loadObject(UIImage.self, from: provider),
               let prepared = ClipImagePreparer.prepare(image: image) {
                return finish(save(imagePNG: prepared.png))
            }
            // 用 NSURL / NSString 而不是 URL / String：NSItemProviderReading 是 Objective-C 协议，
            // Swift 值类型只有桥接重载，泛型里对不上
            if provider.canLoadObject(ofClass: NSURL.self),
               let url = await loadObject(NSURL.self, from: provider) {
                return finish(save(text: (url as URL).absoluteString, rtfData: nil))
            }
            if provider.canLoadObject(ofClass: NSString.self),
               let text = await loadObject(NSString.self, from: provider) {
                return finish(save(text: text as String, rtfData: nil))
            }
        }
        return finish(.empty)
    }

    // MARK: - 剪贴板写回后的同步

    /// 我们自己往剪贴板里写了东西（用户点卡片复制）之后调用，
    /// 否则下次回到前台会把刚复制出去的内容再存一遍。
    func markSeen() {
        IOSSettings.lastPasteboardChangeCount = UIPasteboard.general.changeCount
    }

    // MARK: - 内部

    private func capture(changeCount: Int) -> Outcome {
        let pasteboard = UIPasteboard.general
        // has* 这几个属性不会触发系统弹窗，只有真的取值才会；先用它们决定读什么，少弹一次窗
        let hasURLs = pasteboard.hasURLs
        let hasStrings = pasteboard.hasStrings
        let hasImages = pasteboard.hasImages
        guard hasURLs || hasStrings || hasImages else {
            IOSSettings.lastPasteboardChangeCount = changeCount
            return finish(.empty)
        }

        // 取值读到 nil = 用户在系统弹窗里点了「不允许」。这时**也要记账**：不记的话 changeCount
        // 永远对不上，之后每回一次前台都会再读一次、再弹一次授权框，拒绝一次等于被纠缠到底。
        // 横幅照样亮（`.needsBanner`），而横幅上的 UIPasteControl 不依赖 changeCount。
        func denied() -> Outcome {
            IOSSettings.lastPasteboardChangeCount = changeCount
            return finish(.needsBanner)
        }

        // 只有 URL 没有文本时才当链接读；Safari 之类两种表示都给，走文本路径由分类器判定
        if hasURLs && !hasStrings {
            guard let url = timedRead({ pasteboard.url }) else { return denied() }
            IOSSettings.lastPasteboardChangeCount = changeCount
            return finish(save(text: url.absoluteString, rtfData: nil))
        }

        if hasStrings {
            guard let text = timedRead({ pasteboard.string }) else { return denied() }
            IOSSettings.lastPasteboardChangeCount = changeCount
            let rtf = pasteboard.data(forPasteboardType: "public.rtf")
            return finish(save(text: text, rtfData: rtf))
        }

        // 图片先拿原始字节交给 ImageIO 缩到 2048 边长再转 PNG（与分享扩展同一条路）。
        // 直接 `pasteboard.image` + `pngData()` 是在主线程上全尺寸解码再全尺寸编码，
        // 一张 5K 截图就是几十 MB 内存加一次明显的卡顿，存进库里的也是全尺寸原图
        // 先用 `types`（只是元数据，不触发授权框）挑出实际存在的那一种编码，只取一次值——
        // 挨个 `data(forPasteboardType:)` 试过去，在「询问」模式下可能连弹好几次框
        let encodedTypes = [UTType.png, .jpeg, .heic].map(\.identifier)
        let prepared: ClipImagePreparer.Prepared?
        if let type = pasteboard.types.first(where: encodedTypes.contains) {
            guard let imageData = pasteboard.data(forPasteboardType: type) else { return denied() }
            prepared = ClipImagePreparer.prepare(data: imageData)
        } else {
            guard let image = pasteboard.image else { return denied() }
            prepared = ClipImagePreparer.prepare(image: image)
        }
        IOSSettings.lastPasteboardChangeCount = changeCount
        guard let prepared else { return finish(.empty) }
        return finish(save(imagePNG: prepared.png))
    }

    // MARK: - 有没有弹「允许粘贴」

    /// 读剪贴板内容，并顺手记下这次有没有弹「允许粘贴」。
    ///
    /// iOS 没有任何 API 能问出「从其他 App 粘贴」设成了什么。但弹框时这次取值会**一直阻塞到用户点完**
    /// （系统的 pasted 进程为此专门关掉看门狗：「Prevent watchdog termination while blocking on OOP
    /// authorization」），设成「允许」时则直接返回——所以量一下耗时就知道。据此在**连续**弹过几次之后
    /// 提示用户去设成「允许」，改了之后下一次读取变快，提示自己消失（`AppModel.allowPasteTipVisible`）。
    ///
    /// 慢不一定是弹框：Mac 通用剪贴板（Handoff）的内容要在取值时跨设备拉，大一点的富文本就可能过阈值；
    /// 延迟提供数据的来源 App 也会让读取等一会儿。所以三条防线：
    /// - 阈值取 0.8s：人看到弹框、读完、点下去不会更快，偶发的慢读多数落在它之下
    /// - 计**连续**次数：任何一次快速成功的读取都清零，「允许」的用户偶尔慢一次不会累积
    /// - 只有「慢且读到了」才算：弹框后点了「不允许」的人不该被劝去点允许
    /// **只量文字与链接**：从别的 App 跨进程取一张大图本身就可能很慢。
    private func timedRead<T>(_ read: () -> T?) -> T? {
        let start = ContinuousClock.now
        let value = read()
        let slow = ContinuousClock.now - start >= .milliseconds(800)
        if slow, value != nil {
            IOSSettings.lastPasteReadPrompted = true
            IOSSettings.promptedPasteReads += 1
        } else {
            // 快速成功 = 已经是「允许」；快速 nil = 设成了「拒绝」；慢且 nil = 弹框里点了「不允许」。
            // 三种都不该亮提示
            IOSSettings.lastPasteReadPrompted = false
            if !slow, value != nil { IOSSettings.promptedPasteReads = 0 }
        }
        return value
    }

    /// 通道 A / C 的入库出口。Core Spotlight 索引挂在这里而不是 `ClipSaver`：
    /// `CopyoCore` 是跨平台代码，Mac 端不做系统索引。
    /// `.refreshed`（命中去重）也照样重索引——那一支原地改了 `createdAt` 与富文本表示。
    private func save(text: String, rtfData: Data?) -> Outcome {
        do {
            let result = try ClipSaver.save(text: text,
                                            rtfData: rtfData,
                                            source: .local,
                                            historyLimit: IOSSettings.historyLimit,
                                            in: context,
                                            onEvicted: { SpotlightIndexer.remove($0) })
            SpotlightIndexer.index(result.item)
            return outcome(for: result)
        } catch ClipSaverError.emptyContent {
            return .empty
        } catch {
            return .failed(error)
        }
    }

    private func save(imagePNG: Data) -> Outcome {
        do {
            let result = try ClipSaver.save(imagePNG: imagePNG,
                                            source: .local,
                                            historyLimit: IOSSettings.historyLimit,
                                            in: context,
                                            onEvicted: { SpotlightIndexer.remove($0) })
            SpotlightIndexer.index(result.item)
            return outcome(for: result)
        } catch ClipSaverError.emptyContent {
            return .empty
        } catch {
            return .failed(error)
        }
    }

    private func outcome(for result: SaveResult) -> Outcome {
        result.isNew ? .saved(result.item) : .duplicate(result.item)
    }

    @discardableResult
    private func finish(_ outcome: Outcome) -> Outcome {
        onOutcome?(outcome)
        return outcome
    }

    private func loadObject<T: NSItemProviderReading>(_ type: T.Type, from provider: NSItemProvider) async -> T? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: type) { object, _ in
                continuation.resume(returning: object as? T)
            }
        }
    }
}
