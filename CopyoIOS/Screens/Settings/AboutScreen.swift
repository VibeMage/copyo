import SwiftUI
import UIKit

/// 关于（设计稿未画，按 04 的分组风格搭）：应用标识 + 版本 + 许可 + 两条外链。
struct AboutScreen: View {

    var body: some View {
        GuideScroll(spacing: 24) {
            VStack(spacing: 12) {
                AppMark()
                Text(verbatim: "Copyo")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(CopyoTheme.label)
                Text(String(format: String(localized: "Version %@"), AppInfo.versionDisplay))
                    .font(.system(size: 15))
                    .foregroundStyle(CopyoTheme.labelSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            GuideParagraph(text: String(localized: "An open-source clipboard manager. Mac, iPhone and iPad share one history through your own iCloud account."))
                .multilineTextAlignment(.center)

            GroupedCard {
                Link(destination: SettingsLinks.repository) {
                    aboutRow(symbol: "chevron.left.forwardslash.chevron.right",
                             color: SettingsTint.code,
                             title: String(localized: "Open Source · GitHub"))
                }
                .buttonStyle(.plain)
                HairlineSeparator()
                Link(destination: SettingsLinks.privacyPolicy) {
                    aboutRow(symbol: "hand.raised.fill",
                             color: SettingsTint.hand,
                             title: String(localized: "Privacy"))
                }
                .buttonStyle(.plain)
            }

            Text(String(localized: "Released under the MIT License."))
                .font(.system(size: 13))
                .foregroundStyle(CopyoTheme.labelTertiary)
                .frame(maxWidth: .infinity)
        }
        .navigationTitle(String(localized: "About"))
    }

    private func aboutRow(symbol: String, color: Color, title: String) -> some View {
        HStack(spacing: 12) {
            SettingsIconTile(symbol: symbol, color: color)
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(CopyoTheme.label)
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 15))
                .foregroundStyle(CopyoTheme.labelTertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }
}

/// 应用标识。
///
/// 图标本身在 AppIcon.appiconset 里，但 iOS 的 App 图标不保证能按名字从资源目录取出来
/// （只有一张 universal 1024 时尤其容易取不到），所以取不到就现画品牌标记：
/// 骨白卡片上一红一蓝两条错位色条，与空态、引导页用的是同一套品牌元素。
private struct AppMark: View {
    private static let bundleIcon: UIImage? = {
        if let image = UIImage(named: "AppIcon") { return image }
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let last = files.last
        else { return nil }
        return UIImage(named: last)
    }()

    var body: some View {
        Group {
            if let icon = Self.bundleIcon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                BrandMark()
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// 品牌标记：骨白底 + 红蓝错位色条（设计 01b 空态插画的同一构件，按 88pt 等比缩过）
private struct BrandMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            CopyoTheme.Brand.bone
            ZStack {
                Capsule()
                    .fill(CopyoTheme.Brand.red)
                    .frame(width: 48, height: 8)
                    .opacity(0.9)
                    .offset(x: -2, y: -2)
                Capsule()
                    .fill(CopyoTheme.Brand.blue)
                    .frame(width: 48, height: 8)
                    .opacity(0.85)
                    .offset(x: 2, y: 2)
                    .blendMode(colorScheme == .dark ? .screen : .multiply)
            }
            .compositingGroup()
        }
    }
}
