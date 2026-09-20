import AppKit
import CopyoCore
import SwiftData

/// 「删除所有数据」。和「清空历史记录」不同：这里连固定内容和 Pinboard 一起删，
/// 还要管 delete + save 够不着的几处——磁盘上的残留、同步文件夹里的那份、
/// 以及擦完之后别的设备会不会把旧内容再灌回来。
enum DataEraser {
    /// 下次启动建容器之前要不要把库文件整个删掉重建
    static let pendingScrubKey = "pendingStoreScrub"
    /// 刚擦过一次，下次启动要给用户一句交代（应用会自己重启，不说的话像崩了）
    static let justErasedKey = "justErasedAll"
    /// 擦除时这次会话正挂着 CloudKit 镜像：删除已经排进导出队列，但我们无从知道它
    /// 什么时候推完。置位期间设置页挂一行说明，从 iCloud 切走时也换一段更重的提示。
    static let cloudWipePendingKey = "cloudWipePending"
    /// 这台 Mac 在 iCloud 同步关着的时候擦过一次：云端那份没动过，
    /// 用户再打开 iCloud 同步有可能把删掉的条目整份导回来。
    static let icloudCopyMayRemainKey = "icloudCopyMayRemain"
    /// 这份库被 CloudKit 镜像打开过。1.0 (2) 之后的启动才记得下，
    /// 老用户靠 CopyoStore.hasCloudKitArtifacts 认。
    static let everMirroredKey = "hasEverMirroredToCloudKit"

    enum Outcome: Equatable {
        /// 什么都没删：fetch 或 save 失败
        case failed
        /// 本机删干净了，正在重启去做文件级清除
        case relaunching
        /// 本机删干净了，但这次会话挂着 CloudKit 镜像：必须留在原容器里把删除推上去，
        /// 所以既不重启也不删库文件
        case cloudWipePending
        /// 本机删干净了，但 iCloud 上那份这次会话够不着，库文件也不能删
        case icloudCopyRemains
        /// 本机删干净了，但重启没派出去；标记留着，下次启动照样清库文件
        case relaunchFailed
    }

    struct Result {
        var outcome: Outcome
        /// 同步文件夹够不着，本机写进去的那份快照没能删掉
        var syncFolderUnreachable = false
    }

    /// 这份库有没有被 CloudKit 镜像打开过
    @MainActor
    static var hasEverMirrored: Bool {
        if UserDefaults.standard.bool(forKey: everMirroredKey) { return true }
        guard let url = AppDelegate.shared?.storeURL else { return false }
        return CopyoStore.hasCloudKitArtifacts(at: url)
    }

    /// 删完之后能不能删库文件重建。只有「既没有活着的镜像、也没有一份够不着的 iCloud
    /// 副本」时才可以——否则删掉文件等于把服务器上那份变成永远删不掉的孤儿。
    @MainActor
    static var willRelaunch: Bool {
        AppDelegate.shared?.cloudKitActive != true && !hasEverMirrored
    }

    /// 确认框正文。iCloud 那两句、文件夹那句、重启那句都是承诺，只能在成立的情况下出现。
    @MainActor
    static var confirmationMessage: String {
        var parts = [String(localized: "This deletes every clipboard entry and every Pinboard, including everything pinned to them. This action cannot be undone.")]
        if AppDelegate.shared?.cloudKitActive == true {
            // 镜像活着 = 删除会进导出队列。但「容器建得起来」不等于「传得出去」：
            // hasCloudKitEntitlement 只是签名检查，没登录 iCloud 账号时队列会一直堆着，
            // 所以这句话只说「排进队列」，不把到达说死。
            parts.append(String(localized: "The same deletion is queued for your iCloud private database and your other Macs. Keep Copyo open and signed in to iCloud until it finishes — Copyo cannot tell you when that is."))
        } else if hasEverMirrored {
            // 这是默认设置下最容易踩的一格：用过 iCloud、后来关掉了，云端那份还在，
            // 而这次会话一个字节都推不动。不说的话用户会以为已经删干净了。
            parts.append(String(localized: "This Mac has synced with iCloud before. Copyo cannot touch the iCloud copy while sync is off — set Sync to iCloud, reopen Copyo and delete again to remove that copy too."))
        }
        if SyncMode.current == .folder {
            parts.append(String(localized: "Copyo deletes the snapshots and images it put in your sync folder, and turns Shared Folder sync off: folder sync has no way to tell your other Macs to delete anything, so leaving it on would copy their history straight back. What those Macs put in the folder stays until you delete it yourself."))
        }
        if willRelaunch {
            // 应用会自己退出再起来。LSUIElement 没有 Dock 图标也没有窗口，
            // 事先不说一声，菜单栏图标一消失就是一份崩溃报告。
            parts.append(String(localized: "Copyo will restart itself to finish clearing the database file."))
        }
        return parts.joined(separator: " ")
    }

    @MainActor
    static func eraseAll() -> Result {
        guard let app = AppDelegate.shared else { return Result(outcome: .failed) }
        let context = app.container.mainContext

        // 面板的 @State 里攥着 ClipItem（pendingPinItem），删完再往它身上写就是写已删对象。
        // hide() 是带动画的、而且面板没开时直接返回，所以这里走同步那条路，
        // 并且额外发一次通知让面板把这些瞬时状态清掉——宿主视图与进程同寿命，不会重建。
        app.panelController.hideImmediately()
        NotificationCenter.default.post(name: .copyoDidEraseAll, object: nil)
        // 0.3s 的轮询挂在 .common 模式上，确认框弹着的时候照样在跑；
        // 后台转码的那一条也可能正要落库
        app.monitor.stop()
        app.monitor.invalidatePendingCaptures()

        // 先条目后 Pinboard。条目删光之后每个 Pinboard 的 items 已经是空的；
        // 反过来删会让固定内容先变成未固定条目，中间那一瞬 trimHistory 会按上限去砍。
        let items: [ClipItem]
        do {
            items = try context.fetch(FetchDescriptor<ClipItem>())
        } catch {
            app.monitor.start()
            return Result(outcome: .failed)
        }
        // 同步文件夹里的图片按内容哈希命名，条目一删就再也算不出来，先留一份
        let imageHashes = Set(items.compactMap(\.imageHash))
        for item in items { context.delete(item) }
        // 这两次 save 绝不能用 try? 吞掉。既有的「清空历史记录」那样写没问题，那里
        // 最坏就是「没清掉」；这里失败的话行还原样在盘上、也还在用户的 iCloud 私有
        // 数据库里，而界面上的 @Query 已经刷成空了——不报出来用户会以为擦干净了。
        do {
            try context.save()
        } catch {
            context.rollback()
            app.monitor.start()
            return Result(outcome: .failed)
        }

        // Pinboard 的 items 是 .nullify，单删 Pinboard 只会取消固定，什么都不会少
        let boards = (try? context.fetch(FetchDescriptor<Pinboard>())) ?? []
        for board in boards { context.delete(board) }
        do {
            try context.save()
        } catch {
            context.rollback()
            app.monitor.start()
            return Result(outcome: .failed)
        }

        // 缓存只在内存里，但键是 imageHash，相同字节的新条目会命中旧缩略图
        ThumbnailCache.removeAll()

        var result = Result(outcome: .relaunching)
        // 同步文件夹要在关掉同步之前清：eraseExportedSnapshot 自己会判 mode
        if SyncMode.current == .folder {
            let folder = app.syncService.eraseExportedSnapshot(extraImageHashes: imageHashes)
            result.syncFolderUnreachable = folder == .noAccess
            // 快照协议没有删除动作：别的 Mac 下一轮会把它们的全部历史重新送过来，
            // 按完「删除所有数据」30 秒就被填回去。所以擦除同时把文件夹同步关掉。
            //
            // 这里故意不做「按时间戳设一个导入下限」那种方案：下限是本机的墙上时钟，
            // 而过滤比的是条目创建设备写下的 createdAt，对方时钟慢几分钟就会把人家
            // 真正的新内容静默丢掉。syncCursors 一个都不能清——清掉等于把每台设备的
            // 游标退回 .distantPast，下一轮把所有快照整份重新导入。
            UserDefaults.standard.set(SyncMode.off.rawValue, forKey: SyncMode.defaultsKey)
        }
        app.syncService.updateActivation()

        // 剪贴板上那条最敏感的内容还躺在那儿，不对齐基线的话下一次轮询立刻重新记下来
        app.monitor.ignoreNextChange()
        app.monitor.start()

        let defaults = UserDefaults.standard

        // 挂着 CloudKit 的会话绝不能重启去删库文件：待推送的删除就记在这个文件的
        // ANSCKRECORDMETADATA 里（ZNEEDSCLOUDDELETE），文件一删，服务器上那份就
        // 永远没人去删了。宁可留下本地残留，也不能留下云端副本。
        if app.cloudKitActive {
            defaults.set(true, forKey: cloudWipePendingKey)
            result.outcome = .cloudWipePending
            return result
        }
        // 用过 iCloud、现在关着：云端那份这次会话够不着，而库文件里装着服务器变更
        // 令牌——删掉它，用户下次打开 iCloud 同步时容器会当成全新的库，把整个 zone
        // 原样导回来。本地残留是「取证手段才捞得到」的坏，整份历史复活是确定的坏。
        if hasEverMirrored {
            defaults.set(true, forKey: icloudCopyMayRemainKey)
            result.outcome = .icloudCopyRemains
            return result
        }

        // justErased 只在真要重启的那条路上置位：另外两条路当场就弹了结果对话框，
        // 再置位的话下次启动会重复弹一遍「已全部删除」。
        defaults.set(true, forKey: justErasedKey)
        defaults.set(true, forKey: pendingScrubKey)
        guard PasteService.relaunch(arguments: ["-showSettings",
                                                "-settingsTab", String(SettingsTab.clipboard.rawValue)]) else {
            // 标记留着不清：下次启动——用户自己退出再打开也算——照样把库文件清掉。
            // 这一步幂等，清掉反而等于把唯一的文件级清除永久取消。
            result.outcome = .relaunchFailed
            return result
        }
        return result   // 走不到：relaunch 成功时进程已经终止
    }

    /// CloudKit 那一路的后半程：删库文件重建。
    ///
    /// Copyo 观测不到导出队列有没有排空——SwiftData 不暴露底下的
    /// NSPersistentCloudKitContainer，也没有任何受支持的方式去问它。所以这一步只能
    /// 由用户在认为推完之后自己按，界面上把这件事直说。
    @MainActor
    static func finishScrub() -> Bool {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: cloudWipePendingKey)
        defaults.set(true, forKey: pendingScrubKey)
        defaults.set(true, forKey: justErasedKey)
        return PasteService.relaunch(arguments: ["-showSettings",
                                                 "-settingsTab", String(SettingsTab.sync.rawValue)])
    }
}
