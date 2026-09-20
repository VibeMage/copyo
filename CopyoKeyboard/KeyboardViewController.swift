import SwiftUI
import UIKit

/// 系统键盘列表里的「Copyo」。
///
/// 类名被 `Info.plist` 的 `NSExtensionPrincipalClass` 引用，改名要同步改 plist——
/// 对不上的表现是切到本键盘时宿主只出现一块空白，控制台一句提示都没有。
///
/// 本阶段做的是**能独立上架的那块基础键盘**：一整块拉丁键盘加设计 07 的底排，
/// 不读 App Group、不联网。剪贴卡片条与未授权提示态在下一阶段接上，理由见 `LetterPlane`。
///
/// 这里只负责四件事：把高度钉住、把 SwiftUI 挂上去、决定深浅、把按键接到宿主输入框。
final class KeyboardViewController: UIInputViewController {

    // MARK: - 尺寸

    /// 设计 07 的键盘总高。输入视图**没有固有高度**，不自己钉一条约束的话系统会给一块
    /// 几乎为零的高度，键一颗都看不见
    private static let keyboardHeight: CGFloat = 330

    /// 上面那 330 里最底下留给 Home 指示条的一条（设计 07 底排的 `padding-bottom:40`）。
    /// 系统若已经把这一条报进 `view.safeAreaInsets.bottom`，报多少就从这 40 里扣多少；
    /// 报 0 就整条自己补——两种情形下底排离屏幕底边都是 40，见 `KeyboardRootView.bottomPadding`。
    /// 不扣的那种写法是两头各留一次，底排会被顶高一截，换行键离底边差不多有两指宽
    fileprivate static let homeIndicatorStrip: CGFloat = 40

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
    /// 换 `rootView` 而不是往里塞一个 `@Observable`：这棵树只有这三个外部输入，都由本控制器持有；
    /// `KeyboardRootView` 里的 `@State`（当前是哪一面、上档开没开）会被 SwiftUI 按视图身份留住，
    /// 换 `rootView` 不会把它们重置
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
                         bottomSafeArea: inputs.bottomSafeArea)
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

// MARK: - SwiftUI 那一侧

/// 键盘的 SwiftUI 根：设计 07 的竖向排布（上留白 10、左右 8、块间距 10）。
private struct KeyboardRootView: View {
    let scheme: ColorScheme
    let actions: KeyboardActions
    /// nil = 系统不要求显示地球键（这台设备只装了这一块键盘）
    let globe: GlobeKeyWiring?
    /// 由 UIKit 那侧读好传进来。不在 SwiftUI 里用 `GeometryProxy.safeAreaInsets` 读：
    /// 这棵树整体 `ignoresSafeArea`，那种组合下代理报什么值是实现细节，
    /// 而 `UIViewController.view.safeAreaInsets` 是确定的
    let bottomSafeArea: CGFloat

    /// 左右页边距（设计 07 `padding:10px 8px 0`）
    var horizontalInset: CGFloat = 8
    /// 顶部留白（同上）
    var topInset: CGFloat = 10
    /// 块间距（设计 07 `gap:10`）
    var blockSpacing: CGFloat = 10

    @State private var plane: KeyboardPlane = .letters

    private var bottomPadding: CGFloat {
        max(0, KeyboardViewController.homeIndicatorStrip - bottomSafeArea)
    }

    var body: some View {
        VStack(spacing: blockSpacing) {
            // 顶上这块空白是设计 07 留给搜索行与横向剪贴卡片条的位置，本阶段还没有内容。
            // 打字的三排贴着底排放，手指落点才和系统键盘一致；把它们居中会让整块键盘
            // 在视觉上往上飘，而且下一阶段卡片条进来时所有键又得整体下移一次
            Spacer(minLength: 0)

            LetterPlane(plane: plane, actions: actions, scheme: scheme)

            KeyRow(plane: $plane, actions: actions, scheme: scheme, globe: globe)
        }
        .padding(.top, topInset)
        .padding(.horizontal, horizontalInset)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CopyoTheme.keyboardBackground(for: scheme))
        .ignoresSafeArea()
        // **键盘是动态字体契约里那个要想一想的例外。** 键帽高被 330 的总高锁死，
        // 字号无上限地跟着放大只会把字母从 42 高的格子里上下切掉——比不放大还难认。
        // 所以夹一个上限：默认到这一档之间照常跟随（放大档位下字确实会变大），
        // 再往上就停住，保证每一颗键上的字仍然是完整的
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
