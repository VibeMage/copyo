import Foundation
import UIKit

/// 设置页里的外链与版本号。
enum SettingsLinks {
    static let repository = URL(string: "https://github.com/VibeMage/Paster")!

    /// 仓库私有期间用公开 Gist，与 docs/appstore-submission.md 里提交给 App Store 的隐私政策 URL 保持一致。
    /// 换成仓库内 PRIVACY.md 时两处要同时改。
    static let privacyPolicy = URL(string: "https://gist.github.com/VibeMage/d39d7165d762ecfd0f16f72ad1fc553e")!

    /// 系统「设置」里本 App 的页面。iOS 只开放这一个深链，
    /// 「操作按钮」「轻点背面」这些系统页面都跳不过去（App-prefs: 是私有 URL，用了会被拒审）。
    static var appSettings: URL? { URL(string: UIApplication.openSettingsURLString) }
}

/// 版本号显示：「1.0 (1)」
enum AppInfo {
    static var versionDisplay: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
