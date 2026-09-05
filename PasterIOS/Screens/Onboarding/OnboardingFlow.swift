import SwiftUI

/// 首启动引导（设计 05a/b/c）。桩：三页翻页 + 完成回调，插图与逐行说明由引导代理补。
struct OnboardingFlow: View {
    var startPage: Int = 0
    var onFinish: () -> Void

    @State private var page: Int

    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.startPage = startPage
        self.onFinish = onFinish
        _page = State(initialValue: startPage)
    }

    private let titles = [
        String(localized: "Your Mac clipboard, in your pocket"),
        String(localized: "Three ways to save from this iPhone"),
        String(localized: "Two switches and you're set"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(titles[min(page, titles.count - 1)])
                .font(PasterTheme.Fonts.title1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                if page < titles.count - 1 {
                    withAnimation(PasterTheme.springAnimation) { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < titles.count - 1 ? String(localized: "Continue") : String(localized: "Get Started"))
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Button(String(localized: "Skip"), action: onFinish)
                .font(PasterTheme.Fonts.subheadline)
                .foregroundStyle(PasterTheme.labelSecondary)
        }
        .padding(PasterTheme.Metrics.pageInset)
        .padding(.bottom, 16)
        .background(PasterTheme.bgGrouped)
    }
}
