# iOS / iPadOS 版规划

创建日期：2026-09-03 · 最后更新：2026-09-05

## 一、先说结论：移动端能做什么、不能做什么

iOS 对剪贴板的限制远多于 macOS。Mac 版的核心循环是「后台静默抓取 → 全局快捷键呼出 → 模拟 ⌘V 粘贴回去」，这三步在 iOS 上**一步都不能原样照搬**：

| Mac 版能力 | iOS / iPadOS 现状 | 替代方案 |
| --- | --- | --- |
| 后台每 0.3s 轮询剪贴板，静默抓取一切 | **不可能**。应用只有在前台时才能读剪贴板，后台任务读不到 | 回到前台时自动读一次；分享扩展；快捷指令/操作按钮 |
| 读剪贴板无感 | iOS 16+ 程序化读取会弹「允许 Copyo 粘贴来自 X 的内容？」 | 引导用户在 设置 → Copyo → 从其他 App 粘贴 → 选「允许」，之后不再弹；或用系统 UIPasteControl 按钮（用户主动点则免弹） |
| ⇧⌘V 全局快捷键 | **没有全局快捷键**。硬件键盘快捷键仅在 Copyo 处于前台时有效 | 操作按钮 / 背面轻点 / 控制中心按钮 / 小组件 / 键盘扩展 |
| 模拟 ⌘V 粘贴到前台应用 | **不可能**。没有 CGEvent，没有辅助功能 API | 复制后用户手动粘贴；键盘扩展直接输入文本；iPad 拖放到旁边的 App |
| 文件类型条目（路径） | 路径在 iOS 上无意义 | 文件条目不同步到 iOS（或只显示文件名） |
| 来源应用图标与颜色 | 沙盒里拿不到其他 App 的图标 | 只显示来源应用名（Mac 同步来的条目自带名字）；iOS 本机保存的条目来源为空 |
| 忽略指定应用 | 无法得知内容来自哪个 App | 该设置 iOS 不提供 |

**因此 iOS 版的定位不是「手机上的剪贴板管理器」，而是「Mac 剪贴板历史的口袋入口 + 手机侧的收集器」**：
1. 在 Mac 上复制过的一切，手机上随时搜、随时复制出来（靠 CloudKit 同步，这是最大的价值）；
2. 手机上想留住的内容，通过分享面板 / 操作按钮 / 打开 App 存进同一份历史，Mac 上也能看到；
3. 把内容送进其他 App：iPhone 靠键盘扩展和「复制→粘贴」两步，iPad 额外有拖放。

顺带一提：Universal Clipboard（通用剪贴板）本身就能把 iPhone 复制的内容送到附近 Mac 的剪贴板，Mac 版 Copyo 会照常抓到——这是免费获得的「手机采集」通道，文档里要提醒用户。

### 关于「后台监听」的定论

iOS 10 起后台进程读剪贴板一律拿不到内容，iOS 14 加了读取横幅，iOS 16 加了授权弹窗，方向只紧不松，**没有官方途径**。民间的保活手段（静音音频、伪造画中画窗口保持前台态）违反审核指南 2.5.4，随时可能被拒或下架，且用户会一直看到一个悬浮窗，本项目不采用。

真正可用的只有两条：

1. **回到前台自动读取**：打开 Copyo 即保存当前剪贴板，是最基本的兜底。
2. **借道 Mac**：通用剪贴板把手机复制的内容送到附近的 Mac，Mac 版抓到后经 CloudKit 回流手机。

评估过并弃用的方案：iPad 分屏常驻（让一个剪贴板应用长期霸占屏幕对用户不友好）；快捷指令自动化按「某 App 打开 / 关闭」触发（只覆盖列出的应用，配置繁琐，不适合普通用户）；通知栏常驻按钮（iOS 没有 Android 那种前台服务常驻通知；本地通知可被划掉、按钮仍需打开 App 才能读；灵动岛实时活动最多存活 8 小时、按钮同样只能打开 App、且把实时活动当常驻快捷方式违背 HIG，有审核风险）。iOS 上「随时一划就到」的常驻入口就是控制中心与锁屏控件，已包含在一键保存里。

## 二、架构决策

### 2.1 同步：CloudKit 私有数据库（SwiftData 原生）

- `ModelConfiguration(cloudKitDatabase: .private("iCloud.dev.vibemage.Copyo"))`，Mac 与 iOS 共用同一容器。
  容器标识在 2026-09-19 随改名从 `iCloud.dev.vibemage.Paster` 换成了现在这个。旧容器从未随正式版发布过，直接弃用即可；已经拿旧容器同步过的开发机，本地库照常在，云端那份不要了。
- 现有 `ClipItem` / `Pinboard` 模型已满足 CloudKit 要求（全部属性有默认值或可选、关系可选、无 unique 约束），**不需要改模型**。`externalStorage` 的图片会自动作为 CKAsset 上传。
- 与现有文件夹快照同步的关系：**并存，二选一**。公司 Mac 常被 MDM 禁用 iCloud，文件夹同步（含自定义目录）仍是这类环境的唯一出路；CloudKit 是个人设备之间的默认选项。iOS 只做 CloudKit。
- 行为差异要写进设置页说明：快照同步不传播删除，CloudKit 会——一台设备删了，处处都删；Mac 的「历史上限」清理也会同步生效。
- 部署纪律：CloudKit schema 必须在 CloudKit Console 从 Development **部署到 Production** 之后才能发正式版；上线后字段只能加不能删/改类型。
- 直发版（Developer ID）也能用 CloudKit：`build-release.sh` 已改为归档 + `-exportArchive`，entitlements 展开与 Developer ID 描述文件嵌入由 Xcode 完成；前提是后台有一份包含该 iCloud 容器与推送的 Developer ID 描述文件。

### 2.2 代码共享：抽出 `CopyoCore` 本地 Swift Package

| 归属 | 内容 |
| --- | --- |
| **CopyoCore（共享）** | 模型、`ClipKind` 分类逻辑（链接/颜色识别）、SHA-256 去重、缩略图生成（改用 ImageIO/CGImage 消除 NSImage/UIImage 差异）、CloudKit 容器配置、通用格式化 |
| Mac 独有 | `ClipboardMonitor`、`HotkeyManager`、`PasteService`、`AppIconProvider`、面板（NSPanel）、文件夹快照同步 |
| iOS 独有 | 前台采集、分享扩展、键盘扩展、小组件、控制中心控件、App Intents |

粗略估计现有 2600 行里约四成可下沉到 CopyoCore。先抽包、再加 iOS target，Mac 版必须逐字节无回归。

### 2.3 工程与商店

- 同一 `Copyo.xcodeproj` 增加 `Copyo iOS` target（Bundle ID **同为** `dev.vibemage.Copyo`，这是通用购买的硬性要求），扩展用 `dev.vibemage.Copyo.ShareExtension` 等后缀。
- App Store Connect：在现有应用记录里「添加平台 → iOS」，自动成为 Universal Purchase，SKU `paster` 不变。Mac 1.0 审核期间做这件事不影响审核。
- 隐私问卷维持「不收集数据」：私有 iCloud 数据库里的内容开发者无法访问，按 Apple 的定义不算收集。
- 最低系统：**iOS 18 / iPadOS 18**（控制中心控件、SwiftData 成熟度），用 Xcode 26 编译自动获得 iOS 26 的 Liquid Glass 外观。Mac 版维持 macOS 14。

## 三、路线图

### Phase 0 · 地基（Mac 侧，与设计稿并行，iOS 一行 UI 都不写）

- [x] 抽出 `CopyoCore` 包，Mac 版接入，构建产物无回归
- [x] Mac 版接入 CloudKit 同步：设置页「同步方式：iCloud / 文件夹 / 关闭」（两台 Mac 之间增删改与图片的实机验证，要等下一条的开发者后台配置就绪后再补）
- [ ] 开发者后台：App ID 开启 iCloud，创建容器 `iCloud.dev.vibemage.Copyo`；ASC 应用记录添加 iOS 平台
- [x] `build-release.sh` 改为归档 + 导出，签名与 entitlements 交给 Xcode；`build-appstore.sh` 适配 iCloud 描述文件
- [ ] 随 Mac **1.1** 发布 CloudKit 同步（先于 iOS 上线，让 Mac 用户历史先上云）
- [x] 设计：Claude Design 出移动端设计稿（见第四节），原稿在 `art/ios-design/2026-09-05/`，实现依据 `art/ios-design/design-spec.md`

### Phase 1 · iOS / iPadOS 1.0 —— 看得见、搜得到、复制得出

- [x] 历史列表 / 卡片、类型筛选、搜索、详情预览、Pinboard
- [x] 轻点复制（含纯文本复制）、分享、固定、删除、批量清理（设置里的「清空历史」只删未固定条目）
- [x] 采集通道 A：回到前台自动读剪贴板并入库（引导用户把「从其他 App 粘贴」设为允许；未允许时用 UIPasteControl 按钮兜底）
- [x] 采集通道 B：分享扩展「保存到 Copyo」（文本 / 链接 / 图片，可选 Pinboard）
- [x] 采集通道 C「一键保存」：一个 `SaveClipboardIntent`，接三种物理入口（详见 3.1）
  - 操作按钮（iPhone 15 Pro 及 iPhone 16 全系起）：iOS 18 起可直接绑定 App 提供的 Control，无需快捷指令
  - 敲击背面（iPhone 8 起所有机型）：设置 → 辅助功能 → 触控 → 轻点背面 → 运行快捷指令
  - 控制中心按钮与锁屏快捷入口（iOS 18）：与操作按钮共用同一个 Control，一次实现三个入口
  - 应用内提供「添加快捷指令」一键导入（iCloud 分享链接），并按入口给出图文指引
- [x] iPad：`NavigationSplitView` 侧栏 + 网格，卡片可拖放到 Split View / Slide Over 里的其他 App，硬件键盘快捷键（⌘F 搜索、方向键、回车复制、空格预览）
- [x] 首次启动引导（三页：Mac 互通 / 怎么保存 / 开启 iCloud）
- [ ] 中英本地化（已完成，iOS 主应用 + 两个扩展各自的 String Catalog）、截图（待真机验证后重拍）、提审（待开发者后台配置，见 3.2）

#### 3.1 「一键保存」的两条实现路径

| 路径 | 触发方式 | 剪贴板由谁读 | 体验 | 依赖 |
| --- | --- | --- | --- | --- |
| **Control**（iOS 18 ControlWidget） | 操作按钮 / 控制中心 / 锁屏 | Intent 设 `openAppWhenRun`，打开 App 后在前台读 | 零配置，按下即存，但会切到 Copyo 并显示「已保存」，需手动切回 | 无 |
| **快捷指令**（获取剪贴板 → Copyo 保存） | 操作按钮 / 敲击背面 | 快捷指令系统读，内容作为参数传给 Intent，App 不碰剪贴板 | 全程静默，顶部横幅「已保存」，不离开当前 App | 需导入一次快捷指令；Shortcuts 的「从其他 App 粘贴」需设为允许 |

两条都做：Control 是 Apple 为操作按钮设计的正规接法，快捷指令则覆盖没有操作按钮的机型（敲击背面），且体验更静默。

小组件和控件的扩展进程**读不到剪贴板**：它们没有前台身份，iOS 10 起后台读取一律为空，iOS 16 的授权弹窗也无处弹出。所以任何「保存剪贴板」的小组件按钮本质上都是「打开 App 再读」；扩展进程能否**写**剪贴板（小组件点按复制）另行验证。

弃用：摇一摇。摇动事件只送达前台 App，后台的 Copyo 收不到，快捷指令自动化也没有此触发器。

#### 3.2 Phase 1 实现状态（2026-09-05）

代码全部落地：target `Copyo iOS`（`CopyoIOS/`）、`CopyoShareExtension`、`CopyoWidgets`（仅「保存剪贴板」Control）、三 target 共用的 `CopyoShared/`（App Intents、分享面板、入库逻辑）。iOS Debug / Release-AppStore 与 Mac 三个配置全新构建零警告，`CopyoCore` 12 个测试通过。全部验证都在模拟器上、未签名（`CODE_SIGNING_ALLOWED=NO`）完成，下面列出因此**没验证到**的部分。

构建与截图：

```bash
xcodebuild -project Copyo.xcodeproj -scheme "Copyo iOS" -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun simctl launch --terminate-running-process "iPhone 17 Pro" dev.vibemage.Copyo \
  -demoData -skipOnboarding -demoScreen history -demoTheme dark
```

启动参数：`-demoData`（内存库 + 设计稿样例数据）、`-skipOnboarding`、`-localOnly`、`-demoScreen <route>`（取值见 `CopyoIOS/App/LaunchOptions.swift`）、`-demoTheme light|dark`、`-demoSidebar <item>`（iPad）、`-simulateQuickSave`、`-demoMenu`（仅 Debug）。中英切换加 `-AppleLanguages "(en)"`。

**提审前必须做（开发者后台 / 真机）：**

1. 开发者后台：App ID `dev.vibemage.Copyo`、`dev.vibemage.Copyo.ShareExtension`、`dev.vibemage.Copyo.Widgets` 三个都开启 App Group `group.dev.vibemage.Copyo`；主应用另开 iCloud 容器 `iCloud.dev.vibemage.Copyo` 与 Push。至今所有构建都没展开过 entitlements，自动签名归档会直接失败。
2. CloudKit Console：容器换成了 `iCloud.dev.vibemage.Copyo`，schema 要在**新容器**里从头跑一遍 Development，确认 `ClipItem` / `Pinboard` 两张表（含 `sourceColorHex`、`iconName`、`colorHex`）齐全后再部署到 Production。
3. 快捷指令：在真机的「快捷指令」里建「获取剪贴板 → Copyo：保存内容」，iCloud 分享后把链接填进 `CopyoIOS/Screens/Settings/ShortcutLinks.swift`（现在是占位串，按钮只会提示「尚未发布」；「轻点背面」通道依赖它）。
4. App Store Connect：现有应用记录「添加平台 → iOS」。

**真机验证清单（模拟器做不到）：**

- 三进程共用 App Group 库：分享扩展写入 → 主应用可见 → CloudKit 同步到 Mac；主应用开 CloudKit、扩展用本地容器打开同一文件的并存写法。
- 一键保存：控制中心 / 操作按钮按下 → 冷启动与热启动两种时序下都能读到剪贴板并提示「已保存」；「没有可保存的内容」「已保存过」两条提示。
- 系统「从其他 App 粘贴」设为允许后前台读取完全免弹窗；未允许时横幅里的 UIPasteControl 能真正入库。
- 触摸：轻点复制（卡片是 NavigationLink，靠 highPriorityGesture 抢占，抢不到会变成进详情）、长按菜单与预览点按进详情、左滑删除 / 右滑固定、拖放到旁边的 App、图片捏合缩放、Pinboard 行左右滑。
- iPad 硬件键盘：⌘1/2/3、⌘F、方向键移焦、↵ / ⇧↵、空格预览、⌘P、⌫。
- iCloud 状态胶囊三态与设置页状态行（模拟器上恒为「未同步」）。
- 分享扩展在扩展进程里的外观、取消 / 完成收尾；Control 在控制中心与锁屏里的显示。
- 引导页第三页的两个开关、设置里的外链与系统设置跳转。

**与设计稿的取舍（需设计拍板）：** 设置总览「允许从其他 App 粘贴」右值显示「系统设置」而非「询问」（iOS 不提供读取该授权的 API）；04b 没有「打开操作按钮设置」按钮（无公开深链）；04e「Copyo 键盘」整行留到 Phase 2；隐私说明是外链而非二级页；颜色详情的三个色值胶囊在 440pt 宽上折成两行；引导页插图符号偏下约 14pt；iOS 26 系统返回按钮不带「历史」文字。

#### 3.3 原「留到 Phase 2 的已知缺陷」已全部清掉（2026-09-20）

六条一次做完，模拟器上逐屏核对了默认档与 accessibility-extra-large 两套；四个配置
（iOS Debug / iOS Release-AppStore / Mac Release-AppStore / CopyoCore）零警告，20 个测试通过。

| 原缺陷 | 处理 |
| --- | --- |
| 动态字体放大时角标 / 元信息 / 筛选胶囊不跟随 | 设计稿的点数几乎都正好落在系统文本样式的默认值上（11 = caption2、12 = caption、13 = footnote、15 = subheadline、17 = body、20 = title3、22 = title2、28 = title），换过去**默认档逐像素不变**、放大档才动；落不到表上的零散点数（10 / 14 / 18 / 44…）用 `@ScaledMetric(relativeTo:)`。包字的 `.frame(height:)` 一律改成内距 + `minHeight`——只放大字号不放开盒子是把文字上下切掉，比不跟随更糟 |
| 搜索没有 predicate 下推与防抖 | `AppModel` 加 250ms 防抖（清空与截图路由立即生效，不等防抖）；`@Query` 改成动态 predicate（`kindRaw` + `plainText` contains）。**没有**给 `ClipItem` 加反规范化的搜索列：那是 CloudKit schema 变更，而 Production schema 已在 2026-09-20 部署、Mac 1.0 正拿它在审核中。文件名那一路（`displayTitle` 不是 `plainText` 的子串）保留一小段内存过滤 |
| 超长正文详情页整串渲染 | 详情页长文本按行切块进 `LazyVStack`；富文本的 `AttributedString` 不再每帧重解 RTF。卡片上富文本也补上了和纯文本同样的 600 字闸门——原来一条二十万字的富文本每次布局都要全文 split + join |
| `isSelected` 卡片状态未接 | **删掉**。四个调用点没有一个设过它，而这个应用里点卡片就是复制，没有多选也没有检查器面板，没有任何动作以「当前选中哪张卡」为前提。留一个谁都不设的参数只会让下一个人以为它接好了 |
| VoiceOver 未验证 | 卡片合成为一个停留点并自带标签；`.highPriorityGesture(TapGesture)` 接不到旁白的「激活」——不改的话旁白用户双击进的是详情，「轻点复制」正好反过来，现在激活即复制、进详情降级为具名动作；瀑布流按原下标给排序优先级（不然旁白先读完左列再读右列）；轻提示补播报 |
| AppIcon 只有一张 1024 universal | 见下 |

**AppIcon 那条比记录的更严重**：`CopyoIOS/.../AppIcon.png` 与 `art/icon/icon-master-1024.png`
**逐字节相同**——iOS 直接用了 macOS 的母图。实测 RGBA、1 048 576 个像素里 398 384 个全透明，
不透明包围盒 (100, 100, 924, 924)，即一张内缩约 10% 的 824×824 圆角方——那是 **macOS 的图标网格**。
iOS 要的是满幅 1024×1024 且**不带 alpha**（自己会套超椭圆遮罩），装到手机上是「小一圈 + 二次圆角」，
带 alpha 还可能在上传时触发 `ITMS-90717`。现已按 `art/icon/paster-icon-spec.md` 的几何重新生成满幅无 alpha 版，
并补上 dark 与 tinted 两个 `appearances` 变体（tinted 必须是刻意设计的单色还原——系统会盖上用户的色调，
红蓝错位这个品牌标记在那里存活不下来）。`scripts/make-icon.sh --ios` 可复现。

辅助功能字号下还发现一条记录里没有的：卡片头部的角标带 `fixedSize` 优先占位，把「来源 · 时间」
挤到只剩一个「…」。头部改成在辅助档换两行，判据 `ClipCard.headerStacks(typeScale:)` 与瀑布流估高共用，
免得两边在边界档位上对不齐、把某一列的高度整体算少一行。

### Phase 2 · 1.1 —— 把内容送进别的 App

- [ ] 键盘扩展：横向卡片条 + 搜索 + 地球键 + 最小打字行（审核指南 4.4.1 要求键盘必须能输入字符）。需要「允许完全访问」才能读共享容器，引导文案要解释清楚
- [x] 小组件（小 / 中）：最近条目，点按即复制（2026-09-20，见 3.5）
- [x] Core Spotlight 索引：系统搜索直达条目（2026-09-20，见 3.4）


### Phase 2 · 1.1 —— 把内容送进别的 App

- [ ] 键盘扩展：横向卡片条 + 搜索 + 地球键 + 最小打字行（审核指南 4.4.1 要求键盘必须能输入字符）。需要「允许完全访问」才能读共享容器，引导文案要解释清楚
- [ ] 小组件（小 / 中）：最近条目，点按即复制（交互式小组件 + App Intent）
- [ ] Core Spotlight 索引：系统搜索直达条目

### Phase 3 · 1.2 —— 打磨

- [ ] 法语本地化（三平台一起）
- [ ] 富文本 / 代码高亮预览
- [ ] 同步冲突与离线体验打磨、历史上限跨设备策略
- [ ] 视需要：文本片段模板（带占位符）

## 四、给 Claude Design 的设计输入

### 4.1 参考资料（一并上传）

- `art/store/01-panel-zh.png`、`02-search-zh.png`、`03-preview-zh.png`：Mac 版卡片面板的现状，卡片结构（顶部来源色条、类型角标、来源应用 + 时间、内容预览、圆角 12）是品牌识别的一部分，移动端要延续
- `art/icon/icon-master-1024.png` + `art/icon/paster-icon-spec.md`：图标与配色语言
- 本文第一节的能力对照表：设计不能出现 iOS 做不到的交互（比如「自动粘贴」按钮）

### 4.2 Claude Design 提示词（可直接粘贴，配合 4.1 的参考图上传）

````text
为开源剪贴板工具 Copyo 设计 iOS 与 iPadOS 应用。

## 背景
- Copyo 的 Mac 版已经上架：按下快捷键，一个深色卡片面板从屏幕底部滑出，展示复制过的所有内容（文本、富文本、链接、颜色、图片、文件），即输即搜，回车粘贴。参考图见附件。
- 移动版的定位：Mac 剪贴板历史的口袋入口 + 手机侧收集器。通过 iCloud 与 Mac 同步，Mac 上复制过的一切在手机上随时可搜、可复制；手机上想留住的内容，存进同一份历史。
- 用户画像：中英文圈的效率工具用户，含开发者。界面文案先出简体中文，关键界面附英文版。

## 平台硬约束（设计中不得出现做不到的交互）
- iOS 无法在后台读剪贴板、没有全局快捷键、不能把内容自动粘贴进其他 App。不要设计任何「自动粘贴」「后台监听」「常驻通知」的开关或按钮。
- 保存内容进 Copyo 只有三条通道：
  1. 打开或回到 Copyo 时自动读取当前剪贴板；
  2. 系统分享面板里的「保存到 Copyo」；
  3. 「一键保存」：操作按钮 / 敲击背面 / 控制中心按钮，按下后会打开 Copyo 并显示「已保存」。
- 内容送进其他 App 只有三条路：轻点卡片复制后手动粘贴；键盘扩展直接输入；iPad 上拖放到旁边的 App。
- 手机本机保存的条目没有来源 App 信息；Mac 同步来的条目有来源 App 名，但没有图标。
- 自动读取剪贴板需要用户在 iOS 设置里把 Copyo 的「从其他 App 粘贴」设为「允许」，否则系统每次弹窗。未允许时，界面用系统样式的「粘贴」按钮兜底。

## 品牌与风格
- App 图标：骨白卡片 + 红蓝双层错位套印。红 #FF2D55、蓝 #0A84FF、卡片 #F7F3EA、内容条 #16161A、深底 #1B1620 到 #08060B 径向渐变。红蓝错位只用于图标、空态和引导页的点缀，正文界面不要滥用。
- 强调色：蓝 #0A84FF，与 iOS 系统蓝一致；破坏性操作用系统红。
- 遵循 iOS 26 原生设计语言（Liquid Glass 的标签栏、工具栏、搜索栏），系统控件优先，浅色与深色两套。
- 延续 Mac 版的卡片语言：圆角 12；顶部一条来源色带，Mac 同步的条目按来源 App 着色，本机条目用中性灰；色带上放类型角标（文本 / 富文本 / 链接 / 颜色 / 图片 / 文件）与来源 + 相对时间；下方是内容预览。图片卡片显示缩略图；颜色卡片显示色块 + 色值；链接卡片显示域名 + 标题；文件卡片只显示文件名并标注「仅 Mac」。
- 内容优先，克制，不堆插画；空态与引导用图标语言。
- 字体：SF Pro / 苹方；图标用 SF Symbols，交付时标注符号名。

## 需要的界面（iPhone）
1. 历史主屏：底部标签栏（历史 / Pinboard / 设置）；搜索栏；类型筛选（全部 / 文本 / 链接 / 图片 / 颜色）；卡片流。轻点卡片 = 复制并出现「已复制」轻提示；长按 = 上下文菜单（复制、纯文本复制、分享、固定到 Pinboard、删除）；左滑删除、右滑固定。
   需要的状态：正常；空态（首次启动、尚无 Mac 同步）；顶部「剪贴板有新内容」横幅（回到前台且未允许自动读取时出现，带系统样式粘贴按钮）；「已保存」轻提示（一键保存后打开 App 时）；iCloud 同步中 / 已同步指示。
2. 详情：全文 / 大图 / 色块，字数、来源、时间、所在 Pinboard；操作：复制、纯文本复制、分享、固定、删除。
3. Pinboard：列表（名称、条目数）与内容页；新建、重命名、排序、删除。
4. 设置：iCloud 同步（状态、开关、上次同步时间）；历史上限；「怎样保存剪贴板」引导入口；「一键保存」设置页，按操作按钮 / 敲击背面 / 控制中心三种入口分别给图文步骤，含「添加快捷指令」按钮和跳转系统设置的深链；「允许从其他 App 粘贴」引导；启用键盘扩展指引；关于（开源、隐私说明）。
5. 首次启动引导（三页）：与 Mac 互通；怎么保存（三条通道）；开启 iCloud 与「允许粘贴」。可跳过。
6. 分享扩展面板：紧凑 sheet，内容预览 + 可选 Pinboard + 保存按钮。
7. 键盘扩展：横向卡片条 + 搜索 + 地球键 + 最小打字行（删除、空格、回车）；未开启「完全访问」时的提示态。
8. 小组件：小尺寸（最近 1 条）与中尺寸（最近 4 条），点按复制；另出锁屏 / 控制中心「保存剪贴板」控件的图标。

## 需要的界面（iPad）
9. 侧栏 + 网格：侧栏为历史、各类型、Pinboard；内容区卡片网格，含选中态与硬件键盘焦点态；展示把卡片拖放到 Split View 里另一个 App 的中间态。
10. Slide Over / 紧凑宽度下退化为 iPhone 布局。

## 交付
- 每个界面浅色 + 深色各一版；iPhone 用 6.9 英寸，iPad 用 13 英寸横屏。
- 设计 token：颜色（浅 / 深两套语义色）、圆角、间距、字号层级。
- 组件规格：卡片各类型变体、类型角标、来源色带、轻提示、横幅。
- 交互说明：手势、动效（复制反馈、面板出现方式）。
- SF Symbols 名称清单。
- 文件命名：01-history-light.png、01-history-dark.png，依此类推。

## 禁止
- 不要提及或模仿任何现有商业剪贴板产品的名称与品牌元素。
- 不要出现 iOS 做不到的功能。
````

### 4.3 设计稿落地约定

- 导出 PNG 到 `art/ios-design/<日期>/`，命名 `01-history-light.png` 之类，随仓库管理
- token 与交互说明整理成 `art/ios-design/design-spec.md`，实现时作为唯一依据

## 五、待验证的技术点

开工前用 10 分钟 demo 各验一次，避免设计建立在错误假设上：

1. 「从其他 App 粘贴 → 允许」设置后，`UIPasteboard.general.string` 在前台是否完全免弹窗
2. 快捷指令「获取剪贴板」→ App Intent 全程是否免弹窗（Shortcuts 自身也有同名设置）
3. 交互式小组件的 Intent 在扩展进程里能否**写** `UIPasteboard.general`（决定「点按复制」要不要打开 App；读取已确定不行）
4. 分享扩展处理大图时的内存上限（约 120MB）是否需要先降采样
5. SwiftData + CloudKit 对已有本地库开启同步时，历史数据是否完整上传（预期是）
6. 键盘扩展不开「完全访问」时的可用性边界（预期读不到共享容器，必须开）

## 六、审核风险

- 键盘扩展：4.4.1 要求提供输入功能与切换键盘的途径；申请完全访问必须有隐私政策链接（已有）
- 剪贴板读取：审核员可能质疑自动读取，引导页与审核备注要说明「仅前台、用户可关」
- 分享扩展与 App Intent 的名称含 "Copyo" 即可，不要出现任何商业剪贴板产品名
