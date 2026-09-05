import Foundation
import PasterCore

/// 主应用与两个扩展共享容器的标识符。
/// 真值在 PasterCore 里，这里只是三个进程共用的简称，避免各处硬编码字符串。
public enum PasterAppGroup {
    public static let identifier = PasterStore.appGroupIdentifier
}
