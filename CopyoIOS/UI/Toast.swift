import Accessibility
import Observation
import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var symbol: String = "checkmark.circle.fill"
}

/// 轻提示的调度中心：同一时间只有一条，1.2s 后自动收起。
/// 连续操作（连点几张卡片）时后一条直接顶掉前一条，不排队——排队会让提示比动作慢好几拍。
@MainActor
@Observable
final class ToastCenter {
    private(set) var current: ToastMessage?

    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private let duration: Duration

    init(duration: Duration = .milliseconds(1200)) {
        self.duration = duration
    }

    func show(_ text: String, symbol: String = "checkmark.circle.fill") {
        dismissTask?.cancel()
        current = ToastMessage(text: text, symbol: symbol)
        announce(text)
        dismissTask = Task { [duration] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }

    /// 轻提示是这个 App 唯一的成功反馈（「已复制」「已保存」）。它只是画在屏幕上，
    /// 旁白用户复制完什么都听不到——手势成功与失败长得一模一样。
    ///
    /// 优先级取 `default`：**不**用 `low`，低优先级要等当前朗读让路，而提示只停 1.2s，
    /// 等它读到时用户早翻过去了；也**不**用 `high`，高优先级不可打断，连点几张卡片时
    /// 后一条要排在前一条读完之后，正好和 `show` 的「后一条顶掉前一条、不排队」相反。
    ///
    /// 这里**没有** `AppModel.feedback` 那道 `-demoData` 门禁：那道门是因为模拟器没有触感引擎、
    /// 截图时也不该震；而旁白没开时 `post()` 本身就是空操作，截图与演示跑的正是没开旁白的机器。
    /// `ToastCenter` 手上也没有 `LaunchOptions`，为这一句去接一份依赖不划算。
    private func announce(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .default
        AccessibilityNotification.Announcement(announcement).post()
    }
}

/// 设计 3.4：玻璃胶囊，高 40、圆角 20、顶部距安全区 6，图标 22 success 色 + 15 Semibold 文字
struct ToastOverlay: View {
    let toast: ToastMessage?

    /// 设计稿的 40 现在只是下限：默认档下图标 + 上下 6 的内距还撑不到 40，胶囊仍然是 40，
    /// 逐像素不变；字号调大后它自己长高。写死 `height` 的结果是把「已保存」上下切掉。
    @ScaledMetric(relativeTo: .subheadline) private var pillMinHeight: CGFloat = CopyoTheme.Metrics.toastHeight

    var body: some View {
        ZStack {
            if let toast {
                HStack(spacing: 6) {
                    Image(systemName: toast.symbol)
                        .font(.title2)
                        .foregroundStyle(CopyoTheme.success)
                        // 图标与文案说的是同一件事，旁白读文案就够了
                        .accessibilityHidden(true)
                    Text(toast.text)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(CopyoTheme.label)
                        .multilineTextAlignment(.center)
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .padding(.vertical, 6)
                .frame(minHeight: pillMinHeight)
                .copyoGlass(in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
        }
        .padding(.top, CopyoTheme.Metrics.toastTopInset)
        // 胶囊宽度由文案决定。「重新打开 Copyo 后生效」这种长句在放大档位下会顶出屏幕两侧，
        // 留出页边距让它折行——默认档下最长的提示也用不到这点余量，视觉不变。
        .padding(.horizontal, CopyoTheme.Metrics.pageInset)
        .animation(CopyoTheme.springAnimation, value: toast)
        // 提示只是通知，不能挡住底下的卡片
        .allowsHitTesting(false)
    }
}
