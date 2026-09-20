# Mac App Store 提审材料与操作清单

创建日期：2026-09-01 · 最后更新：2026-09-19

## 一、App Store Connect 建应用（你来操作）

> ⚠️ 下面这张表是 2026-09-01 建第一条应用记录时填的。**那条记录已于 2026-09-19 删除**，
> 新记录已于 2026-09-19 建好，实际填的值见第十三节（名称 `Copyo - Clipboard History`、套装 ID
> `dev.vibemage.Copyo`、SKU `copyo`、Apple ID `6813955206`）。

appstoreconnect.apple.com → 我的 App → ➕ 新建 App：

| 字段 | 填写 |
| --- | --- |
| 平台 | macOS |
| 名称 | Paster |
| 主要语言 | 简体中文（或 English，主语言决定默认展示） |
| 套装 ID | dev.vibemage.Paster |
| SKU | paster（平台中立——iOS 版将来共用这条应用记录与 SKU） |

## 二、App 信息

- **类别**：效率（Productivity）
- **价格**：免费
- **隐私政策 URL**：`https://gist.github.com/VibeMage/d39d7165d762ecfd0f16f72ad1fc553e`
  （仓库私有期间用这个公开 Gist；仓库恢复公开后可换回 repo 内的 PRIVACY.md 链接）
- **App 隐私问卷**：全部选择「不收集数据」（Data Not Collected）
- **出口合规**：不使用加密（应用无任何网络请求）→ 选择"否/豁免"

## 三、商店文案（可直接粘贴）

### 版本页固定字段

| 字段 | 填写 |
| --- | --- |
| 名称 | `Copyo - Clipboard History`（英文，主要语言）／**`Copyo`**（简体中文本地化名称，见第十七节） |
| 技术支持网址 | `https://vibemage.github.io/copyo/support/`（仓库 2026-09-16 已改名为 copyo，旧地址随之 404，见第十二节） |
| 营销网址 | 留空 |
| 版本 | 1.0（新应用记录从 1.0 重新开始，与构建的 MARKETING_VERSION 一致） |
| 版权 | `© 2026 Copyo Contributors` |

### 推广文本（170 字符内，可随时改无需审核）

- zh：`按下 Shift+Command+V，复制过的文本、链接、图片、文件全部回来。开源、本地存储、零网络请求。`
- en：`Press Shift+Command+V and everything you've copied comes back — text, links, images, files. Open source, local-only, zero network requests.`

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
• 可选的文件夹同步（如 iCloud Drive），在多台 Mac 间同步历史
• 自动跳过密码管理器等隐藏内容

隐私优先：所有数据只保存在本机或你自己选择的同步文件夹，
无遥测、无统计、无任何网络请求。代码完全开源。
```

### Description (English)

```
Press ⇧⌘V and everything you've ever copied slides up from the bottom of your screen.

Copyo is an open-source clipboard manager:
• Automatically captures text, rich text, links, colors, images and files
• Bottom card panel — type to search, fully keyboard-driven
• Hit Return and it's back on your clipboard, ready to paste with ⌘V
• Pin frequently used clips to Pinboards, safe from history cleanup
• Optional folder sync (e.g. iCloud Drive) across your Macs
• Concealed content from password managers is never recorded

Privacy first: everything stays on your Mac or in a sync folder you choose.
No telemetry, no analytics, no network requests. Fully open source.
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

No account, no login, no network. All data is stored locally.
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

（`release/1.0` 分支没有跟进 2026-09-19 的第二轮改名，那边仍然是 `Paster.xcodeproj` / scheme `Paster`，
脚本照旧能跑；main 上的工程已改名为 `Copyo.xcodeproj`，见第十三节。）

```bash
git worktree add ../Paster-release-1.0 release/1.0   # 已存在则跳过
cd ../Paster-release-1.0
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

```
Thank you for reviewing Paster. Here is the requested information. A screen recording is attached to this message.

1. Screen recording
Recorded on a physical MacBook running macOS 26.6.1. It starts with launching Paster from the Finder and shows the typical flow: the welcome dialog, the menu bar icon, copying text, a link and an image in other apps, opening the clipboard panel with Shift+Command+V, searching, previewing with Space, pasting an item back into TextEdit with Return, pinning an item to a Pinboard, and the Settings window. Paster has no accounts, no login and no user-generated content shared with other people, so there are no registration, account deletion, content reporting or blocking flows.

2. Purpose and target audience
Paster is a clipboard history manager for macOS. Every time the user copies something (text, rich text, a link, a color value, an image or a file) Paster keeps it, and the user can bring any earlier item back with one keyboard shortcut. It solves the problem that the system clipboard only holds the most recent item, which forces people to re-copy content or lose it. Target audience: Mac users who copy and paste a lot, such as developers, writers, designers, students and office workers. The app is free with no in-app purchases.

3. Setup and access
No account, login credentials or sample files are required.
- Launch Paster. A welcome dialog explains the basics. Paster then lives in the menu bar (the clipboard icon in the top-right corner); it has no Dock icon and no main window.
- Copy anything in any app. It appears in Paster automatically.
- Press Shift+Command+V, or click the menu bar icon, to open the clipboard panel. It slides up from the bottom of the screen. Type to search, use the arrow keys to move, press Space to preview.
- Select an item and press Return to paste it into the app you were using. This uses macOS Accessibility: enable Paster in System Settings > Privacy & Security > Accessibility. Without this permission, Return still copies the item to the clipboard for manual pasting. If pasting does not work right after granting the permission, quit and reopen Paster.
- Right-click a card to pin it to a Pinboard, copy it as plain text, or delete it.
- Settings: click the gear button in the panel header, or right-click the menu bar icon and choose Settings.

4. External services
None. Paster makes no network requests and uses no third-party SDKs, analytics, authentication services, payment processors or AI services. All data is stored locally in the user's Application Support folder. The optional sync feature only writes files to a folder the user explicitly selects (for example a folder inside iCloud Drive) through the standard file APIs; no server operated by us is involved.

5. Regional differences
None. The app functions identically in all regions. The interface is localized in English and Simplified Chinese.

6. Regulated industries and third-party material
Not applicable. Paster does not operate in a regulated industry and contains no protected third-party material. It only stores content the user copies on their own device.

This build was tested on a physical MacBook running macOS 26.6.1 before submission.
```

粘到「备注」时把第一段末尾的 "A screen recording is attached to this message." 换成 "A screen recording was provided as an attachment in App Review messages on 2026-09-03."。

### 录屏方案（不暴露本机内容）

- 新建一个 macOS 标准用户「Demo」录制，桌面干净、无公司应用。语言设为 English。
- 录屏用的沙盒版从提审的 commit（c7dd41f）构建，放在 /Users/Shared/PasterDemo/Paster.app，演示文件在同目录。
- 录前在 Demo 账号里先给 Paster 辅助功能权限（系统设置 → 隐私与安全性 → 辅助功能 → + 选中该 app），开勿扰。
- ⇧⌘5 录整个屏幕，90 秒内：Finder 双击启动 → 欢迎对话框点 Try It Now → 面板出现后关掉 → 在 TextEdit 复制一句话、Safari 复制一个链接、预览里复制一张图 → ⇧⌘V 呼出面板 → 输入关键词搜索 → 空格预览 → 回车粘贴进 TextEdit → 右键卡片固定到 Pinboard → 点齿轮打开设置扫一眼各标签 → 停止录制。
- 录完的 .mov 放到 /Users/Shared/PasterDemo/，用 avconvert 压成 1080p H.264 再上传（附件尽量控制在 50MB 内）。

## 九、2026-09-08 第二次拒审（1.0 (3)）：2.4.5 辅助功能 + 1.5 支持网址

### 拒审内容与事实核对

| 条款 | 审核说法 | 事实 |
| --- | --- | --- |
| 2.4.5 | 应用用辅助功能（Accessibility）来实现热键，属于把无障碍功能挪作他用 | 全局快捷键走 Carbon `RegisterEventHotKey`（当时的 `Paster/Services/HotkeyManager.swift`，现在是 `Copyo/Services/HotkeyManager.swift`），不需要任何权限。辅助功能只在自动粘贴时用于向目标应用发送 ⌘V（当时的 `PasteService.sendCmdV`，现已删除）。审核员把两者混为一谈，欢迎对话框和设置页当时的文案也确实没把两者分开 |
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
- 自动粘贴的旧实现保留在 git 历史里（commit af221d4 时的 `Paster/Services/PasteService.swift`）。上架后若要加回，提审时需自带 2.4.5 的说明，且可能再次被拒。

### 回复正文（贴到 App 审核 → 消息，两条拒审一起回）

```
Thank you for the detailed review. Both issues are addressed in build 1.0 (5).

Guideline 2.4.5 – Accessibility

The feature that used Accessibility, "Paste into the previous app on selection", has been removed from the app. Build 5 no longer calls any Accessibility API and never asks for Accessibility access; nothing in the app requires it. When the user selects an item and presses Return, Paster puts it on the clipboard, closes the panel and returns focus to the app they were using, where they paste with Command+V.

For clarity: the Shift+Command+V shortcut never used Accessibility. It is registered with the Carbon RegisterEventHotKey API, which needs no permission, and is unchanged.

Guideline 1.5 – Support URL

The Support URL has been updated to https://vibemage.github.io/Paster/support/. It is a dedicated support page with contact information, a quick-start guide, an FAQ and a link to the privacy policy.
```

### 发布支持页面（你来操作，回复审核前必须已上线）

先把页面里的占位邮箱换成真实的支持邮箱（两处）：

```bash
grep -n "REPLACE-ME" docs/support/index.html
sed -i '' 's/support@REPLACE-ME.example/你的邮箱/g' docs/support/index.html
```

> ⚠️ 以下命令是 2026-09-09 当时的操作记录，仓库那时还叫 `Paster`。仓库已于 2026-09-16 改名为 `copyo`，
> 现在的支持页面地址是 `https://vibemage.github.io/copyo/support/`。照抄下面的命令会操作到不存在的仓库。

**方案 A（推荐，与「上架即开源」的计划一致）**：仓库转公开，用 main 分支的 /docs 目录做 GitHub Pages。
issues 页面同时可用，PRIVACY.md 和支持页里的 issues 链接都会生效。

```bash
git add docs/support && git commit -m "[docs][paster][1.0]: add support page" && git push
gh repo edit VibeMage/Paster --visibility public --accept-visibility-change-consequences
gh api -X POST repos/VibeMage/Paster/pages -f 'source[branch]=main' -f 'source[path]=/docs'
# 等 1–2 分钟
curl -sI https://vibemage.github.io/Paster/support/ | head -1   # 期望 HTTP/2 200
```

**方案 B（仓库暂时保持私有）**：只把这一个页面推到一个新的公开仓库。
此时支持 URL 改为 `https://vibemage.github.io/paster-support/`，回复正文和 ASC 表单里同步替换；
页面里的 issues 链接会 404，建议顺手把那两行改成邮箱。

```bash
tmp=$(mktemp -d) && cp docs/support/index.html "$tmp/" && cd "$tmp" \
  && git init -q -b main && git add . && git commit -qm "Add support page" \
  && gh repo create VibeMage/paster-support --public --source=. --push \
  && gh api -X POST repos/VibeMage/paster-support/pages -f 'source[branch]=main' -f 'source[path]=/'
```

### 提交顺序（1.0 的历史记录；1.0.1 请按第十一节的「App Store Connect 操作」，那里的支持网址才是现在有效的）

1. 上传新构建：从 `release/1.0` 出包（见第六节），用 Transporter 拖入
   `build/appstore/Paster-1.0-appstore.pkg` → Deliver；或直接 `UPLOAD=1` 让脚本上传。
   注意包里的构建号由 Xcode 导出时自动抬高（取 App Store Connect 上已有的最大值加一），
   2026-09-09 出的包是 1.0 (5)，回复正文里的构建号要与实际上传的一致。
   上传后等 App Store Connect 处理完（收到「已完成处理」邮件，通常 5–30 分钟）。
2. App Store Connect → 我的 App → Paster → 1.0 版本页：
   - 「构建版本」移除 1.0 (3)，选择新上传的构建（1.0 (5)）。
   - 「技术支持网址」改为 `https://vibemage.github.io/Paster/support/`。
   - 「描述」中英文各改一行（见第三节：回车后内容回到剪贴板，⌘V 粘贴）。
   - 「App 审核信息 → 备注」整段替换为第四节的新版本。
   - 存储。
3. 「App 审核」区域打开与审核的消息记录，回复上面的回复正文。
4. 点右上角「提交以供审核」。

## 十、审核通过（2026-09-11，1.0 (5)）

- 状态：审核通过，欧盟之外地区上架，商店页面最长 24 小时后可见。
- 欧盟 27 国暂不可售：需要先在 App Store Connect 完成《数字服务法案》(DSA) 交易者状态声明。
  Paster 免费、无内购、无广告，个人账号可选「非交易者」：应用随即在欧盟可售，商店页对欧盟用户
  显示一条「消费者保护法不适用」的提示，不公开任何联系方式。若选「交易者」，个人开发者的地址、
  电话、邮箱会公开显示在欧盟商店页，并需邮箱/手机验证和上传证明文件。
- 操作路径：App Store Connect → 业务（Business）→ 协议（Agreements）→ 合规（Compliance）→
  Digital Services Act → Complete Compliance Requirements → 选「This is not a trader account」→ Done。
  也可在 App → App 信息 → App Store Regulations and Permits 里按应用单独设置。

## 十一、改名：Paster → Copyo（2026-09-15，随 1.0.1 提交）

### 为什么改、为什么是它

- pasterapp.com 的 Paster 是同平台同品类的 macOS 剪贴板管理器，2026-02-28 上线，比我们早半年；对方在先使用，名称争议一旦提起，被动的是我们。App Store 搜索又把 paster 归一成 paste，新应用被 Paste 系老应用淹没。
- 先后评估过 Déjà + 拾遗（含义好但约 30 个同名应用、deja.app 是别人的产品，独立性不达标）、Revoici（法语真词「它又在这儿了」，最独立，但英语用户读音有门槛且易被听成 revoice）、Copylet（近似 couplet、字形近 Copilot）。最终选 **Copyo**：copy 加一个 o，好念好记，Mac/iOS 商店（美区、中国区）零同名，Google 无同名产品，copyo.app / .io / .dev 可注册；.com 自 2012 年被人持有，GitHub 的 copyo 是闲置个人账号。全部候选与检查数据见对比板（Claude artifact「Paster 改名候选板」）。
- 不设中文名：中英文商店和界面统一叫 Copyo。

### 代码层面改了什么（`rename_brand.py`，main 与 release/1.0 都已执行）

- 产品文件名 `Copyo.app`（PRODUCT_NAME = Copyo），显示名 `Copyo`，用户可见文案全部改名（欢迎对话框、菜单栏菜单、设置窗口标题、关于页、iOS 引导与分享扩展）。
- **不动的**：bundle ID `dev.vibemage.Paster`、数据目录 `Application Support/Paster/`、沙盒容器路径、同步文件夹里的 `Paster/` 子目录、CloudKit 容器、PasterCore 模块名、target/scheme 名、工程文件名。老用户升级后数据原地保留。
  （这份「不动的」清单在 2026-09-19 的第二轮改名里几乎全部改掉了，只有 bundle ID 与沙盒容器路径仍然保留，见第十三节。）
- release/1.0 的 MARKETING_VERSION 升到 1.0.1；上架包 `Copyo-1.0.1-appstore.pkg`。
- 仓库当时暂未改名（Pages 项目站地址不随仓库改名跳转，线上 1.0 的支持网址会失效）。**这条后来没有守住**：仓库于 2026-09-16 改名为 `copyo`，预言的后果照样发生，详见第十二节。

### 提交 1.0.1 前你要做的

1. 商标检索（五分钟）：https://tmsearch.uspto.gov 搜 COPYO（第 9 类）。中国区可顺手在 https://sbj.cnipa.gov.cn 查一下。
2. 建议尽快注册 copyo.app（RDAP 查过可注册），挂到 GitHub Pages 做自定义域名。

### App Store Connect 操作

1. 应用（商店里现在仍显示 Paster）→ 版本 → ➕ 新版本 `1.0.1`。
2. App 信息 → 可本地化信息：英文与简体中文名称都改为 `Copyo: Clipboard History`。副标题不变。
3. 版本页：描述（第三节新版）、关键词（第三节新版）、审核备注（第四节新版）、技术支持网址改为 `https://vibemage.github.io/copyo/support/`（**必须改，旧地址已 404**）、版权改为 `© 2026 Copyo Contributors`。
4. 此版本的新增内容：
   - zh：`Paster 更名为 Copyo。功能不变，你的历史记录、Pinboard 和设置全部原地保留。`
   - en：`Paster is now Copyo. Same app, same data — only the name has changed.`
5. Transporter 拖入 `build/appstore/Copyo-1.0.1-appstore.pkg` → Deliver；处理完后在版本页选中该构建。
6. 提交以供审核。名称在审核通过并发布后才会在商店里变更；商店链接里的 id 不变。

## 十二、仓库改名导致线上支持网址 404（2026-09-16 发生，2026-09-19 排查）

### 发生了什么

GitHub 仓库从 `VibeMage/Paster` 改名为 `VibeMage/copyo`。GitHub 会为 github.com 的仓库链接做 301 跳转，
但 **GitHub Pages 项目站地址不跳转**——第十一节里预先写下的正是这个风险，改名时没有照做。

| 地址 | 状态 |
| --- | --- |
| `https://vibemage.github.io/copyo/support/` | 200 |
| `https://vibemage.github.io/Paster/support/` | 404 ← 线上 1.0 在 App Store 填的就是这个 |

后果：已上架的 1.0 (5) 商品页上的「App 支持」按钮点开是 GitHub 的 404 页。1.5 条款正是 2026-09-08 那次拒审的原因之一。

### 为什么不能直接去 App Store Connect 改

「技术支持网址」是**版本级**字段。Apple 自 2018 年 4 月起规定，支持网址、营销网址和「此版本新增内容」
只能随新版本提交一起修改（见 developer.apple.com/news/?id=12072010c）。已批准版本上可随时编辑的只有
推广文本和版权。所以线上 1.0 的这个链接，在 1.0.1 过审之前无法通过 ASC 修好。

### 处理方式（2026-09-19 已决定：走 B，不建跳转仓库）

**A. 建一个跳转仓库**（唯一能立刻修好线上 1.0 的办法）
新建公开仓库 `VibeMage/Paster`，只放 `docs/.nojekyll` 与 `docs/support/index.html`（meta refresh 跳到
`/copyo/support/`），Pages 设为 main 分支 /docs。旧地址几分钟内恢复。
代价：`github.com/VibeMage/Paster` 的改名 301 会被这个新仓库顶掉。所以**必须先**把仓库内所有指向旧仓库名的
链接改完（已于 2026-09-19 改完）并把两个工作树的 `git remote` 换成 `copyo.git`（已改），否则 push 会推到跳转仓库。

**B. 不建，接受窗口期** ← **已选**
等 1.0.1 过审上架，支持网址随新版本一起切到 `/copyo/support/`。这期间（1–3 天）线上 1.0 的支持链接持续 404。
因此 **1.0.1 要尽快提交**：窗口期长短就等于 1.0.1 的提审到上架时间。提交时务必把版本页的技术支持网址
改成 `https://vibemage.github.io/copyo/support/`，这是本次改动里最关键的一个字段。

> 后续：2026-09-19 旧应用记录被整条删除，商店里已经没有那个页面，这条 404 也就无从点起了。
> 新记录从第一版起就填 `https://vibemage.github.io/copyo/support/`。

### 长期根治

注册 `copyo.app`，在 copyo 仓库 `docs/` 下放 CNAME 并在 Pages 设置里绑定，支持网址改用
`https://copyo.app/support/`。此后再改仓库名也不会断。注意这**不能**修复旧的 `/Paster/` 路径，
那个路径只能靠方案 A 的跳转仓库兜底。

## 十三、第二轮改名：把 Paster 从工程里清干净（2026-09-19，仅 main）

第十一节那次改名只动了产品名与用户可见文案，工程内部——目录、target、模块、类型名、数据路径、
bundle ID、容器标识——原封不动留着 Paster。这一轮把它们全部改掉。

前提变了：**2026-09-19 旧的 App Store Connect 应用记录（`dev.vibemage.Paster`，商店里的 Paster）已被删除，
改名不再是「换个名字发新版」，而是以 Copyo 的身份重新建记录、从 1.0 重新提审。** Apple 不允许复用已删除应用的
bundle ID，所以 bundle ID 必须换，正好与改名一起做完。

### 改了什么

- 源码目录：`Paster/` → `Copyo/`、`PasterCore/` → `CopyoCore/`、`PasterIOS/` → `CopyoIOS/`、
  `PasterShared/` → `CopyoShared/`、`PasterShareExtension/` → `CopyoShareExtension/`、
  `PasterWidgets/` → `CopyoWidgets/`
- 工程：`Paster.xcodeproj` → `Copyo.xcodeproj`；target `Paster` → `Copyo`、`Paster iOS` → `Copyo iOS`、
  `PasterShareExtension` → `CopyoShareExtension`、`PasterWidgets` → `CopyoWidgets`；两个共享 scheme 同步改名
- Swift 模块与类型：`PasterCore` → `CopyoCore`、`PasterStore` → `CopyoStore`、`PasterSchema` → `CopyoSchema`、
  `PasterTheme` → `CopyoTheme`、`PasterTab` → `CopyoTab` 等
- **bundle ID：`dev.vibemage.Paster` → `dev.vibemage.Copyo`**，两个扩展同步改成
  `dev.vibemage.Copyo.ShareExtension` / `dev.vibemage.Copyo.Widgets`
- Control 的 `kind`：`dev.vibemage.Copyo.saveClipboard`（跟着 bundle ID 走）
- App Group：`group.dev.vibemage.Paster` → `group.dev.vibemage.Copyo`
- iCloud 容器：`iCloud.dev.vibemage.Paster` → `iCloud.dev.vibemage.Copyo`
- 本地数据库：`Application Support/Paster/Paster.store` → `Application Support/Copyo/Copyo.store`
- 文件夹同步的子目录：`<共享目录>/Paster/` → `<共享目录>/Copyo/`
- 公证钥匙串配置名的示例：`paster-notary` → `copyo-notary`（只是示例，已经配好的旧 profile
  传 `NOTARY_PROFILE=paster-notary` 照样能用）

### 没改

- `art/`、`specs/` 下的设计稿与设计说明，以及本文件第八至十二节的历史记录：都是带日期的存档，原样留着。
- **`release/1.0` 分支没动。** 那条分支仍然是 `Paster.xcodeproj` / scheme `Paster` / bundle ID
  `dev.vibemage.Paster`，现在已经没有用武之地了——新的应用记录是新的 bundle ID，上架包只能从 main 出。
  留着当 1.0 的存档即可。

### 你要在开发者后台 / ASC 做的

1. Certificates, Identifiers & Profiles → Identifiers → ➕ App IDs：`dev.vibemage.Copyo`（主应用）、
   `dev.vibemage.Copyo.ShareExtension`、`dev.vibemage.Copyo.Widgets`。
2. Identifiers → App Groups → ➕ `group.dev.vibemage.Copyo`，三个 App ID 都勾上。
3. Identifiers → iCloud Containers → ➕ `iCloud.dev.vibemage.Copyo`；主应用 App ID 勾选
   iCloud (CloudKit) 选中该容器，并勾上 Push Notifications。
4. CloudKit Console：在新容器里跑一遍 Development schema，确认 `ClipItem` / `Pinboard` 两张表齐全后
   部署到 Production（正式版发布前必须做完）。
5. ASC → 我的 App → ➕ 新建 App：平台 macOS，名称 `Copyo - Clipboard History`，套装 ID `dev.vibemage.Copyo`，
   SKU `copyo`（旧记录的 SKU `paster` 随记录一起没了）。版本号 **1.0**，构建号从 **1** 开始——新记录没有
   历史构建，`CURRENT_PROJECT_VERSION` 已经重置为 1。商店文案、关键词、审核备注见第三、四节。
6. 描述文件：自动签名会按新 App ID 重新生成；Developer ID 那张要包含新的 iCloud 容器与 App Group，
   否则 `build-release.sh` 归档会失败。

### 老用户升级后会发生什么

- **直发版（Developer ID，未沙盒）**：数据库自动从 `Application Support/Paster/` 搬到 `Copyo/`，
  `Paster.store` 三件套连同外部图片目录 `.Paster_SUPPORT` 一起改名。外部图片目录的名字是 Core Data 从
  store 文件名推导的，不一起改等于把所有图片藏起来，所以搬迁必须成对做（`LegacyStoreMigration`，
  `CopyoCore` 里有对应测试）。搬不动时（权限、文件被占用）继续用旧位置打开，绝不丢数据。
- **App Store 版（沙盒）**：bundle ID 变了，沙盒容器也跟着变成
  `~/Library/Containers/dev.vibemage.Copyo/`。**旧容器里的历史读不到**——沙盒不允许新应用访问
  另一个 bundle ID 的容器，没有官方迁移途径。商店里的 1.0 只活了 8 天（2026-09-11 上架，
  2026-09-19 删除），受影响的用户极少；真要照顾他们，只能在新版里加一个「从旧版导入」的
  `NSOpenPanel` 让用户手动选中旧容器目录，目前没做。
- **文件夹同步**：本机把共享目录里的 `Paster/` 整体改名成 `Copyo/`。还没升级的其他 Mac 会把 `Paster/`
  重新建出来并继续往里写，升级后的这台会继续只读合并那个目录，所以改名窗口期里两边的条目都不会丢。
- **iCloud 同步**：容器换了，等于重新上云。CloudKit 同步从未随正式版发布，线上没有用户受影响；
  开发机上旧容器里的数据作废，本地库不受影响。

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
- 也**不是我们自己的旧记录攥着**：旧记录从建立到删除，App 信息里的名称一直是 `Paster`，
  第十一节计划的 `Copyo: Clipboard History` 那一步从未执行。
- 结论：**第三方在 App Store Connect 里预留了这个字符串**。预留名不出现在商店里，但会挡住新记录，
  且等不到自动释放，支持请求也需要证明名称使用权。

ASC 锁的是精确名称字符串，Apple 官方给的解法就是加限定词；这个品类本来也人人都加
（货架邻居 `CopyClip - Clipboard History`，连 Paste 本尊都是 `Paste – Limitless Clipboard`），
所以加后缀在品牌上零损失。**不要再尝试把商店名改回裸名 `Copyo`。**

评估过的替代品牌全部否掉，主要死因是同品类撞名——**Pinza** 与 **Magpie** 各有一个正在上架的
macOS 菜单栏剪贴板管理器，重蹈 Paster / pasterapp.com 的覆辙；Twofold、Clipo / Clippo、ClipDeck、
Cardo、Roneo、Inkyo 等十余个也都撞了在架应用或踩了发音雷。

### 旧 App ID 删不掉（Apple 拒绝）

尝试删除 `dev.vibemage.Paster` 时 Apple 返回：

> The App ID '9A94W79V84.dev.vibemage.Paster' appears to be in use by the App Store,
> so it can not be removed at this time.

说明已删除的应用记录在 Apple 侧仍与该 bundle ID 绑定（同样的原因，它也不出现在新建记录的套装 ID
下拉里）。**这不是操作失误，是 Apple 的限制**，过一段时间可以再试；删不掉也无害，闲置而已。
`iCloud.dev.vibemage.Paster` 容器同理——iCloud 容器详情页只有 Description 与 Save，**压根没有删除入口**
（对比 App ID 详情页是 Remove + Save），列表筛选器里那个 Hidden 档也没有对应的操作控件。

### 待办（按紧急程度）

1. **注册 `copyo.app` / `copyo.io` / `copyo.dev`**。第十一节写的是「可注册」，至今仍然**没有注册**——
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

1. **删掉「曾用名 Paster」/「formerly Paster」**（描述与审核备注各一处）。
   pasterapp.com 的 Paster 是别家公司仍在售的产品，在商店文案里写「曾用名 Paster」
   容易被读成与对方有关联；而且旧记录已删，商店里没有任何连续性需要交代。
2. **关键词里的 `paster` 换成 `clip`**（中英文各一处）。拿竞品名当关键词违反 App Store 规则，
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

初版四张是 Paster 1.0 时代拍的，其中两张仍在宣传 **1.0 (4) 已经移除的自动粘贴**：

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
