import SwiftUI

/// 设计 06：分享面板「保存到 Copyo」。
///
/// 放在 CopyoShared 而不是扩展目录里，是为了让主应用的 `-demoScreen share` 用**同一份视图**截图——
/// 分享扩展在模拟器里没法从系统分享面板拉起来，只能靠这条路核对设计。
/// 因此这里不能出现任何扩展专属 API（`extensionContext`、`NSExtensionItem` 都留在 ShareViewController 里）。
public struct ShareView: View {

    /// 要保存的内容。附件读取失败时为 nil，此时用 `loadErrorMessage` 说明原因。
    public var payload: SharePayload?
    public var loadErrorMessage: String?
    public var boards: [ShareBoardOption]
    public var onCancel: () -> Void
    /// 真正的入库动作。抛错时由本视图弹 Alert，成功由调用方负责收尾（扩展要 completeRequest）。
    public var onSave: (SharePayload, ShareBoardOption?) async throws -> Void

    @State private var selectedBoard: ShareBoardOption?
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 48 的行高、52 的按钮高、60 的「取消」栏宽都落不到系统样式表上，一律按 `.body` 缩：
    /// 这三处框住的都是 17pt（正好是 `.body`）的字，用同一把尺子才不会字长了框没长。
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = Metrics.rowHeight
    @ScaledMetric(relativeTo: .body) private var saveButtonMinHeight: CGFloat = Metrics.saveButtonHeight
    @ScaledMetric(relativeTo: .body) private var headerSideWidth: CGFloat = Metrics.headerSideWidth

    /// 面板顶上至少留出这么高的遮罩。内容再多也不能让面板顶到屏幕最上沿——
    /// 那样看不出宿主界面还在后面，也没地方点空白取消，面板会被当成一个卡住的整屏页面。
    private static let minDimHeight: CGFloat = 56
    /// 容器高度在首帧可能还量不出来（0），上限至少给这么多，否则会算成负数、面板闪一下
    private static let minSheetHeight: CGFloat = 240

    // MARK: - 分享面板专属尺寸（design-spec 3.10）

    /// 只有这块面板用得上的几个数，没有跟着别的 token 进 `CopyoTheme`——
    /// 那张表是主应用、分享扩展、Widget 三个 target 共用的，
    /// 把「保存按钮高 52」放进去等于让另外两边也看见一个与它们无关的值。
    private enum Metrics {
        static let rowHeight: CGFloat = 48
        static let saveButtonHeight: CGFloat = 52
        static let headerSideWidth: CGFloat = 60
        static let sheetBottomPad: CGFloat = 44
        /// 抓手 / 标题 / 预览卡 / Pinboard 行 / 「保存」之间的统一间距
        static let gap: CGFloat = 16
    }

    public init(payload: SharePayload?,
                loadErrorMessage: String? = nil,
                boards: [ShareBoardOption] = [],
                onCancel: @escaping () -> Void,
                onSave: @escaping (SharePayload, ShareBoardOption?) async throws -> Void) {
        self.payload = payload
        self.loadErrorMessage = loadErrorMessage
        self.boards = boards
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // 宿主界面在 sheet 后加暗（design-spec 3.10）。点击暗部等于取消，与系统 sheet 一致。
                CopyoTheme.dim
                    .contentShape(Rectangle())
                    .onTapGesture { if !isSaving { onCancel() } }
                    // 遮罩只是「点空白取消」的热区，让旁白停在一整块纯色上没有意义。
                    // 取消这个动作在标题左边的按钮上，也接到了下面的 escape 手势上，功能不会丢
                    .accessibilityHidden(true)

                sheet
                    .frame(maxHeight: max(Self.minSheetHeight, proxy.size.height - Self.minDimHeight),
                           alignment: .bottom)
            }
            // 面板比容器还高时（辅助功能字号 + 长内容）必须底对齐。不写这层 frame 的话
            // ZStack 会跟着内容一起长高，再被 GeometryReader 按左上角摆，「保存」按钮直接掉到屏幕外
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // 面板要贴到屏幕最底下（design-spec 3.10 是贴底的 radius 38 面板），
        // 底部 44 的内距本身就把内容让出了 Home 指示条的位置
        .ignoresSafeArea()
        // 旁白的「返回」手势（两指擦除）在自定义面板上没有默认行为，手动接到取消上——
        // 否则旁白用户想退出只能一路摸到左上角那个按钮
        .accessibilityAction(.escape) { if !isSaving { onCancel() } }
        .alert(String(localized: "Couldn't save"),
               isPresented: .init(get: { errorMessage != nil },
                                  set: { if !$0 { errorMessage = nil } })) {
            Button(String(localized: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 面板

    private var sheet: some View {
        VStack(spacing: Metrics.gap) {
            grabber
            // 放得下就按自然高度摆（默认字号下与改造前逐像素一致），放不下才滚。
            // 不能直接套一层 ScrollView：ScrollView 会把提议到的高度全吃掉，
            // 默认字号下面板也会一路撑成整屏。
            ViewThatFits(in: .vertical) {
                scrollableContent
                ScrollView(.vertical) { scrollableContent }
            }
            // 「保存」按钮留在滚动区外面：分享面板是一次性的，按钮滚出屏幕就等于这条内容存不进来，
            // 比字小读不清严重得多
            saveButton
        }
        .padding(.horizontal, CopyoTheme.Metrics.pageInset)
        .padding(.bottom, Metrics.sheetBottomPad)
        .frame(maxWidth: .infinity)
        .background(CopyoTheme.sheet)
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: CopyoTheme.Radius.sheet,
                                   topTrailingRadius: CopyoTheme.Radius.sheet,
                                   style: .continuous)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: -8)
    }

    /// 抓手与「保存」之间的那一段。`ViewThatFits` 要拿它量两遍，所以单独抽出来。
    private var scrollableContent: some View {
        VStack(spacing: Metrics.gap) {
            header
            if let payload {
                SharePreviewCard(payload: payload)
                pinboardRow
            } else if let loadErrorMessage {
                unavailableCard(message: loadErrorMessage)
            } else {
                // 附件还在读（大图要走一次降采样，可能有几百毫秒）
                loadingCard
            }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(CopyoTheme.labelTertiary)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onCancel) {
                Text(String(localized: "Cancel"))
                    .font(.body)
                    .foregroundStyle(CopyoTheme.accent)
                    // 辅助功能字号下「取消」自己就要 180pt 宽，再锁 60 的定宽会把它截成「取…」
                    .frame(width: usesCenteredHeader ? headerSideWidth : nil, alignment: .leading)
            }
            .disabled(isSaving)

            // 居中排法里两边的占位已经隔开了标题，这道下限只在非居中排法下起作用：
            // 不给的话辅助功能字号下「取消」和标题会贴在一起，读成一个词
            Spacer(minLength: usesCenteredHeader ? 0 : 12)
            HStack(spacing: 8) {
                CopyoMark()
                Text(String(localized: "Save to Copyo"))
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(CopyoTheme.label)
            }
            Spacer(minLength: 0)

            // 右侧留同宽的空占位，标题才是真正居中的（design-spec 3.10）。
            // 辅助功能字号下这块占位会和左边一起吃掉将近 400pt，中间连一个字都排不下，
            // 那时候宁可不居中：两侧的 Spacer 会把标题摆在「取消」右边的剩余空间正中，读得完更要紧
            if usesCenteredHeader {
                Color.clear.frame(width: headerSideWidth, height: 1)
            }
        }
    }

    /// 标题还按设计 3.10 居中排（非辅助功能字号）。
    /// 抽成一个判断而不是散在三处，是为了让「左边定宽」「右边占位」「中间下限」永远同进同退——
    /// 只改其中一处，标题就会偏出去半个「取消」的宽度。
    private var usesCenteredHeader: Bool { !dynamicTypeSize.isAccessibilitySize }

    // MARK: - 固定到 Pinboard

    @ViewBuilder
    private var pinboardRow: some View {
        if boards.isEmpty {
            // 一个板都没有时不给菜单：点开只有「不固定」一项是在耍人
            optionRow(value: String(localized: "No pinboards"), showsChevron: false)
        } else {
            Menu {
                Picker(String(localized: "Pin to Pinboard"), selection: $selectedBoard) {
                    Text(String(localized: "Don't pin")).tag(ShareBoardOption?.none)
                    ForEach(boards) { board in
                        Label(board.name, systemImage: board.iconName ?? "pin.fill")
                            .tag(ShareBoardOption?.some(board))
                    }
                }
            } label: {
                optionRow(value: selectedBoard?.name ?? String(localized: "Don't pin"),
                          showsChevron: true)
            }
            .disabled(isSaving)
        }
    }

    private func optionRow(value: String, showsChevron: Bool) -> some View {
        HStack(spacing: 0) {
            Text(String(localized: "Pin to Pinboard"))
                .font(.body)
                .foregroundStyle(CopyoTheme.label)
            Spacer(minLength: 12)
            HStack(spacing: 4) {
                Text(value)
                    .font(.body)
                    .lineLimit(1)
                    // 板名是用户自己起的，截成「工作…」就认不出是哪个板了；
                    // 先缩到 0.8（全应用统一的下限）再谈截断
                    .minimumScaleFactor(0.8)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                }
            }
            .foregroundStyle(CopyoTheme.labelSecondary)
        }
        .padding(.horizontal, 16)
        // 标题放大后会折成两行，写死 `height` 会把第二行整条切掉。默认档内容高 22 + 16 内距 = 38 < 48，
        // `minHeight` 兜回 48——默认字号下逐像素不变
        .padding(.vertical, 8)
        .frame(minHeight: rowMinHeight)
        .background(CopyoTheme.rowOpaque,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        // 旁白读成「固定到 Pinboard，不固定」一句：标题是名字、当前选择是取值。
        // 拆成两个停留点的话，光标停在「不固定」上根本看不出这是哪一项的取值；
        // 这一行外面还套着 Menu，`accessibilityValue` 正好让它每次选完都把新板名念一遍
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Pin to Pinboard"))
        .accessibilityValue(value)
    }

    // MARK: - 读不出内容

    private func unavailableCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(localized: "Nothing to save"), systemImage: "exclamationmark.triangle.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(CopyoTheme.label)
            Text(message)
                .font(.footnote)
                .foregroundStyle(CopyoTheme.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CopyoTheme.Metrics.cardPad)
        .background(CopyoTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
        // 「读不出内容」和它下面那句原因是一件事，读成两个停留点会让人以为漏了什么
        .accessibilityElement(children: .combine)
    }

    private var loadingCard: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            // 96 框的是一个转圈，不是文字，不跟随动态字体
            .frame(height: 96)
            .background(CopyoTheme.tint(sourceHex: nil),
                        in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.card, style: .continuous))
            // 转圈不带文字，旁白停上来就是一个没有名字的元素——
            // 用户分不清是还在读附件还是已经坏了，而这一格正是「保存」能不能点的原因
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Loading…"))
    }

    // MARK: - 保存

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(.body, weight: .semibold))
                        // 符号只是「保存」两个字的装饰，读屏念出 tray and arrow down fill 没有意义
                        .accessibilityHidden(true)
                }
                Text(String(localized: "Save"))
                    .font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(.white)
            // 「Enregistrer」放大后会折行，靠内距撑开；默认档 22 的行高 + 28 内距 = 50 < 52，
            // 按钮仍是设计给的 52
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: saveButtonMinHeight)
            .background(CopyoTheme.accent, in: Capsule())
            .opacity(payload == nil ? 0.4 : 1)
        }
        .disabled(payload == nil || isSaving)
    }

    private func save() {
        guard let payload, !isSaving else { return }
        isSaving = true
        Task {
            do {
                try await onSave(payload, selectedBoard)
                // 扩展里 onSave 成功后会立刻 completeRequest 把界面撤掉，收不收无所谓；
                // 但主应用的演示路由不会撤，不收就永远转圈
                isSaving = false
            } catch {
                // 扩展里没有别的地方能报错，失败必须让用户看见，否则内容悄悄丢了
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

/// 标题旁那枚 26pt 应用标记。
///
/// 设计稿这里画的是 App 图标，但扩展 bundle 里没有图标资源（图标只在主应用的 Assets 里），
/// 跨进程取自己的图标也没有公开 API，所以按品牌语言（骨白卡片 + 红蓝错位套印）现画一枚，
/// 与空态插画同源。
///
