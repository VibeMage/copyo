# Mac App Store 提审材料与操作清单

创建日期：2026-09-01 · 最后更新：2026-09-27

## 一、App Store Connect 建应用（你来操作）

> ⚠️ 下面这张表是 2026-09-01 建第一条应用记录时填的。**那条记录已于 2026-09-19 删除**，
> 新记录已于 2026-09-19 建好，实际填的值如下（名称 `Copyo - Clipboard History`、套装 ID
> `dev.vibemage.Copyo`、SKU `copyo`、Apple ID `6813955206`）。

appstoreconnect.apple.com → 我的 App → ➕ 新建 App：

| 字段 | 填写 |
| --- | --- |
| 平台 | macOS |
| 名称 | Copyo |
| 主要语言 | 简体中文（或 English，主语言决定默认展示） |
| 套装 ID | dev.vibemage.Copyo |
| SKU | copyo（平台中立——iOS 版将来共用这条应用记录与 SKU） |

## 二、App 信息

- **类别**：效率（Productivity）
- **价格**：免费
- **隐私政策 URL**：`https://gist.github.com/VibeMage/d39d7165d762ecfd0f16f72ad1fc553e`
  （仓库私有期间用这个公开 Gist；仓库恢复公开后可换回 repo 内的 PRIVACY.md 链接）
- **App 隐私问卷**：全部选择「不收集数据」（Data Not Collected）。
  **1.0 起带了 CloudKit，这个答案依然成立**，但理由变了，记下来免得下次答不上：
  Apple 对「收集」的定义是数据离开设备且开发者能访问；Copyo 只用 `.private(...)`
  私有数据库（`CopyoStore.swift:72`），全仓库没有 publicCloudDatabase / CKShare，
  我们读不到，所以不构成收集
- **出口合规**：**答案仍是「否/豁免」不用改**，但理由要改：不是「无任何网络请求」
  （1.0 起带 CloudKit），而是只通过 Apple 框架使用 HTTPS，属于豁免加密。
  `ITSAppUsesNonExemptEncryption` 在工程里写死为 NO，随包提交，ASC 无需操作

## 三、商店文案（可直接粘贴）

### 版本页固定字段

| 字段 | 填写 |
| --- | --- |
| 名称 | `Copyo - Clipboard History`（英文，主要语言）／**`Copyo`**（简体中文本地化名称，见第十七节） |
| 技术支持网址 | `https://vibemage.github.io/copyo/support/`（仓库 2026-09-16 已改名为 copyo，旧地址随之 404） |
| 营销网址 | 留空 |
| 版本 | 1.0（新应用记录从 1.0 重新开始，与构建的 MARKETING_VERSION 一致） |
| 版权 | `© 2026 Copyo Contributors` |

### 推广文本（170 字符内，可随时改无需审核）

- zh：`按下 Shift+Command+V，复制过的文本、链接、图片、文件全部回来。开源、数据存在本机、同步默认关闭。`
- en：`Press Shift+Command+V and everything you've copied comes back — text, links, images, files. Open source, stored on your Mac, sync off by default.`

⚠️ ASC 的推广文本/关键词字段不接受 ⇧⌘ 等按键符号（报「无效字符」）；描述字段若同样报错，把 ⇧⌘V 改写为 Shift+Command+V。

### 副标题（30 字符内）

- zh：`剪贴板历史，一按即达`（10 字，已填）
- en：**留空**。原稿那句 `Clipboard history, one key away` 是 **31 字符，超上限填不进去**；
  而且英文名已经是 `Copyo - Clipboard History`，再写一遍 clipboard history 也是重复。
  要填的话建议 `Your clipboard, one key away`（28 字符，不与名称重复）。

### 描述（简体中文）

```
按下 ⇧⌘V，你复制过的一切从屏幕底部滑出。

Copyo 是一款开源的剪贴板管理工具：
• 自动记录复制过的文本、富文本、链接、颜色、图片和文件
• 底部卡片面板，即输即搜，全键盘操作
• 选中回车，内容立刻回到剪贴板，⌘V 即可粘贴
• Pinboard 固定常用内容，不受历史清理影响
• 可选同步：共享文件夹或你自己的 iCloud，默认关闭
• 自动跳过密码管理器等隐藏内容

隐私优先：同步默认关闭，数据只保存在本机；开启同步后也只进入
你自己的 iCloud 或你选定的文件夹，不经过我们的服务器。
无遥测、无统计、无第三方 SDK。代码完全开源。
```

### Description (English)

```
Press ⇧⌘V and everything you've ever copied slides up from the bottom of your screen.

Copyo is an open-source clipboard manager:
• Automatically captures text, rich text, links, colors, images and files
• Bottom card panel — type to search, fully keyboard-driven
• Hit Return and it's back on your clipboard, ready to paste with ⌘V
• Pin frequently used clips to Pinboards, safe from history cleanup
• Optional sync across your Macs: a shared folder, or your own iCloud — off by default
• Concealed content from password managers is never recorded

Privacy first: sync is off by default, so everything stays on your Mac. Turn it
on and your data goes only to your own iCloud or a folder you pick — never to a
server of ours. No telemetry, no analytics, no third-party SDKs. Fully open source.
```

### 关键词（100 字符内）

- zh：`剪贴板,粘贴,历史,剪切板,效率,复制,clipboard,paste,copyo,clip`
- en：`clipboard,paste,history,copy,manager,productivity,snippets,pasteboard,copyo,clip`

## 四、审核备注（App Review Notes，重点！）

菜单栏工具是审核重点对象，把这段贴进「审核备注」能少一轮拒审：

```
Copyo is a menu bar app (LSUIElement) with no Dock icon and no main window.

How to use:
1. On first launch a welcome dialog explains the basics.
2. Press Shift+Command+V at any time to open the clipboard panel
   (slides up from the bottom of the screen).
3. Copy anything — it appears in the panel automatically.
4. Select a card and press Return to put it on the clipboard and go back
   to the previous app, then paste with Command+V.
5. Settings are available from the gear button in the panel header,
   or by right-clicking the menu bar icon.

About permissions: Copyo does not use Accessibility, event taps or input
monitoring, and never asks for any privacy permission. The
Shift+Command+V shortcut is registered with the Carbon
RegisterEventHotKey API, which needs no permission.

No account and no login. No third-party services of any kind. Sync is off by
default; if the user turns it on, data goes only to their own CloudKit private
database (container iCloud.dev.vibemage.Copyo) or a folder they pick. We operate
no server and cannot read it.
```

## 五、截图（你来操作）

要求：2560×1600 或 2880×1800（16:10），最多 10 张，至少 1 张。

建议 4 张：
1. 主面板呼出状态（历史里放几条好看的内容：代码、链接、图片、颜色）
2. 搜索过滤中
3. 右键菜单 + Pinboard
4. 设置窗口（同步页或快捷键页）

截图命令：`screencapture -x screenshot.png` 后裁剪，或 ⇧⌘5 区域录制。
中英文各截一套（切系统语言后重截），分别传到对应本地化。

## 六、构建与上传

**1.0 的上架包一律从 `release/1.0` 分支构建**，不要从 main 打：
main 已经带上 iCloud（CloudKit）同步和推送 entitlements，归档时需要一张
Mac App Development 描述文件，而这要求团队里注册过 Mac；`release/1.0` 是提审
commit c7dd41f 加上「移除自动粘贴」，entitlements 只有沙盒，和 1.0 (3) 一样不需要描述文件，
商店描述里「零网络请求」的说法也仍然成立。iCloud 版本留给 1.1。

> ⚠️ **这段已经作废**：实际提审的 1.0 (1) 是从 main 出的，带 CloudKit 与推送，
> 「零网络请求」因此不成立。见第二十二、二十三节。

（main 上的工程是 `Copyo.xcodeproj`、scheme `Copyo`。）

```bash
git worktree add ../Copyo-release-1.0 release/1.0   # 已存在则跳过
cd ../Copyo-release-1.0
UPLOAD=1 ./scripts/build-appstore.sh   # 归档 → 导出 .pkg → 直接上传 App Store Connect
```

（不加 `UPLOAD=1` 只出包不上传；上传复用 Xcode 已登录的账号，无需 Transporter。
每次上传前把 project.pbxproj 里 Release-AppStore 配置的 `CURRENT_PROJECT_VERSION` +1。）

前置（一次性，Xcode 里点）：
- Xcode → Settings → Accounts → Manage Certificates → ➕ →
  「Apple Distribution」和「Mac Installer Distribution」各建一张

备用上传方式（脚本上传失败时）：从 App Store 装 **Transporter**，拖入 build/appstore/ 里的 .pkg。

## 七、提审前自查

- [ ] App Store Connect 表单全部填完（文案见上）
- [ ] 截图已传（中英各一套）
- [ ] 隐私问卷 = 不收集数据
- [ ] 审核备注已粘贴
- [ ] 构建版本已上传并在「构建版本」中选中
- [ ] 出口合规已回答

提交后通常 1–3 天出结果。被拒不用慌——菜单栏工具常见拒因就是
审核员找不到 UI（备注已覆盖）和权限用途不明（备注已覆盖）。
把拒审信息发给 Claude 分析即可。

## 八、2.1「需要补充信息」的回复（2026-09-03 首次提审收到）

新开发者账号首次提审几乎必收这封信：要一段真机录屏 + 六项说明。回复贴在 App 审核 → 消息里（录屏作附件），同一段文字再粘到「App 审核信息 → 备注」供后续版本复用。

### 回复正文（英文，可直接粘贴）

> ⚠️ **这份是 2026-09-03 Copyo 时期发出的，不要再复用**。其中两处现在是假话：
> ①「用辅助功能粘贴到前一个应用」——1.0 (4) 已整个移除，现在一个辅助功能 API 都不调；
> ②「makes no network requests」——1.0 带 CloudKit。重写版见第二十三节。

```
Thank you for reviewing Copyo. Here is the requested information. A screen recording is attached to this message.

1. Screen recording
Recorded on a physical MacBook running macOS 26.6.1. It starts with launching Copyo from the Finder and shows the typical flow: the welcome dialog, the menu bar icon, copying text, a link and an image in other apps, opening the clipboard panel with Shift+Command+V, searching, previewing with Space, pasting an item back into TextEdit with Return, pinning an item to a Pinboard, and the Settings window. Copyo has no accounts, no login and no user-generated content shared with other people, so there are no registration, account deletion, content reporting or blocking flows.

2. Purpose and target audience
Copyo is a clipboard history manager for macOS. Every time the user copies something (text, rich text, a link, a color value, an image or a file) Copyo keeps it, and the user can bring any earlier item back with one keyboard shortcut. It solves the problem that the system clipboard only holds the most recent item, which forces people to re-copy content or lose it. Target audience: Mac users who copy and paste a lot, such as developers, writers, designers, students and office workers. The app is free with no in-app purchases.

3. Setup and access
No account, login credentials or sample files are required.
- Launch Copyo. A welcome dialog explains the basics. Copyo then lives in the menu bar (the clipboard icon in the top-right corner); it has no Dock icon and no main window.
- Copy anything in any app. It appears in Copyo automatically.
- Press Shift+Command+V, or click the menu bar icon, to open the clipboard panel. It slides up from the bottom of the screen. Type to search, use the arrow keys to move, press Space to preview.
- Select an item and press Return to paste it into the app you were using. This uses macOS Accessibility: enable Copyo in System Settings > Privacy & Security > Accessibility. Without this permission, Return still copies the item to the clipboard for manual pasting. If pasting does not work right after granting the permission, quit and reopen Copyo.
- Right-click a card to pin it to a Pinboard, copy it as plain text, or delete it.
- Settings: click the gear button in the panel header, or right-click the menu bar icon and choose Settings.

4. External services
None. Copyo makes no network requests and uses no third-party SDKs, analytics, authentication services, payment processors or AI services. All data is stored locally in the user's Application Support folder. The optional sync feature only writes files to a folder the user explicitly selects (for example a folder inside iCloud Drive) through the standard file APIs; no server operated by us is involved.

5. Regional differences
None. The app functions identically in all regions. The interface is localized in English and Simplified Chinese.

6. Regulated industries and third-party material
Not applicable. Copyo does not operate in a regulated industry and contains no protected third-party material. It only stores content the user copies on their own device.

This build was tested on a physical MacBook running macOS 26.6.1 before submission.
```

粘到「备注」时把第一段末尾的 "A screen recording is attached to this message." 换成 "A screen recording was provided as an attachment in App Review messages on 2026-09-03."。

### 录屏方案（不暴露本机内容）

- 新建一个 macOS 标准用户「Demo」录制，桌面干净、无公司应用。语言设为 English。
- 录屏用的沙盒版从提审的 commit（c7dd41f）构建，放在 /Users/Shared/CopyoDemo/Copyo.app，演示文件在同目录。
- 录前在 Demo 账号里先给 Copyo 辅助功能权限（系统设置 → 隐私与安全性 → 辅助功能 → + 选中该 app），开勿扰。
- ⇧⌘5 录整个屏幕，90 秒内：Finder 双击启动 → 欢迎对话框点 Try It Now → 面板出现后关掉 → 在 TextEdit 复制一句话、Safari 复制一个链接、预览里复制一张图 → ⇧⌘V 呼出面板 → 输入关键词搜索 → 空格预览 → 回车粘贴进 TextEdit → 右键卡片固定到 Pinboard → 点齿轮打开设置扫一眼各标签 → 停止录制。
- 录完的 .mov 放到 /Users/Shared/CopyoDemo/，用 avconvert 压成 1080p H.264 再上传（附件尽量控制在 50MB 内）。

## 九、2026-09-08 第二次拒审（1.0 (3)）：2.4.5 辅助功能 + 1.5 支持网址

### 拒审内容与事实核对

| 条款 | 审核说法 | 事实 |
| --- | --- | --- |
| 2.4.5 | 应用用辅助功能（Accessibility）来实现热键，属于把无障碍功能挪作他用 | 全局快捷键走 Carbon `RegisterEventHotKey`（当时的 `Copyo/Services/HotkeyManager.swift`，现在是 `Copyo/Services/HotkeyManager.swift`），不需要任何权限。辅助功能只在自动粘贴时用于向目标应用发送 ⌘V（当时的 `PasteService.sendCmdV`，现已删除）。审核员把两者混为一谈，欢迎对话框和设置页当时的文案也确实没把两者分开 |
| 1.5 | 支持网址（Gist）不是一个可以提问、求助的网页 | Gist 里只写了「仓库发布后公开」，而仓库当时是私有的，用户没有任何联系渠道 |

### 1.0 (4) 的改动

- **整体移除「自动粘贴」功能**（两种构建都移除，不留条件编译）。选中条目回车后：写回剪贴板、收起面板、把焦点还给之前的应用，用户按 ⌘V 粘贴。
- 应用不再调用任何辅助功能 API（`AXIsProcessTrusted`、`CGEvent` 投递等），不再导入 `ApplicationServices`，也不再有任何权限提示。
- 随之删除：设置页「选中后自动粘贴」「粘贴音效」开关及辅助功能脚注、未授权提示弹窗、辅助功能变更通知监听；「始终以纯文本粘贴」改名为「始终以纯文本复制」。
- 面板右键菜单「粘贴 / 以纯文本粘贴 / 仅复制」合并为「复制 / 以纯文本复制」；快捷键页文案同步改为「复制」。
- 欢迎对话框只讲快捷键、搜索、回车复制和设置入口。
- 审核备注（第四节）改写，明确应用不使用辅助功能以及快捷键的实现方式。
- 新增支持页面 `docs/support/index.html`（中英双语：联系方式、快速上手、FAQ、隐私政策链接）。
- Release-AppStore 的 `CURRENT_PROJECT_VERSION` 已递增到 4；导出时 Xcode 又自动抬到 5（见提交顺序）。
- 自动粘贴的旧实现保留在 git 历史里（commit af221d4 时的 `Copyo/Services/PasteService.swift`）。上架后若要加回，提审时需自带 2.4.5 的说明，且可能再次被拒。

### 回复正文（贴到 App 审核 → 消息，两条拒审一起回）

```
Thank you for the detailed review. Both issues are addressed in build 1.0 (5).

Guideline 2.4.5 – Accessibility

The feature that used Accessibility, "Paste into the previous app on selection", has been removed from the app. Build 5 no longer calls any Accessibility API and never asks for Accessibility access; nothing in the app requires it. When the user selects an item and presses Return, Copyo puts it on the clipboard, closes the panel and returns focus to the app they were using, where they paste with Command+V.

For clarity: the Shift+Command+V shortcut never used Accessibility. It is registered with the Carbon RegisterEventHotKey API, which needs no permission, and is unchanged.

Guideline 1.5 – Support URL

The Support URL has been updated to https://vibemage.github.io/Copyo/support/. It is a dedicated support page with contact information, a quick-start guide, an FAQ and a link to the privacy policy.
```

### 发布支持页面（你来操作，回复审核前必须已上线）

先把页面里的占位邮箱换成真实的支持邮箱（两处）：

```bash
grep -n "REPLACE-ME" docs/support/index.html
sed -i '' 's/support@REPLACE-ME.example/你的邮箱/g' docs/support/index.html
```

> ⚠️ 以下命令是 2026-09-09 当时的操作记录，仓库那时还叫 `Copyo`。仓库已于 2026-09-16 改名为 `copyo`，
> 现在的支持页面地址是 `https://vibemage.github.io/copyo/support/`。照抄下面的命令会操作到不存在的仓库。

**方案 A（推荐，与「上架即开源」的计划一致）**：仓库转公开，用 main 分支的 /docs 目录做 GitHub Pages。
issues 页面同时可用，PRIVACY.md 和支持页里的 issues 链接都会生效。

```bash
git add docs/support && git commit -m "[docs][copyo][1.0]: add support page" && git push
gh repo edit VibeMage/Copyo --visibility public --accept-visibility-change-consequences
gh api -X POST repos/VibeMage/Copyo/pages -f 'source[branch]=main' -f 'source[path]=/docs'
# 等 1–2 分钟
curl -sI https://vibemage.github.io/Copyo/support/ | head -1   # 期望 HTTP/2 200
```

**方案 B（仓库暂时保持私有）**：只把这一个页面推到一个新的公开仓库。
此时支持 URL 改为 `https://vibemage.github.io/copyo-support/`，回复正文和 ASC 表单里同步替换；
页面里的 issues 链接会 404，建议顺手把那两行改成邮箱。

```bash
tmp=$(mktemp -d) && cp docs/support/index.html "$tmp/" && cd "$tmp" \
  && git init -q -b main && git add . && git commit -qm "Add support page" \
  && gh repo create VibeMage/copyo-support --public --source=. --push \
  && gh api -X POST repos/VibeMage/copyo-support/pages -f 'source[branch]=main' -f 'source[path]=/'
```

### 提交顺序（1.0 的历史记录；现在有效的支持网址见第二节）

1. 上传新构建：从 `release/1.0` 出包（见第六节），用 Transporter 拖入
   `build/appstore/Copyo-1.0-appstore.pkg` → Deliver；或直接 `UPLOAD=1` 让脚本上传。
   注意包里的构建号由 Xcode 导出时自动抬高（取 App Store Connect 上已有的最大值加一），
   2026-09-09 出的包是 1.0 (5)，回复正文里的构建号要与实际上传的一致。
   上传后等 App Store Connect 处理完（收到「已完成处理」邮件，通常 5–30 分钟）。
2. App Store Connect → 我的 App → Copyo → 1.0 版本页：
   - 「构建版本」移除 1.0 (3)，选择新上传的构建（1.0 (5)）。
   - 「技术支持网址」改为 `https://vibemage.github.io/Copyo/support/`。
   - 「描述」中英文各改一行（见第三节：回车后内容回到剪贴板，⌘V 粘贴）。
   - 「App 审核信息 → 备注」整段替换为第四节的新版本。
   - 存储。
3. 「App 审核」区域打开与审核的消息记录，回复上面的回复正文。
4. 点右上角「提交以供审核」。

## 十、审核通过（2026-09-11，1.0 (5)）

- 状态：审核通过，欧盟之外地区上架，商店页面最长 24 小时后可见。
- 欧盟 27 国暂不可售：需要先在 App Store Connect 完成《数字服务法案》(DSA) 交易者状态声明。
  Copyo 免费、无内购、无广告，个人账号可选「非交易者」：应用随即在欧盟可售，商店页对欧盟用户
  显示一条「消费者保护法不适用」的提示，不公开任何联系方式。若选「交易者」，个人开发者的地址、
  电话、邮箱会公开显示在欧盟商店页，并需邮箱/手机验证和上传证明文件。
- 操作路径：App Store Connect → 业务（Business）→ 协议（Agreements）→ 合规（Compliance）→
  Digital Services Act → Complete Compliance Requirements → 选「This is not a trader account」→ Done。
  也可在 App → App 信息 → App Store Regulations and Permits 里按应用单独设置。

## 十四、重建记录的实际结果（2026-09-19 当天完成）

### 开发者后台（全部建好）

| 标识 | 值 | 配置 |
| --- | --- | --- |
| App ID（主应用） | `dev.vibemage.Copyo` | 全平台；App Groups ✓、iCloud + CloudKit（1 个容器）✓、Push ✓ |
| App ID（分享扩展） | `dev.vibemage.Copyo.ShareExtension` | App Groups ✓ |
| App ID（小组件） | `dev.vibemage.Copyo.Widgets` | App Groups ✓ |
| App Group | `group.dev.vibemage.Copyo` | 三个 App ID 都已勾选 |
| iCloud 容器 | `iCloud.dev.vibemage.Copyo` | 主应用 App ID 已选中 |

### ASC 应用记录

| 字段 | 值 |
| --- | --- |
| 名称（英语 美国，主要语言） | `Copyo - Clipboard History`（25 字符） |
| 名称（简体中文本地化） | `Copyo - 剪贴板历史`（13 字符） |
| 平台 | macOS（iOS 待 Phase 1 就绪后「添加平台」） |
| 套装 ID | `dev.vibemage.Copyo` |
| SKU | `copyo` |
| Apple ID | `6813955206` |
| 状态 | 1.0 准备提交 |

### 商店名为什么不是光秃秃的「Copyo」

ASC 拒绝了裸名 `Copyo`：「你输入的 App 名称已被使用」。查证结果：

- **不是被上架应用占用**。iTunes Search API（美区 + 中国区 × Mac + iOS）对 `copyo` 的精确匹配为零，
  中国区 resultCount 直接是 0。
- 也**不是我们自己的旧记录攥着**：旧记录从建立到删除，App 信息里的名称从未改成
  `Copyo: Clipboard History`——那一步计划过，但从未执行。
- 结论：**第三方在 App Store Connect 里预留了这个字符串**。预留名不出现在商店里，但会挡住新记录，
  且等不到自动释放，支持请求也需要证明名称使用权。

ASC 锁的是精确名称字符串，Apple 官方给的解法就是加限定词；这个品类本来也人人都加
（货架邻居 `CopyClip - Clipboard History`，连 Paste 本尊都是 `Paste – Limitless Clipboard`），
所以加后缀在品牌上零损失。**不要再尝试把商店名改回裸名 `Copyo`。**

评估过的替代品牌全部否掉，主要死因是同品类撞名——**Pinza** 与 **Magpie** 各有一个正在上架的
macOS 菜单栏剪贴板管理器，重蹈 Copyo / copyoapp.com 的覆辙；Twofold、Clipo / Clippo、ClipDeck、
Cardo、Roneo、Inkyo 等十余个也都撞了在架应用或踩了发音雷。

### 旧 App ID 删不掉（Apple 拒绝）

尝试删除 `dev.vibemage.Copyo` 时 Apple 返回：

> The App ID '9A94W79V84.dev.vibemage.Copyo' appears to be in use by the App Store,
> so it can not be removed at this time.

说明已删除的应用记录在 Apple 侧仍与该 bundle ID 绑定（同样的原因，它也不出现在新建记录的套装 ID
下拉里）。**这不是操作失误，是 Apple 的限制**，过一段时间可以再试；删不掉也无害，闲置而已。
`iCloud.dev.vibemage.Copyo` 容器同理——iCloud 容器详情页只有 Description 与 Save，**压根没有删除入口**
（对比 App ID 详情页是 Remove + Save），列表筛选器里那个 Hidden 档也没有对应的操作控件。

### 待办（按紧急程度）

1. **注册 `copyo.app` / `copyo.io` / `copyo.dev`**。当初查到的是「可注册」，至今仍然**没有注册**——
   RDAP 权威查询（带对照组）对三个域名均返回 not found。谁都能抢，尽快拿下。
   `copyo.com` 自 2012 年被人持有（GoDaddy 锁定，空页面），放弃。
2. **递交美国第 9 类 COPYO 商标申请**。我们对 ASC 里那个预留者、以及一家同拼写的孟菲斯 AI 文案 SaaS
   「Copyo」都是在后方；有申请在手 + GitHub 提交这类带日期的首次使用证据，将来遇到 App 名称争议才有得打。
   ⚠️ USPTO 注册库**未能核实**（Justia 403、无公开 API、WIPO 有反爬验证），「商标干净」属未证实而非已证实。
3. **DSA 交易者状态**。ASC 首页横幅：不提供交易商状态则无法提交新 App 或更新以在欧盟分发。
   路径见第十节，个人账号选「非交易者」即可。
4. ~~商店文案、关键词、截图、隐私问卷~~ 已填完，见第十五、十七节。

## 十五、1.0 版本页填写进度（2026-09-19）

### 已填好并保存

| 项目 | 状态 |
| --- | --- |
| 英文：推广文本 / 描述 / 关键词 / 技术支持网址 / 版权 | ✅ |
| 简体中文：推广文本 / 描述 / 关键词 / 技术支持网址 | ✅ |
| 审核备注（英文） | ✅ |
| 「需要登录」勾选 | ✅ 已取消（ASC 默认勾上，Copyo 不需要登录账号，勾着且账号为空会卡验证） |
| 截图 | ✅ 2 张（`01-panel-en` / `02-search-en`）。ASC 默认一套截图用于所有本地化版本，要分语言得用「媒体管理」 |
| 隐私政策网址 | ✅ 指向公开 Gist |
| 数据收集问卷 | ✅ 已答「不会从此 App 中收集数据」并保存 |
| 类别 | ✅ 主要 = 效率 |

### 对第三节原稿做的三处修改（已同步回本文档）

1. **删掉「曾用名 Copyo」/「formerly Copyo」**（描述与审核备注各一处）。
   copyoapp.com 的 Copyo 是别家公司仍在售的产品，在商店文案里写「曾用名 Copyo」
   容易被读成与对方有关联；而且旧记录已删，商店里没有任何连续性需要交代。
2. **关键词里的 `copyo` 换成 `clip`**（中英文各一处）。拿竞品名当关键词违反 App Store 规则，
   而且那正是我们要摆脱的名字。
3. **⇧⌘V 一律写成 `Shift+Command+V`**。第三节本来就警告过 ASC 的推广文本/关键词字段
   不接受按键符号；为保持一致，描述与审核备注里也用了展开写法。

### 还没做（需要你本人）

1. **发布隐私答复**。App 隐私页右上角「发布」，弹窗要你确认「答复准确无误且遵守《App Store 审核指南》
   和适用的法律」——这是一条以你名义作出的合规声明，我没有代你点。答案已经存好，点一下即可。
2. **价格与销售范围**：定价时间表与供应情况都还是空的，提审前必须设置（免费 + 选国家/地区）。
   欧盟那部分与 DSA 交易者状态绑在一起。
3. **DSA 交易者状态**（见第十节）。
4. **构建版本**：还没有可上传的包。2026-09-19 在本机跑 `./scripts/build-appstore.sh` 归档失败，
   根因是 **Xcode 里一个 Apple ID 都没登录**（`error: No Accounts: Add a new account in Accounts settings.`），
   连带没有任何证书与描述文件（`security find-identity` 返回 0，描述文件目录为空）。按顺序补：

   1. Xcode → Settings → Accounts → ➕ 登录 Apple ID，选中团队 `9A94W79V84`
   2. Manage Certificates… → ➕ 建 **Apple Distribution** 与 **Mac Installer Distribution**
   3. 用 Xcode 打开 `Copyo.xcodeproj` → target Copyo → Signing & Capabilities，勾上
      Automatically manage signing 并选团队——**这一步会把本机注册进账号**。归档用的是
      Apple Development 身份，要一张 Mac App Development 描述文件，而这类描述文件
      必须账号里至少注册过一台 Mac，`xcodebuild` 自己不会注册设备
   4. 重跑 `./scripts/build-appstore.sh`

   脚本列的另外两条前置（ASC 里有 `dev.vibemage.Copyo` 的应用记录、App ID 开好 iCloud+Push
   与容器）**今天都已经满足**，见第十四节。
5. ~~截图 03 / 04 要重拍~~ **已重拍**，见第十六节。

## 十六、商店截图重拍（2026-09-19）

### 为什么必须重拍

初版四张是 Copyo 1.0 时代拍的，其中两张仍在宣传 **1.0 (4) 已经移除的自动粘贴**：

- `03-preview-*`：副标题「Preview text, images and files — then ↩ **to paste**」／「↩ **直接粘贴**」
- `04-shortcuts-*`：设置页截图里是「**Paste** selected item」「**Paste** selected item as plain text」，
  这两条文案在移除自动粘贴时就改成了 Copy / 复制

拿去提审等于截图展示一个会自动粘贴的应用，而审核备注写的是「本应用不粘贴、不使用辅助功能」，
自相矛盾——2.4.5 正是 2026-09-08 那次拒审的条款。

### 做了什么

四张**全部重拍**，而不是只补两张：初版面板高 564px，本机采集出来是 507px（屏幕宽高比不同），
只换两张会让卡片大小对不上。

新增 `scripts/make-store-shots.py`，把这件事变成可复现的管线：统一的渐变背景板
（`art/store/_background-plate.png`，从初版反推）+ 应用图标 + 标题 + 副标题 + 真实 UI 截图。
版式参数（图标位置与尺寸、标题/副标题基线与字号、设置窗口贴图位置）都由初版实测标定，
新图与初版逐像素对齐（图标包围盒 1218–1340 × 204–329，完全一致）。

`AppDelegate` 新增 `-showPanel` 启动开关（与既有的 `-forceDark`、`-demoPreview`、
`-settingsTab` 同类），启动即拉起面板，省得靠模拟 ⇧⌘V——全局快捷键走 Carbon，
模拟按键要给控制方开辅助功能权限。

演示数据用一个一次性 Swift 包灌进库里再拍，**不要拿自己的真实剪贴板去拍**，
那会把私人内容发到 App Store 上。拍完记得删掉 `~/Library/Application Support/Copyo/`。

### 改掉的文案

| 截图 | 旧（作废） | 新 |
| --- | --- | --- |
| 03 en | Preview text, images and files — then ↩ to paste | Preview text, images and files without leaving the panel |
| 03 zh | 大图预览文本、图片和文件，↩ 直接粘贴 | 大图预览文本、图片和文件，不用离开面板 |
| 04 en | Summon, search, **paste**, preview — and ⇧⌘V is yours to remap | Summon, search, **copy**, preview — and ⇧⌘V is yours to remap |
| 04 zh | 呼出、导航、**粘贴**、预览，全程快捷键；⇧⌘V 可自定义 | 呼出、导航、**复制**、预览，全程快捷键；⇧⌘V 可自定义 |

01 与 02 的文案原样保留，只是重新采集了 UI。

## 十七、本地化名称不受名称预留限制（2026-09-19 实测）

**裸名 `Copyo` 在简体中文的本地化名称字段里可以用**，保存无报错。

ASC 的名称唯一性检查只卡**主要语言那一个名称字符串**（建记录时填的那个，就是它撞上了第三方的预留）；
其他语言的本地化名称不走同一个检查。所以：

| 语言 | 名称 | 副标题 |
| --- | --- | --- |
| 英语（美国，主要语言） | `Copyo - Clipboard History` | 留空（见第三节） |
| 简体中文 | **`Copyo`** | `剪贴板历史，一按即达` |

中国区商店里显示的就是干净的「Copyo」加一行中文副标题，品牌词不必带后缀。英文区仍然受预留所限，
只能用带限定词的形式——这不是可以绕开的，别再去试改主要语言的名称。

### 截图按语言分开配置

ASC 默认一套截图通用于所有本地化版本。要给中文单独一套：
**版本页 →「在"媒体管理"中查看所有尺寸」→ 切到简体中文 → 点「使用英语（美国）的 Mac 文件」旁边的
「编辑」解除继承 → 再上传。** 解除继承不影响英文那套。

两套都已配好，各 4 张，顺序为 01 面板 → 02 搜索 → 03 预览 → 04 快捷键。

⚠️ 上传多张时**必须一张一张传、等上一张处理完再传下一张**——一次选多个文件，ASC 落盘顺序是乱的
（实测传 4 张得到的顺序是 03、02、01、04）。

## 十八、1.0 构建版本出包成功（2026-09-20）

### 签名前置（本机一次性）

初次在本机构建时 `security find-identity` 返回 0、描述文件目录为空，`build-appstore.sh` 依次报了
`No Accounts` → `no devices from which to generate a provisioning profile`。补齐顺序：

1. Xcode → Settings → Accounts 登录，选团队 `9A94W79V84`
2. Manage Certificates… → ➕ 新建三张（私钥只存在于创建它的那台机器，旧 Mac 上的证书在
   Xcode 里显示 **Not in Keychain**，下载不下来，只能新建或从旧机导出 `.p12`）：
   `Apple Development` / `Apple Distribution` / `Mac Installer Distribution`
3. Xcode 打开工程 → target Copyo → Signing & Capabilities → **Register Device**
   （归档用 Apple Development 身份，需要 Mac App Development 描述文件，
   而这类描述文件要求账号里至少有一台已注册的 Mac；`xcodebuild` 自己不会注册设备）

Xcode 随之重写了 `project.pbxproj`，顺带补上了 Copyo 的 Release-AppStore 一直缺失的
`DEVELOPMENT_TEAM`（见 commit fae79f8）。

### 产物核验

`build/appstore/Copyo-1.0-appstore.pkg`（1.9 MB），展开后逐项核过：

| 项目 | 值 |
| --- | --- |
| .app 签名 | `Apple Distribution: NING YUAN (9A94W79V84)` |
| .pkg 签名 | `3rd Party Mac Developer Installer: NING YUAN (9A94W79V84)` |
| aps-environment | `production` |
| iCloud 容器 / 环境 | `iCloud.dev.vibemage.Copyo` / `Production` |
| 沙盒 | `com.apple.security.app-sandbox: true` |
| Bundle ID / 版本 | `dev.vibemage.Copyo` / 1.0 (1) |
| LSUIElement | true |
| 最低系统 | macOS 14.0 |
| 出口合规 | `ITSAppUsesNonExemptEncryption: false` |
| 图标 / 本地化 | `AppIcon.icns` ✓ / `en.lproj` + `zh-Hans.lproj` ✓ |

归档阶段那份是 Apple Development 签名、`aps-environment: development`，**这是正常的**——
`-exportArchive` 会重签成 Apple Distribution 并切到 production。要核验的是导出后的 `.pkg`，不是归档。

### 商务页面新冒出来的两条阻塞

1. **法律实体合规筛查**（带移除警告，优先级最高）：横幅「请立即查看"NING YUAN"的相关信息。
   如未能提交补充文稿，你的内容可能会从 App Store 移除」。要求上传显示**英文法律实体名称**与
   出生日期的政府证件。**用护照身份信息页，不要用中国大陆身份证**——身份证既无英文姓名也无
   英文格式。护照拼音姓名要与账号登记的 `NING YUAN` 完全一致（含顺序）。
   受此影响，**免费 App 协议的状态从「有效」变成了「等待用户信息」**，协议不恢复有效会挡提审与上架。
2. **DSA 交易商状态**：另一条横幅「完成合规要求」，个人账号选「非交易商」即可（见第十节）。
   不做只影响欧盟可售，不挡审核。

上传构建版本不依赖协议状态，可以与补材料并行。

## 十九、提审前全量核查（2026-09-20）

逐页核对的结果，**当时还不能提交**。

### 本次补齐

| 项目 | 结果 |
| --- | --- |
| 年龄分级 | **4+**，覆盖 172 个国家或地区（巴西「全部」、韩国「00+」）。七步问卷全部答「否 / 无」：无家长控制、无年龄保证、无不受限网页访问、无用户生成内容、无社交、无信息聊天、无广告、无成人主题、无医疗、无性或裸体、无暴力、无基于概率的活动。「年龄类别和覆盖」保持**不适用**——选「面向儿童」会归进儿童类目，那有一整套额外合规要求 |
| 内容版权 | **否，此 App 不包含、显示或访问第三方内容**。面板里显示的是用户自己设备上的剪贴板数据，开发者既不提供也不访问；选「是」等于无中生有地声称拥有某些内容的版权 |

答「无不受限的网页访问」前核过代码：全工程没有任何 `WKWebView`，唯一的
`NSWorkspace.shared.open` 是跳系统设置的 Apple ID 面板，不涉及网页内容。

### 仍然缺的（按阻塞程度）

1. **构建版本** —— 版本页「构建版本」区域仍是「添加构建版本」，即尚无任何构建。
   `build/appstore/Copyo-1.0-appstore.pkg` 已就绪，待用 Transporter 上传并等处理完成后选中。
2. **价格与销售范围** —— 定价时间表与 App 供应情况**都还是空的**，两项提审必填。
3. **发布隐私答复** —— App 隐私页右上角「发布」按钮仍可点，说明答复尚未发布。
   这是一条以开发者名义作出的合规声明，需本人确认。
4. **免费 App 协议：正在验证** / **数字服务法：正在审核**（27 个国家或地区）——
   法律实体材料与 DSA 声明均已提交，等 Apple 处理，不是自己能推进的。
   协议不恢复「有效」会挡上架。
5. **CloudKit schema 未部署到 Production** —— 不挡审核，但包里
   `icloud-container-environment` 是 Production，新容器 `iCloud.dev.vibemage.Copyo`
   的 schema 从未部署，上架后用户开 iCloud 同步会直接失败。

### 一条需要确认的选择

App 信息页显示「**该开发者已表明是此 App 的交易商**」。选交易商意味着地址、电话、
电子邮件会公开显示在欧盟区产品页上。第十节与本文档此前的建议是：个人账号、免费、
无内购、无广告可选「非交易商」，等真的上内购再改。若这不是有意为之，趁 DSA 仍在
「正在审核」时可以在 App 信息页的「数字服务法 → 编辑」改回。

## 二十、1.0 已提交审核（2026-09-20）

| 项目 | 值 |
| --- | --- |
| 版本状态 | 正在等待审核 |
| 构建版本 | 1.0 (1)，2026-09-20 00:32 上传，包含 App 图标 |
| 免费 App 协议 | 正在验证 |
| 数字服务法 | 正在审核（27 个国家或地区，交易商） |

第十九节列的三个硬缺口（构建版本、价格与销售范围、发布隐私答复）均已由维护者补齐并提交。

### 提交后仍未处理的风险：CloudKit schema 未部署

提交的包里 `icloud-container-environment` 为 `Production`，而 `iCloud.dev.vibemage.Copyo`
是 2026-09-19 新建的容器，**schema 从未部署**——容器里没有 `ClipItem` / `Pinboard` 两张表。

此前记为「不挡审核」，更准确的说法是**也可能挡审核**：同步默认关闭，但审核员若在设置页
把同步方式切到 iCloud 试功能，会直接失败，构成 2.1（App 完整性）的拒审理由；即便审核员
没试，上架后第一个开启 iCloud 同步的用户也会撞上。

处理步骤：

1. 在已登录 iCloud 的 Mac 上跑一次带 iCloud 同步的构建，设置页把同步方式切到 iCloud，
   让 SwiftData 把表结构推到 Development 环境（会往自己的 iCloud 账号写入若干记录）
2. CloudKit Console → 选中 `iCloud.dev.vibemage.Copyo` → Deploy Schema Changes → 部署到 Production

### 另一条需要盯的

**免费 App 协议仍是「正在验证」**。即便审核通过，协议不恢复「有效」也会挡住发布上架。
1.0 那次从提交到过审用了 3 天（2026-09-08 拒审 → 09-11 通过）。

## 二十一、CloudKit schema 已部署到 Production（2026-09-20）

容器 `iCloud.dev.vibemage.Copyo` 的 schema 已部署：`CD_ClipItem`（22 字段）与
`CD_Pinboard`（12 字段），含 34 + 16 个索引。Production 环境逐字段核验通过。

### 做法

1. 用一次性 Swift 包把**每个属性都填满**的种子记录写进本地库（属性为 nil 的字段，
   CloudKit 不会建出来）
2. `defaults write dev.vibemage.Copyo syncMode -string icloud`，跑**真实签名的** Debug 构建
   （`CODE_SIGNING_ALLOWED=NO` 不展开 entitlements，CloudKit 根本连不上），
   让 SwiftData 把表结构推到 Development
3. CloudKit Console → Deploy Schema Changes → Production

### 坑一：新建容器第一次连接会被拒

首次启动报：

```
CKModifyRecordZonesOperation → CKError "Partial Failure" (2/1011)
  com.apple.coredata.cloudkit.zone → "Server Rejected Request" (15/2000)
→ Failed to set up CloudKit integration for store
```

账号本身是通的（`fetch-user-record-id` 成功）。**重启一次应用即恢复**——容器是几小时前
刚建的，服务端还没完全就绪。遇到别急着怀疑 entitlements 或账号。

### 坑二（重要）：二进制属性有两个字段，BYTES 与 ASSET

CoreData+CloudKit 对二进制属性建**两个**字段：数据小的时候写 `CD_x`（BYTES），
超过阈值时写 `CD_x_ckAsset`（ASSET）。**字段是按写入的记录惰性创建的**，所以：

> 只用小数据做种子 → Development schema 里只有 BYTES 那一个 → 部署到 Production 之后，
> 第一个复制大图的用户同步就会失败，而 **Production schema 只能加不能改**。

本次实测：先用 50 KB 的图标，schema 里只有 `CD_imageData`（BYTES）；再写入一条 5.9 MB
的噪声图，`CD_imageData_ckAsset`（ASSET）才出现。

因此部署前额外写入了大号 `rtfData`（3.4 MB）与 `filePaths`（22000 条路径），把三个
asset 变体全部逼出来。**最终部署的 Production schema 含：**

```
CD_filePaths BYTES + CD_filePaths_ckAsset ASSET
CD_imageData BYTES + CD_imageData_ckAsset ASSET
CD_rtfData   BYTES + CD_rtfData_ckAsset   ASSET
```

**以后给模型加任何二进制属性，都必须在部署前用一大一小两条记录各写一次**，否则
Production 会缺 asset 字段。

### 收尾

探针记录（3 条 ClipItem + 1 个 Pinboard，含噪声图与假路径）已删除，删除经同步传播到
私有数据库；本机 `~/Library/Application Support/Copyo/` 与应用偏好一并清除。

## 二十二、「零网络请求」的说法与在审的包已经对不上（2026-09-20 发现，待维护者定夺）

第六节记着「**1.0 的上架包一律从 `release/1.0` 分支构建**……商店描述里『零网络请求』的说法也仍然成立。
iCloud 版本留给 1.1」。但第十八节核验的 `Copyo-1.0-appstore.pkg` 里写着
`iCloud 容器 / 环境：iCloud.dev.vibemage.Copyo / Production`、`aps-environment: production`——
**在审的这个包是从 main 出的，带 CloudKit 与推送**。于是下面这几处的措辞都不再准确：

| 位置 | 现在的说法 |
| --- | --- |
| 推广文本 zh / en（第三节） | `零网络请求` / `zero network requests` |
| 描述 zh / en（第三节） | `无遥测、无统计、无任何网络请求` / `No telemetry, no analytics, no network requests.` |
| 出口合规（第二节） | 「不使用加密（**应用无任何网络请求**）→ 选择否/豁免」 |
| 审核备注（第八节） | `Copyo makes no network requests and uses no third-party SDKs…` |
| `PRIVACY.md` 与线上 Gist | `No analytics, no telemetry, no crash reporting, no network requests.` |

几点判断：

- **出口合规的答案本身没错**，错的只是记在这里的理由。CloudKit 用的是系统提供的标准加密，
  仍然属于豁免；下次填的时候别再写「无任何网络请求」当依据。
- **描述与推广文本是真要改的那一处**。同步默认关闭不能让「零网络请求」变成真话，
  而 1.0 (3) 那次正是栽在「商店文案承诺了应用做不到的事」（2.4.5，见第九节）——
  这回是反过来：文案否认了应用**做得到**的事。同一类问题。
- 隐私政策要跟着改的是**线上那份 Gist**（`gist.github.com/VibeMage/d39d7165…`），
  仓库里的 `PRIVACY.md` 只是副本，审核员看的不是它。改的时候要写清两件事：
  iCloud 同步镜像到的是**用户自己 Apple 账户下的私有数据库**，开发者看不到；
  以及注册 APNs 只为让 CloudKit 通知「另一台设备改了东西」，是静默推送、从不弹通知。
- 文案属于维护者自己的口径，这里只记录不一致，不代笔。

## 二十三、把「零网络请求」的口径全部改正（2026-09-20）

第二十二节列出的不一致已按以下方式处理。**判断的基准是送审包里的 entitlements**：
`network.client` + `CloudKit` + `aps-environment: production`。

### 已改（仓库内，随下一个构建生效）

| 位置 | 改成什么 |
| --- | --- |
| `PRIVACY.md` | 重写。写明同步默认关闭、两种可选模式各自做什么、iCloud 镜像进的是**用户自己**的私有数据库、APNs 只做 CloudKit 的静默变更通知 |
| `Copyo/Settings/SettingsView.swift:610` + 三种语言译文 | 「关于」页那句 "All data stays on this Mac…" 是**无条件为假**的——开了 iCloud 同步就不成立。改为「同步默认关闭；开启后也只进你自己的 iCloud 或你选的文件夹」 |
| `docs/support/index.html:286` | 「Download on the Mac App Store」指向 `id6807507103`（**已删除的旧记录，实测 404**），而新记录 `6813955206` 未过审同样不存在。先改为 GitHub Releases，过审后换回去 |
| `README.md` / `README.en.md` 第 6 行 | 去掉「无任何网络请求」，改为「同步默认关闭」 |
| 本文件第二、三、八节 | 出口合规与 App 隐私的**理由**、推广文本、描述、审核备注一并更正 |

### 核过之后决定**不改**的

- **出口合规答案**仍是「否/豁免」：CloudKit 走的是 Apple 框架提供的 HTTPS，属于豁免加密。
  错的只是理由，答案本身没错。
- **App 隐私问卷**仍是「不收集数据」：Apple 对「收集」的定义要求开发者能访问，
  而 Copyo 只用 `.private(...)` 私有数据库（`CopyoStore.swift:72`），全仓库没有
  `publicCloudDatabase` / `CKShare`，我们读不到。
- **`SettingsView.swift:387`**（App Store 版文件夹同步的说明，「数据只经过你自己的存储」）：
  这条只在同步方式为「共享文件夹」时显示，在那个语境下是真的。
- **`SettingsView.swift:251`**（「剪贴板历史只保存在这台 Mac 上」）：只在同步关闭时显示，同样为真。
- **GitHub 上 v0.1.0 的 Release 说明**里写着「自动粘贴」：它描述的是 0.1.0，当时确实有，
  属于历史记录，改了等于篡改历史。

### 还要在浏览器里做的（需维护者本人操作或授权）

1. **线上 Gist**（`gist.github.com/VibeMage/d39d7165…`）——**优先级最高**。它是商店页
   直接引用的隐私政策，审核员一点就到，而它和二进制对不上。内容照 `PRIVACY.md` 新版。
2. **推广文本**（中英各一）——ASC 里推广文本可随时改、不用重新提审。
3. **描述与审核备注**——属于版本级字段，在「等待审核 / 正在审核」状态下只读。
   要改必须先把版本撤出审核，代价是重新排队。**建议：不撤**，因为我们本来就要回复
   2.1 那封信，回信里已经主动写明了这处不一致并说明正在更正；主动披露比被查出来好，
   也比丢掉排队位置划算。描述随下一个版本改。

### 顺带发现、与文案无关的两件事

- **同步开关关不掉本次会话**：CloudKit 镜像与 APNs 注册都在启动时latch一次
  （`AppDelegate.swift:41-47`、`:78-84`），用户把同步从 iCloud 切到关闭之后，
  这次会话仍在上传，要重启才真的停。设置页已经如实提示了，但这意味着每一句隐私
  承诺都得带上「重启后生效」的尾巴。**正确的修法是改代码，不是改文案。**
- **没有「全部删除」**：两处「清空历史」都只删未固定的条目
  （`SettingsView.swift:179`、`AppDelegate.swift:242`），删 Pinboard 也只是解绑
  （`Pinboard.swift:13` 是 `.nullify`）。想彻底清空要先删 Pinboard 再清历史，顺序错了
  最敏感的内容还留在 iCloud 里。建议加一个「删除所有数据」。

## 二十四、2.1「需要补充信息」的处理（2026-09-20）

1.0 (1) 提交当天被退回，条款是 **Guideline 2.1 Performance: App Completeness**，
正文是新开发者账号首次提审的标准模板：要一段真机录屏 + 六项说明。
**不是功能拒审**，补齐即可。

### 关键发现：状态是「被拒绝」而不是「等待审核」

这一点改变了整个策略。此前按「等待审核」判断，以为描述与审核备注是只读的、
要改必须撤回重排队；进 ASC 才看到状态是**被拒绝**，所有版本级字段都可编辑，
右上角「保存」与「更新审核」都是亮的。于是描述、推广文本、审核备注全部就地改正，
不用撤回、不损失排队位置。

### 做了什么

| 项目 | 内容 |
| --- | --- |
| 录屏 | 1080p / 1 分 57 秒 / 6.5 MB。从「应用程序」双击启动开始，含首启动欢迎框、菜单栏图标、现场复制四类内容、⇧⌘V 呼面板、即输即搜、空格预览、**回车→焦点交还→用户自己按 ⌘V**、设置五个标签页 |
| 回复正文 | 按 Apple 六项编号逐条回答，3985 字（回复框上限 4000） |
| 审核备注 | 整段重写，六项齐全，3980 字（备注上限 4000） |
| 附件 | 录屏同时挂在「App 审核信息 → 附件」与消息线程两处 |
| 描述 / 推广文本 | 中英两套一并改正「零网络请求」的说法 |

### 录屏怎么做的（下次照做）

**必须用 Release-AppStore 配置构建**：`APPSTORE` 编译标志只在这个配置里开，
Debug 版的欢迎语和面板齿轮按钮都和审核员看到的不一样。
并且要**从送审那个提交单开 worktree 构建**（本次是 `fae79f8`），否则 main 上
后加的法语会出现在画面里，一眼就能看出录的不是送审那个包。

录制环境三件事缺一不可，否则会把私人内容拍给 Apple：

```bash
defaults write com.apple.finder CreateDesktop -bool false       # 桌面图标
defaults write com.apple.dock autohide -bool true               # 程序坞
defaults write com.apple.WindowManager StandardHideWidgets -bool true   # 桌面小组件
killall Finder Dock WindowManager
```

演示素材放 `/Users/Shared/CopyoDemo/`——空格预览会显示**完整路径**
（`PreviewOverlay.swift:52`），放家目录会把用户名带进画面。
（卡片本身只显示文件名，`CardView.swift:161` 取的是 `lastPathComponent`。）

应用语言用单应用覆盖，不必改系统语言：

```bash
defaults write dev.vibemage.Copyo AppleLanguages -array en
defaults write dev.vibemage.Copyo hasCompletedOnboarding -bool false   # 让欢迎框重新出现
```

`hasCompletedOnboarding` 必须走 `defaults write` 而不是直接删容器里的 plist：
cfprefsd 有缓存，直接改文件不生效。

### 踩过的坑

- **访达的「输入定位」对合成的 unicode 事件不生效**，文本框里有效。靠它定位要打开的
  应用会时灵时不灵，改用辅助功能 API 按名字取行再双击才稳。
- **卡片时间戳渲染一次就冻住**：面板只隐藏不销毁，视图不重算，新条目永远显示
  `in 0 sec.`，直到有新条目进来触发整列刷新。1.0 (1) 里就有，属已知瑕疵。
- **ASC 的回复框与备注框都是 4000 字上限**，超了保存会红框报错并显示差多少字。
- **回复框会抢焦点**：焦点停在上面时在别处打的字会进到回复框里。发送前务必核对
  一遍正文，别把不相干的内容发给 Apple。

## 二十五、同步「关闭」其实没关（2026-09-21 实测发现，1.0 就有）

修「删除所有数据」时顺带挖出来的，比原本要修的两件都严重，而且**已经在审核中的
1.0 (1) 里**。

### 现象

`CopyoStore.makeContainer` 的非 CloudKit 分支：

```swift
: ModelConfiguration(schema: schema, url: url, allowsSave: allowsSave)
```

没有显式给 `cloudKitDatabase`。它的默认值是 `.automatic`，含义是
**「签了 CloudKit entitlement 就开镜像」**——而上架版正是签了的。
于是用户把同步设成「关闭」，SwiftData 照样把整个库镜像到他自己的 iCloud。

### 怎么确认的

排除法，不靠读代码猜：删掉整个库目录 → 启动 → **全程不复制任何东西** →
`syncMode` 从头到尾是 `off`。

| 时刻 | 库里条目数 |
| --- | --- |
| 启动 4 秒 | 0 |
| 再等 8 秒 | **6**（全是旧记录，时间戳跨越前几轮测试） |

显式写 `cloudKitDatabase: .none` 之后，同一实验稳定停在 0 条，
`Copyo_ckAssets` 目录也不再生成。

这也是「删除所有数据」一度怎么都删不干净的真正原因——删完几秒就被 CloudKit
灌回来。查了好几轮才定位到，中间一度误以为是测试方法的问题。

### 影响与处置

隐私政策（商品页直接引用的那份 Gist）里写着「同步默认关闭，关闭时不会有任何数据
离开本机」。**这个修复之前那句话是假的。**

数据进的是用户自己 Apple 账户下的私有数据库，开发者读不到，所以不构成
「收集数据」，App 隐私问卷的答案不用改。

**维护者决定：不动正在审核的 1.0 (1)，修复随 1.1.0 发布。**
代价是 1.0 上架后到 1.1.0 之间，设置成「关闭」的用户数据仍会进他们自己的 iCloud。
这条在这里记下来，是为了万一将来被问起，能说清当时知道什么、怎么权衡的。

### 给下次的教训

`ModelConfiguration` 那几个带默认值的参数，凡是涉及数据去向的都要显式写出来。
`.automatic` 这种「看情况」的默认值，在一个签了 entitlement 的上架包里和在
开发机上行为完全不同，而单元测试和本地 Debug 跑都发现不了。


## 二十六、iOS / iPadOS 首版（1.1.0）提审材料（2026-09-27）

iOS 版挂在同一条应用记录（`6813955206`）上，走通用购买：ASC → App → 左上「添加平台」→ iOS。
版本号 1.1.0（与工程 `MARKETING_VERSION` 一致；iOS 与 macOS 的版本号在 ASC 里各自独立）。

### 字段归属：哪些是两个平台共用的

- **App 级（共用）**：名称、副标题、隐私政策网址、类别、年龄分级、App 隐私问卷。
  改副标题会**同时改掉 Mac 商品页**，所以下面的副标题两端都成立。
- **版本级（iOS 单独填）**：推广文本、描述、关键词、技术支持网址、版权、截图、审核备注。
- 隐私政策（Gist）与支持页已按 iOS 补写，见仓库 `PRIVACY.md` 与 `docs/support/index.html`。
  **Gist 要手工同步**（`gist.github.com/VibeMage/d39d7165…`），支持页随 main 推送由 GitHub Pages 发布。

### 截图

`art/store-ios/`，由 `scripts/capture-store-shots-ios.sh` 采集、`scripts/make-store-shots-ios.py` 合成。
6.9 英寸 iPhone（1320×2868）六张、13 英寸 iPad（2064×2752）四张，中英各一套。
**ASC 的 iPhone 截图位要的是 6.5 英寸**（1284×2778，不收 6.9 英寸的尺寸），上传用的是
`art/store-ios/iphone-6.5/`：从 6.9 英寸成图按宽等比缩放、上下各裁约 6px 得到。版式跟 iOS 设计稿走
（暖白底、系统字体），不沿用 Mac 那套深色底板。ASC 里用「媒体管理」按语言分别上传（见第十七节）。

### 口径（与 Mac 不同的地方，写文案时别抄错）

- **iOS 上 iCloud 同步默认开启**（`IOSSettings` 注册默认值为 `true`），Mac 上默认关闭
- iOS 只在前台读剪贴板；首次启动只记账不读取；没有「隐藏内容过滤」与「忽略应用」
- 键盘扩展**不在**这一版的包里（见 `docs/ios-plan.md` 3.6），文案与审核备注都不要提它能用
- 系统搜索索引默认关闭

### 副标题（App 级字段，iOS 与 macOS 共用）

English (U.S.) — 28/30

```
Search everything you copied
```

简体中文 — 11/30

```
复制过的一切，随时找回
```

---

### 推广文本（iOS 版本字段）

English — 163/170

```
Everything you copy on your Mac, searchable on iPhone and iPad through your own iCloud. Tap to copy it again. Save new clips from the share sheet or Action Button.
```

简体中文 — 81/170

```
Mac 上复制过的一切，经你自己的 iCloud 来到 iPhone 和 iPad，随时搜索、轻点即可再次复制。分享面板、操作按钮一键保存新内容。开源，无需账号。
```

---

### 描述

English — 2279/4000

```
Everything you've copied on your Mac, in your pocket. Copyo brings your clipboard history to iPhone and iPad through your own iCloud account, so you can search it anywhere and tap any clip to copy it again.

Copyo is an open-source clipboard manager for Mac, iPhone and iPad.

SEARCH AND COPY
• Text, rich text, links, colors and images, shown as cards
• Type to search, or filter by links, images or colors
• Tap a card to copy it, then paste it wherever you like
• Copy as plain text, share, or open a full-size preview
• Swipe right to pin, swipe left to delete
• Files copied on your Mac are listed by name and marked "Mac only"

SAVE FROM YOUR iPHONE
iOS doesn't let apps read the clipboard in the background, so Copyo saves at moments you choose:
• When you open Copyo, it saves what's on the clipboard. You can turn this off and use the Paste button instead.
• Share sheet: save text, links and images from any app, straight into a Pinboard if you like
• Quick Save: one press on the Action Button, a Control Center or Lock Screen control, or Back Tap through a shortcut. Copyo opens and saves the clipboard.
• "Save Clipboard" is also available in Shortcuts and Siri

PINBOARDS
Keep the clips you use often on Pinboards. Clearing history never touches pinned clips.

WIDGETS
• Recent Clips widget in small and medium sizes. Tap a clip to open Copyo and copy it.
• Save Clipboard control for Control Center, the Lock Screen and the Action Button

ON iPAD
• Sidebar layout with a grid of cards
• Drag clips into the app next to Copyo
• Hardware keyboard: Command-F to search, arrow keys to move, Return to copy, Shift-Return for plain text, Space to preview, Command-P to pin

PRIVACY
• Sync goes through Apple's iCloud to a private database in your own Apple Account. We run no server and can't read your clips.
• iCloud sync is on by default on iPhone and iPad so your devices share one history. Turn it off during setup or anytime in Settings, and your clips stay on this device.
• Showing clips in system Search is off by default.
• No account, no sign-in, no ads, no analytics, no third-party SDKs.
• The source code is on GitHub under the GNU GPLv3.

To sync with your Mac, get Copyo for Mac and turn on iCloud sync in its Settings (it's off by default on the Mac).
```

简体中文 — 956/4000

```
Mac 上复制过的一切，装进口袋。Copyo 通过你自己的 iCloud 把剪贴板历史带到 iPhone 和 iPad，随时搜索，轻点任意一条即可再次复制。

Copyo 是一款开源的剪贴板管理工具，支持 Mac、iPhone 和 iPad。

搜索与复制
• 文本、富文本、链接、颜色、图片，以卡片呈现
• 即输即搜，也可按链接、图片、颜色筛选
• 轻点卡片即复制，再粘贴到任何地方
• 纯文本复制、分享、大图预览
• 右滑固定，左滑删除
• Mac 上复制的文件显示文件名，并标注「仅 Mac」

在 iPhone 上保存
iOS 不允许应用在后台读取剪贴板，所以 Copyo 只在你选择的时刻保存：
• 打开 Copyo 时自动保存当前剪贴板。可以关闭，改用「粘贴」按钮手动保存
• 分享面板：在任意 App 里保存文本、链接和图片，可直接放进 Pinboard
• 一键保存：操作按钮、控制中心或锁屏控件一按即存，也可以通过快捷指令用「轻点背面」触发。Copyo 会打开并保存剪贴板
• 「保存剪贴板」也可以在快捷指令和 Siri 里使用

Pinboard
常用内容固定到 Pinboard，清空历史不会动到已固定的条目。

小组件
• 「最近的内容」小组件，小、中两种尺寸，轻点即打开 Copyo 并复制
• 「保存剪贴板」控件，可放进控制中心、锁屏，或绑定操作按钮

iPad
• 侧栏布局，卡片网格
• 把卡片拖到旁边的 App 里
• 硬件键盘：Command-F 搜索，方向键移动，回车复制，Shift-回车复制纯文本，空格预览，Command-P 固定

隐私
• 同步走 Apple 的 iCloud，数据存在你自己 Apple 账户下的私有数据库里。我们没有服务器，也读不到你的内容
• iPhone 和 iPad 上 iCloud 同步默认开启，让各设备共享同一份历史；可在首次引导或设置里随时关闭，关闭后内容只保存在本机
• 在系统搜索中显示条目，默认关闭
• 无需账号，无需登录，无广告，无统计，无第三方 SDK
• 源代码以 GNU GPLv3 许可证发布在 GitHub

要与 Mac 同步，请在 Mac 上安装 Copyo，并在其设置里开启 iCloud 同步（Mac 版默认关闭）。
```

---

### 关键词（iOS 版本字段）

English — 96/100（14 个词，逗号后没有空格，没有 App 名称，没有竞品名）。名称里已有的 clipboard、history 会被自动索引，所以没有重复写。

```
paste,copy,pasteboard,manager,clip,clips,pinboard,snippets,sync,icloud,widget,save,organizer,mac
```

简体中文 — 49/100 字符（UTF-8 为 97 字节，不管 ASC 按字符还是按字节计，都在 100 以内）

```
剪贴板,剪切板,粘贴板,历史,复制,粘贴,同步,小组件,收藏,效率,clipboard,paste
```

---

### 审核备注（英文）— 3964/4000

```
Copyo for iPhone and iPad is the companion to Copyo for Mac, which is already on the Mac App Store under this app record. It shows the user's clipboard history, synced from their Mac through their own private iCloud database, and lets them save new clips from the iPhone. Everything below can be tested on one iPhone or iPad, without a Mac.

No account, no login, no demo credentials needed. No in-app purchases.

CLIPBOARD ACCESS
- Copyo reads the clipboard only while it is in the foreground: when the user opens or returns to the app, and when the user presses the Save Clipboard control (which opens the app first). It never reads the clipboard in the background.
- On the very first launch Copyo only records the pasteboard change count and reads nothing, so whatever was copied before installing is not saved. To see a capture, copy something after onboarding, then return to Copyo.
- The iOS system prompt "Copyo would like to paste from <app>" is expected. Tap Allow Paste. Onboarding and Settings > Allow Paste from Other Apps explain how to set it to Allow in iOS Settings.
- The user can turn this off in Settings > Read Clipboard Automatically. Copyo then shows a banner with the system Paste button (UIPasteControl) and saves only when the user taps it.
- Copyo never pastes into other apps and uses no Accessibility APIs. Tapping a card copies it; the user pastes it themselves.

HOW TO TEST
The attached video shows steps 1-4 in the iOS Simulator. It has no iCloud account, so the sync status there reads "Not synced".
1. Launch Copyo. Three onboarding pages; tap Skip or go through them.
2. History: in Safari, copy some text, a link and an image (touch and hold > Copy). Return to Copyo after each one and allow paste; the clip appears at the top. Tap a card to copy it. Touch and hold for Copy as Plain Text, Share, Pin and Delete. Swipe right to pin, left to delete. Use the search field and filter chips.
3. Pinboard tab: create a Pinboard and pin clips to it.
4. Share extension: in Safari, tap Share > Copyo (under More if hidden), optionally choose a Pinboard, tap Save. The item appears in History.
5. Quick Save control: open Control Center, touch and hold an empty area > Add a Control > search "Copyo" > Save Clipboard. Copy something in another app, then tap the control: Copyo opens and shows "Saved". On iPhone 15 Pro or later the same control can be assigned in Settings > Action Button > Controls. Back Tap is optional and uses a shortcut the user builds with Copyo's Save Clipboard action; steps are in Settings > Quick Save.
6. Widgets: add Copyo's Recent Clips widget (small or medium) to the Home Screen. Tapping a clip opens Copyo and copies it.
7. iPad: sidebar layout; drag a card into another app in Split View; with a hardware keyboard: Command-F, arrow keys, Return, Shift-Return, Space, Command-P, Delete, Command-1/2/3.

ICLOUD SYNC (OPTIONAL)
- The only network use is Apple CloudKit, through SwiftData mirroring to the user's own private database (container iCloud.dev.vibemage.Copyo). We operate no server and cannot read it. No third-party services, SDKs, analytics or ads.
- Sync is on by default on iPhone and iPad (switch on onboarding page 3) and can be turned off in Settings > iCloud Sync; the change applies the next time Copyo opens. Without an iCloud account Copyo works fully on the device.
- The push entitlement is used only by CloudKit's silent change notifications. Copyo never asks for notification permission and shows no notifications.
- To see sync with a Mac: sign in to the same Apple Account, install Copyo for Mac and choose iCloud under its Settings > Sync. Not required for review.

OTHER
- System Search (Core Spotlight) indexing is off by default: Settings > Show Clips in System Search. Turning it off removes everything Copyo indexed.
- This build contains no keyboard extension.
- Interface languages: English, Simplified Chinese, French.
- Source code: https://github.com/VibeMage/copyo
```

### 提审前的检查单

1. 隐私政策 Gist 已同步为新版 `PRIVACY.md`；支持页已发布（两处审核员都会点）
2. 构建版本：`UPLOAD=1 ./scripts/build-appstore-ios.sh`（先在 ASC 添加 iOS 平台，否则上传被拒）
3. App 隐私问卷**不用改**：仍是「不收集数据」（私有 CloudKit 数据库开发者读不到）
4. 出口合规已写进 Info.plist（`ITSAppUsesNonExemptEncryption = NO`），上传后无需回答
5. 年龄分级沿用 4+；价格与销售范围沿用 Mac 的设置（免费），iOS 平台需确认一遍「App 供应情况」
6. **TestFlight 真机装一次再提审**：iCloud 同步的 entitlement 判断曾经只在 Apple 重签过的包里出错
   （`embedded.mobileprovision` 被删），本地出的任何包都测不出来——见 `docs/ios-plan.md` 3.9

### 2026-09-27 在 ASC 上已经做了的

| 项目 | 状态 |
| --- | --- |
| 添加平台 → iOS | ✅ 版本号改为 **1.1.0**（ASC 默认给 1.0，要和包里的 `CFBundleShortVersionString` 一致） |
| 版本页（英 / 中） | ✅ 推广文本、描述、关键词；支持网址与版权沿用 Mac 的 |
| 审核备注 | ✅ 替换掉了从 Mac 版带过来的「菜单栏应用」那一段（新平台会把 Mac 的备注原样抄过来，要当心） |
| 截图（英 / 中） | ✅ iPhone 6.5 英寸 6 张、iPad 13 英寸 4 张 |
| 副标题（App 级，Mac 共用） | ✅ `Search everything you copied` / `复制过的一切，随时找回`，随下一次提交生效 |
| 隐私政策 Gist | ✅ 已换成含 iPhone / iPad 的新版（替换前核对过线上内容与 main 的 PRIVACY.md 一致） |
| 构建版本 1.1.0 (3) | ✅ 已上传、处理完成、选入版本页。命令行上传失败过一次：Xcode 账户凭据残缺（`missing Xcode-Username` → `App Store Connect access for “9A94W79V84” is required`，账户页只列出 Certificates 一项权限），改由维护者在 Organizer → Distribute App 上传，流程里重新登录即恢复。出口合规没有再问（Info.plist 已声明豁免） |
| TestFlight | ✅ 内部群组 `Maintainer`（自动分发开），测试员 iyn@live.com |
| 提交审核 | ✅ 2026-09-27 21:14 UTC 用 API 提交（构建 11，附审核视频），状态「等待审核」，过审自动上架 |

### 上传与查询改用 App Store Connect API 密钥（2026-09-27 起）

Xcode 账户凭据残缺时命令行上传一律失败（见上表），所以配了一把团队 API 密钥
（`copyo-upload`，App 管理权限）。以后出包、上传、查处理状态都不需要打开 Xcode 或 Transporter：

| 文件 | 内容 |
| --- | --- |
| `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` | 密钥本体，只能下载一次，丢了只能作废重建 |
| `~/.appstoreconnect/copyo.env` | `ASC_KEY_ID` / `ASC_ISSUER_ID`。两个 ID 不是机密，但仓库是公开的，所以放仓库外 |

```bash
UPLOAD=1 ./scripts/build-appstore-ios.sh   # 递增构建号、出包、核验、上传
./scripts/asc.rb builds                    # 最近的 iOS 构建与处理状态（VALID = 可选入版本 / 可在 TestFlight 安装）
./scripts/asc.rb version                   # 待发布版本：状态、发布方式、选中的构建
./scripts/asc.rb attach 7                  # 把待提交版本的构建换成 7（只改草稿）
./scripts/asc.rb mac-media art/store --dry-run  # Mac 待提交版本的商店截图与预览：先看计划，去掉 --dry-run 才替换（第二十九节）
```

**提交审核故意没做成子命令**：那是以维护者名义对外的一步，每次都在 ASC 里由人确认。

`altool --build-status` 需要上传时返回的 delivery ID，Transporter / Organizer 传的构建拿不到，
所以查询走 REST API（`asc.rb`，系统 Ruby + OpenSSL 签 ES256，不依赖第三方库）。

**发布方式：审核通过后自动上架**（`AFTER_APPROVAL`，维护者 2026-09-27 确认保持）。
iOS 平台新建时默认就是它，别以为是「手动发布」。

### 构建与真机轮次（2026-09-27）

TestFlight 真机上逐轮修掉的，都进了 1.1.0：

| 构建 | 改了什么 |
| --- | --- |
| 4 | 引导第 3 页去掉「前往设置」：iOS 要 App 先请求过一次粘贴，系统设置里才出现「从其他 App 粘贴」那一行，引导时按下去必然扑空 |
| 5 / 6 | 同步胶囊只转箭头、去掉省略号、滤掉一闪而过的同步；本机卡片浅色下改白底（设计公式的本机灰与页面底只差两三个色阶） |
| 7 | 箭头转速减半，「减弱动态效果」下不转 |
| 8 | 「已同步」时云朵整朵自转（旋转效果残留到了新图标上）；连续被弹两次「允许粘贴」后提示去设成「允许」 |
| 9 / 10 | 历史页顶部状态复盘后的改动：同步胶囊四态与防闪、toast 移到底部、「允许粘贴」提示的出现时机，与 Codex 四轮评审（见 `docs/ios-plan.md` 3.10） |
| 11 | 审核录像里发现：横图的图片卡比列宽宽，瀑布流被撑出屏幕、压住另一列。缩略图改成 `Color.clear` 定框 + overlay 放图（Mac 版本来就是这么写的）；分享扩展的预览卡同一个问题一并修 |

版本页现在选的是 **构建 11**（`./scripts/asc.rb attach 11`）。

**许可证改为 GNU GPLv3**（仓库历史被整体改写，不是本会话做的）：iOS 描述里原来的许可证说明已用 API 改成 GPLv3，中英各一处。

### TestFlight 外部测试（给朋友，2026-09-27）

朋友不在开发者团队里，走外部测试：群组 **Friends**，公开链接 `https://testflight.apple.com/join/eC9XZhfV`（上限 100 人，
随时可在群组里改或关）。Beta 描述与「测试内容」中英各一份，反馈邮箱 iyn@live.com（测试员可见），Beta 审核联系人复用正式版
「App 审核信息」那份。同一版本只有第一个构建要过 Beta 审核；它与正式提审互不影响。

内部群组 **Maintainer** 只给团队成员用。邀请邮件里的兑换码绑定的是那个测试员的名额，不能转给别人。

### 审核演示视频：模拟器里自动录（2026-09-27）

Mac 版 1.0 第一次提审被 2.1 退回过，要的就是演示录屏（见第二十四节）。iOS 首版提审时主动附上一段，
省掉一轮来回。维护者不在电脑前，所以做成了模拟器里全自动的：

```bash
./scripts/record-review-video.sh                                   # → build/review/copyo-ios-review.mp4
./scripts/asc.rb review-attachment build/review/copyo-ios-review.mp4   # 挂到「App 审核信息 → 附件」，同名旧附件先删
```

脚本抹掉专用模拟器「Copyo Review」（iPhone 17 Pro）、切英文、固定 9:41，本机起服务提供
`scripts/review-video/index.html`（虚构的里斯本行程笔记），然后跑 UI 测试 `CopyoIOSUITests/ReviewWalkthrough`：
主屏幕点图标 → 三页引导 → Safari 里点网页的复制按钮 → 回到 Copyo 点系统「允许粘贴」→ 高亮新卡片 →
Safari 复制图片 → 再次允许 → 「不想每次都点允许粘贴？」提示 → Safari「更多 › 分享 › Copyo › 存储」→
轻点复制 → 长按菜单新建 Pinboard → Pinboard 标签 → 搜索 → 设置页。

2026-09-27 挂到 1.1.0「App 审核信息 → 附件」的是修完图片卡之后重录的一版：152 秒、884×1920、8.2 MB；
审核备注「HOW TO TEST」下加了一句说明。第一版录像里横图卡片撑出了屏幕——录像顺带当了一次端到端的界面走查，
这个 bug 设计稿样例图（偏方）和商店截图都没暴露出来。

**局限**：录的是模拟器，没有 iCloud 账号，右上角胶囊显示「Not synced」，审核备注里写明了。
Apple 的 2.1 模板要的是**真机**录屏；如果审核员还是要，维护者用控制中心的屏幕录制在手机上录两分钟即可。

踩过的坑（改脚本前先看）：

- **不要另开 `simctl io recordVideo`**。Xcode 的 UI 测试自己就在录屏（结果包里的 mp4，满分辨率），
  两路同时抓一台模拟器会把它的 io 卡死，连截图都截不了。scheme 里设了 `systemAttachmentLifetime = keepAlways`，
  成功也保留录屏，脚本用 `xcresulttool export attachments` 取出来。
- **bash 边跑边读脚本**：脚本在跑的时候别改它，否则后半截会读到错位的内容，报莫名其妙的语法错误。
- 中文标点紧贴变量名（`$status）`）时 bash 会把全角字节当成变量名的一部分，一律写成 `${status}`。
- 端口 8765 常被别的本地服务占着，Safari 会打开那个服务的页面；脚本现在用 8779，并先 curl 确认页面对。
- 新装的 App 在主屏幕第二页；`test-without-building` 要等 `launch()` 才装目标 App，所以脚本先 `simctl install`。
- 文字和图片都用网页上的复制按钮（剪贴板 API；图片经 canvas 转 PNG，Safari 只收 PNG）。模拟器里长按图片常常
  不出菜单，而长按菜单里的「Copy」又会和网页按钮重名、点错，所以不走长按。按钮的无障碍名字是
  「Copy meeting point」/「Copy photo」，复制成功后变成「Copied」，测试据此确认——Safari 第一次开网页会冒一个
  功能提示气泡，第一下点击会被它吃掉，没变就再点一次。
- iOS 26 的搜索栏右边是「✕」不是「Cancel」，测试挨个试名字，找不到就点搜索框右侧。
- 长按链接的菜单里有网页预览，维基百科会一直加载，测试干等一分钟，「分享」还在菜单折叠线以下。改走「更多 › 分享」。
- 开机后半分钟左右系统会弹「Apple Intelligence 已就绪」通知，脚本等它弹完再开录；Safari 也先在录像外预热一次。
- 机器负载高的时候模拟器会整体卡死（开机停在转圈、`simctl bootstatus` 永远不返回），重启 CoreSimulator 也没用，
  过几个小时自己恢复了。卡住时别反复重跑，先看 `uptime`。

## 二十七、Mac 1.2.0 (3) 提交审核（2026-09-27）

1.2.0 按 v2 设计稿重做了面板与设置（`art/macos-design/2026-09-27/`）。当天出 TestFlight 并提审，
发布方式「审核通过后自动发布」。**当天审核通过并自动上架（`READY_FOR_SALE`）。**

### 构建与上传

- **只从最新的 `origin/main` 出包**：用一个从 `origin/main`（`cdacd42`）新建的干净 worktree，
  不用本地可能落后或带着未提交改动的分支。
- `./scripts/build-appstore.sh` 归档、导出都成功，但最后的上传步骤报
  `error: exportArchive Failed to Use Accounts`（Xcode 账户登录态的问题，与包无关）。
  改用 App Store Connect API 密钥上传，一次通过：

  ```bash
  xcrun altool --upload-package build/appstore/Copyo-1.2.0-appstore.pkg --type macos \
    --apple-id 6813955206 --bundle-id dev.vibemage.Copyo \
    --bundle-version 3 --bundle-short-version-string 1.2.0 \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  ```

  （`--apple-id` 是 ASC 里的 App ID。密钥 `.p8` 放在 `~/.appstoreconnect/private_keys/`，altool 默认就去那里找；两个 ID 在 `~/.appstoreconnect/copyo.env`，都不入库。）
- TestFlight：build 3 处理完即进入内部测试（`IN_BETA_TESTING`），Mac 的内部测试不需要 Beta 审核。
- 归档留在 `~/Library/Developer/Xcode/Archives/2026-09-27/Copyo macOS 1.2.0 (3) AppStore.xcarchive`，符号化崩溃要用。

### 商店截图与预览视频

面板从「满宽贴底」改成了「悬浮在 Dock 上方的玻璃面板」，旧的四张截图全部作废。1.2.0 上架的是下面这一套（第一版；`art/store/` 现在已换成第二版，见本节末）：

| 序号 | en 标题 / 副标题 | zh 标题 / 副标题 |
| --- | --- | --- |
| 01-panel | Everything you copied, one key away / Press ⇧⌘V — your history floats right above the Dock | 复制过的一切，随叫随到 / 按下 ⇧⌘V，剪贴板历史浮在 Dock 上方 |
| 02-search | Type to filter / Search content, source app or file name — the cards never jump | 即输即搜 / 按内容、来源应用、文件名过滤，卡片不跳动 |
| 03-preview | Space to peek / Preview text, links and images above the panel | 空格，先看一眼 / 在面板上方预览文本、链接和图片 |
| 04-pinboard | Keep what you use most / Press ⌘P to choose a Pinboard, right from the keyboard | 常用的，固定下来 / 按 ⌘P 选择 Pinboard，手不离键盘 |
| 05-shortcuts | Hands stay on the keyboard / ⇥ switches filters, ⌘1–9 copies a card — ⇧⌘V is yours to remap | 手不离键盘 / ⇥ 切换筛选，⌘1–9 直接复制；⇧⌘V 可自定义 |

文案仍守 1.0 那次 2.4.5 拒审的底线：只说「复制」，不说应用会替用户粘贴。

预览视频中英各一段（`art/store/preview/`）：1920×1080、H.264、30 fps、约 28 秒，
带一条 48 kHz 立体声 AAC 静音轨——**Mac 的 App 预览没有音轨会被 ASC 拒收**，无声也得有这条轨。
海报帧设在 `00:00:01:00`（面板完整浮起的那一帧）。

流水线分三段：

1. **拍原始素材**（维护者本机，没有入库的临时工具）：`-demoData` 演示数据、深色外观；
   背后铺一张全屏无边框「舞台」窗口（`art/store/_background-plate.png` 裁成 16:9，窗口层级 23，
   低于菜单栏 24 与面板 25），这样既盖住桌面，面板的玻璃又是按这张背景真实合成的。
   录屏用 `screencapture -v`，截图用 `screencapture -R0,0,1920,1080`。
2. **合成截图**：`python3 scripts/make-store-shots.py <raw 目录>`，从原图裁 16:10（天然去掉顶部真实菜单栏），
   叠图标、标题、副标题，转 sRGB 去 alpha，输出到 `<raw>/../out/`，不会写 `art/store/`。
3. **剪预览**：`scripts/make-store-preview.sh`（ffmpeg），剪掉停顿压到 30 秒内，补静音轨，导出海报帧。

合成与剪辑由 Codex 完成，拍摄与验收由 Claude Code 完成。

踩过的坑：

- `screencapture -x <路径>` 整屏模式**会静默地不覆盖**已存在的文件，拿到的是上一张；一律加 `-R` 指定区域。
- 本机正在运行的 Copyo 会截走 `⇧⌘V`，演示实例收不到，拍摄期间要先退出它（这段时间的剪贴板不会进历史）。
- 英文录屏前把输入法切到 ABC，拍完切回。

### 用 API 上传媒体

截图与预览都用 App Store Connect API 传（`appScreenshotSets` / `appPreviewSets` 的上传三步：
POST 预约 → 按返回的分片 PUT → PATCH `uploaded: true` 带 MD5）。API 可以直接 PATCH 截图集的
`appScreenshots` 关系来定顺序，所以第十七节那条「必须一张一张传」的限制在 API 下不存在。
中英两套各 5 张 + 各 1 段预览。

### 审核备注

`appStoreReviewDetails.notes` 上限 **4000 字符**，第一稿 4532 超了，压到 3997。
在「OPENING THE APP」之后新增一段「NEW IN 1.2.0」，其余结构沿用上一版：打开方式、测试说明、审核问卷 1–6 条、剪贴板隐私。

### 第二版素材（给 1.2.1，2026-09-27 晚）

维护者看了第一版，三点意见：面板太小、副标题到面板空了约三分之一屏；最右一张卡被切掉一半，像截歪了；
图片卡是一块模糊的土黄色占位。第一版已随 1.2.0 送审（审核中截图锁定），维护者决定**不撤回，第二版随 1.2.1 换上**。

- 拍摄：新增启动参数 `-panelWidth 1104`，面板压窄到正好放满四张整卡（卡片轨道一直延伸到面板边缘，
  取对称的 1108 时第五张会露出 4pt 细边，所以是 1104）。这是窄屏上真实会出现的形态，不是修图。
- 演示图片：`DemoSampleImage` 换成 Codex 生成的原创山湖照片（浅 / 深两套只调色调）。
- 合成：每张单独裁切，面板在成品里从约 2272px 放大到约 2426px，卡片文字约大 24%，副标题到面板的留白从约 430px 收到约 100px。
  03 有过「预览山湖照片」的备选（`make-store-shots.py --include-image-preview`），面板里只剩一张卡、照片两侧是来源色的土黄边，维护者选了文本版。
- 视频：照片预览那一段在动作的静止处硬切到宽取景，其余是紧取景；中 29.2s / 英 28.7s。
- 质检：三路独立核对（规格与像素、视频逐帧、脚本复现）都通过。顺带查出一个应用 bug：预览窗的相对时间用 `Date()`，
  卡片用每分钟刷新的 `TimelineView`，跨整分钟时一个写「12 分钟前」一个写「11 分钟前」，已改成同一个分钟时钟后重拍了 03。
- 两个脚本都记了这批素材的指纹（截图原图 SHA-256，录屏精确时长与帧数），以后换素材会直接报错，提示重调裁切 / 剪点。


## 二十八、Mac 1.2.1 (4) 上 TestFlight，版本页备好、暂不提审（2026-09-27）

1.2.0 当天过审上架后，维护者决定 1.2.1 **先上 TestFlight 用几天，再提审**。

### 出包与上传

- 版本号在 main 上改成 `1.2.1 (4)`（Mac 三个配置；iOS 不动），再从 `origin/main` 新建干净 worktree，
  `NO_BUMP=1 ./scripts/build-appstore.sh` 出包（构建号已经改好，不能让脚本再加一次）。
- 现在的 `build-appstore.sh` 只出包、不上传，上传照第二十七节用 altool + API 密钥。
- 构建 4 几分钟就处理完（`VALID`），内部测试自动可用（`IN_BETA_TESTING`）；TestFlight「测试内容」中英都写了。
- ⚠️ **删出包用的 worktree 之前，先把 `build/Copyo.xcarchive` 复制进 `~/Library/Developer/Xcode/Archives/<日期>/`。**
  这次忘了，`git worktree remove --force` 连同归档一起删掉，只从 DerivedData 的 `ArchiveIntermediates` 里找回了 dSYM
  （UUID 与上传的二进制一致，放进了 Archives，Spotlight 能按 UUID 找到）。导出选项本来就是 `uploadSymbols = true`，Apple 那边也有符号。

### 版本页（`PREPARE_FOR_SUBMISSION`，已挂构建 4，审核通过后自动发布）

- 新建版本时，描述、关键词和**上一版的截图与视频**都会继承过来；截图与视频按版本各存一份，
  删新版本页上的旧图不影响线上版本（用 `sourceFileChecksum` 逐张核过：1.2.0 仍是第一版，1.2.1 是第二版）。
- 视频上传时带的海报时间码会在转码后被重置成 `00:00:05:01`，要等 `videoDeliveryState = COMPLETE` 之后再 PATCH 一次 `00:00:01:00`。
- 新功能说明、审核备注、隐私政策里关于 1.2.1 的说法，都让独立的 agent 逐句对照代码核过一遍，改掉了几处说过头的地方：
  - 冲突提示只在「录制新组合被拒」时保留原组合；启动时就冲突的，只在设置 › 快捷键里提示；
  - 多文件拖拽只在 macOS 26 及以上生效；
  - 录快捷键时每次读的是全部按键的状态（`keyState` + `flagsState`），只对按着 ⌘/⌥/⌃ 时按下的键做判断；
    中途切走时还会多查一次；平时只接收自己窗口里的按键和自己的全局快捷键。
- 审核备注 3997 字符：在「NEW IN 1.2.1」里如实写了录快捷键时轮询按键状态、不需要权限、不记录；
  为了塞进 4000 字符，压缩了几处对审核员价值不大的措辞，「菜单栏图标隐藏时怎么打开」挪到了 OPENING 段末。
- 隐私政策（`PRIVACY.md` 与商品页引用的 Gist）已加上「录制全局快捷键」一条并同步。

### 提审时要做的

版本页、构建、素材、文案都已就绪，维护者说提审时只需再建一个 `MAC_OS` 的 `reviewSubmission`、挂上 1.2.1 版本、提交。

## 二十九、Mac 商店素材第三版：浅色（2026-09-28，替换 1.2.1 版本页）

朋友反馈浅色系更受欢迎、日间模式看着更舒服，维护者决定把 Mac 商店截图、App 预览和宣传页（`docs/support/`）都从深色切到浅色。
第三版版式与第二版相同（文案不变，只说「复制」），`art/store/` 已换成它，1.2.1 (4) 版本页上的截图与视频也已替换（见本节末）；
1.2.0 线上版本仍是第一版。规格与拍法写在 design-spec 6.6，这里记过程与踩过的坑。

### 舞台：奶白底 + 品牌角光

- 应用用新的 `-forceLight` 拍；背后的舞台由 `scripts/make-store-plate.py` 生成：底色 `#F4F2ED`（与 iOS 商店图同色），
  左红 `#FF2D55` 右蓝 `#0A84FF` 各一团大而柔的上光 + 一团贴边侧光，截图里是左上 / 右上的角光，标题、面板、横幅边缘都不着色。
- 第一轮直接照深色版的位置放光，结果光心都在取景框外，成片几乎是纯奶白。后面的参数是在 `build.noindex/store-light/sim/` 里挑的：
  模拟器按「新舞台 / 旧舞台」的逐像素比值给真实原图换背景（窗体外精确、玻璃内按 15% 透光近似），再走真实的合成函数出图；
  四个设计 agent 从品牌、克制、马卡龙、跨场景一致四个方向各调一版，三个评审按商店转化、可读与保真、跨场景一致打分，
  综合后再由挑刺 agent 找问题。之后衰减从 `(1 − d)²` 换成平顶的 `(1 − d²)²`（去掉中心尖峰），按 8 条量化阈值
  （角部 ΔE、文字框内 alpha、面板玻璃、宽取景、横幅边缘、左右不镜像、4K 舞台色阶）重调，验收脚本是 `sim/retune/measure_all.py`。
- 4K 舞台直接按 3840 × 2160 渲染并加 Bayer 抖动，不再把 2560 的图放大（放大后重新量化会出 2 级色阶）；
  拍前截一张空舞台与舞台图比对，窗口逐像素显示、误差 ±1 级。

### 拍摄里踩到的

- **卡片时间少一分钟**：卡片与预览窗的参照时间是「当前这一分钟的起点」，演示数据却按启动时刻往前推，所以整分之前拍到的是
  「1 / 11 / 24 / 59 分钟前」，跨过整分又整体 +1。演示数据改为从这一分钟的起点往前推（`MacDemoData.swift`），拍摄时每个镜头不跨整分。
- **视频开头一帧弹出**：`-showPanel` 启动时面板没有呼出动画。录屏改为先起进程、再用 ⇧⌘V 呼出（System Events 模拟按键能触发 Carbon 热键），
  开头是真实的约 150ms 淡入；全程不点击，指针停在取景框外（录屏会把指针录进去，指针停在右下角会触发热角缩略图）。
- **输入法指示器**：搜索框获得焦点时系统偶尔弹出输入法指示器的玻璃浮层（约一帧），拍到过一张静帧（重拍）和英文视频的一帧（剪掉）。
- **中文清空搜索时第一张卡闪蓝**：约 0.2 秒，应用端问题，英文输入法下没有；成片在闪烁前后的静止帧之间剪掉。
- **录屏是可变帧率**：画面不动时不出帧，按帧序号 ÷ 60 算时间会错，挑剪点要用 `ffprobe` / `showinfo` 的真实时间戳。
- **Otty 里给 Codex 发任务**：`send-text` 之后第一个回车经常只落成输入框里的换行，要再补一个；Codex 调子 agent 时
  `agent_state` 会短暂报 idle，`watch:codex` 会提前返回，以输出文件是否写出为准。

### 验收

三轮对抗式验收（共约 60 个 agent：找问题的按规格与复现、视觉、视频逐帧、宣传页、代码分维度，每条发现两个独立 agent 试图反驳）。
改掉的：上面几条、合成脚本把舞台图纳入指纹（13 项）、`-forceLight` 传到演示照片的深浅、宣传页 iOS FAQ 的问句暗示「替我粘贴」（违反只说复制的规则）、
视频结尾「已复制」一帧消失（成片停在提示完整显示的最后一帧）。成品：截图两次生成逐字节一致；视频中 27.7s / 英 27.3s。
接受并记了 bead 的：视频与截图奶白差约 3 级（BT.709 传递曲线，copyo-3jj）；宣传页「Mac 直接下载版」指向空的 Releases（copyo-cwo）。
Figma / Microsoft Remote Desktop 两张演示卡是空白来源图标（拍摄机没装这两个 App），深色版也是如此，未改。

### 上传：`./scripts/asc.rb mac-media art/store`

新子命令，先传新的、等 Apple 处理完，再删旧的、排序、把海报帧设回 `00:00:01:00`；中途失败只清理本次新传的，旧素材原样留着；
重跑按 MD5 认出已传好的新素材直接复用（逐张），补完剩下的步骤。上传前用一个进程内的假 App Store Connect 跑了 42 个场景
（中途 5xx / 429 / 网络超时、Ctrl-C、登记成功但响应丢失留下的空占位、处理失败、第二段失败后重跑、JWT 过期重签等），
并逐条对照 Apple 官方 OpenAPI 4.5 核过请求体。先 `--dry-run` 看计划再正式跑。

2026-09-28 已替换 Mac 1.2.1 (4) 版本页（`PREPARE_FOR_SUBMISSION`）：zh-Hans / en-US 各 5 张截图 + 1 段预览，全部 `COMPLETE`，
顺序与文件名一致，远端 `sourceFileChecksum` 与 `art/store/` 逐个相同，海报帧 `00:00:01:00`。第二版（深色）已从 1.2.1 版本页删除；
1.2.0 的线上版本不受影响。提审时照第二十八节末尾即可，素材不用再动。
