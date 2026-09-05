import SwiftUI

/// 设计 01b 的空态。插画是全 App 唯一一处品牌红蓝错位套印，
/// 所以没有复用通用的 `EmptyState`（它只画 SF Symbol）。
struct HistoryEmptyState: View {
    var onEnableSync: () -> Void
    var onHowToSave: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            illustration
                .padding(.bottom, 8)

            Text(String(localized: "No clips yet"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PasterTheme.label)

            Text(String(localized: "Anything you copy on your Mac shows up here through iCloud. To keep something from this iPhone, use Share or Quick Save."))
                .font(.system(size: 15))
                .lineSpacing(6)
                .foregroundStyle(PasterTheme.labelSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button(action: onEnableSync) {
                    HStack(spacing: 6) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 17, weight: .semibold))
                        Text(String(localized: "Turn on iCloud Sync"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(PasterTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onHowToSave) {
                    Text(String(localized: "How to save clipboard"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PasterTheme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(PasterTheme.fill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 380)
    }

    /// 96 × 96 骨白卡片：红蓝两条错位套印 + 三条正文条（尺寸逐字取自设计稿）
    private var illustration: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PasterTheme.Brand.bone)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)

            bar(width: 52, color: PasterTheme.Brand.red)
                .opacity(0.9)
                .offset(x: 20, y: 18)
            bar(width: 52, color: PasterTheme.Brand.blue)
                .opacity(0.85)
                .blendMode(.multiply)
                .offset(x: 24, y: 22)

            bar(width: 36, color: PasterTheme.Brand.ink).offset(x: 22, y: 38)
            bar(width: 52, color: PasterTheme.Brand.ink).offset(x: 22, y: 56)
            bar(width: 24, color: PasterTheme.Brand.ink).offset(x: 22, y: 74)
        }
        .frame(width: 96, height: 96)
        // 套印用 multiply，混合范围锁在这张插画里，别影响背后的分组底色
        .compositingGroup()
    }

    private func bar(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: width, height: 8)
    }
}
