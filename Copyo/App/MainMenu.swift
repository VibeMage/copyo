import AppKit

/// 最小主菜单（design-spec 7.5.3 / §4.2.1，选 A）。
///
/// AppKit 的 ⌘A / ⌘C / ⌘X / ⌘V / ⌘Z 是 Edit 菜单提供的 key equivalent。此前全工程没有主菜单，
/// 面板搜索框里这五个组合全部不工作。LSUIElement 应用也可以有主菜单，只在应用被激活时显示——
/// 面板呼出时正是激活状态，于是菜单栏在那段时间里会出现「Copyo · 编辑」两个菜单，这是可接受的代价。
///
/// **刻意不放** ⌘F / ⌘P / ⌘Y / ⌘1–9 / ⌘⌫：它们是面板自己的快捷键，放进菜单会被菜单先吃掉，
/// 面板的 onKeyPress 就收不到了。
@MainActor
enum MainMenu {
    static func install() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Copyo")
        appMenu.addItem(withTitle: String(localized: "Settings…"),
                        action: #selector(AppDelegate.openSettings as (AppDelegate) -> () -> Void),
                        keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Quit Copyo"),
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        NSApp.mainMenu = main
    }
}
