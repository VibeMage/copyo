import Accessibility
import Observation
import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    /// 提示的语义。原来所有图标都固定染成成功绿，连「无法保存」的警告三角也是绿的（Codex 复盘 F）
    enum Kind: Equatable {
        case success, info, warning

        var color: Color {
            switch self {
            case .success: CopyoTheme.success
            case .info: CopyoTheme.labelSecondary
            case .warning: CopyoTheme.warning
            }
        }
    }

    let id = UUID()
    var text: String
    var symbol: String = "checkmark.circle.fill"
    var kind: Kind = .success
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

    /// - Parameter sticky: 不自动收起。只给截图路由用（设计 01d 要拍的就是「已保存」这一帧，
    ///   1.2s 后才截图的话提示早没了），真实链路一律走默认值。
    func show(_ text: String, symbol: String = "checkmark.circle.fill",
              kind: ToastMessage.Kind = .success, sticky: Bool = false) {
        dismissTask?.cancel()
        current = ToastMessage(text: text, symbol: symbol, kind: kind)
        announce(text)
        guard !sticky else {
            dismissTask = nil
            return
        }
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
    /// 不画提示、只让旁白说一句。自动读取存下内容时屏幕上的反馈是新卡片的高亮（不再弹「已保存」，
    /// 见 `AppModel.handle`），而高亮旁白听不到——视觉上安静了，旁白用户不能跟着什么都听不到
    func announce(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .default
        AccessibilityNotification.Announcement(announcement).post()
    }
}

/// 设计 3.4 的玻璃胶囊（高 40、圆角 20、图标 22 + 15 Semibold 文字），**但放在底部**、标签栏上方。
///
/// 设计稿放在顶部安全区下 6pt——正好是 iOS 系统「粘贴自 X」横幅出现的位置。App 读剪贴板时
/// 系统通常会在那里显示那条横幅（设成「允许」也会，App 关不掉），真机上两者叠在一起，
/// 再加上右上角胶囊为提示让位，顶部一次粘贴要变四五回。挪到底部之后，顶部只归系统横幅与
/// 同步胶囊，两边各说各的（维护者 2026-09-27 真机反馈 + Codex 复盘）。
struct ToastOverlay: View {
    let toast: ToastMessage?

    /// 「减弱动态效果」下只淡入淡出，不从底部滑上来
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 设计稿的 40 现在只是下限：默认档下图标 + 上下 6 的内距还撑不到 40，胶囊仍然是 40，
    /// 逐像素不变；字号调大后它自己长高。写死 `height` 的结果是把「已保存」上下切掉。
    @ScaledMetric(relativeTo: .subheadline) private var pillMinHeight: CGFloat = CopyoTheme.Metrics.toastHeight

    private static let bottomClearance: CGFloat = 64 + 26 + 12

    var body: some View {
        ZStack {
            if let toast {
                HStack(spacing: 6) {
                    Image(systemName: toast.symbol)
                        .font(.title2)
                        .foregroundStyle(toast.kind.color)
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
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
            }
        }
        // 从屏幕物理底边往上量：标签栏高 64、底距 26（设计 2.3），再留 12 的空隙。
        // 详情页底部的操作条、iPad 底部的快捷键提示都在这个高度以下。只忽略**容器**安全区，
        // 键盘弹出时（搜索中）仍会被顶到键盘上方，不会藏在键盘后面
        .padding(.bottom, Self.bottomClearance)
        .ignoresSafeArea(.container, edges: .bottom)
        // 胶囊宽度由文案决定。「重新打开 Copyo 后生效」这种长句在放大档位下会顶出屏幕两侧，
        // 留出页边距让它折行——默认档下最长的提示也用不到这点余量，视觉不变。
        .padding(.horizontal, CopyoTheme.Metrics.pageInset)
        .animation(CopyoTheme.springAnimation, value: toast)
        // 提示只是通知，不能挡住底下的卡片
        .allowsHitTesting(false)
    }
}
