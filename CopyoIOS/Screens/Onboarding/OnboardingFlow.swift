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

    /// 40 的跳过按钮与 52 的 CTA 都不在样式表上，按各自 17pt 文字的 `.body` 缩。
    /// 这两条与页码点一起固定在 `TabView` 外面，放大档位下**必须**始终够得着——
    /// 页内容溢出时由 `OnboardingPageView` 的 ScrollView 吸收，不挤这一条。
    @ScaledMetric(relativeTo: .body) private var skipMinHeight: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var ctaMinHeight: CGFloat = 52

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
        .background(CopyoTheme.bgGrouped)
    }

    // MARK: - 顶部

    private var header: some View {
        HStack {
            Spacer()
            Button(action: finish) {
                Text(pages[safe: page]?.skipTitle ?? String(localized: "Skip"))
                    .font(.body)
                    .foregroundStyle(CopyoTheme.accent)
                    .lineLimit(1)
                    // 「Maybe Later」「Plus tard」放大后会顶到屏幕边，缩到 0.8 也还读得出来
                    .minimumScaleFactor(0.8)
                    .frame(minHeight: skipMinHeight)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CopyoTheme.Metrics.pageInset)
        .padding(.top, 8)
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(spacing: 22) {
            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == page ? CopyoTheme.accent : CopyoTheme.labelTertiary)
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            Button(action: advance) {
                Text(page == pages.count - 1
                     ? String(localized: "Get Started")
                     : String(localized: "Continue"))
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    // 默认档 20 的行高 + 28 内距 = 48 < 52，胶囊仍是 52；
                    // 放大后靠内距长高，写死 height 会把「Commencer」上下切掉
                    .padding(.vertical, 14)
                    .frame(minHeight: ctaMinHeight)
                    .background(CopyoTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CopyoTheme.Metrics.pageInset)
        .padding(.bottom, 50)
    }

    // MARK: - 动作

    private func advance() {
        if page < pages.count - 1 {
            withAnimation(CopyoTheme.springAnimation) { page += 1 }
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
        // 三页是固定高度的 `TabView`，页内容一旦超出就只能被裁掉——最大的辅助功能档位下
        // 28pt 的标题与三条说明行加起来远超一屏。这层 ScrollView 是那时唯一的出路：
        // `.basedOnSize` 保证默认档内容装得下时不回弹，看起来仍是一张静态页。
        ScrollView {
            VStack(spacing: 0) {
                // 中文的 05b 标题会折成两行，插图上下留白按设计原值（40 / 36）时
                // 第三条说明行会被推出可视区（内容可滚动，但设计要求一屏看全）
                OnboardingArtwork(kind: content.artwork)
                    .padding(.top, content.rows.isEmpty ? 40 : 24)
                    .padding(.bottom, content.rows.isEmpty ? 36 : 24)

                Text(content.title)
                    .font(.system(.title, weight: .bold))
                    .lineSpacing(6)
                    .foregroundStyle(CopyoTheme.label)
                    .multilineTextAlignment(.center)

                Text(content.body)
                    .font(.body)
                    .lineSpacing(7)
                    .foregroundStyle(CopyoTheme.labelSecondary)
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
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// 设计 3.9 的说明行：36 圆角砖 + 标题 15 Semibold + 副文 13，右侧可挂开关或胶囊按钮。
///
/// 砖是定尺装饰（已 `accessibilityHidden`），17pt 符号跟着放大会顶破 36 × 36，所以保持写死。
private struct OnboardingRow: View {
    let row: OnboardingPageContent.Row
    @Binding var cloudSyncEnabled: Bool
    let onOpenSettings: () -> Void

    /// 胶囊按钮的 14 / 30 都不在样式表上，按行内标题的 `.subheadline`（15pt）缩，
    /// 字与胶囊同一把尺子才不会放大后被上下切掉
    @ScaledMetric(relativeTo: .subheadline) private var pillFontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var pillMinHeight: CGFloat = 30

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CopyoTheme.tintBlue)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: row.symbol)
                        .font(.system(size: 17, weight: .medium))
                        // 系统默认会给 .fill 符号上分层配色，设计要的是单色描边
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(CopyoTheme.accent)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(CopyoTheme.label)
                Text(row.detail)
                    .font(.footnote)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 标题与副文是一句话；分成两个停留点的话，副文单独念出来（「设为允许，不再询问」）
            // 脱离了它说明的那一项
            .accessibilityElement(children: .combine)

            switch row.accessory {
            case .none:
                EmptyView()
            case .cloudToggle:
                Toggle("", isOn: $cloudSyncEnabled)
                    .labelsHidden()
                    .tint(CopyoTheme.switchOn)
                    .accessibilityLabel(row.title)
            case .settingsButton:
                Button(action: onOpenSettings) {
                    Text(String(localized: "Go to Settings"))
                        .font(.system(size: pillFontSize, weight: .semibold))
                        .foregroundStyle(CopyoTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        // 默认档 14pt 的行高约 17，加 8 内距是 25 < 30，胶囊仍是 30
                        .padding(.vertical, 4)
                        .frame(minHeight: pillMinHeight)
                        .background(CopyoTheme.tintBlue, in: Capsule())
                }
                .buttonStyle(.plain)
                // 读屏把这枚胶囊单独念成「前往设置」，脱开左边那行就分不清是去 Copyo 的设置页
                // 还是系统「设置」。复用说明页主按钮那条文案把去处补上。
                // 用 hint 不用 label，是因为改 label 会让「语音控制」认不出屏幕上那四个字。
                .accessibilityHint(String(localized: "Open Copyo's Settings"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .background(CopyoTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.group, style: .continuous))
    }
}

// MARK: - 插图

/// 180 × 180 白卡，卡上摆本页的符号（设计 3.9 / 05a–05c）。
///
/// 设计稿三页的 art 只有 accent 色的符号本身，没有红蓝错位色条——
/// 品牌的红蓝套印按 design-spec 01b 是「全 App 唯一」的那一处（历史空态的插画），
/// 引导页再画一次就不唯一了。
///
/// 卡与卡上的符号一律**不跟随**辅助功能字号：05a 的 34 / 20 / 31 三个符号是一幅
/// 「Mac ←→ iPhone」的构图，各自按自己的字号放大会把箭头顶到机器身上，画面直接走形；
/// 180 × 180 的白卡也放不下放大后的符号。整块已 `accessibilityHidden`，
/// 读屏用户拿不到任何信息，放大也就没有收益——页上的字照常放大。
private struct OnboardingArtwork: View {
    let kind: OnboardingPageContent.Artwork

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(CopyoTheme.bgCard)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 16)

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
                    .foregroundStyle(CopyoTheme.sourceLocal)
                Image(systemName: "iphone")
                    .font(.system(size: 31, weight: .light))
            }
            .foregroundStyle(CopyoTheme.accent)
            .symbolRenderingMode(.monochrome)
        case .tray:
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 54, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(CopyoTheme.accent)
        case .cloudCheck:
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 50, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(CopyoTheme.accent)
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
                body: String(localized: "iOS won't let apps read the clipboard in the background, so Copyo only saves at these three moments."),
                skipTitle: String(localized: "Skip"),
                artwork: .tray,
                rows: [
                    Row(symbol: "doc.on.clipboard",
                        title: String(localized: "When you open Copyo"),
                        detail: String(localized: "Reads the current clipboard")),
                    Row(symbol: "square.and.arrow.up",
                        title: String(localized: "Share sheet"),
                        detail: String(localized: "“Save to Copyo” in any app")),
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
