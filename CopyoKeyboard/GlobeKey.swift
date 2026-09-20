import SwiftUI
import UIKit

/// 地球键要接到的 target-action 对。
///
/// 选择器在 `KeyboardViewController` 里用 `#selector` 取，不在本文件取：
/// 它是 `UIInputViewController` 的子类，`handleInputModeList(from:with:)` 在那里是自己的成员，
/// 编译器直接查得到；在这里写 `#selector(UIInputViewController.handleInputModeList(from:with:))`
/// 则要赌这个方法对 ObjC 可见，而那是 UIKit 的导出细节，不该拿键盘唯一的换挡键去赌。
struct GlobeKeyWiring {
    /// 弱引用：键盘进程被系统回收时 controller 先走，这里不能把它留住
    weak var target: AnyObject?
    let action: Selector
}

/// 设计 07 底排最左那颗地球键。
///
/// 它必须是 `UIButton`，不能是 SwiftUI 的 `Button`：长按弹出系统键盘列表的
/// `UIInputViewController.handleInputModeList(from:with:)` 第二个参数要一个**真实的 `UIEvent`**，
/// 而 SwiftUI 的按钮回调里根本没有事件对象可给，传 nil 那条路也不存在。
/// UIKit 的 target-action 会把事件原样带过来，所以这里用一颗完全透明的 `UIButton`
/// 盖在 SwiftUI 画的键帽上，只借它的触摸分发，外观仍然是 `KeyCap` 那一份。
///
/// **只连 `.allTouchEvents` 这一路。** `handleInputModeList` 自己分辨轻点与长按——
/// 轻点切到下一个键盘，长按弹列表。再补一条 `.touchUpInside → advanceToNextInputMode()`
/// 会让轻点一次跳过两个键盘，用户只会觉得这块键盘的地球键坏了。
struct GlobeKey: View {
    let scheme: ColorScheme
    let wiring: GlobeKeyWiring
    /// 键宽（设计 07 的功能键 46）
    var width: CGFloat = 46
    /// 键高（设计 07 全部 42）
    var height: CGFloat = 42

    @State private var isPressed = false

    var body: some View {
        KeyCap(width: width,
               height: height,
               fill: .function,
               externalPressed: isPressed,
               scheme: scheme,
               action: nil) {
            Image(systemName: "globe")
                // 设计 6.x 的符号表：键盘地球 = `globe`
                .font(.title3)
        }
        // UIButton 盖在键帽之上并吃掉触摸，所以 `KeyCap` 那边不装手势（`action: nil`），
        // 否则同一次按下会被两套手势各处理一遍
        .overlay { TouchBridge(wiring: wiring, isPressed: $isPressed) }
        .accessibilityLabel(String(localized: "Next keyboard"))
    }
}

/// 透明的 `UIButton`，只做两件事：把事件交给 controller、把按下态回传给 SwiftUI。
private struct TouchBridge: UIViewRepresentable {
    let wiring: GlobeKeyWiring
    @Binding var isPressed: Bool

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        if let target = wiring.target {
            button.addTarget(target, action: wiring.action, for: .allTouchEvents)
        }
        // 额外挂两路只为按下态。`.allTouchEvents` 已经包含它们，但 UIKit 会把同一个事件
        // 发给所有匹配的 target，互不影响——上面那一路照样收得到完整的触摸序列
        button.addTarget(context.coordinator,
                         action: #selector(Coordinator.touchDown),
                         for: [.touchDown, .touchDownRepeat])
        button.addTarget(context.coordinator,
                         action: #selector(Coordinator.touchEnded),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        // 每次刷新都换成最新的那个 binding setter：`TouchBridge` 是值类型，
        // 旧闭包捕获的是上一帧的 `_isPressed`，留着它按下态会停在某一帧不动
        context.coordinator.onPressedChange = { isPressed = $0 }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var onPressedChange: ((Bool) -> Void)?

        @objc func touchDown() { onPressedChange?(true) }
        @objc func touchEnded() { onPressedChange?(false) }
    }
}
