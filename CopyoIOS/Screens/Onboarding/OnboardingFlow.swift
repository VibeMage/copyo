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

    /// 本次启动建库时用的那个值。容器在 App 启动时就按开关建好了，引导页里再拨只能等下次打开才生效
    /// （与设置页同一条限制），行上要把这件事说出来
    @State private var cloudSyncAtLaunch = IOSSettings.cloudSyncEnabled

    /// 底部安全区高度。设计 3.9 的底边距 50 是从屏幕物理底边量起的（含 Home 指示条），
    /// 而 footer 本身已经坐在安全区之上——直接加 50 会整条上移 34pt
    @State private var bottomSafeArea: CGFloat = 0

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    /// iPad（regular 宽度）上把三页与底栏收进一根手机宽的竖栏并在屏幕中间摆：
    /// 设计只画了 440 × 956 的 iPhone，照原样铺满 13 寸屏会是插图挤在顶上 30%、
    /// 中间空一大片、CTA 横跨整屏。「跳过」留在屏幕右上角，那是系统里这类按钮的惯常位置。
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, content in
                        OnboardingPageView(content: content,
                                           cloudSyncChanged: cloudSyncEnabled != cloudSyncAtLaunch,
                                           cloudSyncEnabled: $cloudSyncEnabled)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                footer
            }
            .frame(maxWidth: isRegularWidth ? Self.regularColumnWidth : .infinity,
                   maxHeight: isRegularWidth ? Self.regularColumnHeight : .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CopyoTheme.bgGrouped)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: {
            bottomSafeArea = $0
        }
    }

    /// 设计画布 440 × 956 去掉状态栏与「跳过」那一条后大约剩下的尺寸；
    /// 屏幕比这矮（11 寸 iPad 横放）时 maxHeight 不起作用，照常撑满
    private static let regularColumnWidth: CGFloat = 440
    private static let regularColumnHeight: CGFloat = 820

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
        // 带 Home 指示条的机型上安全区已占 34，只补剩下的 16；
        // Home 键机型（安全区 0）与 iPad 中间那根竖栏也至少留 16，按钮不贴边
        .padding(.bottom, max(Self.footerBottomFromEdge - bottomSafeArea, 16))
    }

    /// 设计 3.9 `padding 0 20px 50px`：CTA 下沿到屏幕物理底边
    private static let footerBottomFromEdge: CGFloat = 50

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
}

// MARK: - 单页

private struct OnboardingPageView: View {
    let content: OnboardingPageContent
    let cloudSyncChanged: Bool
    @Binding var cloudSyncEnabled: Bool

    var body: some View {
        // 三页是固定高度的 `TabView`，页内容一旦超出就只能被裁掉——最大的辅助功能档位下
        // 28pt 的标题与三条说明行加起来远超一屏。这层 ScrollView 是那时唯一的出路：
        // `.basedOnSize` 保证默认档内容装得下时不回弹，看起来仍是一张静态页。
        ScrollView {
            VStack(spacing: 0) {
                OnboardingArtwork(kind: content.artwork)
                    .padding(.top, 40)
                    .padding(.bottom, 36)

                // 设计是 28/34：`.title` 的自然行高已经是 34，不再叠行距
                Text(content.title)
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(CopyoTheme.label)
                    .multilineTextAlignment(.center)

                // 17/24：`.body` 自然行高约 20，`lineSpacing` 是叠在它上面的额外间距，只补 4
                Text(content.body)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(CopyoTheme.labelSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                if !content.rows.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(content.rows) { row in
                            OnboardingRow(row: row,
                                          cloudSyncChanged: cloudSyncChanged,
                                          cloudSyncEnabled: $cloudSyncEnabled)
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// 设计 3.9 的说明行：36 圆角砖 + 标题 15 Semibold + 副文 13，右侧可挂开关。
///
/// 砖是定尺装饰（已 `accessibilityHidden`），17pt 符号跟着放大会顶破 36 × 36，所以保持写死。
private struct OnboardingRow: View {
    let row: OnboardingPageContent.Row
    let cloudSyncChanged: Bool
    @Binding var cloudSyncEnabled: Bool


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
                Text(detail)
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
                    // 开关与左边的说明是两个停留点，拨完之后旁白停在开关上，
                    // 听不到说明行换成了「重新打开后生效」，所以在开关上再挂一遍
                    .accessibilityHint(cloudSyncChanged ? detail : "")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .background(CopyoTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.group, style: .continuous))
    }

    /// iCloud 那一行在本次拨过开关后改说「重新打开后生效」：容器在启动时就按开关建好了，
    /// 这次运行里历史照旧在同步（设置页同一个开关弹的是同一句提示）。
    /// 引导页盖在根视图的轻提示上面，弹 toast 看不见，只能写在行上。
    private var detail: String {
        if row.accessory == .cloudToggle, cloudSyncChanged {
            return String(localized: "Takes effect after you reopen Copyo")
        }
        return row.detail
    }
}

// MARK: - 插图

/// 180 × 180 白卡：上面一组红蓝错位套印色条，下面是本页的符号（设计 3.9 / 05a–05c）。
///
/// 三页共用同一组色条（设计模板 left 44 / top 60，92 × 14，红压蓝各错开 3pt）。
/// design-spec 01b 说的「全 App 唯一」约束的是正文界面；ios-plan 的品牌说明写明
/// 红蓝错位「用于图标、空态和引导页的点缀」，引导页正是它该出现的地方。
/// 符号 `.padding(.top, 34)` 就是给色条让出的位置。
///
/// 卡与卡上的符号一律**不跟随**辅助功能字号：05a 的 34 / 20 / 31 三个符号是一幅
/// 「Mac ←→ iPhone」的构图，各自按自己的字号放大会把箭头顶到机器身上，画面直接走形；
/// 180 × 180 的白卡也放不下放大后的符号。整块已 `accessibilityHidden`，
/// 读屏用户拿不到任何信息，放大也就没有收益——页上的字照常放大。
private struct OnboardingArtwork: View {
    let kind: OnboardingPageContent.Artwork

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(CopyoTheme.bgCard)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 16)

            brandBars
                .frame(width: 180, height: 180, alignment: .topLeading)

            symbols
                .padding(.top, 34)
        }
        .frame(width: 180, height: 180)
        .accessibilityHidden(true)
    }

    /// 红蓝套印。写法与关于页的 BrandMark、历史空态的插画一致：
    /// 浅色 multiply 叠出深蓝，深色 screen 叠出粉色（设计 `t.blend`）
    private var brandBars: some View {
        ZStack {
            Capsule()
                .fill(CopyoTheme.Brand.red)
                .frame(width: 92, height: 14)
                .opacity(0.9)
                .offset(x: -3, y: -3)
            Capsule()
                .fill(CopyoTheme.Brand.blue)
                .frame(width: 92, height: 14)
                .opacity(0.85)
                .offset(x: 3, y: 3)
                .blendMode(colorScheme == .dark ? .screen : .multiply)
        }
        .compositingGroup()
        .padding(.leading, 44)
        .padding(.top, 60)
    }

    @ViewBuilder
    private var symbols: some View {
        switch kind {
        case .macAndPhone:
            HStack(spacing: 10) {
                // 设计画的是带底座的空心显示器，不是笔记本。`desktopcomputer`（卡片来源等处用的那个）
                // 屏幕是实心的，放在这幅线性插图里比 iPhone 重一截，所以用描边的 `display`
                Image(systemName: "display")
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
            // 设计的 64pt 托盘，网格线宽 1.5 → 64 × 1.5 / 24 = 4pt
            TrayGlyph()
                .stroke(CopyoTheme.accent,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 64)
        case .cloudCheck:
            // 设计的云描边约 4pt（64pt、网格线宽 1.5），light 字重细得撑不起 180 的卡
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 50, weight: .medium))
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

    private static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    static var all: [OnboardingPageContent] {
        [
            OnboardingPageContent(
                title: String(localized: "Your Mac clipboard, in your pocket"),
                body: String(localized: "Everything you copy on your Mac arrives here through iCloud. Search anytime, tap to copy."),
                skipTitle: String(localized: "Skip"),
                artwork: .macAndPhone
            ),
            OnboardingPageContent(
                // iPad 没有操作按钮也没有轻点背面（一键保存页在 iPad 上也只剩控制中心一段），
                // 标题里的「iPhone」同样不成立——审核员拿 iPad 看一眼就会挑出来
                title: isPad
                    ? String(localized: "Three ways to save from this iPad")
                    : String(localized: "Three ways to save from this iPhone"),
                // 与 04c 的导语不是同一句：05b 的设计文案更短（没有「所以」「内容」），单开一个 key
                body: String(localized: "iOS won't let apps read the clipboard in the background. Copyo only saves at these three moments."),
                skipTitle: String(localized: "Skip"),
                artwork: .tray,
                rows: [
                    // 三个砖里的符号都用描边款，与设计的线性图标一套（design-spec 05b：clipboard / share / bolt）
                    Row(symbol: "list.clipboard",
                        title: String(localized: "When you open Copyo"),
                        detail: String(localized: "Reads the current clipboard")),
                    Row(symbol: "square.and.arrow.up",
                        title: String(localized: "Share sheet"),
                        detail: String(localized: "“Save to Copyo” in any app")),
                    Row(symbol: "bolt",
                        title: String(localized: "Quick Save"),
                        detail: isPad
                            ? String(localized: "Control Center")
                            : String(localized: "Action Button, Back Tap or Control Center")),
                ]
            ),
            OnboardingPageContent(
                title: String(localized: "Two last things"),
                body: String(localized: "You can change both later in Settings."),
                skipTitle: String(localized: "Maybe Later"),
                artwork: .cloudCheck,
                rows: [
                    Row(symbol: "cloud",
                        title: String(localized: "iCloud Sync"),
                        detail: String(localized: "Share one history with your Mac"),
                        accessory: .cloudToggle),
                    Row(symbol: "list.clipboard",
                        title: String(localized: "Allow Paste from Other Apps"),
                        // 设计 05c 在这里挂了一枚「前往设置」。**去掉了**：iOS 只在 App 请求过一次粘贴、
                        // 弹过一次系统授权框之后，才在「设置 › Copyo」里显示「从其他 App 粘贴」这一行，
                        // 而引导页一定发生在第一次读剪贴板之前（首启只记账不读，见 PasteboardCapture）。
                        // 按下去必然落进一个找不到这一项的设置页——维护者第一次上真机就撞上了。
                        // 改成告诉用户会发生什么；设置里 04d 那页仍然有「打开 Copyo 的系统设置」
                        detail: String(localized: "iOS asks the first time Copyo reads the clipboard. Tap Allow Paste; later you can set it to Allow in Settings."),
                        accessory: .none),
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
