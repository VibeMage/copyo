import PasterCore
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

    var body: some View {
        VStack(spacing: 0) {
            if let measurement {
                InfoRow(title: measurement.title) {
                    Text(measurement.value)
                        .foregroundStyle(PasterTheme.labelSecondary)
                }
                separator
            }

            InfoRow(title: String(localized: "Source")) {
                HStack(spacing: 5) {
                    Image(systemName: isFromMac ? "desktopcomputer" : "iphone")
                        .font(.system(size: 14))
                    Text(sourceValue)
                }
                .foregroundStyle(PasterTheme.labelSecondary)
            }
            separator

            InfoRow(title: String(localized: "Time")) {
                Text(timeValue)
                    .foregroundStyle(PasterTheme.labelSecondary)
            }
            separator

            Menu {
                pinboardMenu
            } label: {
                InfoRow(title: String(localized: "Pinboard")) {
                    HStack(spacing: 4) {
                        Text(item.pinboard?.name ?? String(localized: "Not pinned"))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PasterTheme.labelTertiary)
                    }
                    .foregroundStyle(PasterTheme.labelSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .background(PasterTheme.bgCard,
                    in: RoundedRectangle(cornerRadius: PasterTheme.Radius.group, style: .continuous))
    }

    private var separator: some View {
        Rectangle()
            .fill(PasterTheme.separator)
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

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(PasterTheme.label)
            Spacer(minLength: 8)
            value()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
