import Foundation

/// 「刚刚 / 3 分钟前 / 1 小时前 / 昨天 18:42 / 3 天前 / 上周 / 日期」，英文对应
/// `now / 3m / 1h / Yesterday 18:42 / 3d / Last week / 日期`。
///
/// 此前 iOS 主应用、小组件、键盘各抄了一份（design-spec 第八节第 39 条把 Mac 也并进来），
/// 本地化键逐字相同，改档位得改三处。现在四端都调这一份；`CopyoShared` 在每个 target 的
/// 同步组里，`String(localized:)` 取的是各自进程的译文表，所以**加键时每个 target 的
/// `Localizable.xcstrings` 都要补**（键：`now` / `%lldm` / `%lldh` / `%lldd` / `Last week`）。
///
/// 当天的分 / 时不走系统的 `.relative` 格式化：那个在英文下给的是 "3 minutes ago"，
/// 卡片的「来源 · 时间」一行放不下。
enum RelativeTime {
    /// - Parameter reference: 按哪个时刻算。小组件的时间线条目带自己的时刻，
    ///   必须按 `entry.date` 算，按「现在」算的话归档过的条目全会显示成生成时的那个字。
    static func string(for date: Date, reference: Date = Date()) -> String {
        let interval = reference.timeIntervalSince(date)
        if interval < 60 { return String(localized: "now") }
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: reference) {
            let minutes = Int(interval / 60)
            if minutes < 60 {
                return String(format: String(localized: "%lldm"), minutes)
            }
            return String(format: String(localized: "%lldh"), minutes / 60)
        }
        // 昨天保留「日期 + 时刻」，那就是系统相对日期格式化的结果
        if calendar.isDateInYesterday(date) {
            return dateTimeFormatter.string(from: date)
        }
        // 更早的给「3 天前 / 上周」：卡片元信息一行放不下 `2026/8/28 13:16`，截断后读不出任何时间信息
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: reference)).day ?? 0
        if days < 7 { return String(format: String(localized: "%lldd"), days) }
        if days < 14 { return String(localized: "Last week") }
        return dateOnlyFormatter.string(from: date)
    }

    /// 详情页、预览浮层用的绝对时间：`今天 14:32`
    static func absolute(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        // 「今天 / 昨天」由系统按当前语言给，自己拼会在英文下变成错误的语序
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}
