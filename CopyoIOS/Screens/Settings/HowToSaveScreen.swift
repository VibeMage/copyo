import SwiftUI

/// 怎样保存剪贴板（设计 04c）：三条平台允许的通道，各一张卡片。
struct HowToSaveScreen: View {
    @Environment(\.openURL) private var openURL
    @State private var showsQuickSave = false

    var body: some View {
        GuideScroll(spacing: 14) {
            GuideParagraph(text: String(localized: "iOS won't let apps read the clipboard in the background, so Copyo only saves at these three moments."))
                .padding(.bottom, 6)

            // 设计 04c 画的是带横线的剪贴板。`doc.on.clipboard` 是历史页横幅的符号，
            // 这里再用一次会让两处看起来是同一件事
            GuideChannelCard(symbol: "list.clipboard",
                             symbolColor: CopyoTheme.accent,
                             tileBackground: CopyoTheme.tintBlue,
                             title: String(localized: "When you open Copyo"),
                             message: String(localized: "Every time you open or come back to Copyo it reads the current clipboard and saves it to your history. “Paste from Other Apps” has to be set to Allow.")) {
                Button {
                    if let url = SettingsLinks.appSettings { openURL(url) }
                } label: {
                    InlineActionPill(title: String(localized: "Go to Settings"))
                }
                .buttonStyle(.plain)
            }

            GuideChannelCard(symbol: "square.and.arrow.up",
                             symbolColor: CopyoTheme.accent,
                             tileBackground: CopyoTheme.tintBlue,
                             title: String(localized: "Share sheet"),
                             // 分享面板里那一格显示的是扩展的 CFBundleDisplayName「Copyo」，
                             // 「保存到 Copyo」只是点进去之后的标题——照设计稿写，用户在面板里找不到这个名字
                             message: String(localized: "Select text or an image in any app, tap Share, then tap “Copyo”. You can pick a Pinboard on the way in."))

            GuideChannelCard(symbol: "bolt.fill",
                             symbolColor: CopyoTheme.Brand.red,
                             tileBackground: CopyoTheme.tintRed,
                             title: String(localized: "Quick Save"),
                             message: quickSaveMessage) {
                Button {
                    showsQuickSave = true
                } label: {
                    InlineActionPill(title: String(localized: "Set Up Quick Save"))
                }
                .buttonStyle(.plain)
            }

            GuideParagraph(text: String(localized: "Anything you copy on your Mac needs no action at all — it arrives here through iCloud."),
                           footnote: true)
                .padding(.top, 4)
        }
        .navigationTitle(String(localized: "How Copyo Saves Clips"))
        .navigationDestination(isPresented: $showsQuickSave) {
            QuickSaveGuideScreen()
        }
    }

    /// iPad 没有操作按钮，也没有轻点背面，一键保存那页在 iPad 上只剩控制中心一段，这里跟着说
    private var quickSaveMessage: String {
        UIDevice.current.userInterfaceIdiom == .pad
            ? String(localized: "After copying, tap the “Save Clipboard” button in Control Center. Copyo opens and shows “Saved”.")
            : String(localized: "After copying, press the Action Button, double-tap the back of your iPhone, or tap the Control Center button. Copyo opens and shows “Saved”.")
    }
}
