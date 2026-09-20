import SwiftUI
import UIKit

/// 系统键盘列表里的「Copyo」。
///
/// 类名被 `Info.plist` 的 `NSExtensionPrincipalClass` 引用，改名要同步改 plist——
/// 对不上的表现是切到本键盘时宿主只出现一块空白，控制台一句提示都没有。
///
/// 这里只负责五件事：把高度钉住、把 SwiftUI 挂上去、决定深浅、把按键接到宿主输入框、
/// 在每次出现时重读一遍共享库。界面本身全在 `KeyboardRootView` 里。
///
/// **本进程从不写共享库。** 读取端是 `KeyboardClipStore`，它以只读方式打开容器，
/// 理由写在那里与 `CopyoStore.makeContainer(url:cloudKit:allowsSave:)`。
final class KeyboardViewController: UIInputViewController {

    // MARK: - 尺寸

    /// 设计 07 的键盘总高。输入视图**没有固有高度**，不自己钉一条约束的话系统会给一块
    /// 几乎为零的高度，键一颗都看不见
    private static let keyboardHeight: CGFloat = 330

    /// 上面那 330 里最底下留给 Home 指示条的一条（设计 07 底排的 `padding-bottom:40`）。
    /// 系统若已经把这一条报进 `view.safeAreaInsets.bottom`，报多少就从这 40 里扣多少；
    /// 报 0 就整条自己补——两种情形下底排离屏幕底边都是 40，见 `KeyboardRootView.bottomPadding`。
    /// 不扣的那种写法是两头各留一次，底排会被顶高一截，换行键离底边差不多有两指宽。
    /// 不是 `fileprivate`：`KeyboardRootView` 已经搬到自己的文件里，而这个数只该有一个出处
    static let homeIndicatorStrip: CGFloat = 40

    // MARK: - 状态

    /// SwiftUI 那棵树的三个外部输入。打包成一个值只为了能整体比较，见 `refresh()`
    private struct Inputs: Equatable {
        var scheme: ColorScheme
        var needsGlobe: Bool
        var bottomSafeArea: CGFloat
    }

    private var host: UIHostingController<KeyboardRootView>?
    /// 上一次真正装上去的那一组输入；nil = 还没装
    private var applied: Inputs?

    /// 共享库的只读读取端。**由本控制器持有**：它内部留着 `ModelContainer`，
    /// 容器一被释放，取出来的对象全部失效（`ShareViewController` 的 `ShareSession`
    /// 记着同一个坑）。它是 `@Observable`，界面靠观察拿到状态变化，
    /// 不必经过 `refresh()` 去换整棵树
    private let store = KeyboardClipStore()

    override func viewDidLoad() {
        super.viewDidLoad()

        // 每一次 `viewDidLoad` 都当成冷启动：每个宿主 App 拿到的是**自己的**一个键盘进程，
        // 而且系统回收得很勤。缓存不会在宿主之间被复用（省不到），却会在下一次出现时
        // 指向一份早已失效的状态（会错）。所以这里不留任何跨次数的东西。
        installHeightConstraint()
        installHost()

        // 宿主输入框没有指定外观（`.default`）时深浅才跟系统走，那一档下用户在控制中心
        // 切深色模式得由这条回调把键盘带过去；只靠 `textDidChange` 的话，
        // 键盘要等到下一次敲键才变色
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.refresh()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 换一个宿主输入框时 `keyboardAppearance` 与 `needsInputModeSwitchKey` 都可能变
        refresh()
        // **每次出现都重读，不是在 `viewDidLoad` 读一次。** 键盘一次出现很短，
        // 而两次出现之间用户完全可能在别处复制了新内容；只在加载时读一次的表现是
        // 「刚复制完切到键盘，最上面那张还是上一条」
        store.reload()
    }

    /// 键盘扩展是所有扩展点里 jetsam 预算最紧的一个，被杀掉在用户眼里就是「键盘坏了」，
    /// 而且这条路上没有任何崩溃上报面。收到告警就把库连接放掉，见 `handleMemoryWarning()`
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        store.handleMemoryWarning()
    }

    /// 焦点移到另一个输入框时系统会调这里。深浅是**跟着输入框**走的，所以必须在这里重算
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refresh()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        refresh()
    }

    // MARK: - 装配

    private func installHeightConstraint() {
        // 自适应高度要显式打开，否则系统不理会我们加的那条约束
        inputView?.allowsSelfSizing = true

        let constraint = view.heightAnchor.constraint(equalToConstant: Self.keyboardHeight)
        // **不能用 `.required`。** 系统会往输入视图上加一条 `UIView-Encapsulated-Layout-Height`，
        // 那条也是 required；两条 required 互相矛盾时 Auto Layout 会自己挑一条打断，
        // 控制台刷满 unsatisfiable constraints，而被打断的是哪一条并不稳定。
        // 999 的意思是「除非系统另有安排，否则就按 330」
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
    }

    /// 与 `CopyoShareExtension/ShareViewController.swift` 同一套挂法
    private func installHost() {
        let inputs = currentInputs()
        let host = UIHostingController(rootView: makeRootView(inputs))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        self.host = host
        apply(inputs)
    }

    // MARK: - 刷新

    /// 三个外部输入变了才把整棵树换掉。
    ///
    /// **那道 `guard` 不是省事，是必须的**：`textDidChange` 每敲一个字符都会来一次，
    /// 而重建 `rootView` 会给每一颗 `KeyCap` 发一个**新的** action 闭包；闭包不可比较，
    /// SwiftUI 只能当作整棵树都变了，于是每打一个字母就把三十来颗键全部重新求值一遍。
    ///
    /// 这三个换 `rootView`、库状态却走 `@Observable`（`KeyboardClipStore`），是因为两者的变化
    /// 频次与来源不同：这三个由 UIKit 的回调推过来、几乎不动；而库状态每次出现都会重读一遍，
    /// 每次都换整棵树等于每次都把三排键重建一遍。
    /// `KeyboardRootView` 里的 `@State`（当前是哪一面、查询、预览、轻提示）会被 SwiftUI
    /// 按视图身份留住，换 `rootView` 不会把它们重置
    private func refresh() {
        let inputs = currentInputs()
        guard inputs != applied else { return }
        apply(inputs)
        host?.rootView = makeRootView(inputs)
    }

    private func currentInputs() -> Inputs {
        Inputs(scheme: resolvedScheme,
               needsGlobe: needsInputModeSwitchKey,
               bottomSafeArea: view.safeAreaInsets.bottom)
    }

    /// UIKit 那一侧要跟着一起变的两处
    private func apply(_ inputs: Inputs) {
        applied = inputs
        // 键盘那四个 token 自己吃 scheme，不经过 trait collection；但 `CopyoTheme` 其余颜色
        // 是 `UIColor(dynamicProvider:)`，仍然看 trait。两边都由这同一个 `scheme` 驱动，
        // 不会各说各话
        host?.overrideUserInterfaceStyle = inputs.scheme == .dark ? .dark : .light
        // SwiftUI 根视图铺满之前先垫一层同色底，切换宿主的那一帧不会闪白
        view.backgroundColor = UIColor(CopyoTheme.keyboardBackground(for: inputs.scheme))
    }

    private func makeRootView(_ inputs: Inputs) -> KeyboardRootView {
        KeyboardRootView(scheme: inputs.scheme,
                         actions: makeActions(),
                         globe: inputs.needsGlobe ? globeWiring : nil,
                         bottomSafeArea: inputs.bottomSafeArea,
                         store: store)
    }

    // MARK: - 外观

    /// **先看输入框，再看系统。**
    ///
    /// 宿主可以在一个浅色 App 里放一个 `keyboardAppearance == .dark` 的输入框（搜索栏最常见），
    /// 那时系统键盘是深色的，只看 trait collection 会让我们在它旁边亮成一块白板。
    /// `.default` 才表示「跟随系统」，那一档才轮到 trait collection 说话。
    private var resolvedScheme: ColorScheme {
        let appearance = textDocumentProxy.keyboardAppearance
        if appearance == .dark { return .dark }
        if appearance == .light { return .light }
        return traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    // MARK: - 接线

    private func makeActions() -> KeyboardActions {
        // 一律 `[weak self]`：这些闭包活在 SwiftUI 的视图树里，而视图树由本控制器持有，
        // 强引用会绕成一个环，键盘每被创建一次就漏一次
        KeyboardActions(
            insert: { [weak self] text in self?.textDocumentProxy.insertText(text) },
            deleteBackward: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            space: { [weak self] in self?.textDocumentProxy.insertText(" ") },
            newline: { [weak self] in self?.textDocumentProxy.insertText("\n") }
        )
    }

    /// 地球键的 target-action。选择器在这里取——本类是 `UIInputViewController` 的子类，
    /// `handleInputModeList(from:with:)` 在这儿是自己的成员，编译器查得到，见 `GlobeKeyWiring`。
    /// 要不要显示这颗键由 `Inputs.needsGlobe` 决定，不在这里判断
    private var globeWiring: GlobeKeyWiring {
        GlobeKeyWiring(target: self, action: #selector(handleInputModeList(from:with:)))
    }
}
