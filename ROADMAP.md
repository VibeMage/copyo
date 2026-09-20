# Roadmap

## 进行中

- [ ] **Mac App Store 上架**：1.0 (1) 于 2026-09-20 因 Guideline 2.1（新账号需补充信息）
  被退回，当天已补齐真机录屏与六项说明、重写审核备注并重新提交，状态回到「等待审核」。
  全过程见 docs/appstore-submission.md 第二十三、二十四节。同时在等 Apple 处理的还有两项：
  免费 App 协议「正在验证」、DSA 交易商状态「正在审核」——协议不恢复「有效」会挡住发布
- [ ] **1.1.0：三件隐私修复已完成，等 1.0 过审后发布**
  维护者决定不动正在审核的 1.0 (1)，修复随 1.1.0 走。**代价要记住**：1.0 上架后到
  1.1.0 之前，把同步设成「关闭」的用户数据仍会进他们自己的 iCloud 私有数据库。
  - ✅ **同步关闭其实没关**（实测，1.0 就有）：`makeContainer` 的非 CloudKit 分支没有
    显式给 `cloudKitDatabase`，默认值 `.automatic` 的含义是「签了 entitlement 就开镜像」，
    而上架版正是签了的。排除法验证：删掉整个库目录、启动、全程不复制任何东西、
    `syncMode` 全程 off——4 秒 0 条，再等 8 秒自己长出 6 条旧记录。显式写 `.none` 后
    稳定 0 条。这也是「删除所有数据」一度怎么都删不干净的真正原因
  - ✅ **切换同步方式不再留残留状态**：从 iCloud 切走时阻塞式确认 + 立即重启，
    拒绝就把选择器退回去，界面上不再出现「显示关闭而 CloudKit 还在传」
  - ✅ **「删除所有数据」**：连固定内容与 Pinboard 一起删，并在下次启动、建容器之前
    把库文件整个删掉重建——SQLite 不清零释放的页，光 delete+save 的话正文仍能用
    `strings` 捞出来。端到端验证：擦除前库里 6 处标记串，重启重建后库与 -wal 均为 0 处。
    CloudKit 活着、或用过 iCloud 但现在关着这两种情况**故意不删库文件**（待推送的删除
    和服务器变更令牌都在里面），对话框如实说明，不假装删干净
  - ✅ 「关于」页文案、`importSnapshots` 的游标存量 bug、录入竞态保护

## 计划中

- [ ] iOS / iPadOS 版（详见 docs/ios-plan.md）
  - 定位：Mac 剪贴板历史的口袋入口 + 手机侧收集器，同一应用记录组成 Universal Purchase
  - Phase 0：抽出共享 `CopyoCore` 包，Mac 接入 CloudKit（已完成）
  - Phase 1：历史 / 搜索 / Pinboard / 复制，三条保存通道（前台自动读取、分享扩展、一键保存：
    操作按钮 / 敲击背面 / 控制中心），iPad 侧栏与拖放。2026-09-05 代码完成，
    **开发者后台配置已于 2026-09-19 完成**（三个 App ID、App Group、iCloud 容器），
    剩真机验证与提审，清单见 docs/ios-plan.md 3.2
  - **Phase 2 代码已于 2026-09-21 全部完成**：Core Spotlight 索引（默认关，见 ios-plan 3.4）、
    主屏小组件（小 / 中，见 3.5）、键盘扩展（见 3.6）。但**键盘刻意不随 iOS 首版一起发**——
    它要申请「允许完全访问」、会把整个 iOS 版拖进审核指南 4.4.1 的审视范围，
    而 iOS 版本身还有一整条从未在签名真机上跑通过的链路。target 留在工程里、CI 照编，
    只是不在包里；要发时把 project.pbxproj 里两处引用加回去即可
  - **Phase 1 遗留缺陷已于 2026-09-20 全部清掉**（动态字体、搜索防抖与 predicate 下推、
    超长正文、`isSelected`、VoiceOver、AppIcon），过程与取舍见 docs/ios-plan.md 3.3。
    顺带查出 iOS 的 AppIcon 与 macOS 母图逐字节相同——带 alpha、内缩 10%，那是 Mac 的图标网格，
    已重新生成满幅无 alpha 版并补上 dark / tinted 变体
- [ ] 同步合并逻辑的单元测试。这是目前**唯一没有测试保护的复杂逻辑**，而它直接决定
  用户数据会不会丢。前提是先把 `Copyo/Services/SyncService.swift` 里的快照导入导出、
  游标推进、identity 去重下沉到 `CopyoCore`——留在 app target 里测不了
- [ ] App Store 法语商店元数据：应用内界面已是法语，但商店页只有英文和简体中文两种，
  法国区用户看到的仍是英文描述。补一套法语描述 / 关键词 / 截图（截图管线加一种语言即可，
  见 `scripts/make-store-shots.py` 的 TEXT 表）
- [ ] 应用内更新检查：比对 GitHub Releases，有新版时提示下载（仅直发版启用，
  App Store 版必须屏蔽该入口）
- [ ] GitHub Actions CI：推送 tag 自动构建并附加 DMG 到 Release
  （2026-09-20 构建校验与测试已接入，发布流程待配置 secret 并演练，见 docs/ci.md）

## 已完成

### 未发布（已在 main，随下一个版本上架）

- **法语本地化**：420 条词条全部译出并入库（Mac 114 / iOS 229 / 分享扩展 39 / 小组件 38），
  先定 51 条术语表再翻译、最后统一校对。三处复数词条按法语规则给了 one / other 变体
  （法语的 0 走单数）。已在三种语言下逐屏核对排版，修掉两处只有法语才会暴露的布局问题：
  设置窗口标签页栏被折叠、iOS 卡片角标被挤成「Cou…」
- **英文版 README**：`README.en.md`，与中文版双向互链

### v1.0（2026-09-20 提交审核）

- **CloudKit iCloud 同步**：SwiftData 直接镜像到用户自己的 iCloud 私有数据库，
  与文件夹快照同步并存、二选一。Production schema 已于 2026-09-20 部署并逐字段核验
  （见 docs/appstore-submission.md 第二十一节）
- **改名 Paster → Copyo**：目录、工程、target、模块、类型名、bundle ID、App Group、
  iCloud 容器全部更名；本地数据库与文件夹同步目录带自动迁移，老用户升级不丢数据
- **商店截图管线**：`scripts/make-store-shots.py`，背景板 + 图标 + 文案 + 真实 UI 截图合成，
  可复现。初版四张里有两张还在宣传已移除的自动粘贴，已全部重拍
- **构建号自动递增**：`scripts/bump-build-number.sh`，只动上架配置；导出选项显式设置
  `manageAppVersionAndBuildNumber=false`，出包的号就是仓库里记着的号，出包后自动核对

### v0.1.0

- Developer ID 签名 + Apple 公证的发布流程（Release 中的 DMG 双击即装）
- 界面中英双语（String Catalog，英文基准 + 简体中文，跟随系统语言）
- 剪贴板历史：文本 / 富文本 / 链接 / 颜色 / 图片 / 文件，自动去重
- `⇧⌘V` 底部滑出卡片面板，即输即搜，全键盘操作，空格预览
- ~~自动粘贴回之前的前台应用~~（1.0 起移除：Mac App Store 审核不允许把辅助功能权限用于
  模拟 ⌘V，回车改为复制并回到之前的应用；旧实现见 git 历史）
- Pinboard 固定分组、历史上限自动清理、忽略指定应用
- 隐私：跳过密码管理器的 Concealed/Transient 内容，数据仅存本地
- iCloud Drive 文件夹同步（可选，支持自定义同步文件夹）
- 自定义全局快捷键（录制任意组合键）
- 首次启动引导、DMG 打包脚本、图标生成管线
- 单元测试：`CopyoCore` 20 个，覆盖内容分类、颜色/代码识别、SHA-256 去重、
  入库与历史上限、改名后的数据迁移

## 维护者须知

踩过的坑，动手前先看一眼，省得重犯：

- **给模型加二进制属性时**，部署 CloudKit schema 前要用一大一小两条记录各写一次。
  CoreData+CloudKit 对二进制属性建两个字段（`CD_x` BYTES / `CD_x_ckAsset` ASSET），
  且按写入的记录惰性创建；只用小数据做种子就部署，Production 会缺 asset 字段，
  而 **Production schema 只能加不能改**——第一个复制大图的用户同步就会失败
- **上内购之前**必须先把 DSA 交易商状态改对（见 docs/appstore-submission.md 第十节、
  第十九节）。目前登记为交易商，联系方式会公开显示在欧盟区产品页上
- **加语言前先看排版，别只看译文**。设置窗口宽度是按标签页标题实测算出来的
  （`SettingsLayout.width`），英文 / 中文都落在 540pt 上——商店截图正是按 540pt 拍的，
  动这个常数就得重拍。标题更长的语言会把窗口撑宽，否则整条标签栏会被 SwiftUI
  折叠成一个 » 按钮
- **商店截图的文案不能承诺应用做不到的事**。1.0 (4) 移除自动粘贴后，任何「回车即粘贴」
  的说法都是 2.4.5 的拒审理由

欢迎通过 Issue 提出建议，或直接认领上面的条目提 PR。
