import AppKit
import SwiftUI

// MARK: - 关于

/// 关于页：居中品牌图 + 名字 + 两句说明，底下一组「版本」行（v2 `Settings-history.dc.html` 右窗）。
/// 第八节第 43 条：沿用单段文字，不另开隐私说明二级页。
struct AboutView: View {
    /// 说明里要印当前快捷键；页面每次切进来都会重建，改完快捷键回来就是新值
    @State private var hotkeyDisplay = HotkeyConfig.load().displayString
    /// 探测出当前组合按下去 Copyo 收不到时，第一句不再教用户按它（7.5.1，与菜单栏、面板空态同一口径）
    @State private var hotkeyWorks = (AppDelegate.shared?.hotkeyStatus ?? .active) == .active

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                // 画板上是空态插画那块骨白卡。这里直接用 App 图标：第八节第 27 条把品牌红蓝
                // 限定在 App 图标与空态插画上，设置页再自绘一份等于多开一个品牌出口
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                Text(verbatim: "Copyo")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(CopyoTheme.label)
                    .padding(.top, 4)
                // 两句是对外承诺（design-spec §04c：改动需同步改隐私说明）
                VStack(spacing: 0) {
                    if hotkeyWorks {
                        Text("Everything you’ve copied is here. Press \(hotkeyDisplay) to get it back anytime.")
                    } else {
                        Text("Everything you’ve copied is here.")
                    }
                    Text("Your history lives only on this Mac and in the sync location you choose. Copyo collects no data.")
                }
                .font(.system(size: 12))
                .lineSpacing(4)
                .foregroundStyle(CopyoTheme.labelMeta)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 380)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            SettingsGroup {
                SettingsRow(title: Text("Version"),
                            lead: { SettingsTile(hex: "#30B0C7", symbol: "info.circle") },
                            trailing: {
                                SettingsValue(verbatim: version)
                                    .textSelection(.enabled)
                            })
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
    }
}
