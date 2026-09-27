import CopyoCore
import SwiftUI

/// 设计 03c 的「新建 Pinboard」系统 Alert：标题 + 副文 + 单行输入框 + 取消 / 创建。
///
/// 做成 modifier 是因为触发点有三处：列表右上的 `+`、空态按钮、以及卡片长按菜单里的
/// 「新建 Pinboard…」（`PinboardPickerMenu` 的 onCreate）。三处必须是同一段文案与同一套校验。
private struct NewPinboardAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    @State private var name = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func body(content: Content) -> some View {
        content
            .alertBackdrop(isPresented)
            .alert(String(localized: "New Pinboard"), isPresented: $isPresented) {
                TextField(String(localized: "Name"), text: $name)
                Button(String(localized: "Cancel"), role: .cancel) { name = "" }
                Button(String(localized: "Create")) {
                    let trimmed = trimmedName
                    name = ""
                    // 兜底：真正挡住空名字的是下面的 `.disabled`，这里防的是硬件键盘回车之类的漏网路径
                    guard !trimmed.isEmpty else { return }
                    onCreate(trimmed)
                }
                // 设计 03c 里「创建」是加粗的确认项，标成默认动作系统才会加粗
                .keyboardShortcut(.defaultAction)
                // 空名字时置灰：满色的「创建」点下去却什么都不建、也不说一声，用户会以为建好了
                .disabled(trimmedName.isEmpty)
            } message: {
                Text(String(localized: "It syncs to the Pinboard tags on your Mac."))
            }
            .onChange(of: isPresented) { _, presented in
                // 每次打开都从空白开始，免得上次取消掉的名字又冒出来
                if presented { name = "" }
            }
    }
}

/// 设计 03b 标题菜单的「重命名」：同一套 Alert 骨架，预填当前名字。
private struct RenamePinboardAlert: ViewModifier {
    @Binding var isPresented: Bool
    let currentName: String
    let onRename: (String) -> Void

    @State private var name = ""

    /// 空名字或没改动都不算一次重命名，「重命名」按钮置灰
    private var canRename: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != currentName
    }

    func body(content: Content) -> some View {
        content
            .alertBackdrop(isPresented)
            .alert(String(localized: "Rename Pinboard"), isPresented: $isPresented) {
                TextField(String(localized: "Name"), text: $name)
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Rename")) {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, trimmed != currentName else { return }
                    onRename(trimmed)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canRename)
            }
            .onChange(of: isPresented) { _, presented in
                if presented { name = currentName }
            }
    }
}

/// 设计 3.11：Alert 底层 `blur(6) opacity .7`，dim 由系统叠。
/// 系统 Alert 只压暗、不模糊，所以宿主内容得自己糊一层；半径 0 / 不透明度 1 时两个修饰符都是恒等变换
private struct AlertBackdrop: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? 6 : 0)
            .opacity(isActive ? 0.7 : 1)
            .animation(.easeOut(duration: 0.2), value: isActive)
    }
}

private extension View {
    func alertBackdrop(_ isActive: Bool) -> some View {
        modifier(AlertBackdrop(isActive: isActive))
    }
}

extension View {
    func newPinboardAlert(isPresented: Binding<Bool>, onCreate: @escaping (String) -> Void) -> some View {
        modifier(NewPinboardAlert(isPresented: isPresented, onCreate: onCreate))
    }

    func renamePinboardAlert(isPresented: Binding<Bool>,
                             currentName: String,
                             onRename: @escaping (String) -> Void) -> some View {
        modifier(RenamePinboardAlert(isPresented: isPresented, currentName: currentName, onRename: onRename))
    }
}
