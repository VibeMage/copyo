import AppIntents

/// 让「保存剪贴板」在 Spotlight、快捷指令库与 Siri 里直接可见，用户不必先自己拼一条快捷指令。
///
/// 短语里必须出现 `\(.applicationName)`（系统要求）。这里只放英文（源语言），
/// 中文与法语短语在 `CopyoIOS/AppShortcuts.xcstrings` 里按语言给——原来中英混写在同一个数组里，
/// 结果每种语言的 Siri 都拿到一半听不懂的短语，法语一条都没有。
struct CopyoShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveClipboardIntent(),
            phrases: [
                "Save my clipboard to \(.applicationName)",
                "Save clipboard with \(.applicationName)",
                "Save this clip to \(.applicationName)",
                "\(.applicationName) save clipboard",
            ],
            shortTitle: "Save Clipboard",
            systemImageName: "tray.and.arrow.down.fill"
        )
    }
}
