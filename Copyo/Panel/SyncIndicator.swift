import SwiftUI

/// 面板顶栏右侧那一格（design-spec 第八节第 13–15 条）。
///
/// 代码里可区分的同步状态有 11 种（7.5.7），这一格只表达两态：「正常」与「需要处理」，
/// 外加文件夹模式的「还没配置」。不设「同步中」——代码里读不到这个信号。
/// 形状随同步方式：iCloud 用云，共享文件夹用文件夹（第 14 条，iOS 没有对应物，不能照搬）；
/// 同步关着时整格不出现。完整的 11 态文案留在设置 · 同步页，点这一格就直达那里。
enum SyncIndicator: Equatable {
    case hidden
    case icloudOK
    case icloudNeedsAttention
    case folderOK
    /// 同步开着但还没选目录：是「未配置」不是「出错」，用灰色，不用橙色
    case folderUnset
    case folderNeedsAttention

    /// 读的是 UserDefaults 与文件系统（沙盒版要解析书签），只在面板呼出时算一次，不放进 body。
    @MainActor
    static func current() -> SyncIndicator {
        // 演示模式拍的是设计稿主态（icloud-ok）；读真实偏好的话，开发机设的同步方式会漏进截图，
        // 而且 SyncMode.current 在键缺失时还会把迁移结果写回真实偏好
        if MacDemoData.isEnabled { return .icloudOK }
        switch SyncMode.current {
        case .off:
            return .hidden
        case .icloud:
            let containerError = UserDefaults.standard.string(forKey: CloudSyncStatus.containerErrorKey) ?? ""
            let active = AppDelegate.shared?.cloudKitActive ?? false
            // 没挂上镜像（没签 entitlement、建容器失败、改了方式还没重启）一律算需要处理
            return active && containerError.isEmpty ? .icloudOK : .icloudNeedsAttention
        case .folder:
#if APPSTORE
            if SyncService.syncRoot != nil { return .folderOK }
            let lostAccess = UserDefaults.standard.string(forKey: SyncService.lastErrorKey)
                == SyncService.SyncFailure.noAccess.rawValue
            return lostAccess ? .folderNeedsAttention : .folderUnset
#else
            // 直接分发版默认走 iCloud Drive，不存在「没选目录」；目录够不着就是需要处理
            return SyncService.isAvailable ? .folderOK : .folderNeedsAttention
#endif
        }
    }

    var help: String {
        switch self {
        case .hidden: ""
        case .icloudOK: String(localized: "iCloud is in sync")
        case .icloudNeedsAttention: String(localized: "iCloud sync needs attention")
        case .folderOK: String(localized: "Shared folder is in sync")
        case .folderUnset: String(localized: "No sync folder selected")
        case .folderNeedsAttention: String(localized: "Choose the sync folder again")
        }
    }
}

/// 同步格的图标。文件夹的「需要处理」没有现成符号，用 folder + 右下角橙色感叹号拼出来。
struct SyncIndicatorIcon: View {
    let state: SyncIndicator

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .icloudOK:
            symbol("checkmark.icloud", CopyoTheme.success)
        case .icloudNeedsAttention:
            symbol("exclamationmark.icloud", CopyoTheme.warning)
        case .folderOK:
            symbol("folder", CopyoTheme.success)
        case .folderUnset:
            symbol("folder.badge.questionmark", CopyoTheme.labelSecondary)
        case .folderNeedsAttention:
            symbol("folder", CopyoTheme.warning)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(CopyoTheme.warning)
                        .background(Circle().fill(CopyoTheme.bgGrouped).padding(1))
                        .offset(x: 3, y: 3)
                }
        }
    }

    /// 画板 17pt、线宽 1.5 → .regular（第八节第 25 条；5.2 表「同步格」行、5.2.1；gen_v2.py:180）
    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(color)
    }
}
