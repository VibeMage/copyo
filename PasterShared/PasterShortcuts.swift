import AppIntents

/// 让「保存剪贴板」在 Spotlight、快捷指令库与 Siri 里直接可见，用户不必先自己拼一条快捷指令。
///
/// 短语里必须出现 `\(.applicationName)`（系统要求），中英各给几条常见说法：
/// 中文用户更可能说「保存剪贴板」，英文用户更可能说 "save my clipboard"。
struct PasterShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveClipboardIntent(),
            phrases: [
                "Save my clipboard to \(.applicationName)",
                "Save clipboard with \(.applicationName)",
                "Save this clip to \(.applicationName)",
                "\(.applicationName) save clipboard",
                "保存剪贴板到 \(.applicationName)",
                "用 \(.applicationName) 保存剪贴板",
                "\(.applicationName) 存剪贴板",
            ],
            shortTitle: "Save Clipboard",
            systemImageName: "tray.and.arrow.down.fill"
        )
    }
}
