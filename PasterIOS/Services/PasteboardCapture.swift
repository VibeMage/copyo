import PasterCore
import SwiftData
import SwiftUI
import UIKit

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
               let png = image.pngData() {
                return finish(save(imagePNG: png))
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

        // 只有 URL 没有文本时才当链接读；Safari 之类两种表示都给，走文本路径由分类器判定
        if hasURLs && !hasStrings {
            guard let url = pasteboard.url else { return finish(.needsBanner) }
            IOSSettings.lastPasteboardChangeCount = changeCount
            return finish(save(text: url.absoluteString, rtfData: nil))
        }

        if hasStrings {
            guard let text = pasteboard.string else { return finish(.needsBanner) }
            IOSSettings.lastPasteboardChangeCount = changeCount
            let rtf = pasteboard.data(forPasteboardType: "public.rtf")
            return finish(save(text: text, rtfData: rtf))
        }

        guard let image = pasteboard.image else { return finish(.needsBanner) }
        IOSSettings.lastPasteboardChangeCount = changeCount
        guard let png = image.pngData() else { return finish(.empty) }
        return finish(save(imagePNG: png))
    }

    private func save(text: String, rtfData: Data?) -> Outcome {
        do {
            let result = try ClipSaver.save(text: text,
                                            rtfData: rtfData,
                                            source: .local,
                                            historyLimit: IOSSettings.historyLimit,
                                            in: context)
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
                                            in: context)
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
