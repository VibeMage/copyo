import SwiftUI

/// 设计 01b 的空态。插画是全 App 唯一一处品牌红蓝错位套印，
/// 所以没有复用通用的 `EmptyState`（它只画 SF Symbol）。
struct HistoryEmptyState: View {
    /// 同步没开成时才给「开启 iCloud 同步」。同步默认就是开的，这时再摆一颗「开启」按钮，
    /// 点下去只是落到设置页、什么也没打开——第一次打开应用的人（包括审核员）看到的就是这一屏
    var showsEnableSync: Bool
    var onEnableSync: () -> Void
    var onHowToSave: () -> Void

    /// 两颗胶囊按钮里装的是整句译文（法语的「Comment enregistrer le presse-papiers」最长）。
    /// 50 写死会在放大档位下把文字上下切掉，所以它只当下限：
    /// 默认档是 body 行高 22 + 2 × 14 的内距 = 50，逐像素不变。
    @ScaledMetric(relativeTo: .body) private var buttonMinHeight: CGFloat = 50

    var body: some View {
        VStack(spacing: 14) {
            illustration
                .padding(.bottom, 8)

            Text(String(localized: "No clips yet"))
                .font(CopyoTheme.Fonts.title2)
                .foregroundStyle(CopyoTheme.label)

            Text(message)
                .font(CopyoTheme.Fonts.subheadline)
                // 设计 01b 是 15/21：subheadline 自然行高约 18，只补 3
                .lineSpacing(3)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                if showsEnableSync {
                    Button(action: onEnableSync) {
                        HStack(spacing: 6) {
                            // 设计 01b 是描边的云；实心的 icloud.fill 属于设置页的 iCloud 图标砖
                            Image(systemName: "icloud")
                                .font(.system(.body, weight: .regular))
                            Text(String(localized: "Turn on iCloud Sync"))
                                .font(.system(.body, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .frame(minHeight: buttonMinHeight)
                        .background(CopyoTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onHowToSave) {
                    // 与设置页那一行、指引页标题同一个键：同一个去处在英文里只有一个名字
                    Text(String(localized: "How Copyo Saves Clips"))
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(CopyoTheme.accent)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .frame(minHeight: buttonMinHeight)
                        .background(CopyoTheme.fill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        // 设计 01b 的正文与按钮宽 352（440 画布减去两侧 20 + 24）。
        // 原来先加内距再封顶 380，内容只剩 332，按钮比设计窄一截
        .frame(maxWidth: 352)
        .padding(.horizontal, 24)
    }

    /// 正文里「这台设备」按实际设备说：iPad 上写「this iPhone / 手机上」是错的
    private var message: String {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return String(localized: "Anything you copy on your Mac shows up here through iCloud. To keep something from this iPad, use Share or Quick Save.")
        }
        return String(localized: "Anything you copy on your Mac shows up here through iCloud. To keep something from this iPhone, use Share or Quick Save.")
    }

    /// 96 × 96 骨白卡片：红蓝两条错位套印 + 三条正文条（尺寸逐字取自设计稿）
    private var illustration: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CopyoTheme.Brand.bone)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 8)

            bar(width: 52, color: CopyoTheme.Brand.red)
                .opacity(0.9)
                .offset(x: 20, y: 18)
            bar(width: 52, color: CopyoTheme.Brand.blue)
                .opacity(0.85)
                .blendMode(.multiply)
                .offset(x: 24, y: 22)

            bar(width: 36, color: CopyoTheme.Brand.ink).offset(x: 22, y: 38)
            bar(width: 52, color: CopyoTheme.Brand.ink).offset(x: 22, y: 56)
            bar(width: 24, color: CopyoTheme.Brand.ink).offset(x: 22, y: 74)
        }
        .frame(width: 96, height: 96)
        // 套印用 multiply，混合范围锁在这张插画里，别影响背后的分组底色
        .compositingGroup()
        // 纯装饰的品牌插画：尺寸逐字取自设计稿、不跟随字号，也没有旁白能读的信息
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: width, height: 8)
    }
}
