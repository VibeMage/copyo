import SwiftUI

/// 通用空态：图标 / 标题 / 说明 / 主按钮 / 次链接。
/// 历史空、搜索无结果、Pinboard 空、板内空都用它，保证四处的留白与字号一致。
struct EmptyState: View {
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(PasterTheme.labelTertiary)
                .padding(.bottom, 6)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PasterTheme.label)
            if let message {
                Text(message)
                    .font(PasterTheme.Fonts.subheadline)
                    .foregroundStyle(PasterTheme.labelSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 15, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.top, 4)
            }
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .font(PasterTheme.Fonts.subheadline)
                    .foregroundStyle(PasterTheme.accent)
            }
        }
        .padding(.horizontal, PasterTheme.Metrics.pageInset)
        .frame(maxWidth: .infinity)
    }
}
