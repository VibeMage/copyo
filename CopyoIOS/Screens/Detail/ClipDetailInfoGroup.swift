import CopyoCore
import SwiftUI

/// 详情页的信息组（design-spec 3.13）：inset grouped 卡片，行高 44、内距 16、
/// 左标题 15 `label` + 右值 `label.secondary`，行间 .5pt 分隔线。
///
/// 不用 `List`：这一屏是 ScrollView（预览块要跟着一起滚），List 套进去会变成两层滚动。
struct ClipDetailInfoGroup: View {
    let item: ClipItem
    let boards: [Pinboard]
    var onPin: (Pinboard) -> Void
    var onUnpin: () -> Void

    /// 来源图标的 14pt 不在系统样式表上，按行文字的 subheadline 缩，两者才会一起长
    @ScaledMetric(relativeTo: .subheadline) private var sourceSymbolSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            if let measurement {
                InfoRow(title: measurement.title) {
                    Text(measurement.value)
                        .foregroundStyle(CopyoTheme.labelSecondary)
                }
                separator
            }

            InfoRow(title: String(localized: "Source")) {
                HStack(spacing: 5) {
                    Image(systemName: isFromMac ? "desktopcomputer" : "iphone")
                        .font(.system(size: sourceSymbolSize))
                        // 旁边的值已经写了「… · Mac」，这枚图标只是重复一遍
                        .accessibilityHidden(true)
                    Text(sourceValue)
                }
                .foregroundStyle(CopyoTheme.labelSecondary)
            }
            separator

            InfoRow(title: String(localized: "Time")) {
                Text(timeValue)
                    .foregroundStyle(CopyoTheme.labelSecondary)
            }
            separator

            Menu {
                pinboardMenu
            } label: {
                InfoRow(title: String(localized: "Pinboard")) {
                    HStack(spacing: 4) {
                        Text(item.pinboard?.name ?? String(localized: "Not pinned"))
                        Image(systemName: "chevron.right")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(CopyoTheme.labelTertiary)
                            // 展开指示符：这一行本来就是 `Menu`，旁白已经会报「按钮」
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(CopyoTheme.labelSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .background(CopyoTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: CopyoTheme.Radius.group, style: .continuous))
    }

    private var separator: some View {
        Rectangle()
            .fill(CopyoTheme.separator)
            .frame(height: 0.5)
    }

    // MARK: - 首行：字数 / 尺寸 / 文件数

    private var measurement: (title: String, value: String)? {
        switch item.kind {
        case .image:
            guard let metadata = item.imageMetadata else { return nil }
            return (String(localized: "Dimensions"), metadata)
        case .file:
            let count = max(item.filePaths.count, 1)
            // 单复数分开写：英文的 "1 files" 读着别扭，中文两条译文一样
            let value = count == 1 ? String(localized: "1 file") : String(localized: "\(count) files")
            return (String(localized: "Files"), value)
        case .color:
            // 设计 02b 的颜色详情没有字数行
            return nil
        case .text, .richText, .link:
            let count = item.charCount > 0 ? item.charCount : (item.plainText?.count ?? 0)
            guard count > 0 else { return nil }
            let value = count == 1
                ? String(localized: "1 character")
                : String(localized: "\(count) characters")
            return (String(localized: "Characters"), value)
        }
    }

    // MARK: - 来源

    /// Mac 采集的条目才有来源 App 名；iOS 本机存的一律没有（沙盒里拿不到别的 App）
    private var isFromMac: Bool {
        !(item.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var sourceValue: String {
        isFromMac ? "\(item.sourceDisplayName) · Mac" : item.sourceDisplayName
    }

    // MARK: - 时间

    /// 今天 / 昨天走系统的相对日期（`今天 14:32`），更早的给完整日期。
    private var timeValue: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: item.createdAt),
                                           to: calendar.startOfDay(for: Date())).day ?? 0
        if days <= 1 { return item.absoluteTime }
        return item.createdAt.formatted(.dateTime.year().month(.abbreviated).day().hour().minute())
    }

    // MARK: - Pinboard 选择

    @ViewBuilder
    private var pinboardMenu: some View {
        ForEach(boards) { board in
            Button {
                onPin(board)
            } label: {
                Label {
                    Text(board.name)
                } icon: {
                    Image(systemName: board.persistentModelID == item.pinboard?.persistentModelID
                          ? "checkmark"
                          : (board.iconName ?? "pin"))
                }
            }
        }
        if item.pinboard != nil {
            Divider()
            Button(role: .destructive, action: onUnpin) {
                Label(String(localized: "Remove from Pinboard"), systemImage: "pin.slash")
            }
        }
    }
}

/// 信息组的一行。高度按设计固定 44，但用 minHeight——大字号下要能撑开。
private struct InfoRow<Value: View>: View {
    let title: String
    @ViewBuilder var value: () -> Value

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // 辅助功能档位下左右并排必然互相挤：`Pinboard` 和一个中文板名各分半行，
        // 两边一起被截成两三个字。改成上下排，标题和值都能用满整行宽度。
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text(title)
                .foregroundStyle(CopyoTheme.label)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            // `Spacer` 在竖排里会撑高整行，只在横排时放
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            value()
                // **必须是单行**：这一行的高度是设计稿定死的 44，折成两行连同上下内距就是 56，
                // `minHeight: 44` 再也说了不算，同一组里有的行 44 有的行 56。
                // 而默认档位下就能溢出的是板名（用户自己起的，没有长度上限）和长一点的来源名，
                // 不是只有放大档位才会碰到的事。
                // 这两个值头尾都认得出来（「工作 · 需求文档」掐成「工作 …」就只剩前半句），
                // 所以掐中间比掐尾巴留得多。
                .lineLimit(1)
                .truncationMode(.middle)
                // 先缩到 0.8 再截断：放大档位下宁可小一号，也好过少给几个字。
                // 0.8 是全项目统一的下限
                .minimumScaleFactor(0.8)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil,
                       alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        // 上下各 8：默认档位下 15pt 文字连内距才 36，仍然被 minHeight 44 顶成 44（逐像素不变），
        // 放大档位下撑开之后文字才不会贴着分隔线
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
