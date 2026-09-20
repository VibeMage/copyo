# Copyo

Copyo（曾用名 Paster）是一款开源的 macOS 剪贴板管理工具：菜单栏常驻，`⇧⌘V` 呼出底部卡片面板，历史即输即搜。
所有数据仅保存在本机（`~/Library/Application Support/Paster/`），无任何网络请求，适合不允许安装第三方闭源工具的办公环境。

## 功能

- **剪贴板历史**：后台自动记录复制过的内容——纯文本、富文本、链接、颜色（`#RRGGBB`）、图片、文件
- **底部滑出面板**：按 `⇧⌘V` 从屏幕底部滑出卡片式面板，横向卡片流展示历史
- **即输即搜**：面板打开后直接键入即可过滤历史，支持按内容、文件名、来源应用搜索
- **键盘优先**：`← →` 导航、`↩` 复制并回到之前的应用、`⌥↩` 以纯文本复制、`空格` 预览、`⌘⌫` 删除、`Esc` 关闭
- **Pinboard**：把常用内容固定到自定义分组，不受历史上限清理影响
- **来源应用标识**：卡片头部显示来源应用的图标与主题色（取应用图标平均色）
- **拖拽**：卡片可直接拖出到任何应用
- **隐私保护**：自动跳过密码管理器等标记为 Concealed/Transient 的内容；可按 Bundle ID 忽略指定应用
- **同步（可选，三选一）**：关闭 / 文件夹 / iCloud。文件夹方式把历史与 Pinboard 写成快照放进 iCloud Drive
  或任意多设备都能读写的目录（公司 NAS、网盘同步目录等），**不传播删除**——一台 Mac 上删掉的条目在其他 Mac
  上依然保留；iCloud 方式经你自己的 iCloud 私有数据库同步，增删改全量生效，**删除会在所有设备上同时消失**。
  两种方式的数据都只经过你自己的存储，默认关闭（公司环境可保持完全离线）
- **自定义快捷键**：默认 `⇧⌘V`，可在设置中录制任意组合键
- **历史上限**：100/300/500/1000/无限制，超限自动清理最旧的未固定记录
- **开机自启**、纯文本模式等设置
- **中英双语界面**：跟随系统语言（简体中文 / English），基于 String Catalog

## 安装

推荐从 [Mac App Store](https://apps.apple.com/app/id6807507103) 安装。

也可以从 [Releases](https://github.com/VibeMage/copyo/releases) 下载 DMG，打开后把 Copyo
拖进 Applications 即可。官方发布均已使用 Developer ID 签名并通过 Apple 公证——双击即可打开，
仅首次有一次「从互联网下载的 App」标准确认弹窗。

## 从源码构建

需要 Xcode 16+、macOS 14+。

```bash
git clone <repo-url> && cd Paster
xcodebuild -project Paster.xcodeproj -scheme Paster -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Copyo.app   # 或拷贝到 /Applications
```

也可以直接用 Xcode 打开 `Paster.xcodeproj` 运行（⌘R）。

iOS / iPadOS 版在同一个工程里（scheme `Paster iOS`，iOS 18+，与 Mac 版共用 `PasterCore` 与 iCloud 数据），模拟器构建：

```bash
xcodebuild -project Paster.xcodeproj -scheme "Paster iOS" -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

工程使用 Xcode 的自动签名，Team 填的是维护者的。贡献者请在 Xcode 的 Signing & Capabilities
里把 Team 换成自己的，或者构建时传入：

```bash
xcodebuild -project Paster.xcodeproj -scheme Paster -configuration Release \
  -derivedDataPath build DEVELOPMENT_TEAM=<你的 Team ID> build
```

只想编译看看、不打算安装到别的机器，也可以加 `CODE_SIGNING_ALLOWED=NO` 直接跳过签名。
注意 iCloud 同步依赖 App ID 上的 iCloud 容器与推送能力，换成自己的 Team 构建时这一项不可用
（需要在自己的开发者账号里建一个 iCloud 容器并改掉 `PasterStore.cloudKitContainerIdentifier`），
其余功能不受影响。

## 打包分发（维护者）

```bash
NOTARY_PROFILE=paster-notary ./scripts/build-release.sh
# 归档 → 以 Developer ID 导出（签名、entitlements、描述文件由 Xcode 处理）
# → Apple 公证 → staple → 产出 dist/Copyo-<版本>.dmg + .zip
```

首次需要一次性配置公证凭据（App 专用密码在 account.apple.com 生成）：

```bash
xcrun notarytool store-credentials paster-notary \
  --apple-id <AppleID邮箱> --team-id <TEAMID> --password <App专用密码>
```

- 脚本需要一份 Developer ID 证书与对应的描述文件（含 iCloud 容器与推送能力）。
  **没有开发者证书时**（比如自行从源码构建）：直接用上一节的 `CODE_SIGNING_ALLOWED=NO`
  构建即可，产物只适合本机使用；拿到其他机器会提示「已损坏，无法打开」（Gatekeeper 对
  无开发者身份应用的固定提示），需执行一次 `xattr -cr /Applications/Copyo.app`。
- 企业环境若有 MDM（Jamf 等），也可以白名单分发。

### 自动构建（GitHub Actions）

每个 PR 和推送到 main（纯文档改动除外）都会跑 `.github/workflows/ci.yml`：无签名编译
macOS Debug、macOS Release-AppStore、iOS 模拟器三条，外加 `swift test --package-path PasterCore`。
不需要任何证书，fork 出去的 PR 也能跑绿。

推送 `v<版本>` 形式的 tag 触发 `.github/workflows/release.yml`：校验 tag 与工程里的
`MARKETING_VERSION` 一致 → 归档 → 以 Developer ID 手动签名导出 → Apple 公证 → staple
→ 产出 DMG / ZIP，并自动创建 Release 附上产物。

```bash
# 先把 project.pbxproj 里的 MARKETING_VERSION 改成要发的版本并提交，再打 tag
git tag v1.0.1 && git push origin v1.0.1
```

CI 跑的不是上面那条 `build-release.sh`，而是 `scripts/ci-release.sh`：无人值守的 runner
既没有 Xcode 里登录的 Apple ID，也没有已注册的 Mac，自动签名那条路在它上面走不通，
所以 CI 改走手动签名 + 预装的 Developer ID 描述文件。两边产出的 .app 与 DMG 完全一致，
CI 只额外多附一份 `SHA256SUMS.txt`。

在 Actions 页面手动触发（Run workflow）是演练：缺哪一环就降级到哪一步，没配任何 secret
时也能跑完，产物只作为 workflow artifact 提供、不会挂到 Release 上。推 tag 则是在要一次
正式发布，签名或公证凑不齐就当场失败——这保证了 Release 页面上的 DMG 永远是签过名并
公证过的。

证书与凭据怎么配、怎么先演练一遍再推 tag，见 [`docs/ci.md`](docs/ci.md)。

### 更新

官方发布签名身份固定：新版 DMG 覆盖安装（拖进 Applications 替换）即可，历史数据在
`~/Library/Application Support/Paster/`，不受影响。

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
| 复制选中内容并回到之前的应用 | `↩` 或双击卡片 |
| 以纯文本复制 | `⌥↩` |
| 预览选中内容 | `空格`（搜索框为空时；输入中则键入空格） |
| 搜索 | 直接输入 |
| 删除选中内容 | `⌘⌫` |
| 清除搜索 / 关闭面板 | `Esc` |

## 架构

```
Copyo/
├── App/        应用入口、菜单栏常驻（NSStatusItem）
├── Models/     SwiftData 模型：ClipItem、Pinboard
├── Services/   剪贴板轮询监听、写回剪贴板并把焦点还给之前的应用、全局快捷键、iCloud 同步、图标取色、缩略图缓存
├── Panel/      底部滑出面板（NSPanel + SwiftUI）：卡片流、搜索、预览
└── Settings/   设置窗口（通用 / 历史 / 同步 / 快捷键 / 关于）
```

技术要点：

- macOS 没有剪贴板变化通知 API，`ClipboardMonitor` 以 0.3s 间隔轮询 `NSPasteboard.changeCount`（所有剪贴板工具的通用做法）
- 文本优先于图片抓取：Excel/Numbers 等复制文本时会同时放一份图像渲染，必须按文本记录
- 全局快捷键使用 Carbon `RegisterEventHotKey`，零第三方依赖；应用不使用辅助功能权限
- 存储使用 SwiftData（SQLite），图片走 `externalStorage` + SHA-256 去重 + 缩略图缓存
- 同步有两条互斥的通道：文件夹方式是快照合并（iCloud Drive 或任意共享目录皆可，
  无需付费开发者账号，但不传播删除）；iCloud 方式由 SwiftData 直接镜像到 CloudKit
  私有数据库，增删改全量同步。两者共用同一份 `Paster.store`，同一时刻只有一种生效

## License

[MIT](LICENSE)
