import Foundation
import SwiftData

/// 汇总需要注册进 ModelContainer 的模型类型，各平台建容器时统一引用这里。
public enum CopyoSchema {
    public static let models: [any PersistentModel.Type] = [
        ClipItem.self,
        Pinboard.self,
    ]
}
