import SwiftUI

/// 怎样保存剪贴板（设计 04c）：三条平台允许的通道，各一张卡片。
struct HowToSaveScreen: View {
    @Environment(\.openURL) private var openURL
    @State private var showsQuickSave = false

    var body: some View {
        GuideScroll(spacing: 14) {
            GuideParagraph(text: String(localized: "iOS won't let apps read the clipboard in the background, so Paster only saves at these three moments."))
                .padding(.bottom, 6)

            GuideChannelCard(symbol: "doc.on.clipboard",
                             symbolColor: PasterTheme.accent,
                             tileBackground: PasterTheme.tintBlue,
                             title: String(localized: "When you open Paster"),
                             message: String(localized: "Every time you open or come back to Paster it reads the current clipboard and saves it to your history. “Paste from Other Apps” has to be set to Allow.")) {
                Button {
                    if let url = SettingsLinks.appSettings { openURL(url) }
                } label: {
                    InlineActionPill(title: String(localized: "Go to Settings"))
                }
                .buttonStyle(.plain)
            }

            GuideChannelCard(symbol: "square.and.arrow.up",
                             symbolColor: PasterTheme.accent,
                             tileBackground: PasterTheme.tintBlue,
                             title: String(localized: "Share sheet"),
                             message: String(localized: "Select text or an image in any app, tap Share, then tap “Save to Paster”. You can pick a Pinboard on the way in."))

            GuideChannelCard(symbol: "bolt.fill",
                             symbolColor: PasterTheme.Brand.red,
                             tileBackground: PasterTheme.tintRed,
                             title: String(localized: "Quick Save"),
                             message: String(localized: "After copying, press the Action Button, double-tap the back of your iPhone, or tap the Control Center button. Paster opens and shows “Saved”.")) {
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
        .navigationTitle(String(localized: "How Paster Saves Clips"))
        .navigationDestination(isPresented: $showsQuickSave) {
            QuickSaveGuideScreen()
        }
    }
}
