import Foundation

/// 这一版的包里到底带没带键盘扩展。
///
/// 键盘是 Phase 2 的东西，**iOS 首个版本（1.1.0）不随包发布**（见 docs/ios-plan.md 3.6）：
/// `CopyoKeyboard` target 还在工程里、CI 也照编，但它不是 `Copyo iOS` 的依赖，
/// 也不在「Embed Foundation Extensions」里，所以出的包里没有 `CopyoKeyboard.appex`。
///
/// 设置页那一行与 04e 引导页都要按这个值决定出不出现——包里没有键盘却留着那一行，
/// 就是一步步教用户去「添加新键盘…」里找一个不存在的东西。
///
/// **为什么按包内实际情况判，而不是留一个常量开关：** 开关要靠人记得翻，而两种忘法都难被发现——
/// 发键盘时忘了打开，用户压根找不到入口；不发时忘了关掉，设置里多一行做不到的事。
/// 读 appex 是自洽的：哪天把 embed 挂回去，这一行自己就回来了，不需要有人想起来。
enum KeyboardExtension {

    /// 扩展的 bundle 标识。与 project.pbxproj 里 `CopyoKeyboard` 三个配置的
    /// `PRODUCT_BUNDLE_IDENTIFIER` **逐字一致**；对不上的表现是这一行永远不出现，
    /// 不报错也不崩溃，所以改 bundle id 时两处要一起改。
    static let bundleIdentifier = "dev.vibemage.Copyo.Keyboard"

    /// 包里有没有这个扩展。
    ///
    /// 走 `builtInPlugInsURL` 列目录而不是 `Bundle(identifier:)`：后者只认**已经加载过**的 bundle，
    /// 而扩展跑在别的进程里，主应用这边永远不会加载它，那样判永远是假。
    ///
    /// 结果缓存成 `static let`：包内容在进程存活期间不会变，而设置页每次重画都会读它。
    static let isBundled: Bool = {
        guard let plugIns = Bundle.main.builtInPlugInsURL,
              let contents = try? FileManager.default.contentsOfDirectory(at: plugIns,
                                                                          includingPropertiesForKeys: nil)
        else { return false }
        return contents.contains { url in
            guard url.pathExtension == "appex" else { return false }
            return Bundle(url: url)?.bundleIdentifier == bundleIdentifier
        }
    }()
}
