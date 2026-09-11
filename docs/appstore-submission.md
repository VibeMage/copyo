# Mac App Store 提审材料与操作清单

创建日期：2026-09-01 · 最后更新：2026-09-11

## 一、App Store Connect 建应用（你来操作）

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
| 技术支持网址 | `https://vibemage.github.io/Paster/support/`（页面源码在 docs/support/，发布步骤见第九节。原先的 Gist 已因 1.5 被拒，不能再用） |
| 营销网址 | 留空 |
| 版本 | 1.0（与构建的 MARKETING_VERSION 一致） |
| 版权 | `© 2026 Paster Contributors` |

### 推广文本（170 字符内，可随时改无需审核）

- zh：`按下 Shift+Command+V，复制过的文本、链接、图片、文件全部回来。开源、本地存储、零网络请求。`
- en：`Press Shift+Command+V and everything you've copied comes back — text, links, images, files. Open source, local-only, zero network requests.`

⚠️ ASC 的推广文本/关键词字段不接受 ⇧⌘ 等按键符号（报「无效字符」）；描述字段若同样报错，把 ⇧⌘V 改写为 Shift+Command+V。

### 副标题（30 字符内）

- zh：剪贴板历史，一按即达
- en：Clipboard history, one key away

### 描述（简体中文）

```
按下 ⇧⌘V，你复制过的一切从屏幕底部滑出。

Paster 是一款开源的剪贴板管理工具：
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

Paster is an open-source clipboard manager:
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

- zh：`剪贴板,粘贴,历史,剪切板,效率,复制,clipboard,paste`
- en：`clipboard,paste,history,copy,manager,productivity,snippets,pasteboard`

## 四、审核备注（App Review Notes，重点！）

菜单栏工具是审核重点对象，把这段贴进「审核备注」能少一轮拒审：

```
Paster is a menu bar app (LSUIElement) with no Dock icon or main window.

How to use:
1. On first launch a welcome dialog explains the basics.
2. Press Shift+Command+V at any time to open the clipboard panel
   (slides up from the bottom of the screen).
3. Copy anything — it appears in the panel automatically.
4. Select a card and press Return to put it on the clipboard and go back
   to the previous app, then paste with Command+V.
5. Settings are available from the gear button in the panel header,
   or by right-clicking the menu bar icon.

About permissions: Paster does not use Accessibility, event taps or input
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
| 2.4.5 | 应用用辅助功能（Accessibility）来实现热键，属于把无障碍功能挪作他用 | 全局快捷键走 Carbon `RegisterEventHotKey`（`Paster/Services/HotkeyManager.swift`），不需要任何权限。辅助功能只在自动粘贴时用于向目标应用发送 ⌘V（当时的 `PasteService.sendCmdV`，现已删除）。审核员把两者混为一谈，欢迎对话框和设置页当时的文案也确实没把两者分开 |
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

### 提交顺序（支持页面已于 2026-09-09 上线，仓库已公开）

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
