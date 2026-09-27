import SwiftUI

/// 读不到剪贴历史时占住正文区的那一屏。
///
/// **底排功能键仍然在屏幕上**——它不归本视图管，由 `KeyboardRootView` 画在下面。
/// 这件事是这一态能通过 4.4.1 的关键：指南要求键盘在没有开启「完全访问」时仍然可用，
/// 而用户此刻按面板切换键就能拿到能打字的三排键（见 `LetterPlane`）。
/// 把这一屏做成整块键盘的全部，就是照着设计 07b 画出一次必然的拒绝。
struct ClipsUnavailableView: View {

    /// 为什么读不到。两种情形的下一步完全不同，文案必须分开
    enum Reason {
        /// 够不着 App Group 容器 —— 设计 07b。判据见 `KeyboardClipStore.reload()`
        case needsFullAccess
        /// 容器够得着，但库打不开或读不出来
        case libraryUnreadable
    }

    let reason: Reason
    /// 外观。理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme

    /// 图标与文字之间的间距
    var spacing: CGFloat = 8

    var body: some View {
        // 字号放大档位下这三行一定超出正文区的高度（键盘总高被钉在 330，正文区分不到更多）。
        // 超出就得能滚，否则底下那句「怎么开」被切掉，用户拿不到任何可执行的下一步
        ScrollView {
            VStack(spacing: spacing) {
                Image(systemName: symbolName)
                    // 设计 07b 的锁 28pt → 契约里的 `.title`
                    .font(.title)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                Text(title)
                    // 设计 07b 标题 15/600 → `.subheadline` + semibold
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CopyoTheme.label)
                Text(message)
                    // 设计 07b 正文 13/18 → `.footnote`
                    .font(.footnote)
                    .foregroundStyle(CopyoTheme.labelSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, CopyoTheme.Metrics.cardPad)
            .padding(.vertical, spacing)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityElement(children: .combine)
    }

    /// 设计第五节：键盘未授权 = `lock.fill`。
    /// 「库读不出来」那一档设计稿里没有帧、也没有指定符号，用通用的警告三角，
    /// 已记进 design-spec 第八节
    private var symbolName: String {
        switch reason {
        case .needsFullAccess: "lock.fill"
        case .libraryUnreadable: "exclamationmark.triangle.fill"
        }
    }

    private var title: String {
        switch reason {
        case .needsFullAccess: String(localized: "Full Access is required to show your history")
        case .libraryUnreadable: String(localized: "Can't read your clips right now")
        }
    }

    /// 设计 07b 那句原文的主语是整个应用。这里**收窄了主语**：
    /// Copyo 这个应用是联网的（CloudKit 私有数据库 + APNs 静默通知），
    /// 那句话按字面讲是假的——仓库里已经有一次专门的提交在修同一类过度承诺
    /// （`stop claiming the app makes no network requests`）。
    /// 收窄成「Copyo 键盘」之后它才是真的：这个进程里没有任何一行网络代码，
    /// entitlement 里只有 App Group，而键盘全程只读库、从不读也不记宿主输入框里的内容。
    /// 已记进 design-spec 第八节等待设计确认。
    private var message: String {
        switch reason {
        case .needsFullAccess:
            String(localized: "Settings › General › Keyboard › Keyboards › Copyo. The Copyo keyboard never goes online, and never records what you type.")
        case .libraryUnreadable:
            String(localized: "Open Copyo once, then come back.")
        }
    }
}
