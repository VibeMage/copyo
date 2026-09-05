import PasterCore
import SwiftData
import SwiftUI

extension View {
    /// 截图用：`-demoScreen detail-*` 时把对应类型的样例条目推进当前导航栈。
    /// 挂在历史标签的 `NavigationStack` 内层，正常启动时什么都不做。
    func demoDetailDestination() -> some View {
        modifier(DemoDetailDestination())
    }
}

private struct DemoDetailDestination: ViewModifier {
    @Environment(AppModel.self) private var model

    @State private var item: ClipItem?
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $isPresented) {
                if let item {
                    ClipDetailScreen(item: item)
                }
            }
            .task {
                guard item == nil, let kind = DemoDetailRoute.requestedKind else { return }
                item = DemoDetailRoute.sample(of: kind, in: model.modelContext)
                guard item != nil else { return }
                // 等导航栈自己挂好再推：首帧就翻 isPresented 会被丢掉
                try? await Task.sleep(for: .milliseconds(300))
                isPresented = true
            }
    }
}

/// `-demoScreen` 里属于详情页的取值。
///
/// `DemoRoute` 只列了 detail-text / detail-color / detail-image / detail-link 四个，
/// 富文本与文件也要出图，所以这里直接解析启动参数，多认 `detail-rich` 与 `detail-file` 两个值——
/// 这样不必去改 `LaunchOptions`（那是壳代理的文件，多人并行改必冲突）。
enum DemoDetailRoute {

    /// 这次启动要打开哪种类型的详情；不是详情路由就返回 nil
    static var requestedKind: ClipKind? {
        guard let raw = value(of: "-demoScreen") else { return nil }
        switch raw {
        case "detail-text": return .text
        case "detail-color": return .color
        case "detail-image": return .image
        case "detail-link": return .link
        case "detail-rich": return .richText
        case "detail-file": return .file
        default: return nil
        }
    }

    /// 挑一条最贴近设计稿的样例：文本取来源是 Mac 且非等宽的那条（02 用的是微信长文本），
    /// 其余类型取最新的一条。
    static func sample(of kind: ClipKind, in context: ModelContext) -> ClipItem? {
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let items = try? context.fetch(descriptor) else { return nil }
        let sameKind = items.filter { $0.kind == kind }
        if kind == .text {
            return sameKind.first(where: { $0.sourceAppName != nil && !$0.isMono }) ?? sameKind.first
        }
        return sameKind.first
    }

    private static func value(of flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        let value = arguments[index + 1]
        return value.hasPrefix("-") ? nil : value
    }
}
