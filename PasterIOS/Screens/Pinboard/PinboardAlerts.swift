import PasterCore
import SwiftUI

/// 设计 03c 的「新建 Pinboard」系统 Alert：标题 + 副文 + 单行输入框 + 取消 / 创建。
///
/// 做成 modifier 是因为触发点有三处：列表右上的 `+`、空态按钮、以及卡片长按菜单里的
/// 「新建 Pinboard…」（`PinboardPickerMenu` 的 onCreate）。三处必须是同一段文案与同一套校验。
private struct NewPinboardAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert(String(localized: "New Pinboard"), isPresented: $isPresented) {
                TextField(String(localized: "Name"), text: $name)
                Button(String(localized: "Cancel"), role: .cancel) { name = "" }
                Button(String(localized: "Create")) {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    name = ""
                    // 空名字直接当取消：Alert 的按钮没法可靠地禁用，不如什么都不建
                    guard !trimmed.isEmpty else { return }
                    onCreate(trimmed)
                }
                // 设计 03c 里「创建」是加粗的确认项，标成默认动作系统才会加粗
                .keyboardShortcut(.defaultAction)
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

    func body(content: Content) -> some View {
        content
            .alert(String(localized: "Rename Pinboard"), isPresented: $isPresented) {
                TextField(String(localized: "Name"), text: $name)
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Rename")) {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, trimmed != currentName else { return }
                    onRename(trimmed)
                }
                .keyboardShortcut(.defaultAction)
            }
            .onChange(of: isPresented) { _, presented in
                if presented { name = currentName }
            }
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
