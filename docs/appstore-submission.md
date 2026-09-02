# Mac App Store 提审材料与操作清单

创建日期：2026-09-01 · 最后更新：2026-09-01

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
| 技术支持网址 | `https://gist.github.com/VibeMage/d787b8025a61e125eacd504313ee8a8f` |
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
• 选中回车，直接粘贴到你正在使用的应用
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
• Hit Return to paste straight into the app you're working in
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
4. Select a card and press Return to paste it into the frontmost app.
5. Settings are available from the gear button in the panel header,
   or by right-clicking the menu bar icon.

About Accessibility permission: the "paste into previous app" feature
simulates Cmd+V and therefore asks the user to grant Accessibility
access in System Settings. The app is fully functional without it —
selecting a card simply copies it to the clipboard instead.

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

```bash
./scripts/build-appstore.sh   # 归档并导出 .pkg 到 build/appstore/
```

前置（一次性，Xcode 里点）：
- Xcode → Settings → Accounts → Manage Certificates → ➕ →
  「Apple Distribution」和「Mac Installer Distribution」各建一张

上传方式二选一：
- Xcode → Window → Organizer → 选中归档 → Distribute App → App Store Connect
- 或从 App Store 装 **Transporter**，拖入 build/appstore/ 里的 .pkg（推荐——
  避免误选到 GUI 归档出的非沙盒包）

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
