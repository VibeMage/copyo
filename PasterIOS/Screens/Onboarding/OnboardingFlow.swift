import SwiftUI

/// 首次启动引导（设计 05a / 05b / 05c）。
///
/// 三页横滑，页码点与 CTA 固定在底部，所以用 `TabView(.page)` 只滑上半部分，
/// 底部那一条留在外面——原生的 page indicator 与设计的 7pt 圆点差得远，直接隐藏自绘。
struct OnboardingFlow: View {
    var startPage: Int = 0
    var onFinish: () -> Void

    @State private var page: Int

    @AppStorage(IOSSettings.Key.cloudSyncEnabled, store: IOSSettings.defaults)
    private var cloudSyncEnabled = true

    @Environment(\.openURL) private var openURL

    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.startPage = startPage
        self.onFinish = onFinish
        _page = State(initialValue: startPage)
    }

    private var pages: [OnboardingPageContent] { OnboardingPageContent.all }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, content in
                    OnboardingPageView(content: content,
                                       cloudSyncEnabled: $cloudSyncEnabled,
                                       onOpenSettings: openSystemSettings)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(PasterTheme.bgGrouped)
    }

    // MARK: - 顶部

    private var header: some View {
        HStack {
            Spacer()
            Button(action: finish) {
                Text(pages[safe: page]?.skipTitle ?? String(localized: "Skip"))
                    .font(.system(size: 17))
                    .foregroundStyle(PasterTheme.accent)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PasterTheme.Metrics.pageInset)
        .padding(.top, 8)
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(spacing: 22) {
            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == page ? PasterTheme.accent : PasterTheme.labelTertiary)
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            Button(action: advance) {
                Text(page == pages.count - 1
                     ? String(localized: "Get Started")
                     : String(localized: "Continue"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(PasterTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PasterTheme.Metrics.pageInset)
        .padding(.bottom, 50)
    }

    // MARK: - 动作

    private func advance() {
        if page < pages.count - 1 {
            withAnimation(PasterTheme.springAnimation) { page += 1 }
        } else {
            finish()
        }
    }

    /// 跳过与走完都写同一个标记：引导只该出现一次
    private func finish() {
        IOSSettings.onboardingCompleted = true
        onFinish()
    }

    private func openSystemSettings() {
        if let url = SettingsLinks.appSettings { openURL(url) }
    }
}

// MARK: - 单页

private struct OnboardingPageView: View {
    let content: OnboardingPageContent
    @Binding var cloudSyncEnabled: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OnboardingArtwork(kind: content.artwork)
                    .padding(.top, 40)
                    .padding(.bottom, 36)

                Text(content.title)
                    .font(.system(size: 28, weight: .bold))
                    .lineSpacing(6)
                    .foregroundStyle(PasterTheme.label)
                    .multilineTextAlignment(.center)

                Text(content.body)
                    .font(.system(size: 17))
                    .lineSpacing(7)
                    .foregroundStyle(PasterTheme.labelSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                if !content.rows.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(content.rows) { row in
                            OnboardingRow(row: row,
                                          cloudSyncEnabled: $cloudSyncEnabled,
                                          onOpenSettings: onOpenSettings)
                        }
                    }
                    .padding(.top, 28)
                }
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// 设计 3.9 的说明行：36 圆角砖 + 标题 15 Semibold + 副文 13，右侧可挂开关或胶囊按钮
private struct OnboardingRow: View {
    let row: OnboardingPageContent.Row
    @Binding var cloudSyncEnabled: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PasterTheme.tintBlue)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: row.symbol)
                        .font(.system(size: 17, weight: .medium))
                        // 系统默认会给 .fill 符号上分层配色，设计要的是单色描边
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(PasterTheme.accent)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PasterTheme.label)
                Text(row.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(PasterTheme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch row.accessory {
            case .none:
                EmptyView()
            case .cloudToggle:
                Toggle("", isOn: $cloudSyncEnabled)
                    .labelsHidden()
                    .tint(PasterTheme.switchOn)
                    .accessibilityLabel(row.title)
            case .settingsButton:
                Button(action: onOpenSettings) {
                    Text(String(localized: "Go to Settings"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PasterTheme.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(PasterTheme.tintBlue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .background(PasterTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: PasterTheme.Radius.group, style: .continuous))
    }
}

// MARK: - 插图

/// 180 × 180 白卡 + 红蓝错位色条，卡上摆本页的符号（设计 3.9）
private struct OnboardingArtwork: View {
    let kind: OnboardingPageContent.Artwork

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(PasterTheme.bgCard)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 16)

            ZStack {
                Capsule()
                    .fill(PasterTheme.Brand.red)
                    .frame(width: 92, height: 14)
                    .opacity(0.9)
                    .offset(x: -3, y: -3)
                Capsule()
                    .fill(PasterTheme.Brand.blue)
                    .frame(width: 92, height: 14)
                    .opacity(0.85)
                    .offset(x: 3, y: 3)
                    .blendMode(colorScheme == .dark ? .screen : .multiply)
            }
            .compositingGroup()
            .offset(y: -23)

            symbols
                .padding(.top, 34)
        }
        .frame(width: 180, height: 180)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var symbols: some View {
        switch kind {
        case .macAndPhone:
            HStack(spacing: 10) {
                Image(systemName: "macbook")
                    .font(.system(size: 34, weight: .light))
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(PasterTheme.sourceLocal)
                Image(systemName: "iphone")
                    .font(.system(size: 31, weight: .light))
            }
            .foregroundStyle(PasterTheme.accent)
            .symbolRenderingMode(.monochrome)
        case .tray:
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 54, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(PasterTheme.accent)
        case .cloudCheck:
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 50, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(PasterTheme.accent)
        }
    }
}

// MARK: - 三页文案

struct OnboardingPageContent {
    enum Artwork {
        case macAndPhone
        case tray
        case cloudCheck
    }

    struct Row: Identifiable {
        enum Accessory {
            case none
            case cloudToggle
            case settingsButton
        }

        let id = UUID()
        var symbol: String
        var title: String
        var detail: String
        var accessory: Accessory = .none
    }

    var title: String
    var body: String
    var skipTitle: String
    var artwork: Artwork
    var rows: [Row] = []

    static var all: [OnboardingPageContent] {
        [
            OnboardingPageContent(
                title: String(localized: "Your Mac clipboard, in your pocket"),
                body: String(localized: "Everything you copy on your Mac arrives here through iCloud. Search anytime, tap to copy."),
                skipTitle: String(localized: "Skip"),
                artwork: .macAndPhone
            ),
            OnboardingPageContent(
                title: String(localized: "Three ways to save from this iPhone"),
                body: String(localized: "iOS won't let apps read the clipboard in the background, so Paster only saves at these three moments."),
                skipTitle: String(localized: "Skip"),
                artwork: .tray,
                rows: [
                    Row(symbol: "doc.on.clipboard",
                        title: String(localized: "When you open Paster"),
                        detail: String(localized: "Reads the current clipboard")),
                    Row(symbol: "square.and.arrow.up",
                        title: String(localized: "Share sheet"),
                        detail: String(localized: "“Save to Paster” in any app")),
                    Row(symbol: "bolt.fill",
                        title: String(localized: "Quick Save"),
                        detail: String(localized: "Action Button, Back Tap or Control Center")),
                ]
            ),
            OnboardingPageContent(
                title: String(localized: "Two switches and you're set"),
                body: String(localized: "You can change both later in Settings."),
                skipTitle: String(localized: "Maybe Later"),
                artwork: .cloudCheck,
                rows: [
                    Row(symbol: "icloud.fill",
                        title: String(localized: "iCloud Sync"),
                        detail: String(localized: "Share one history with your Mac"),
                        accessory: .cloudToggle),
                    Row(symbol: "doc.on.clipboard",
                        title: String(localized: "Allow Paste from Other Apps"),
                        detail: String(localized: "Set it to Allow, no more prompts"),
                        accessory: .settingsButton),
                ]
            ),
        ]
    }
}

private extension Array {
    /// 页码越界时不崩，退回 nil（`-demoScreen onboarding-3` 之类的参数是外部输入）
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
