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
}

/// 设计 3.4：玻璃胶囊，高 40、圆角 20、顶部距安全区 6，图标 22 success 色 + 15 Semibold 文字
struct ToastOverlay: View {
    let toast: ToastMessage?

    var body: some View {
        ZStack {
            if let toast {
                HStack(spacing: 6) {
                    Image(systemName: toast.symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(PasterTheme.success)
                    Text(toast.text)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PasterTheme.label)
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .frame(height: PasterTheme.Metrics.toastHeight)
                .pasterGlass(in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(toast.id)
            }
        }
        .padding(.top, PasterTheme.Metrics.toastTopInset)
        .animation(PasterTheme.springAnimation, value: toast)
        // 提示只是通知，不能挡住底下的卡片
        .allowsHitTesting(false)
    }
}
