import SwiftUI

/// 设计 07 的一颗键帽：圆角 6、`box-shadow: 0 1px 0 keySh`，按下时与另一档底色对调。
///
/// **键帽高度写死 42，这是动态字体契约里「键盘属于例外」的那一条。**
/// 输入视图的总高由 `KeyboardViewController` 钉在 330，四排键分的是固定的那 330，
/// 任何一排长高都只能把别的排挤出屏幕——而键盘被挤掉的那一排往往正是空格与换行。
/// 所以这里反过来：高度不动，改为在 `KeyboardViewController` 那一层夹住字号档位，
/// 让字在 42 的格子里仍然放得下。字号本身仍按契约走文本样式（22 → `.title2` 等），
/// 夹的是上限而不是「不跟随」。
struct KeyCap<Label: View>: View {

    /// 键帽底色的两档（design-spec 2.2 的 `key` 与 `keyDark`）
    enum Fill {
        /// 字母 / 数字 / 空格
        case cap
        /// 地球、上档、删除、换行、面板切换
        case function
    }

    /// 键宽；nil = 吃掉一排里剩下的宽度（设计 07 的 `空格` 是 `flex:1`）
    var width: CGFloat?
    /// 键高（设计 07 全部是 42）
    var height: CGFloat = 42
    /// 底色档位
    var fill: Fill = .cap
    /// 圆角（设计 07 `border-radius:6`）
    var cornerRadius: CGFloat = 6
    /// 长按连发。只有删除键要，字母键连发会把人打出一串重复字母
    var repeatsOnHold: Bool = false
    /// 由外部驱动的按下态。地球键的触摸归 UIKit 管，SwiftUI 这边看不到，只能由它告诉我们
    var externalPressed: Bool?
    /// 外观。键盘的深浅跟宿主输入框走，不跟系统走，所以必须显式传，理由见 `CopyoTheme.keyCap(for:)`
    let scheme: ColorScheme
    /// nil = 这颗键的触摸由外部接管（地球键），`KeyCap` 只负责画，不装手势
    var action: (() -> Void)?
    @ViewBuilder var label: () -> Label

    /// 长按到开始连发之间的等待。比系统略长一点：短了会让「按住看一眼再松手」变成删掉两三个字。
    /// 写成 computed 而不是 `static let`，是因为 Swift 不允许泛型类型有静态存储属性
    private static var repeatDelay: Duration { .milliseconds(450) }
    /// 连发的间隔（同上，只能是 computed）
    private static var repeatInterval: Duration { .milliseconds(90) }

    @State private var selfPressed = false
    @State private var repeatTask: Task<Void, Never>?

    private var isPressed: Bool { externalPressed ?? selfPressed }

    /// 按下时两档底色对调：字母键压深、功能键提亮。
    /// 这与系统键盘的反馈方向一致，且正好只用到设计给的这两档，不必再发明一个「按下色」。
    private var fillColor: Color {
        switch (fill, isPressed) {
        case (.cap, false), (.function, true): CopyoTheme.keyCap(for: scheme)
        case (.function, false), (.cap, true): CopyoTheme.keyCapFunction(for: scheme)
        }
    }

    var body: some View {
        let cap = label()
            .foregroundStyle(CopyoTheme.label)
            .frame(maxWidth: .infinity)
            .frame(width: width, height: height)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
                    // radius 0 才是设计要的那条 1pt 硬边；给半径会糊成一团灰影，
                    // 键与键之间的缝隙就看不出来了
                    .shadow(color: CopyoTheme.keyShadow(for: scheme), radius: 0, x: 0, y: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        if let action {
            cap
                // 用 DragGesture 而不是 Button：键盘在**按下**的瞬间就要出字（系统键盘就是如此），
                // Button 要等抬手，快速连打时字会明显落后于手指。
                // `minimumDistance: 0` 让它等同于「触摸按下」。
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in press(action) }
                        .onEnded { _ in release() }
                )
                // 手势被系统打断（来电、切换宿主）时 onEnded 不一定来，
                // 不在这里收尾的话连发任务会一直删下去
                .onDisappear { release() }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { action() }
        } else {
            cap
        }
    }

    private func press(_ action: @escaping () -> Void) {
        // onChanged 在手指移动时会反复触发，只认第一次
        guard !selfPressed else { return }
        selfPressed = true
        action()
        guard repeatsOnHold else { return }
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: Self.repeatDelay)
            // sleep 被取消时 `try?` 会把错误吞掉直接往下走，所以每一轮都要自己看一眼取消标志，
            // 否则松手的那一刻还会再删一个字
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: Self.repeatInterval)
            }
        }
    }

    private func release() {
        selfPressed = false
        repeatTask?.cancel()
        repeatTask = nil
    }
}
