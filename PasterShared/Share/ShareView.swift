import SwiftUI

/// 设计 06：分享面板「保存到 Paster」。
///
/// 放在 PasterShared 而不是扩展目录里，是为了让主应用的 `-demoScreen share` 用**同一份视图**截图——
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
        ZStack(alignment: .bottom) {
            // 宿主界面在 sheet 后加暗（design-spec 3.10）。点击暗部等于取消，与系统 sheet 一致。
            ShareTheme.dim
                .contentShape(Rectangle())
                .onTapGesture { if !isSaving { onCancel() } }

            sheet
        }
        // 面板要贴到屏幕最底下（design-spec 3.10 是贴底的 radius 38 面板），
        // 底部 44 的内距本身就把内容让出了 Home 指示条的位置
        .ignoresSafeArea()
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
        VStack(spacing: ShareTheme.Metrics.gap) {
            grabber
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
            saveButton
        }
        .padding(.horizontal, ShareTheme.Metrics.pageInset)
        .padding(.bottom, ShareTheme.Metrics.sheetBottomPad)
        .frame(maxWidth: .infinity)
        .background(ShareTheme.sheet)
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: ShareTheme.Metrics.sheetRadius,
                                   topTrailingRadius: ShareTheme.Metrics.sheetRadius,
                                   style: .continuous)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: -8)
    }

    private var grabber: some View {
        Capsule()
            .fill(ShareTheme.labelTertiary)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button(action: onCancel) {
                Text(String(localized: "Cancel"))
                    .font(.system(size: 17))
                    .foregroundStyle(ShareTheme.accent)
                    .frame(width: ShareTheme.Metrics.headerSideWidth, alignment: .leading)
            }
            .disabled(isSaving)

            Spacer(minLength: 0)
            HStack(spacing: 8) {
                PasterMark()
                Text(String(localized: "Save to Paster"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ShareTheme.label)
            }
            Spacer(minLength: 0)

            // 右侧留同宽的空占位，标题才是真正居中的（design-spec 3.10）
            Color.clear.frame(width: ShareTheme.Metrics.headerSideWidth, height: 1)
        }
    }

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
                .font(.system(size: 17))
                .foregroundStyle(ShareTheme.label)
            Spacer(minLength: 12)
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 17))
                    .lineLimit(1)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(ShareTheme.labelSecondary)
        }
        .padding(.horizontal, 16)
        .frame(height: ShareTheme.Metrics.rowHeight)
        .background(ShareTheme.rowBackground,
                    in: RoundedRectangle(cornerRadius: ShareTheme.Metrics.cardRadius, style: .continuous))
    }

    // MARK: - 读不出内容

    private func unavailableCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(localized: "Nothing to save"), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ShareTheme.label)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ShareTheme.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ShareTheme.Metrics.cardPad)
        .background(ShareTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: ShareTheme.Metrics.cardRadius, style: .continuous))
    }

    private var loadingCard: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(ShareTheme.tint(sourceHex: nil),
                        in: RoundedRectangle(cornerRadius: ShareTheme.Metrics.cardRadius, style: .continuous))
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
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(String(localized: "Save"))
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ShareTheme.Metrics.saveButtonHeight)
            .background(ShareTheme.accent, in: Capsule())
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
