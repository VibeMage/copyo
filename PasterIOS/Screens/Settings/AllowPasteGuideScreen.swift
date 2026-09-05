import SwiftUI

/// 允许从其他 App 粘贴（设计 04d）。
///
/// 设计稿的状态卡写「当前：每次询问」，但 iOS 不提供读取 `UIPasteboard` 授权状态的 API
/// （`UIPasteboard.detectPatterns` 之类都会触发弹窗），照抄会显示一个假状态。
/// 所以这里改成说明卡：只讲未设为「允许」时系统的行为，并说明 Paster 读不到当前值。
struct AllowPasteGuideScreen: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        GuideScroll {
            statusCard

            GuideParagraph(text: String(localized: "Set it to Allow and Paster reads the clipboard the moment it opens, with no prompt. This is an iOS privacy setting, so it can only be changed in Settings."))

            GroupedCard {
                GuideStepRow(1, title: String(localized: "Open Settings › Apps › Paster"))
                HairlineSeparator()
                GuideStepRow(2, title: String(localized: "Tap “Paste from Other Apps”"))
                HairlineSeparator()
                GuideStepRow(number: 3, title: String(localized: "Choose “Allow”")) {
                    optionPreview
                        .padding(.top, 6)
                }
            }

            GuidePrimaryButton(title: String(localized: "Open Paster's Settings"),
                               symbol: "arrow.up.forward.app") {
                if let url = SettingsLinks.appSettings { openURL(url) }
            }

            GuideParagraph(text: String(localized: "Until you allow it, History shows a “New clipboard content” banner at the top — use the system paste button there to save by hand."),
                           footnote: true)
        }
        .navigationTitle(String(localized: "Allow Paste from Other Apps"))
    }

    // MARK: - 状态卡

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PasterTheme.warning)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "iOS asks every time"))
                    .font(.system(size: 15))
                    .foregroundStyle(PasterTheme.label)
                Text(String(localized: "Paster can't read the current value of this setting"))
                    .font(.system(size: 13))
                    .foregroundStyle(PasterTheme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PasterTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: PasterTheme.Radius.group, style: .continuous))
    }

    // MARK: - 系统选项示意

    /// 设计 04d 第三步里嵌的三行示意，底色用页面底色以示这是「系统设置里的样子」
    private var optionPreview: some View {
        VStack(spacing: 0) {
            optionRow(String(localized: "Ask"), checked: false)
            HairlineSeparator()
            optionRow(String(localized: "Deny"), checked: false)
            HairlineSeparator()
            optionRow(String(localized: "Allow"), checked: true)
        }
        .background(PasterTheme.bgGrouped,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func optionRow(_ title: String, checked: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(PasterTheme.label)
            Spacer(minLength: 8)
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PasterTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }
}
