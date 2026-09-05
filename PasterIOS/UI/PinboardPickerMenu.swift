import PasterCore
import SwiftUI

/// 上下文菜单里的「固定到…」子菜单。
/// 列出全部 Pinboard、勾选当前所在的板，末尾一条「新建 Pinboard…」把创建交回调用方
/// （新建要弹输入框，那是界面的事，这里只负责触发）。
struct PinboardPickerMenu: View {
    let boards: [Pinboard]
    /// 条目当前所在的板，用来打勾
    var current: Pinboard?
    var onSelect: (Pinboard) -> Void
    var onUnpin: (() -> Void)?
    var onCreate: (() -> Void)?

    var body: some View {
        Menu {
            ForEach(boards) { board in
                Button {
                    onSelect(board)
                } label: {
                    Label {
                        Text(board.name)
                    } icon: {
                        Image(systemName: board.persistentModelID == current?.persistentModelID
                              ? "checkmark"
                              : (board.iconName ?? "pin"))
                    }
                }
            }
            if current != nil, let onUnpin {
                Divider()
                Button(role: .destructive, action: onUnpin) {
                    Label(String(localized: "Remove from Pinboard"), systemImage: "pin.slash")
                }
            }
            if let onCreate {
                Divider()
                Button(action: onCreate) {
                    Label(String(localized: "New Pinboard…"), systemImage: "plus")
                }
            }
        } label: {
            Label(String(localized: "Pin to…"), systemImage: "pin")
        }
    }
}
