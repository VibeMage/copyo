# Paster

开源的 macOS 剪贴板管理工具：菜单栏常驻，`⇧⌘V` 呼出底部卡片面板，历史即输即搜。
所有数据仅保存在本机（`~/Library/Application Support/Paster/`），无任何网络请求，适合不允许安装第三方闭源工具的办公环境。

## 功能

- **剪贴板历史**：后台自动记录复制过的内容——纯文本、富文本、链接、颜色（`#RRGGBB`）、图片、文件
- **底部滑出面板**：按 `⇧⌘V` 从屏幕底部滑出卡片式面板，横向卡片流展示历史
- **即输即搜**：面板打开后直接键入即可过滤历史，支持按内容、文件名、来源应用搜索
- **键盘优先**：`← →` 导航、`↩` 粘贴、`⌥↩` 纯文本粘贴、`空格` 预览、`⌘⌫` 删除、`Esc` 关闭
- **自动粘贴**：选中条目后自动粘贴到之前的前台应用（需要辅助功能权限；未授权时退化为仅复制）
- **Pinboard**：把常用内容固定到自定义分组，不受历史上限清理影响
- **来源应用标识**：卡片头部显示来源应用的图标与主题色（取应用图标平均色）
- **拖拽**：卡片可直接拖出到任何应用
- **隐私保护**：自动跳过密码管理器等标记为 Concealed/Transient 的内容；可按 Bundle ID 忽略指定应用
- **iCloud 同步**：可选开启，经由 iCloud Drive 在多台 Mac 间同步历史与 Pinboard；数据只经过你自己的 iCloud，默认关闭（公司环境可保持完全离线）
- **自定义快捷键**：默认 `⇧⌘V`，可在设置中录制任意组合键
- **历史上限**：100/300/500/1000/无限制，超限自动清理最旧的未固定记录
- **开机自启**、粘贴音效、纯文本模式等设置

## 安装

从 [Releases](https://github.com/VibeMage/Paster/releases) 下载最新 DMG，打开后把 Paster
拖进 Applications 即可。官方发布均已使用 Developer ID 签名并通过 Apple 公证——双击即可打开，
仅首次有一次「从互联网下载的 App」标准确认弹窗。

## 从源码构建

需要 Xcode 16+、macOS 14+。

```bash
git clone <repo-url> && cd Paster
xcodebuild -project Paster.xcodeproj -scheme Paster -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Paster.app   # 或拷贝到 /Applications
```

也可以直接用 Xcode 打开 `Paster.xcodeproj` 运行（⌘R）。

首次使用「自动粘贴」时，系统会引导授予**辅助功能**权限
（系统设置 → 隐私与安全性 → 辅助功能，勾选 Paster）。

## 打包分发（维护者）

```bash
NOTARY_PROFILE=paster-notary ./scripts/build-release.sh
# 自动检测 Developer ID 证书 → 签名 → Apple 公证 → staple → 产出 dist/Paster-<版本>.dmg + .zip
```

首次需要一次性配置公证凭据（App 专用密码在 account.apple.com 生成）：

```bash
xcrun notarytool store-credentials paster-notary \
  --apple-id <AppleID邮箱> --team-id <TEAMID> --password <App专用密码>
```

- **没有开发者证书时**（比如自行从源码构建）：脚本自动退回 ad-hoc 签名，产物只适合
  本机使用。拿到其他机器会提示「已损坏，无法打开」（Gatekeeper 对无开发者身份应用的
  固定提示），需执行一次 `xattr -cr /Applications/Paster.app`；且 ad-hoc 签名每次构建
  都变化，覆盖安装后需要在辅助功能列表中移除再重新添加 Paster。
- 企业环境若有 MDM（Jamf 等），也可以白名单分发。

### 更新

官方发布签名身份固定：新版 DMG 覆盖安装（拖进 Applications 替换）即可，历史数据在
`~/Library/Application Support/Paster/`，辅助功能等已授予的权限均不受影响。

每台新机器首次使用「自动粘贴」需授予辅助功能权限（系统会自动引导）。

## 图标

主图标是 `art/icon-master.png`（1024×1024）。替换成你自己的设计后执行：

```bash
./scripts/make-icon.sh          # 重新生成资产目录里的全部尺寸
```

再重新构建即可生效。当前仓库内置一个程序化绘制的占位图标。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开 / 关闭面板 | `⇧⌘V`（全局，可在设置中自定义） |
| 在卡片间导航 | `←` `→` |
| 粘贴选中内容 | `↩` 或双击卡片 |
| 以纯文本粘贴 | `⌥↩` |
| 预览选中内容 | `空格`（搜索框为空时；输入中则键入空格） |
| 搜索 | 直接输入 |
| 删除选中内容 | `⌘⌫` |
| 清除搜索 / 关闭面板 | `Esc` |

## 架构

```
Paster/
├── App/        应用入口、菜单栏常驻（NSStatusItem）
├── Models/     SwiftData 模型：ClipItem、Pinboard
├── Services/   剪贴板轮询监听、写回与模拟 ⌘V、全局快捷键、iCloud 同步、图标取色、缩略图缓存
├── Panel/      底部滑出面板（NSPanel + SwiftUI）：卡片流、搜索、预览
└── Settings/   设置窗口（通用 / 历史 / 同步 / 快捷键 / 关于）
```

技术要点：

- macOS 没有剪贴板变化通知 API，`ClipboardMonitor` 以 0.3s 间隔轮询 `NSPasteboard.changeCount`（所有剪贴板工具的通用做法）
- 文本优先于图片抓取：Excel/Numbers 等复制文本时会同时放一份图像渲染，必须按文本记录
- 全局快捷键使用 Carbon `RegisterEventHotKey`，零第三方依赖；模拟 `⌘V` 前会确认目标应用已回到前台
- 存储使用 SwiftData（SQLite），图片走 `externalStorage` + SHA-256 去重 + 缩略图缓存
- 同步经由 iCloud Drive 文件夹快照合并实现（iCloud Drive 是无需付费开发者账号
  即可使用的 iCloud 通道）；快照式同步不传播删除

## License

[GPL-3.0](LICENSE)
