import SwiftUI

/// `-demoScreen share` 的宿主：在主应用里用**分享扩展的同一份 `ShareView`** 展示设计 06。
///
/// 分享扩展在模拟器里没法从系统分享面板拉起来（`simctl openurl` 打不开分享面板），
/// 唯一能核对这一帧设计的办法就是在主应用里挂同一个视图。因为共用的是 PasterShared 里那份实现，
/// 这里看到的间距、字号、圆角就是扩展里跑的那一套。
///
/// 只在 `-demoScreen share` 下出现，正常启动这一层完全不存在。
struct ShareDemoOverlay: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        if model.demoRoute == .share {
            content
                // 设计 06：宿主界面 blur(2) + opacity .6，遮罩由 ShareView 自己叠
                .blur(radius: 2)
                .opacity(0.6)
                .overlay {
                    ShareView(payload: DemoSharePayload.current,
                              boards: boards,
                              onCancel: {},
                              onSave: { _, _ in })
                }
        } else {
            content
        }
    }

    private var boards: [ShareBoardOption] {
        model.pinboards().map {
            ShareBoardOption(id: $0.persistentModelID,
                             name: $0.name,
                             iconName: $0.iconName,
                             colorHex: $0.colorHex)
        }
    }
}

extension View {
    func shareDemoOverlay() -> some View {
        modifier(ShareDemoOverlay())
    }
}

/// 设计 06 预览卡里那段文案（design-spec 1.06）。英文版自己写，不硬翻中文。
enum DemoSharePayload {
    static var current: SharePayload {
        .text(isEnglish ? english : chinese, rtfData: nil)
    }

    private static var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier != "zh"
    }

    private static let chinese = "Liquid Glass 是一种动态材质，会根据背后的内容折射光线并实时响应移动。标签栏、工具栏与搜索栏默认采用该材质。"

    private static let english = "Liquid Glass is a dynamic material that refracts the content behind it and responds to movement in real time. Tab bars, toolbars, and search fields use it by default."
}
