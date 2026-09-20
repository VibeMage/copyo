# Copyo macOS 设计规格

创建日期：2026-09-20 · 来源：Claude Design 画布 `Copyo Mac 设计稿`（`art/macos-design/2026-09-20/canvas.json`）

> 本文是把 `art/macos-design/2026-09-20/` 的十张画板整理成的实现依据。
> 数值逐字取自生成脚本 `gen.py` / `gen2.py`，未做取整或推断；设计稿里没有的内容不在此文档中，
> 含糊之处集中在第八节。
>
> 原始文件（只读，不得改动）：
>
> - `Main.dc.html` —— A 版面板 · 浅色主态（画布 1440 × 520）。**这张是手写留存的、比 `gen.py` 旧**：
>   `gen.py` 的 `FILES` 字典里已经没有生成它的那一节，两者共有 6 处取值漂移。**取值一律以 `gen.py` 为准**，
>   这张只作构图参考（详见 7.5.14）。
> - `A-panel-dark.dc.html` —— A 版面板 · 深色主态（1440 × 520）。**十张里唯一的成品深色整帧**，由现行 `gen.py` 生成。
> - `A-hover-toast.dc.html` —— A 版 · 悬停动作簇 + 「已复制」轻提示（1360 × 452）。
> - `A-search.dc.html` —— A 版 · 搜索中，两条结果（1360 × 452）。
> - `A-empty.dc.html` —— A 版 · 空态「历史为空」（1360 × 452）。
> - `Card.dc.html` —— `ClipCard · dense` 组件板：六种类型（浅色一行 + 深色一行）、四种状态、排版最紧的四条（1760 × 1180）。
> - `Tokens.dc.html` —— 语义色板、圆角、字号、来源淡染演示，每格左半浅色 / 右半深色（1760 × 1000）。
> - `Settings.dc.html` —— 设置窗口换肤，只画了「通用」与「快捷键」两页（1240 × 600）。
> - `B-window-light.dc.html` / `B-window-dark.dc.html` —— B 版主窗口（1180 × 800，228pt 侧栏 + 三列 268pt 网格）。
>   **本轮未采纳，顺延到 1.2**，两张留档，本文不展开（处置见第八节第 45 条）。
> - `canvas.json` —— 画布索引：十张画板的坐标、标题与 2026-09-20 的拍板便签。
> - `gen.py` —— A 版面板、卡片、空态、轻提示、搜索态与 B 版主窗口的生成脚本；主题字典 `L` / `D` 与全部图标常量在此。
> - `gen2.py` —— 组件板、Token 板、设置窗口的生成脚本。
>
> **方向定稿**：A 版 = 菜单栏常驻图标 + `⇧⌘V` 唤出的悬浮面板；本轮范围 = **面板重做 + 设置换肤**。
> 卡片 = 整卡淡染来源色（浅 12% / 深 20%）+ 实心类型角标 + 「来源 · 相对时间」+ 圆角 12；
> **卡片不透明**，玻璃只用于面板外壳、悬停动作簇与轻提示；颜色类条目的淡染取**剪贴内容自身的颜色**，不取来源 App 的色；
> 复制后**交还焦点、由用户自己按 `⌘V`**，全文不得出现任何形似「粘贴按钮 / 粘贴标签 / 粘贴动画」的表达。
>
> **基线声明**：全文的 `文件:行号` 引用取自 **2026-09-20 的工作区文件**，对应提交 `5a3f8fe`
> （起草时这批改动尚未提交，成文后已入库；文件内容未变，行号继续成立）。唯一的例外是
> `CopyoShared/UI/CopyoTheme.swift`：它在 `5a3f8fe` 之后又追加了键盘扩展的四档颜色（第 107 行起），
> 本文引用的行号全部 ≤ 106，不受影响。
> 引用**已被删除**的文件时会就地注明——那类路径 `git show HEAD:<路径>` 取不到，要用删除它的提交：
> `git show 0cda755^:CopyoShared/Share/ShareTheme.swift`（通式：`git log --all --diff-filter=D -- <路径>`
> 找到删除它的 `<sha>`，再 `git show <sha>^:<路径>`）。设计数值取自
> `art/macos-design/2026-09-20/gen.py` 与 `gen2.py`。
>
> **与 iOS 规格的关系**：本文与 `art/ios-design/design-spec.md` 同构，节次一一对应（一～八节同名同序），
> 便于互引「第 N 节第 M 条」。两端共用的 token、角标、样例数据以 iOS 规格为对照基准，分歧逐条登记在第八节；
> 需要 iOS 一并跟进的修订集中在 **7.4 全平台修订**。

## 目录

- [一、界面清单](#一界面清单)
- [二、Tokens](#二tokens)
- [三、组件规格](#三组件规格)
- [四、交互 · 键盘 · 悬停 · 动效](#四交互--键盘--悬停--动效)
- [五、SF Symbols 对照表](#五sf-symbols-对照表)
- [六、样例数据](#六样例数据)
- [七、实现映射备注](#七实现映射备注)（含 7.4 全平台修订、7.5 工程风险登记）
- [八、待确认](#八待确认)

**画布尺寸**：面板 1280 × 332（圆角 26）；卡片 260 × 184（圆角 12，dense 档）；
设置窗口 540 × 460（设计值，与代码现值的冲突见第八节第 9 条）。
A 版展示画布 1440 × 520 / 1360 × 452，面板在其中的位置是**展示构图，不是布局规则**。

---

## 一、界面清单

本章对应 A 版定稿：菜单栏常驻 + ⇧⌘V 唤出的悬浮面板，本轮范围为**面板重做 + 设置换肤**。
B 版主窗口（`B-window-light.dc.html` / `B-window-dark.dc.html`）未采纳，顺延到 1.2，本文不展开。

数值逐字取自 `art/macos-design/2026-09-20/gen.py` 与 `gen2.py`；画板文件为这两个脚本的产物。
`Main.dc.html` 是脚本更早一版的留存（见 7.5.14），凡与 `gen.py` 冲突处一律以 `gen.py` 为准。

导出文件名一律 `<编号>-<名称>-<light|dark>.png`。
十张画板里**成品深色帧只有 `A-panel-dark.dc.html`（01 一帧）**；另有两处深色内容不构成整帧：
`Card.dc.html` 的「六种类型 · 深色」类型行（`dark_strip(kind_row(D))`，`gen2.py:84-85`），
以及 `Tokens.dc.html` 每个 token 右半格的深色值（`gen2.py:153` 题注「左半格 = 浅色，右半格 = 深色」）。
B 版的 `B-window-dark.dc.html` 是深色整帧，但 B 版本轮未采纳，不在导出清单内。
**01b / 01c / 01d / 04 / 04b 的深色版设计稿未出**，需按 `D` 字典换算后导出（见第八节第 46 条）。

主题字典记号（下文反复引用，完整表在第二章）：

| 记号 | 浅色 `L` | 深色 `D` |
| --- | --- | --- |
| `glass` | `rgba(255,255,255,0.74)` | `rgba(58,58,60,0.72)` |
| `ring` | `inset 0 0 0 0.5px rgba(0,0,0,0.06)` | `inset 0 0 0 0.5px rgba(255,255,255,0.15)` |
| `cring` | `inset 0 0 0 0.5px rgba(0,0,0,0.05)` | `inset 0 0 0 0.5px rgba(255,255,255,0.06)` |
| `swatchring` | `inset 0 0 0 0.5px rgba(0,0,0,0.08)` | `inset 0 0 0 0.5px rgba(255,255,255,0.10)` |
| `label` | `#000000` | `#FFFFFF` |
| `meta` | `rgba(60,60,67,0.78)` | `rgba(235,235,245,0.72)` |
| `sec` | `rgba(60,60,67,0.60)` | `rgba(235,235,245,0.60)` |
| `ter` | `rgba(60,60,67,0.34)` | `rgba(235,235,245,0.34)` |
| `fill` | `rgba(118,118,128,0.12)` | `rgba(118,118,128,0.24)` |
| `fill2` | `rgba(118,118,128,0.20)` | `rgba(118,118,128,0.32)` |
| `sep` | `rgba(60,60,67,0.24)` | `rgba(84,84,88,0.60)` |
| `grouped` | `#F2F2F7` | `#1C1C1E` |
| `card` | `#FFFFFF` | `#2C2C2E` |
| `desktop` / `d1` / `d2` | `#4E5766` / `#5E6878` / `#47505E` | `#22262E` / `#2B3039` / `#1B1F26` |
| `dock` / `dockr` | `rgba(255,255,255,0.20)` / `rgba(255,255,255,0.28)` | `rgba(255,255,255,0.12)` / `rgba(255,255,255,0.16)` |

`accent` = `#0A84FF`（两色同值，钉死）。`destructive` 浅 `#FF3B30` / 深 `#FF453A`。
`success` 浅 `#34C759` / 深 `#30D158`。`warning` = `#FF9F0A`。
等宽字族 `MONO` = `ui-monospace, 'SF Mono', Menlo, monospace`；正文字族 `-apple-system, "SF Pro Text", "PingFang SC", system-ui, sans-serif`。

---

### 01 面板 · 主态

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 01 | 正常 · 筛选停在「全部」· iCloud 已同步 | `01-panel-light.png`（`Main.dc.html`）/ `01-panel-dark.png`（`A-panel-dark.dc.html`） |
| 01b | 第一张卡键盘焦点 + 第二张卡悬停动作簇 + 「已复制」轻提示 | `01-panel-hover-light.png`（`A-hover-toast.dc.html`） |
| 01c | 搜索中 · 命中高亮 · 结果计数 | `01-panel-search-light.png`（`A-search.dc.html`） |
| 01d | 空态 | `01-panel-empty-light.png`（`A-empty.dc.html`） |

#### 画布与真实尺寸

画布 **1440 × 520 是展示用外框**（桌面背景 + Dock 示意），**真实面板是 1280 × 332**。
页面 `body` 底色 `#ECEBE7`；外框内：

| 元素 | 位置 | 尺寸 | 样式 |
| --- | --- | --- | --- |
| 桌面底 | 0, 0 | 1440 × 520 | `desktop` |
| 装饰圆 1 | left 118, top 44 | 420 × 420 | radius 210，`d1` |
| 装饰圆 2 | left 880, top −60 | 520 × 520 | radius 260，`d2` |
| Dock 条 | left 440, top 448 | 560 × 64 | radius 18，底 `dock`，`inset 0 0 0 0.5px` `dockr` |
| 面板 | left 80, top 92 | 1280 × 332 | 见下 |

面板本体：`padding 16`、`border-radius 26`、底 `glass`、`backdrop-filter: blur(24px)`、
`box-shadow: <ring>, 0 1px 3px rgba(0,0,0,0.10), 0 24px 56px rgba(0,0,0,0.30)`，纵向 flex。

#### 面板纵向骨架（合计 332）

| 段 | 高 |
| --- | --- |
| 上内距 | 16 |
| 搜索行 | 32 |
| 间距 | 10 |
| 筛选行 | 26 |
| 间距 | 12 |
| 卡片轨道 | 184 |
| 间距 | 12 |
| 底部提示条 | 24 |
| 下内距 | 16 |

#### 搜索行（高 32，`gap 8`）

- 搜索框：占满剩余宽，高 32，`padding 0 10`，`radius 8`，底 `fill`，`gap 6`；
  内含 14pt 放大镜（`stroke-width 1.6`，色 `sec`）+ 占位文字 13pt 色 `label`。
- iCloud 按钮：32 × 32，`radius 8`，17pt 云 + 勾图标（`stroke-width 1.5`），色 `success`；`aria-label` / `title` 均为「iCloud 已同步」。
- 设置按钮：32 × 32，`radius 8`，17pt 齿轮（`stroke-width 1.5`），色 `sec`；`aria-label` / `title` 为「设置」。

#### 筛选行（高 26，`gap 8`；左侧 chips 间 `gap 6`）

胶囊：高 26、`radius 8`、字号 12、`padding 0 11`；
选中 = `accent` 底 + `#FFFFFF` 字 + 600；未选 = `fill` 底 + `label` 字 + 500。
带 chevron 的胶囊改 `padding 0 9px 0 11px`、`gap 5`，chevron 11pt `stroke-width 1.8` 色 `sec`。

六项筛选固定为：`全部`（本帧选中）`文本` `链接` `图片` `颜色` `文件`；行尾右对齐一个带 chevron 的 `Pinboard` 胶囊。

#### 卡片轨道（高 184，`gap 12`，`overflow: hidden`）

卡片 **260 × 184**、`padding 12`、`radius 12`、内部 `gap 8`、底色 = 来源淡染、描边 `cring`。
首行高 18、`gap 6`：类型角标 + meta + 可选图钉。
角标（dense）：高 18、`padding 0 6px 0 5px`、`radius 9`、`gap 3`、字号 10 / 600、底 = 来源色、
前景由 `onband()` 判定（相对亮度 > 0.62 取 `#16161A`，否则 `#FFFFFF`），内含 10pt 类型图标。
meta 单行 10pt 色 `meta`，溢出省略号。末行高 20 右对齐一个 20 × 20、`radius 5` 的来源色方块（描边 `swatchring`）。

五张卡逐字：

| # | 类型 | 来源色 / 淡染浅 / 淡染深 | meta | 正文 |
| --- | --- | --- | --- | --- |
| 1 | 文本 | `#147EFB` / `#E3F0FE` / `#273C57` | `Xcode · 2 分钟前` | 等宽 11/15：`git rebase -i HEAD~3 && git push --force-with-lease` |
| 2 | 文本 | `#07C160` / `#E1F8EC` / `#254A38` | `微信 · 12 分钟前` | `周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。` |
| 3 | 链接 | `#1EA7FD` / `#E4F4FF` / `#294457` | `Safari · 25 分钟前` | 标题 `Adopting Liquid Glass | Apple Developer Documentation` + 域名 `developer.apple.com` |
| 4 | 颜色 | `#FF2D55` / `#FFE6EB` / `#562E36` | `Figma · 1 小时前` | 色块 `#FF2D55` + 色值胶囊 `#FF2D55` |
| 5 | 图片 | `#FFC300` / `#FFF8E0` / `#564A25` | `备忘录 · 昨天 18:42` | 缩略图占位色 浅 `#F0E4BE` / 深 `#4A431F` |

正文排版：普通文本 12/16、等宽文本 `MONO` 11/15，均 `white-space: pre-line`、`-webkit-line-clamp: 7`、`word-break: break-word`。
链接体：标题 12/16 Medium 色 `label`、3 行截断；域名 11/15 色 `accent`、单行省略；两者 `gap 6`。
颜色体：色块 `flex-grow`、`radius 10`、描边 `swatchring`；色值胶囊高 22、`padding 0 8`、`radius 11`、底 `fill2`、`MONO` 11 / 600 色 `label`、左对齐；两者 `gap 8`。
图片体：占位块 `flex-grow`、`radius 10`、描边 `swatchring`。

**第 4 张卡是「颜色类取剪贴内容自身颜色」这条修订的落点**：角标底色、右下方块、色块三处全部取 `#FF2D55`（`COLORCLIP[0]`），
不取来源 App Figma 的 `#A259FF`；淡染取 `COLORCLIP` 的 `#FFE6EB` / `#562E36`。

#### 底部提示条（高 24，`gap 14`）

四组提示左对齐，每组 `gap 5`、文字 11pt 色 `sec`，前置 keycap；
keycap：`min-width 20`、高 20、`padding 0 5`、`radius 6`、底 `fill2`、`MONO` 11 / 500、色 `meta`。

逐字：`↩ 复制` · `空格 预览` · `⌘P 固定` · `⌘⌫ 删除`。
右端撑开后放一行 11pt 色 `sec` 的文字：`复制后回到原来的 App，按 ⌘V 粘贴`。

#### 01 文案（全部逐字）

搜索框占位 `搜索历史`（另有视觉隐藏的 `<label>` 同文）· 筛选 `全部` `文本` `链接` `图片` `颜色` `文件` · `Pinboard` ·
按钮无障碍名 `iCloud 已同步` / `设置` · 提示条 `复制` `预览` `固定` `删除` + `复制后回到原来的 App，按 ⌘V 粘贴` ·
卡片内容见上表。

#### 01 特有交互

- **⇧⌘V 唤出 / 再按收起**。面板从 `visibleFrame` 内缩浮动（不是 `screen.frame`，否则会压住 Dock），四角 radius 26。
- 面板呼出即取得 key window，键盘焦点默认落在第一张卡；搜索框常驻接管键入（直接打字即进入搜索）。
- **↩ 复制**：写回系统剪贴板 → 收起面板 → 把焦点交还给唤出前的 App，由用户自己按 ⌘V。
  界面上**不出现任何形似「粘贴按钮」的控件或文案**。
- `空格` 预览、`⌘P` 固定、`⌘⌫` 删除、`⌘F` 聚焦搜索、`⌘1–9` 直接取第 N 张卡、`esc` 关闭面板。
- `⇧↩` 纯文本复制——**本轮待拍板，见第八节第 17 条**。设计稿写的是 `⇧↩`（`gen2.py:241`），
  今天的实现是 `⌥↩`；是直接换掉、还是两个都接受，未定。
- `⇥` 在筛选间循环——**本轮待拍板，见第八节第 18 条**。设计稿的设置页写「在筛选间循环」（`gen2.py:242`），
  而第四节 4.1.1 的目标焦点模型要求 `⇥` 在 **search / cards / filters 三区**之间循环，两者不是一回事；
  拍板结果要同时回改本节、§04b 的九行表与设置页文案。
- 卡片轨道横向滚动；键盘移动选中时把当前卡滚到可视中央。
- 筛选六项单选；`Pinboard` 胶囊带 chevron，点开列出 Pinboard。
- 卡片可拖出面板到其他 App（系统拖放）。
- 面板失去 key 时自动收起（面板自身弹出的 alert / 菜单期间除外）。

---

### 01b 悬停 + 已复制轻提示

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 01b | 卡 1 键盘焦点 · 卡 2 悬停带动作簇 · 底部「已复制」轻提示 | `01-panel-hover-light.png` |

画布 **1360 × 452**，底 `desktop`；一个装饰圆 left 118 / top 24 / 420 × 420 / radius 210 / `d1`；**无 Dock 条**。
面板 1280 × 332 置于 left 40 / top 40。顶栏、筛选、轨道、提示条与 01 完全一致，五张卡内容也一致。

#### 卡片态

| 态 | 落在 | 描边 / 变换 |
| --- | --- | --- |
| 键盘焦点 | 卡 1（Xcode） | `0 0 0 2px #0A84FF, 0 0 0 7px rgba(10,132,255,0.32)` |
| 悬停 | 卡 2（微信） | 描边仍为 `cring`，右上叠一簇玻璃动作按钮 |

悬停动作簇：`position: absolute; right: 8px; top: 8px`，高 28、`padding 0 3`、`radius 9`、`gap 2`，
底 `glass` + `backdrop-filter: blur(14px)`，`box-shadow: <ring>, 0 2px 8px rgba(0,0,0,0.14)`。
内含两个 24 × 24、`radius 7` 的按钮：

| 按钮 | 无障碍名 | 图标 |
| --- | --- | --- |
| 固定 | `固定到 Pinboard` | 14pt 图钉，`stroke-width 1.5`，色 `accent` |
| 删除 | `删除` | 14pt 垃圾桶，`stroke-width 1.5`，色 `destructive` |

#### 轻提示

定位在**画布**上（不在面板内）：`left: 50%`、`bottom: 60px`、`transform: translateX(-50%)`。
高 36、`padding 0 16`、`radius 18`、`gap 7`，底 `glass` + `backdrop-filter: blur(20px)`，
`box-shadow: <ring>, 0 6px 20px rgba(0,0,0,0.18)`；文字 13pt / 500 色 `label`；
前置 14pt 勾图标、`stroke-width 2`、色 `success`。

逐字：`已复制 · 按 ⌘V 粘贴`。

按画布坐标算，轻提示占 y 356–392，面板下沿在 y 372，即轻提示**跨在面板底边上、向下越出 20pt**。

#### 01b 特有交互

- 鼠标进入卡片 → 动作簇淡入；离开即消失。动作簇只有「固定」「删除」两项，其余动作走右键菜单（见 03）。
- 轻提示在复制动作后出现，随后面板收起；提示是复制结果的回执，**不是**可点的粘贴入口。
- 键盘焦点环与鼠标悬停是两套互不干扰的视觉：本帧同时出现在两张不同的卡上。

---

### 01c 搜索中

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 01c | 搜索词「会议」· 筛选停在「文本」· 2 条命中 | `01-panel-search-light.png` |

画布 **1360 × 452**，底 `desktop`，**无装饰圆、无 Dock**；面板 1280 × 332 置于 left 40 / top 40。

#### 纵向骨架（合计 332）

| 段 | 高 |
| --- | --- |
| 上内距 | 16 |
| 搜索行 | 32 |
| 间距 | 10 |
| 筛选行 | 26 |
| 间距 | 12 |
| 结果计数行 | 18 |
| 间距 | 8 |
| 卡片轨道 | 158 |
| 间距 | 12 |
| 底部提示条 | 24 |
| 下内距 | 16 |

#### 与 01 的差异

- 搜索框取得焦点环：`box-shadow: 0 0 0 2px #0A84FF, 0 0 0 6px rgba(10,132,255,0.28)`。
- 搜索框内不再是占位符，而是 13pt 色 `label` 的实文 `会议`，其后紧跟光标：
  行内块 1.5 × 15、`margin-left 1px`、`vertical-align: -3px`、底色 `accent`。
- 筛选行选中项从「全部」移到 **`文本`**；六项与 `Pinboard` 胶囊不变。
- 新增结果计数行：高 18、`gap 8`，文字 11pt 色 `meta`，逐字 `2 条结果`。
- 轨道高从 184 **降到 158**（`gen.py:310` 的 `track("".join(scs), 158)`）。
  **卡片本身仍是 260 × 184**：`scs` 里两张卡调 `card()` 时没传 `w` / `h`，走的是 `gen.py:108` 的默认 `w=260, h=184`；
  `track()`（`gen.py:240-241`）只是 `height: 158px; overflow: hidden`。
  也就是说画板上是**把 184 高的卡片从底部裁掉 26pt**，不是换了一套矮卡片。
  搜索态到底用真矮卡片（重排内容）还是沿用裁切，**需定，见第八节第 5 条**。
- 提示条右侧文案换成 `Esc 清空搜索 · 再按一次关闭面板`；左侧四组 keycap 提示不变。

#### 两张结果卡逐字

| # | 类型 | 来源色 / 淡染 | meta | 卡态 | 正文 |
| --- | --- | --- | --- | --- | --- |
| 1 | 文本 | `#07C160` / `#E1F8EC` | `微信 · 12 分钟前` | 键盘焦点 | `周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上。` |
| 2 | 文本 | `#FFC300` / `#FFF8E0` | `备忘录 · 昨天 09:12` | 默认 | `站会议纪要 9/4`↵`· 登录页流程另开一稿`↵`· 图标最终稿 8a 已定`↵`· TestFlight 周三发` |

命中高亮：两张卡里的 `会议` 二字包在 `<mark>` 内，
样式 `background: rgba(10,132,255,0.22); color: inherit; border-radius: 3px; padding: 0 1px`——
只加底，不改字色。

#### 01c 特有交互

- 面板内直接打字即进入搜索，不必先点搜索框；`⌘F` 显式聚焦。
- 搜索结果实时过滤，结果计数行随之更新；搜索与筛选叠加生效（本帧是「文本」∩「会议」）。
- 搜索态轨道高度降到 158，卡片本身不变形（仍 260 × 184），被轨道裁掉底部 26pt，正文可见行数随之减少；
  画板上末行是**被切掉一半**而不是整行省略，这正是第八节第 5 条要解决的问题。
- `Esc` 两段式：第一次清空搜索词，第二次关闭面板。提示条右侧文案就是这条规则的说明。

---

### 01d 空态

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 01d | 无任何历史条目 | `01-panel-empty-light.png` |

画布 **1360 × 452**，底 `desktop`，无装饰圆、无 Dock；面板 1280 × 332 置于 left 40 / top 40。

#### 纵向骨架

搜索行 32 → 间距 12 → 空态区 **222** → 间距 12 → 提示条 24，上下内距各 16。
**空态下筛选行不显示**（`showchips=False`），搜索行本身保持完整（搜索框 + iCloud 按钮 + 设置按钮）。

#### 空态区（高 222）

整块水平垂直居中，插画与文字块 `gap 24`。

插画 96 × 96（`plate`，`gen.py:316-324`；`BONE #F7F3EA` / `BRED #FF2D55` / `BBLUE #0A84FF` / `INK #16161A` 四个常量在 `gen.py:28`）。

「**全 App 唯一在正文界面使用品牌红蓝错位的地方**」这句话是 iOS 规格的口径，**macOS 端是否照搬待确认**
（见第八节第 27 条）。事实依据：`Tokens.dc.html` 的 token 表把
`brand.bone` / `brand.red` 的允许范围写成「只在图标、空态、引导、设置图标砖」（`gen2.py:115-116`），
但 macOS 的设置图标砖 `TILE`（`gen2.py:177-181`）用的全是系统语义色（`#0A84FF` / `#5856D6` / `#FF9F0A` /
`#34C759` / `#8E8E93` / `#30B0C7` / `destructive`），**一个品牌色都没有**。
即 macOS 实际的品牌色出现点只有 App 图标与本帧插画两处，比 token 表写的清单更窄——收紧清单还是保留该表述，需拍板。

图层逐字：

| 层 | 位置 | 尺寸 | 样式 |
| --- | --- | --- | --- |
| 骨白卡 | 0, 0 | 96 × 96 | radius 22，`#F7F3EA`，`box-shadow: 0 8px 24px rgba(0,0,0,0.12)` |
| 红条 | left 20, top 24 | 52 × 8 | radius 2，`#FF2D55`，`opacity 0.9` |
| 蓝条 | left 24, top 28 | 52 × 8 | radius 2，`#0A84FF`，`opacity 0.85`，`mix-blend-mode: multiply` |
| 内容条 1 | left 22, top 52 | 36 × 8 | radius 4，`#16161A` |
| 内容条 2 | left 22, top 64 | 52 × 8 | radius 4，`#16161A` |
| 内容条 3 | left 22, top 76 | 24 × 8 | radius 4，`#16161A` |

文字块：`max-width 420`、纵向 `gap 6`。

| 行 | 样式 | 逐字 |
| --- | --- | --- |
| 标题 | 17 / 700，色 `label` | `还没有内容` |
| 正文 | 12 / 17，色 `meta` | `复制任何东西，它都会出现在这里。Copyo 在后台自动记录，不需要你做任何事。` |
| 提示行 | `margin-top 6`、`gap 6`、11pt 色 `sec`，前置 keycap `⇧⌘V` | `随时按 ⇧⌘V 唤出这个面板` |

提示条右侧文案换成 `Esc 关闭`；左侧四组 keycap 提示不变（空态下仍然画出）。

#### 01d 特有交互

- 空态只在历史为空时出现；搜索无命中是另一种空（设计稿未出，见第八节第 3 条）。
- 空态不显示筛选行，也不显示 Pinboard 胶囊。
- `Esc` 直接关闭面板（没有搜索词可清）。

---

### 02 预览浮层（空格 Quick Look）

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 02 | 文本 / 富文本 / 图片 / 颜色 / 文件五类内容的预览 | `02-preview-light.png` / `02-preview-dark.png` |

> **本轮需重做、设计未出。** 以下是 `Copyo/Panel/PreviewOverlay.swift` 的**现状记录**，不是定稿值，
> 也不得当作实现依据照抄。已列入第八节第 2 条。

现状（`Copyo/Panel/PreviewOverlay.swift`）：

| 项 | 现值 | 位置 |
| --- | --- | --- |
| 背景遮罩 | `Color.black.opacity(0.35)`，铺满，点击即关 | :12–14 |
| 浮层尺寸 | 680 × 320 | :20 |
| 浮层底 | `.regularMaterial`，`RoundedRectangle(cornerRadius: 14)` | :21 |
| 浮层描边 | `Color.primary.opacity(0.15)`，`lineWidth: 1`，radius 14 | :22–25 |
| 浮层阴影 | `.black.opacity(0.35)`，`radius: 18`，`y: 6` | :26 |
| 图片内容 | `scaledToFit()` + `padding(12)` | :34–39 |
| 颜色内容 | `RoundedRectangle(cornerRadius: 10)` 填色 + `padding(16)` | :40–43 |
| 文件内容 | 每行 20 × 20 系统图标 + 12pt 等宽路径，行距 6，`padding(14)` | :44–60 |
| 文本 / 富文本 | 13pt（富文本走 `NSAttributedString`），可选中，`padding(14)` | :61–76 |
| 页脚条 | 高 30，`padding(.horizontal, 14)`，底 `Color.primary.opacity(0.05)`，字号 11 secondary | :88–101 |
| 页脚三栏 | 来源名 · 类型（图片 / 文件只写类型名，其余追加字数）· `abbreviated` 日期 + `shortened` 时间 | :80–95 |

#### 02 重做的四个选项（全部未拍板）

十张画板里没有任何一张画预览浮层，所以这一帧必须从别处取骨架。目前有四条路：

| 选项 | 内容 |
| --- | --- |
| (a) | 沿用现状尺寸（680 × 320 / radius 14 / `.regularMaterial`），只把颜色换成本规格的 token |
| (b) | 按新面板重画：radius 26、`glass` + `blur(24px)` 外壳，meta 行统一成「来源 · 相对时间」 |
| (c) | 本轮不动，顺延到 1.2 |
| (d) | **按 iOS 规格 §3.13「详情页骨架」降 dense 档外推**（详见下表） |

**选项 (d) 的来源值**（逐字取自 `art/ios-design/design-spec.md` §3.13，第 469–479 行）：

| 构件 | iOS §3.13 的值 |
| --- | --- |
| 预览块 | radius 12、`padding 12`、**来源淡染底**，正文 17/24 |
| 颜色详情 · 色块 | 高 220、radius 10 |
| 颜色详情 · 色值胶囊 | 高 30、`padding 0 10`、radius 15、`fill` 底、SF Mono 13（首个 `label` Semibold，其余 `label.secondary`） |
| 信息组 | radius 12、`bg.card`；行高 44、`padding 0 16`、15pt `label` + 右值 `label.secondary`；行间 `0.5px separator` |
| 底部工具栏 | 底距 26、高 64、`padding 0 8`、`gap 2`、radius 32、glass |
| 工具栏主按钮 | 高 48、`padding 0 18`、radius 24、accent 底、15 Semibold 白字 + 图标；其余四个图标按钮 50 × 48，图标 20 |

**上表是 iOS 的触屏档值，不是 macOS 的定稿值。** 照搬到 macOS 前至少要解决三件事：
(i) 行高 44 与工具栏高 64 是拇指命中尺寸，macOS 鼠标档需按本规格已有的 dense 换算降档
（面板内同类构件：设置行 `min-height 40`、keycap 高 20、色值胶囊高 22）；
(ii) iOS 的 §3.13 是一张**独占的详情页**，macOS 的 02 是压在面板上的**浮层**，底部玻璃工具栏与浮层页脚条是两套东西，二选一；
(iii) 「预览块用来源淡染底」与本章 §01 卡片的整卡淡染是同一套色，可直接复用，这是 (d) 相对 (a)(b) 唯一现成的部分。

四个选项与上述三个问题**一并列入第八节第 2 条**，本轮不得据此实现。

#### 02 特有交互

- `空格` 切换开关（`PanelRootView.swift` 的 `handleKeyPress`：`case .space where search.isEmpty`，即**搜索框非空时空格不触发预览**，走普通输入）。
- 预览打开时按方向键移动选中会先关闭预览。
- `Esc` 的第一段优先关预览，其次清搜索，最后关面板。
- 点击遮罩任意处关闭。
- 文本与文件路径可选中复制（`.textSelection(.enabled)`）。

---

### 03 上下文菜单

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 03 | 卡片右键菜单 | `03-menu-light.png` / `03-menu-dark.png` |
| 03b | 面板空白处右键菜单 | `03-menu-blank-light.png` |

macOS 用系统 `NSMenu`（SwiftUI `.contextMenu`），**外观、宽度、行高、材质一律交给系统**，
本规格只定菜单项文案、顺序、分隔位置与破坏项角色。iOS 规格 3.11 里的宽 250 / radius 14 / `blur(30) saturate(180%)` 等数值**不适用于 macOS**。

#### 03 卡片右键 · 文案与顺序

| 序 | 文案 | 角色 |
| --- | --- | --- |
| 1 | `复制` | 默认 |
| 2 | `纯文本复制` | 默认 |
| — | 分隔线 | |
| 3 | `分享` | 默认（系统分享菜单，`NSSharingServicePicker`） |
| 4 | `固定到 Pinboard` | 子菜单：逐个列出已有 Pinboard，分隔线后 `新建 Pinboard…`；条目已固定时该项换为 `取消固定` |
| — | 分隔线 | |
| 5 | `删除` | `destructive` |

（现有实现在 `PanelRootView.swift:253-285` 的 `.contextMenu`：无 Pinboard 时第 4 项直接是
`Pin to Pinboard…`，有 Pinboard 时才是 `Menu("Pin to")` 子菜单；`Unpin` 今天是独立的第 5 项，
不是「该项换为取消固定」。本章的归并口径是本轮新设计，与现状的差异走第七节实现映射。）

#### 03b 面板空白处右键 · 文案与顺序

| 序 | 文案 | 角色 |
| --- | --- | --- |
| 1 | `清空历史` | `destructive`，弹确认 |
| — | 分隔线 | |
| 2 | `设置` | 默认，打开设置窗口 |

#### 03 的两个对话框（本轮必须拍板，见第八节第 20、21 条）

**(1) `新建 Pinboard…` 弹的是面板内的 SwiftUI `.alert`，不是 `NSAlert`。**
入口有两个：「03 卡片右键 · 文案与顺序」表第 4 项 `固定到 Pinboard` 的子菜单尾项，以及一个 Pinboard 都没有时直接落在第 4 项上。
实现在 `PanelRootView.swift:108-117`：

```
.alert("New Pinboard", isPresented: $showNewPinboardAlert) { TextField("Name", …) … }
```

**正因为它在面板内弹**，才需要 `PanelRootView.swift:98-107` 那段补丁：`.onChange(of: showNewPinboardAlert)`
在弹出时把 `panelController.suppressAutoHide` 置 `true`，关闭时置回 `false` 并调 `makePanelKey()` 重夺 key、
再把焦点还给搜索框。换句话说「面板失去 key 不自动收起」（§01 特有交互末条）这条例外，
主要就是为这个 alert 开的。

视觉归属三选一，**均未定**：

| 选项 | 内容 | 代价 |
| --- | --- | --- |
| (a) | 保持系统 `.alert` 原样，只做文案中文化 | 面板是无边框玻璃浮层，系统 alert 会在它上方另开一块 macOS 标准材质，与新皮完全不同构 |
| (b) | 按 iOS 规格 §3.11 的 Alert 降 macOS 档重画 | iOS 的 Alert 是触屏档（宽 250 / radius 14 / `blur(30) saturate(180%)`），降档规则本章 §03 开头已声明**不适用于 macOS**，等于要新定一套 |
| (c) | 不弹对话框，改成**面板内联输入行**（在筛选行下方或 Pinboard 胶囊展开处直接起一行输入） | 可以彻底去掉 `suppressAutoHide` / `makePanelKey()` 这套补丁，但要新画一帧 |

另两件配套：文案需中文化（现为英文原串 `New Pinboard` / `Name` / `Create` / `Cancel` /
`Pinboards keep the clips you use most within reach`）；以及它与第四节 4.1.3 第 3 条
「`suppressAutoHide` 升级为计数」的落地顺序——若选 (c)，那条计数改造就不必做了，需按顺序拍板。

**(2) `清空历史` 的确认框在仓库里有两份实现，共用同一批字符串。**

| 入口 | 实现 | 位置 |
| --- | --- | --- |
| 菜单栏菜单的 `Clear History…` | `NSAlert`（`alertStyle = .warning`，`NSApp.activate` 后 `runModal()`） | `AppDelegate.swift:231-239`（菜单项本身在 `:201`） |
| 设置 · 历史页的 `Clear History…` 按钮 | SwiftUI `.confirmationDialog` | `SettingsView.swift:170-175`（按钮在 `:164`） |

两者的标题（`Clear History?`）、正文与按钮（`Clear` / `Cancel`）是同一批 `String(localized:)`，
删除逻辑也一致（都只删 `pinboard == nil` 的条目，删完 `save()` 并 `ThumbnailCache.removeAll()`：
`AppDelegate.swift:241-249`、`SettingsView.swift:178-186`）。
§03b 新增的「面板空白处右键 → 清空历史」会成为**第三个**入口。
**需定：三个入口是否收敛成一处实现**（例如统一走 `.confirmationDialog`，或统一走 `NSAlert`），
以及面板内弹出时是否同样需要上面 (1) 的 `suppressAutoHide` 补丁。

#### 03 特有交互

- 菜单弹出期间面板**不得**因失去 key 而自动收起。
- 与 iOS 不同：macOS 不做「底层模糊 + 卡片抬起」的长按预览，右键即出系统菜单，卡片本身不变形。
- `固定到 Pinboard` 的子菜单与 `Pinboard` 筛选胶囊列的是同一份 Pinboard，顺序一致。
- `清空历史` 只清未固定条目；确认对话框的文案沿用现有 `Clear History?` 那一组的中文版，
  但**实现收敛与否见上面「03 的两个对话框」第 (2) 条**（仓库里现有两份实现，本轮再加一个入口）。
- `新建 Pinboard…` 弹的是面板内的 SwiftUI `.alert`，不是系统 `NSAlert`；它的视觉归属见上面第 (1) 条，未定。
- 悬停动作簇（01b）与右键菜单是同一批动作的两个入口，动作语义必须一致。

---

### 04 设置 · 通用

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 04 | 设置窗口 · 通用页 | `04-settings-general-light.png` / `04-settings-general-dark.png` |
| 04b | 设置窗口 · 快捷键页（含快捷键被占用的失败态） | `04-settings-shortcuts-light.png` / `04-settings-shortcuts-dark.png` |

`Settings.dc.html` 把这两扇窗**并排画在同一张画板**上：画布 1240 × 600、`padding 36`、底 `desktop`、两列 `gap 40`、顶对齐；
每扇窗下方 `gap 10` 配一行 11 / 16 的说明文字，色 `rgba(255,255,255,0.7)`、宽 540。

#### 窗口外壳（两页共用）

| 项 | 值 |
| --- | --- |
| 窗口 | **540 × 460**，`radius 11`，`overflow: hidden`，底 `grouped` |
| 窗口阴影 | `0 0 0 0.5px rgba(0,0,0,0.2), 0 24px 56px rgba(0,0,0,0.34)` |
| 标题栏 | 高 **38**，`padding 0 14`，`gap 12`，底 `glass`，下边 `0.5px solid <sep>` |
| 红绿灯 | 三个 12 × 12 圆：`#FF5F57` / `rgba(118,118,128,0.3)` / `rgba(118,118,128,0.3)`（后两枚为禁用态），`gap 8` |
| 标题 | `设置`，13 / 600 色 `label`，居中（`margin-left: -56px` 抵消红绿灯宽度） |
| 分段控件区 | `padding 12px 16px 4px`，水平居中 |
| 内容区 | `padding 12px 16px 16px`，纵向 flex，`gap 14`，`overflow: hidden` |

分段控件：容器 `padding 3`、`radius 8`、底 `fill`、`gap 2`；
每项高 24、`padding 0 12`、`radius 6`、字号 12、字色 `label`；
选中 = 底 `card` + 600 + `box-shadow: 0 1px 2px rgba(0,0,0,0.12)`；未选 = 底 `transparent` + 400。

五项逐字、顺序固定：`通用` `同步` `快捷键` `历史` `关于`。

#### 分组、行、图标砖（两页共用）

| 构件 | 值 |
| --- | --- |
| 分组标题 | 11 / 600、`letter-spacing 0.4`、高 20、色 `sec`；可带副标 11 / 400 色 `ter`、`margin-left 8` |
| 分组容器 | `radius 10`、`overflow: hidden`、底 `card`、描边 `cring` |
| 普通行 | `min-height 40`、`padding 7px 12px`、`gap 10`；非末行下边 `0.5px solid <sep>` |
| 行主文 | 13pt 色 `label` |
| 行副文 | 10 / 14 色 `ter`、`margin-top 1` |
| 行右值 | 12pt 色 `meta` |
| 图标砖 | 26 × 26、`radius 7`、底 = 指定色；内容为 15pt 描边图标（`stroke-width 1.6`）或 `MONO` 13 / 600 字形，前景由 `onband()` 判定 |
| 脚注 | 11 / 16 色 `meta` |
| 开关 | 38 × 22、`radius 11`；开 = `#34C759`、旋钮 `left 18`；关 = `rgba(118,118,128,0.24)`、旋钮 `left 2`；旋钮 18 × 18、`radius 9`、`#FFFFFF`、`box-shadow: 0 1px 3px rgba(0,0,0,0.2)`、`top 2` |

#### 04 通用页 · 逐字文案

分组一，标题 `启动`：

| 图标砖 | 主文 | 副文 |
| --- | --- | --- |
| `#34C759` + 勾 | `登录时启动 Copyo` | — |
| `#8E8E93` + 齿轮 | `在菜单栏显示图标` | —（末行，无下边） |

分组二，标题 `捕获`：

| 图标砖 | 主文 | 副文 |
| --- | --- | --- |
| `#0A84FF` + 剪贴板 | `自动记录剪贴板` | `Copyo 在后台记录，不需要任何权限` |
| `#FF9F0A` + 字形 `A` | `忽略密码管理器` | `来自 1Password、钥匙串的内容不会被记录`（末行，无下边） |

页面脚注（宽 460）：
`复制后 Copyo 把内容写回系统剪贴板并把焦点交还给原来的 App，由你自己按 ⌘V —— Copyo 从不代你粘贴。`

画板上该窗下方的说明：`通用 · 540 × 460，结构不动，只换行样式与彩色图标砖`

#### 04 特有交互

- 四行都是开关行，点整行或点开关都切换（开关本身在画板上未绘出，见第八节第 8 条）。
- `登录时启动 Copyo` 走 `SMAppService.mainApp` 的注册 / 注销；失败时开关回弹到系统实际状态，并在窗口回到前台时重查。
- `在菜单栏显示图标` 关掉后，设置窗口只能从面板搜索行右侧的齿轮按钮进入。
- 页面脚注是「不代粘贴」这条硬约束的对外说明，**不可删、不可改写成粘贴动作的说明**。

---

### 04b 设置 · 快捷键

分段控件选中项为 `快捷键`；窗口外壳、分组与行的样式同 04。

#### 唤出分组

分组标题 `唤出`，副标 `点一下可以改`。

录制行（单行独占一组）：`min-height 44`、`padding 8px 12px`、`gap 10`。

| 元素 | 值 |
| --- | --- |
| 图标砖 | `#5856D6`，内容为 `MONO` 13 / 600 字形 `⌘` |
| 主文 | `唤出面板`，13pt 色 `label` |
| 录制按钮 | `min-width 88`、高 26、`padding 0 10`、`radius 7`、底 `card`、`box-shadow: 0 0 0 2px #0A84FF`、`MONO` 12 / 500 色 `label`；内容 `⇧⌘V` |

失败态行（紧贴分组下方，`gap 6`）：13pt 感叹号圆图标（`stroke-width 1.6`）+ 11pt 文字，两者均为 `destructive`。

逐字：`这个组合已被另一个 App 占用，Copyo 收不到它`

#### 面板内分组

分组标题 `面板内`。九行，每行高 **34**、`padding 0 12`、非末行下边 `0.5px solid <sep>`；
左侧 13pt 色 `label`，右侧 keycap（底 `fill2`、`MONO` 11 / 500、色 `meta`、`min-width 20`、高 20、`radius 6`）。

| 序 | 动作 | keycap |
| --- | --- | --- |
| 1 | `复制选中项` | `↩` |
| 2 | `纯文本复制` | `⇧↩` ⚠ |
| 3 | `预览` | `空格` |
| 4 | `固定到 Pinboard` | `⌘P` |
| 5 | `删除` | `⌘⌫` |
| 6 | `聚焦搜索` | `⌘F` |
| 7 | `在筛选间循环` ⚠ | `⇥` |
| 8 | `直接取第 N 张卡` | `⌘1–9` |
| 9 | `关闭面板` | `esc`（末行，无下边） |

（`唤出面板 / ⇧⌘V` 不在这张表里，它是上面的录制行。）

⚠ **两处未定，画板上的字面值不等于定稿**（与 §01 特有交互同一问题）：
第 2 行的 `⇧↩` 是设计稿的写法（`gen2.py:241`），今天的实现是 `⌥↩`，是否直接换掉见**第八节第 17 条**；
第 7 行的行名「在筛选间循环」（`gen2.py:242`）与第四节 4.1.1 的 search / cards / filters 三区循环模型不一致，
见**第八节第 18 条**。拍板后**这一页的行名与 keycap 都要跟着改**，因为它是只读说明页，写错就是对用户说谎。

画板上该窗下方的说明：
`快捷键 · 商店截图 04 就是这一页；keycap 转为共享组件，并补上「快捷键被占用」这个今天完全不存在的失败态`

#### 04b 特有交互

- 点录制按钮进入录制态，按钮描边 `0 0 0 2px #0A84FF` 就是录制中的视觉；再点一次或按 `Esc` 取消。
- 组合必须含 `⌘` / `⌥` / `⌃` 至少一个，否则 `NSSound.beep()` 并拒绝（`Copyo/Settings/SettingsView.swift:569–572`）。
- 注册失败（被别的 App 占用）时在录制行下方显示失败态行。**这个失败态今天的代码里完全不存在**，属本轮新增。
- 非默认组合时录制按钮右侧另有一个 `重置` 按钮（现有行为，`SettingsView.swift:526–533`）；画板未绘出。
- 「面板内」九行是只读清单，不可点、不可改。

---

### 04c 设置 · 其余三页（同步 / 历史 / 关于）

**本轮没画。** 这三页在**换肤范围内**：结构与控件清单照搬现状，视觉一律按 04 的分组标题、行、图标砖、脚注规则执行，
窗口外壳与分段控件与 04 / 04b 完全一致。

下面三张表是 `Copyo/Settings/SettingsView.swift` 的**现状读数**，体例与 iOS 规格一致：
左列「元素」一律用中文名，右列「现值」给结构与数值。
界面上现有的英文串单独标为「英文原串」并附中文说明——**这些英文是今天代码里的字面量，不是定稿文案**，
中文化在本地化阶段统一做（新增 / 作废的字符串清单见 7.5.8）。

#### 同步页（`SyncSettingsView`，`SettingsView.swift:194–258`）

| 元素 | 现值 |
| --- | --- |
| 同步方式选择器 | `Picker`，三选一；英文原串 `Sync Method`，选项 `Off` / `Shared Folder` / `iCloud`（中文：关 / 共享文件夹 / iCloud）。`iCloud` 一项用 `Text(verbatim:)`，不参与本地化 |
| 方式说明 | Section footer，12pt secondary；三段随选项变的文案（`modeDescription`，:248–257） |
| 重启提示 | 独立 Section，仅 `needsRestart` 为真时出现（:227–237）；一行说明 + 一枚按钮，英文原串 `Restart Copyo`（中文：重新启动 Copyo） |

`iCloud` 分支（`CloudKitSyncSections`，:264–353）：

| 元素 | 现值 |
| --- | --- |
| 分组标题 | 英文原串 `iCloud Account`（中文：iCloud 账户） |
| 状态行 | SF Symbol（`checkmark.circle.fill` / `ellipsis.circle` / `exclamationmark.triangle.fill`）+ 六种状态文案 |
| 未登录时的按钮 | 英文原串 `Open System Settings`（中文：打开系统设置），跳 `x-apple.systempreferences:…AppleIDSettings`（:349–352） |
| 三段降级说明 | 「未签 iCloud entitlement」「容器创建失败」「推送不可用」各一段 Section footer |

`Shared Folder` 分支（`FolderSyncSections`）按构建风味分两套，同名不同实现：

| 元素 | 现值 · `APPSTORE`（:361–454） | 现值 · 非 `APPSTORE`（:458–492） |
| --- | --- | --- |
| 立即同步按钮 | 英文原串 `Sync Now`（中文：立即同步） | 同左，且仅 `SyncService.isAvailable` 时出现 |
| 首个 footer | 含「上次同步于 …」状态行（英文原串 `Last synced …`）与失去访问权告警 | 三种情形分支：iCloud Drive 可用 / 未开启 / 自定义目录父级不存在 |
| 目录分组标题 | 英文原串 `Sync Folder`（中文：同步文件夹） | 英文原串 `Custom Sync Folder (Optional)`（中文：自定义同步文件夹（可选）） |
| 目录输入方式 | **只读**：等宽 12pt 路径 + `lineLimit(1)` + `truncationMode(.head)`，未选时显示英文原串 `No folder selected`（中文：未选择文件夹）；改动只能点按钮，英文原串 `Choose Sync Folder…`（中文：选择同步文件夹…）（`:395–405`） | **可手输**：等宽 12pt `TextField`，占位串为一条示例路径（`:482–483`） |
| 下附说明 | 一段说明文字 | 一段说明文字 |

#### 历史页（`HistorySettingsView`，`SettingsView.swift:134–187`）

| 元素 | 现值 |
| --- | --- |
| 历史上限选择器 | `Picker`，五选一；英文原串 `History Limit`（中文：历史上限），选项 `100 items` / `300 items` / `500 items` / `1000 items` / `Unlimited`（中文：100 / 300 / 500 / 1000 条、不限），`tag` 依次 100 / 300 / 500 / 1000 / 0（`:143–149`） |
| 上限说明 | Section footer，12pt secondary；超限时自动删除最旧的未固定条目，已固定的不受影响 |
| 忽略名单分组 | 分组标题英文原串 `Ignored Apps`（中文：忽略的 App）；内含 `TextEditor`，等宽 12pt、`frame(height: 80)`（`:156-158`） |
| 忽略名单说明 | 12pt secondary；每行一个 bundle ID，并说明密码管理器标记为 concealed 的内容一律跳过 |
| 清空历史按钮 | `Button`，`role: .destructive`；英文原串 `Clear History…`（中文：清空历史…），在 `:164` |
| 清空确认框 | `.confirmationDialog`（`:170–175`）：标题英文原串 `Clear History?`，按钮 `Clear`（destructive）/ `Cancel`，另附 message。**这是仓库里的第二份实现**，详见 §03「03 的两个对话框」第 (2) 条 |

#### 关于页（`AboutView`，`SettingsView.swift:593–617`）

| 元素 | 现值 |
| --- | --- |
| 图标 | SF Symbol `doc.on.clipboard.fill`，48pt，`.tint`（`:602–604`） |
| 应用名 | `Copyo`，22pt Bold；用 `Text(verbatim:)`，**不参与本地化**（`:605–606`） |
| 版本行 | 12pt secondary；英文原串 `Version <short> (<build>)`（中文：版本 …），取自 `CFBundleShortVersionString` / `CFBundleVersion`（`:594–598`、`:607–609`） |
| 说明 | 12pt secondary、居中；代码里是**一个** `Text`，中间用 `\n` 断成两句（开源声明 + 同步默认关闭的隐私声明），英文原串见 `:610` |
| 布局 | 纵向 `VStack(spacing: 12)`，`frame(maxWidth: .infinity, maxHeight: .infinity)` 居中铺满 |

#### 04c 特有交互

- 三页均沿用现有行为，本轮不改功能，只换视觉。
- 同步方式切换后 `iCloud` 一路需重启才换容器；文件夹一路的定时器立即起停（:207–210）。
- 沙盒构建的同步目录必须由用户在 `NSOpenPanel` 里亲选并存安全作用域书签，不接受手输路径。
- 关于页的「同步默认关闭 / 不经第三方服务器」这段文字是对外承诺，改动需同步改隐私说明。

---

### 本章待确认

> 本章相关的待确认条目：见第八节第 1、2、3、4、5、8、9、12、17、18、20、21、22、27、45、46、47 条。
> `Main.dc.html` 与 `gen.py` 的六处漂移属工具链问题，见 7.5.14。

---

## 二、Tokens

> 本节数值逐字取自 `art/macos-design/2026-09-20/gen.py` 的主题字典 `L` / `D`、常量区，以及
> `gen2.py` 的 `SW`（语义色板）、`tintdemo`、`typerow`、`radrow` 调用。设计稿 `Tokens.dc.html` 是这两段代码的渲染产物。
> 「与 iOS 一致」列对照的是 `art/ios-design/design-spec.md` 第 2.1 / 2.2 节，以及它今天在代码里的落地
> `CopyoShared/UI/CopyoTheme.swift`（该文件 `import UIKit`，现由 iOS App + 分享扩展 + Widget 三个 target 共用）。
> 该文件由 `CopyoIOS/UI/Theme.swift` 与 `CopyoShared/Share/ShareTheme.swift` 合并而来（提交 `0cda755`
> 「move the shared ui vocabulary into CopyoShared」），后两者已在同一提交中删除，只能用
> `git show 0cda755^:<路径>` 取。`CopyoTheme.swift` 本身已入库，工作区与 `git show HEAD:` 均可打开。
> macOS 侧 `Copyo/` 目录**不参与任何 theme**，Panel 与 Settings 的颜色、字号今天全部是字面量，
> 因此「落点」一列写的是本轮要落到的位置，不是今天的位置。

### 2.1 语义色

`Tokens.dc.html` 的「语义色」色板共 16 条，逐条对应 `gen2.py:100–117` 的 `SW` 列表。
色板每格左半是浅色、右半是深色。下表在这 16 条之外补了一行 `label.tertiary`——
它没有上色板，但 `gen.py` 的 `L` / `D` 字典里以 `ter` 之名定义并在画板上生效，且取值与 iOS 不同。

| token | 浅 | 深 | 与 iOS 规格是否一致 | 落点 |
| --- | --- | --- | --- | --- |
| `bg.grouped` | `#F2F2F7` | `#1C1C1E` | **不一致**。iOS 规格与 `CopyoTheme.swift:62` 深色为 `#000000`。见 2.2 (a) | 设置窗口底（`win()` 的 `th["grouped"]`）、深色卡片展板衬底（`gen2.py:75–76` 的 `dark_strip`） |
| `bg.card` | `#FFFFFF` | `#2C2C2E` | **不一致**。iOS 规格与 `CopyoTheme.swift:63` 深色为 `#1C1C1E`。见 2.2 (a) | 卡片淡染的基底（`mix()` 的 base）、设置分组底（`gen2.py:204–206` 的 `group()`）、分段控件选中项底（`gen2.py:214`） |
| `bg.raised` | `#FFFFFF` | `#3A3A3C` | **新增**，iOS 规格与 `CopyoTheme.swift` 均无同名 token。见 2.2 (b) | 贴在面板 / 卡片上的实心行；今天只有分享面板「固定到 Pinboard」那一行在用（`CopyoShared/Share/ShareView.swift:232` 的 `CopyoTheme.rowOpaque`） |
| `label` | `#000000` | `#FFFFFF` | 一致（`CopyoTheme.swift:64`） | 卡片正文（`body_text`）、搜索框输入文字、设置行标题、色值胶囊文字 |
| `label.secondary` | `rgba(60,60,67,.6)` | `rgba(235,235,245,.6)` | 一致（`CopyoTheme.swift:65`，写作 `rgb(0x3C3C43, 0.6)` / `rgb(0xEBEBF5, 0.6)`，`0x3C3C43` 即 60,60,67） | 底部提示条文字（`hintbar`）、搜索框放大镜与齿轮描边色、侧栏「设置」行 |
| `label.meta` | `rgba(60,60,67,.78)` | `rgba(235,235,245,.72)` | **新增**，macOS 专属。iOS 侧无此档。见 2.2 (c) | 卡片 meta 行「来源 · 相对时间」（`card()` 的 `meta_cell`）、keycap 文字、设置行右侧值、`note()` 说明文字、搜索结果计数 |
| `label.tertiary` | `rgba(60,60,67,.34)` | `rgba(235,235,245,.34)` | **不一致**。iOS 规格与 `CopyoTheme.swift:66` 均为 `.3` | 分组小标题（`h2()`）、B 版侧栏计数、圆角/淡染标注文字、设置行副文 |
| `fill` | `rgba(118,118,128,.12)` | `rgba(118,118,128,.24)` | 一致（`CopyoTheme.swift:70`） | 搜索框底、未选中筛选胶囊底、分段控件容器底 |
| `fill2` | `rgba(118,118,128,.2)` | `rgba(118,118,128,.32)` | 一致（`CopyoTheme.swift:71`） | keycap 底、色值胶囊底、文件堆叠的后两枚方块 |
| `separator` | `rgba(60,60,67,.24)` | `rgba(84,84,88,.6)` | 一致（`CopyoTheme.swift:72`） | 设置行之间 0.5px 分隔线、设置窗口标题栏下沿 |
| `accent` | `#0A84FF` | `#0A84FF` | 一致（`CopyoTheme.swift:57–58`）。**钉死，不跟随系统重点色** | 选中环、键盘焦点环、搜索框聚焦环、选中筛选胶囊底、链接域名、图钉图标、搜索高亮 `rgba(10,132,255,.22)` |
| `destructive` | `#FF3B30` | `#FF453A` | 一致（`CopyoTheme.swift:60`） | 悬停动作簇的删除图标、设置里的危险项图标砖、「快捷键被占用」告警 |
| `success` | `#34C759` | `#30D158` | 一致（`CopyoTheme.swift:61`） | iCloud 已同步图标、「已复制」轻提示的对勾、开关开启态、设置「登录时启动」图标砖 |
| `warning` | `#FF9F0A` | `#FF9F0A` | 一致（`CopyoTheme.swift:89`，`Color(uiColor: rgb(0xFF9F0A))`，无浅深之分） | 设置「忽略密码管理器」图标砖、「历史」图标砖、B 版侧栏图片分类点 |
| `source.local` | `#8E8E93` | `#8E8E93` | 一致（`CopyoTheme.swift:104–105`）。**两端必须同一个** | 算不出来源色时的回退；iOS 存进来的条目在 Mac 上一律走这一档（`gen2.py:68–69` 的「本机」卡） |
| `brand.bone` | `#F7F3EA` | `#F7F3EA` | 一致（`CopyoTheme.swift:99`） | 只在图标、空态插画、引导、设置图标砖（macOS 实际是否收紧见第八节第 27 条） |
| `brand.red` | `#FF2D55` | `#FF2D55` | 一致（`CopyoTheme.swift:97`）。**正文、描边、控件一律不得使用** | 同上（macOS 实际是否收紧见第八节第 27 条）；空态插画的红色错位条（`gen.py` 的 `BRED`） |

`SW` 未列、但 `gen.py` 的 `L` / `D` 字典里定义并在画板上生效的其余键：

| 名称 | 浅 | 深 | 与 iOS 规格是否一致 | 落点 |
| --- | --- | --- | --- | --- |
| `glass` | `rgba(255,255,255,0.74)` + `blur(24)` | `rgba(58,58,60,0.72)` + `blur(24)` | **不一致**。iOS 规格为 `rgba(255,255,255,.72)` + blur20 / `rgba(120,120,128,.28)` + blur20 | 面板外壳（`panel()`）、悬停动作簇、「已复制」轻提示、设置窗口标题栏、B 版工具栏 |
| `ring`（glassRing） | `inset 0 0 0 0.5px rgba(0,0,0,0.06)` | `inset 0 0 0 0.5px rgba(255,255,255,0.15)` | 一致（iOS 2.2 节 `glassRing`；`CopyoTheme.swift:92` 的 `glassStroke` 是同值的手工回退） | 面板外壳、动作簇、轻提示的描边 |
| `cring`（cardRing） | `inset 0 0 0 0.5px rgba(0,0,0,0.05)` | `inset 0 0 0 0.5px rgba(255,255,255,0.06)` | **新增**，iOS 规格无此档（iOS 卡片明确「无边框」） | 卡片默认态描边、设置分组描边 |
| `swatchring` | `inset 0 0 0 0.5px rgba(0,0,0,0.08)` | `inset 0 0 0 0.5px rgba(255,255,255,0.10)` | **新增**，iOS 规格无此档 | 色块、缩略图、来源色点、文件堆叠方块的描边 |
| `desktop` / `d1` / `d2` | `#4E5766` / `#5E6878` / `#47505E` | `#22262E` / `#2B3039` / `#1B1F26` | 画板外壁纸，非产品 token | 仅用于 `desktop_frame()` / `flat_frame()` 的演示桌面，不进代码 |
| `dock` / `dockr` | `rgba(255,255,255,0.20)` / `rgba(255,255,255,0.28)` | `rgba(255,255,255,0.12)` / `rgba(255,255,255,0.16)` | 同上 | 仅演示 Dock |

阴影常量（`gen.py` 直接写在各构件里，未进主题字典）：

| 位置 | 值 |
| --- | --- |
| 面板（`panel()`） | `<ring>, 0 1px 3px rgba(0,0,0,0.10), 0 24px 56px rgba(0,0,0,0.30)` |
| 悬停动作簇 | `<ring>, 0 2px 8px rgba(0,0,0,0.14)` |
| 「已复制」轻提示 | `<ring>, 0 6px 20px rgba(0,0,0,0.18)` |
| 卡片 lift 态 | `<cring>, 0 12px 32px rgba(0,0,0,0.28)` |
| 空态插画骨白卡 | `0 8px 24px rgba(0,0,0,0.12)` |
| 设置窗口 | `0 0 0 0.5px rgba(0,0,0,0.2), 0 24px 56px rgba(0,0,0,0.34)` |
| 分段控件选中项 | `0 1px 2px rgba(0,0,0,0.12)` |
| 开关滑块 | `0 1px 3px rgba(0,0,0,0.2)` |

**角标文字色（`onband`）取值与 iOS 不一致。** `gen.py` 的 `onband()` 在亮度 > 0.62 时返回 `INK = "#16161A"`（不透明），
而 iOS 规格与 `CopyoTheme.swift:138` 返回的是 `rgba(0,0,0,.78)`。详见 2.5。

### 2.2 macOS 修订与新增

#### (a) 深色基色整体抬离纯黑

| token | iOS 今天 | macOS 定稿 | 代码位置 |
| --- | --- | --- | --- |
| `bg.grouped` 深 | `#000000` | `#1C1C1E` | `CopyoShared/UI/CopyoTheme.swift:62` —— `static let bgGrouped = dynamic(light: rgb(0xF2F2F7), dark: rgb(0x000000))` |
| `bg.card` 深 | `#1C1C1E` | `#2C2C2E` | `CopyoShared/UI/CopyoTheme.swift:63` —— `static let bgCard = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x1C1C1E))` |

理由记录在 `gen2.py:101` 与 `gen2.py:84` 的注解里：「深色离开纯黑 —— 窗口里的黑是个洞」、
「底色从 `#1C1C1E` 抬到 `#2C2C2E`，20% 淡染才分得出来」。浅色两档不变。

**影响面（macOS）**：

- 卡片淡染的深色基底随之从 `#1C1C1E` 变成 `#2C2C2E`。2.5 表里所有深色淡染值都是按 `#2C2C2E` 算出来的，
  照旧基底重算会全部对不上。
- 设置窗口底 `win()` 用 `th["grouped"]`，分组底 `group()` 用 `th["card"]`，深色下两者的对比从
  `#000000` vs `#1C1C1E` 变为 `#1C1C1E` vs `#2C2C2E`，差值不变，观感整体抬高一档。
- macOS 今天没有任何一处使用这两个值：`Copyo/Panel/CardView.swift:24` 用的是 `Color(nsColor: .textBackgroundColor)`，
  `:198` 用 `Color(nsColor: .windowBackgroundColor)`，面板底是 `Copyo/Panel/PanelRootView.swift:62` 的
  `VisualEffectView(material: .hudWindow)`。所以 macOS 侧是**首次落地**，没有迁移成本。

**iOS 侧需要同步改什么**：

1. `CopyoTheme.swift:62` 深色值 `rgb(0x000000)` → `rgb(0x1C1C1E)`。
2. `CopyoTheme.swift:63` 深色值 `rgb(0x1C1C1E)` → `rgb(0x2C2C2E)`。
3. `CopyoTheme.swift:113`，`tintUIColor(source:)` 的深色 base `rgb(0x1C1C1E)` → `rgb(0x2C2C2E)`，
   否则 iOS 的淡染仍按旧基底混，两端同一条目颜色不同。同文件 `:109` 的注释「深色按 20% 混进 `#1C1C1E`」一并改。
4. `CopyoTheme.swift:77` 的 `sheet`（`#F2F2F7` / `#1C1C1E`）改完之后深色与 `bgGrouped` 同值，
   需要确认是合并成一个 token 还是保留两个同值 token。
5. `CopyoTheme.swift:75` 的 `menu`（深 `rgba(44,44,46,.86)`，即 `#2C2C2E` @86%）与新的 `bgCard` 同色相，
   叠在卡片上时会几乎看不出层级，需要复核分享面板与上下文菜单。
6. `CopyoIOS/` 里所有假设「深色分组底是纯黑」的手写值需要 grep 一遍（本轮未逐一核对；回归范围见 7.4.1）。

#### (b) 新增 `bg.raised`

| | 浅 | 深 |
| --- | --- | --- |
| `bg.raised` | `#FFFFFF` | `#3A3A3C` |

`gen2.py:103` 的注解原文：「新增 · 把 ShareTheme 里那条没回流的补丁转正」。

被转正的那条补丁在 `CopyoShared/Share/ShareTheme.swift`。**该文件已在 2026-09-20 的重构中删除**，
工作区里打不开；下面的行号引用的是 `git show 0cda755^:CopyoShared/Share/ShareTheme.swift`：

- 第 50 行：`static let rowBackground = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x2C2C2E))`
- 第 45–49 行是它的注释，记的正是「设计稿这行用的是 `bg.card`，但深色下 `bg.card` 与 `sheet` 都是 `#1C1C1E`——
  照抄的结果是整行在深色里完全看不见」。

今天这条补丁已经合并进统一 theme：`CopyoShared/UI/CopyoTheme.swift:84`
`static let rowOpaque = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x2C2C2E))`，
注释在 `:79–83`，其中 `:82–83` 逐字记录了 `bgCard` 与 `sheet` 在深色下同为 `#1C1C1E` 的撞色。
唯一使用者是 `CopyoShared/Share/ShareView.swift:232`。

**注意这不是一次改名。** 采纳 (a) 之后 `bg.card` 深色变成 `#2C2C2E`，恰好等于 `rowOpaque` 今天的深色值，
撞色问题原地复发。所以 `bg.raised` 的深色必须再抬一档到 `#3A3A3C`，浅色维持 `#FFFFFF`（与 `bg.card` 浅色同值，
浅色下靠 `cring` 与阴影分层，不靠底色）。

**影响面（macOS）**：面板与卡片之上的实心行、实心控件底。本轮面板重做里没有这类行，
设置换肤里也没有（设置分组走 `bg.card`）。macOS 侧本轮**只声明不使用**，为 1.2 的 B 版主窗口预留。

**iOS 侧需要同步改什么**：

1. `CopyoTheme.swift:84` 的 `rowOpaque` 深色值 `rgb(0x2C2C2E)` → `rgb(0x3A3A3C)`，并改名为 `bgRaised` 以对齐 token 名。
2. `CopyoTheme.swift:79–83` 的注释要重写：撞色对象从「`bgCard` 与 `sheet` 同为 `#1C1C1E`」变成
   「`bgCard` 与 `rowOpaque` 同为 `#2C2C2E`」。
3. `CopyoShared/Share/ShareView.swift:232` 的调用点随改名更新。
4. `docs/ios-plan.md:229–232` 记录 `rowOpaque` 命名由来的那条 bullet（起于 `:229`）需要跟进。

#### (c) 新增 `label.meta`

| | 浅 | 深 |
| --- | --- | --- |
| `label.meta` | `rgba(60,60,67,.78)` | `rgba(235,235,245,.72)` |

`gen2.py:106` 的注解原文：「Mac 专属 · 10pt meta 在淡染上要 4.5:1」。

这一档在 iOS 规格与 `CopyoTheme.swift` 里都不存在。现有的两档是：

- `CopyoTheme.swift:65` `labelSecondary` = `rgba(60,60,67,.6)` / `rgba(235,235,245,.6)`；
- `CopyoTheme.swift:69` `cardBodySecondary` = `rgba(60,60,67,.9)` / `rgba(235,235,245,.85)`，
  用途是富文本卡片的正文，不是 meta 行。

`label.meta` 插在这两档之间，浅色 `.78`、深色 `.72`。

**影响面（macOS）**：`gen.py` / `gen2.py` 里取 `th["meta"]` 的全部位置 ——
卡片 meta 行（`card()` 的 `meta_cell`，10pt）、`keycap()` 文字（11pt mono）、
`hintbar` 右侧说明、搜索结果计数、`note()` 说明段、设置行右侧值（`srow()` 的 `val`）、
`tintdemo` 的来源名、`swatch` 的色值标注。macOS 今天对应的位置是
`Copyo/Panel/CardView.swift:195` 的 `.foregroundStyle(.secondary)`（系统语义色，不是这个值）。

**iOS 侧需要同步改什么**：

1. `CopyoTheme.swift` 新增 `static let labelMeta = dynamic(light: rgb(0x3C3C43, 0.78), dark: rgb(0xEBEBF5, 0.72))`。
2. iOS 侧卡片 meta 行今天走的是 `labelSecondary`（`.6`）。要不要一并抬到 `.78` / `.72`，
   规格未定；若不改，同一条目的 meta 行在两端浓度不同（见第八节第 32 条 (e)）。

### 2.3 圆角 · 间距

#### 圆角

`gen2.py:171–173` 的 `radrow` 调用逐字：

| 位置 | 值 |
| --- | --- |
| 面板 | 26 |
| 卡片 · 预览块 | 12 |
| 缩略图 · 色块 | 10 |
| 胶囊 · 搜索框 | 8 |
| 角标 | 9 |
| keycap | 6 |

与 iOS 的差异：iOS `radius.inner` = 8（色块、缩略图），macOS 是 10；
iOS `radius.badge` = 10（高 20 胶囊），macOS dense 角标是 9（高 18）。
`CopyoTheme.swift:147–157` 的 `Radius` 今天是 `card 12 / inner 8 / badge 10 / group 12 / sheet 38 / banner 14 / tabBar 32 / button 20 / toast 20`，
其中 `card` 一档两端相同。

未进圆角板、但在构件里出现的其余半径：

| 位置 | 值 | 出处 |
| --- | --- | --- |
| 悬停动作簇外壳 | 9 | `gen.py` `card()` 的 `cluster` |
| 动作簇内按钮 | 7 | 同上 |
| 顶栏图标按钮（32 × 32） | 8 | `gen.py` `topbar()` |
| 色值胶囊（高 22） | 11 | `gen.py` `body_color()` |
| 「已复制」轻提示（高 36） | 18 | `gen.py` 轻提示段 |
| 卡片来源色点（20 × 20） | 5 | `gen.py` `card()` |
| 文件堆叠方块（30 × 30） | 7 | `gen.py` `body_files()` |
| 设置窗口 | 11 | `gen2.py:229` `win()` |
| 设置分组 | 10 | `gen2.py:205` `group()` |
| 设置图标砖（26 × 26） | 7 | `gen2.py:186` `tile()` |
| 分段控件容器 / 选中项 | 8 / 6 | `gen2.py:212–216` `seg()` |
| 开关（38 × 22）/ 滑块（18） | 11 / 9 | `gen2.py:199–201` `toggle()` |
| 空态插画骨白卡（96 × 96） | 22 | `gen.py` 空态段 |

#### 面板尺寸与间距

`gen.py` `panel()` / `topbar()` / `track()` / `hintbar()` 的实际值：

| 项 | 值 |
| --- | --- |
| 面板尺寸 | 1280 × 332（`panel(th, inner, w=1280, h=332)`） |
| 面板内距 | 16（四边） |
| 面板圆角 | 26 |
| 面板材质 | `glass` + `backdrop-filter: blur(24px)` |
| 顶栏第一行高 | 32 |
| 顶栏第一行元素间距 | 8 |
| 搜索框 | 高 32、内距 `0 10px`、圆角 8、内部 gap 6、底 `fill` |
| 搜索框聚焦环 | `0 0 0 2px <accent>, 0 0 0 6px rgba(10,132,255,0.28)` |
| 顶栏图标按钮 | 32 × 32，圆角 8，图标 17、stroke 1.5 |
| 搜索放大镜图标 | 14、stroke 1.6 |
| 第一行与筛选行之间 | 10 |
| 筛选行高 | 26 |
| 筛选胶囊之间 | 6；筛选组与 Pinboard 胶囊之间 8 |
| 筛选胶囊 | 高 26、圆角 8、字号 12、内部 gap 5；无 chevron 时内距 `0 11px`，带 chevron 时 `0 9px 0 11px`；chevron 图标 11、stroke 1.8 |
| 顶栏与卡片流之间 | 12 |
| 卡片流高 | 184（搜索态 158，见 `A-search.dc.html`） |
| 卡片之间 | 12 |
| 卡片流与提示条之间 | 12 |
| 提示条高 | 24 |
| 提示条各组之间 | 14；单组内 keycap 与文字之间 5 |
| keycap | 最小宽 20、高 20、内距 `0 5px`、圆角 6 |
| 搜索态「N 条结果」行 | 高 18，其下 8 再接卡片流 |

#### 卡片（`card()`，dense）

| 项 | 值 |
| --- | --- |
| 尺寸 | 260 × 184 |
| 内距 | 12 |
| 圆角 | 12 |
| 纵向段间距 | 8 |
| 头部行高 | 18，元素间距 6 |
| 角标（dense） | 高 18、内距 `0 6px 0 5px`、圆角 9、gap 3、字号 10 Semibold、图标 10 |
| 角标（非 dense） | 高 20、内距 `0 7px 0 6px`、圆角 10、gap 4、字号 11、图标 11 |
| 底部来源色行 | 高 20；色点 20 × 20、圆角 5 |
| 悬停动作簇 | 距右 8、距上 8；高 28、内距 `0 3px`、圆角 9、按钮间距 2；按钮 24 × 24、圆角 7、图标 14 stroke 1.5；`blur(14)` |
| 图片缩略图 / 色块 | 占满剩余高，圆角 10 |
| 色值胶囊 | 高 22、内距 `0 8px`、圆角 11、mono 11 Semibold、底 `fill2` |
| 文件堆叠 | 容器 46 × 38；三枚 30 × 30 方块，圆角 7，偏移 `(0,6) / (7,3) / (14,0)` |

卡片状态环（`card()` 的 `sel` 分支）：

| 状态 | 值 |
| --- | --- |
| 默认 | `cring` |
| 选中 · 面板是 key window | `0 0 0 3px #0A84FF` |
| 选中 · 面板失焦 | `0 0 0 3px rgba(10,132,255,0.45)` —— macOS 才有的态 |
| 键盘焦点 | `0 0 0 2px #0A84FF, 0 0 0 7px rgba(10,132,255,0.32)` |
| 拖起 lift | `rotate(-2deg) scale(1.03)` + `cring, 0 12px 32px rgba(0,0,0,0.28)` |

与 iOS 的差异：iOS focused 是 `2px + 5px @.35`，macOS 是 `2px + 7px @.32`；
iOS lift 是 `scale(1.04) rotate(-2deg)`，macOS 是 `rotate(-2deg) scale(1.03)`；
「面板失焦」一态 iOS 没有。

macOS 今天的实际值（本轮全部替换）：`Copyo/Panel/CardView.swift:10–11` 卡片 224 × 268；
`:28` 圆角 12；`:31–32` 选中 3pt `Color.accentColor`、未选中 1pt `Color.primary.opacity(0.1)`；
`:34` 阴影 `radius 6, y 2`，黑色 0.3 / 0.18；`:68` 彩色头部高 42；内容内距 `:103` / `:124` / `:135` / `:172` 均为 10；
`:150` 图片区高 `cardHeight - 42 - 26`；底栏左右内距 10 在 `:196`、高 26 在 `:197`。
面板侧：`Copyo/Panel/PanelRootView.swift:164–165` 顶栏内距 `horizontal 16 / vertical 10`；
`:209` 搜索框固定宽 240、`:210` 圆角 8、`:207–208` 内距 `horizontal 10 / vertical 6`；
`:222` 卡片间距 **14**（定稿是 12）；`:227–228` 卡片流内距 `horizontal 16 / bottom 16`；
`:67` 顶栏上方有一条 1px `Color.primary.opacity(0.12)` 横线（定稿没有）。
`Copyo/Panel/PanelController.swift:15` `panelHeight = 380`、`:79–81` 从 `screen.frame` 取全宽贴底 ——
定稿改为从 `visibleFrame` 内缩浮动、圆角 26。

`CopyoTheme.swift:161–179` 的 `Metrics` 今天给的是 iOS 值（`gridGap 12` / `cardPad 12` / `cardPadDense 10` /
`colorSwatchDense 40` / `thumbnailDense 70` 等），macOS dense 的卡片内距是 12 而非 10，不能直接复用 `cardPadDense`。

### 2.4 字号

`gen2.py:162–170` 的 `typerow` 调用逐字，外加每档在 macOS 今天的对应值：

| 档 | 值 | 用途（设计稿原文） | macOS 今天的对应值与出处 |
| --- | --- | --- | --- |
| 标题 | 17 / 22 Bold | 窗口标题、详情标题 | 无对应。最接近的是 `Copyo/Settings/SettingsView.swift:606` 的 `.font(.system(size: 22, weight: .bold))`（关于页应用名）；面板空态标题是 `Copyo/Panel/PanelRootView.swift:294` 的 13 |
| 副标题 | 13 / 18 Regular | 搜索框、侧栏行 | `Copyo/Panel/PanelRootView.swift:190` 搜索框 `.font(.system(size: 13))` —— **字号已对**；`Copyo/Panel/CardView.swift:115` 链接域名 13 Semibold；`:133` 色值 13 Medium mono |
| 卡片正文 | 12 / 16 Regular | 卡片正文 | `Copyo/Panel/CardView.swift:97` `.font(.system(size: 12))` —— 字号已对，行高未声明；`Copyo/Panel/PanelRootView.swift:174` 是 **Pinboard 标签胶囊**的 12pt（`tabButton()`，选中 Semibold / 未选中 Regular）——注意面板今天**没有类型筛选胶囊**，定稿的筛选行在 Mac 上是新增，规格见 §3.8 |
| 代码正文 | 11 / 15 Medium mono | 代码正文（**Mac 上是新增**） | **Mac 上今天完全不存在。** `Copyo/Panel/CardView.swift:89–105` 的 `textContent` 有**一个**分支，但分的不是等宽：`:91–93` 判 `item.kind == .richText` 且 `rtfData` 能解成 `NSAttributedString` 时，走 `:94` 的 `Text(AttributedString(attributed))`——**不经过** `:97` 的 `.font`，字号由 RTF 自带、不受控；`.text` 与解不出 RTF 的 `.richText` 落到 `:96–97`，一律 `.font(.system(size: 12))`。两条路都**没有等宽分支**。全仓 grep `isCodeLike` 命中 7 处：`CopyoCore/Sources/CopyoCore/ClipItem+Display.swift:21`（定义）、`CopyoCore/Tests/CopyoCoreTests/CopyoCoreTests.swift:307/310/322`（测试）、`CopyoIOS/Model/ClipItem+Display.swift:7`（注释）与 `:97`（`isMono`）、`CopyoWidgets/ClipSnapshot.swift:56` —— `Copyo/` 目录下零引用。`Copyo/` 里出现 `design: .monospaced` 的 7 处全部与代码正文无关：`Copyo/Panel/CardView.swift:133`（颜色条目的色值文本）、`Copyo/Panel/PreviewOverlay.swift:53`（**`.file` 分支里的文件路径行**，12pt mono——预览浮层的正文在 `default:` 分支的 `:70`，是 `.font(.system(size: 13))`，**不等宽**）、`Copyo/Settings/SettingsView.swift:157/398/483/523/548`（设置里的路径与快捷键文本）。所以 `card.mono` 在 Mac 上是**新增功能**，不是改名 |
| 卡片 meta | 10 / 13 Regular | 卡片 meta | `Copyo/Panel/CardView.swift:194` `.font(.system(size: 10))` + `:195` `.foregroundStyle(.secondary)` —— 字号已对，颜色要换成 `label.meta`。注意今天这一行在**卡片底栏**，定稿在**卡片头部行**（`card()` 的 `meta_cell`） |
| 类型角标 | 10 Semibold | 类型角标 | 无对应。今天没有类型角标；`Copyo/Panel/CardView.swift:56` 是彩色头部里的来源应用名 12 Semibold，`:68` 高 42，定稿取消整条彩色头部 |
| 提示条 | 11 Regular + keycap 11 mono | 底部提示条 | 无对应。今天面板没有底部提示条；`Copyo/Panel/PanelRootView.swift:298` 的 11 是空态第三行说明文字，`:137` 的 11 Semibold 是「＋」按钮图标 |

与 iOS 的关系：macOS 是 iOS 的 dense 档。iOS `card.body` = 15/20（dense 13/17），macOS 统一 12/16；
iOS `card.mono` = SF Mono 13/18（dense 11/15），macOS 统一 11/15 Medium ——
即 macOS 的两档正文比 iOS 的 dense 档再小一号（正文）/ 同号（等宽）。
`CopyoTheme.swift:215` `cardBody(dense:)` 返回 `.footnote`（13）/ `.subheadline`（15），
`:217–219` `cardMono(dense:)` 返回 `.caption2`（11）/ `.footnote`（13）—— 两者都没有 12 这一档，
macOS 落地时不能直接复用 `Fonts.cardBody`。

字体族：`gen.py:5` `MONO = "ui-monospace, 'SF Mono', Menlo, monospace"`；
正文族见 `page()` 的 `body` 规则 `-apple-system, "SF Pro Text", "PingFang SC", system-ui, sans-serif`。

macOS 不走 Dynamic Type（`CopyoTheme.swift:183–203` 那段「一律走系统文本样式」的约束是 iOS 侧的），
设计稿给的是死点数；是否要在 macOS 上响应「辅助功能 → 显示 → 文字大小」未定，见第八节第 34 条。

### 2.5 来源淡染

**公式**：`mix(sourceColor, bg.card, 12%)` 浅 / `mix(sourceColor, bg.card, 20%)` 深。
`gen2.py:156` 的板块标题逐字写作「mix(sourceColor, bg.card, 12%) 浅 · 20% 深」。
`bg.card` 按 2.2 (a)：浅 `#FFFFFF`、深 `#2C2C2E`。

混色按 sRGB 分量线性插值，`fraction` 份 source + 其余 base，结果 alpha 恒为 1 ——
实现见 `CopyoShared/UI/CopyoTheme.swift:121–131` 的 `mix(_:into:fraction:)`。

**淡染值**（`gen.py` 的 `SRC` 字典，格式为 `来源 → (来源色, 浅色淡染, 深色淡染)`，逐字）：

| 来源 | 来源色 | 浅色淡染 | 深色淡染 |
| --- | --- | --- | --- |
| Xcode | `#147EFB` | `#E3F0FE` | `#273C57` |
| 微信 | `#07C160` | `#E1F8EC` | `#254A38` |
| Safari | `#1EA7FD` | `#E4F4FF` | `#294457` |
| Figma | `#A259FF` | `#F4EBFF` | `#443558` |
| 备忘录 | `#FFC300` | `#FFF8E0` | `#564A25` |
| VS Code | `#0098FF` | `#E0F3FF` | `#234258` |
| 访达 | `#1EA7FD` | `#E4F4FF` | `#294457` |
| 本机 | `#8E8E93` | `#F1F1F2` | `#404042` |

`Tokens.dc.html` 的「来源淡染」板只展示其中五条（`gen2.py:158–160`）：Xcode、微信、Safari、备忘录、
以及标为「本机 / iOS 来源」的 `#8E8E93`。「访达」与 Safari 共用 `#1EA7FD`，「VS Code」只在 B 版画板出现。

**颜色类条目的例外（`COLORCLIP`）**：

| | 来源色 | 浅色淡染 | 深色淡染 |
| --- | --- | --- | --- |
| `COLORCLIP` | `#FF2D55` | `#FFE6EB` | `#562E36` |

`gen.py` 对该常量的注释原文是「a color clip tints with ITS OWN colour」。
即：`kind == .color` 的条目，淡染与角标底色取**剪贴内容自身的颜色**，不取来源 App 的色。
`gen.py` 的 `card()` 通过 `srccol` 参数实现，`CARDS()` 与 `gen2.py:42` 的 Figma 颜色卡都传了
`tint=(COLORCLIP[2] if th is D else COLORCLIP[1]), srccol=COLORCLIP[0]`——
注意角标底色也一并换成了 `#FF2D55`，而不是 Figma 的 `#A259FF`。
`gen2.py:157` 的说明逐字：「颜色类条目取剪贴内容本身的颜色，不取来源 App —— 这是相对 iOS 的一处修订。」

**角标文字色规则（`onband`）**：

```
lum = (0.299·R + 0.587·G + 0.114·B) / 255
lum > 0.62  →  #16161A
否则        →  #FFFFFF
```

权重 `0.299 / 0.587 / 0.114`，R/G/B 取 0–255。
上表八个来源色中，只有「备忘录」`#FFC300` 的亮度超过 0.62，角标文字取 `#16161A`，其余七个取 `#FFFFFF`。
`onband` 同时用于设置页的图标砖字色 / 图标色（`gen2.py:184–185` 的 `tile()`）与 B 版侧栏分类点。

**与 iOS 的两处不一致**：

1. 深色混色基底从 `#1C1C1E` 变为 `#2C2C2E`（见 2.2 (a)）。`CopyoTheme.swift:113` 要同步。
2. 亮色带上的文字色，macOS 定稿是不透明 `#16161A`，iOS 规格与 `CopyoTheme.swift:138`
   （`UIColor(white: 0, alpha: 0.78)`）是 78% 黑。阈值 0.62 与权重两端相同。

**macOS 今天的来源色从哪来**：`Copyo/Panel/CardView.swift:48` 调用
`AppIconProvider.headerColor(forBundleID:)`，实现在 `Copyo/Services/AppIconProvider.swift:26–65`：
对应用图标做 12 × 12 粗粒度采样求平均色，跳过 alpha ≤ 0.5 与亮度 > 0.92 / < 0.08 的像素，
再按 HSB 提饱和降亮（`saturation * 1.25 + 0.08`，`brightness` 夹在 `max(0.35, brightness * 0.85)` 与 `0.75` 之间）；
取不到时回退 `:10` 的 `fallbackColor = NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1)`。
`Copyo/Panel/CardView.swift:39–49` 里 `.color` 条目已经优先取内容自身颜色，与本节的 `COLORCLIP` 例外方向一致。
**注意回退色不一致**：`fallbackColor` 走的是 `calibratedRed:`，即 `NSCalibratedRGBColorSpace`（Generic RGB，gamma 1.8），
**不是 sRGB**；分量直接 ×255 得到的 `#6B7A94` 是错的。
按 `Copyo/Services/NSColor+Hex.swift:9` 的 `srgbHexString`（`usingColorSpace(.sRGB)` 后交给
`CopyoCore/Sources/CopyoCore/Color+Hex.swift:31–36` 的 `HexColor.string`，通道取 `(v * 255).rounded()`）**实测**：

```
NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1).usingColorSpace(.sRGB)
  → (0.493993, 0.555688, 0.646518)  →  #7E8EA5
```

（在 macOS 27.0 / Darwin 27.0.0 上跑 `swift` 实测；Generic RGB 是系统内置色彩空间，与显示器配置无关。
此值可用于销掉第八节第 30 条里「转到 sRGB 后的确切 hex 需要实测」那一问。）

所以真正的冲突是 `#7E8EA5` vs 规格要求的 `source.local` = `#8E8E93`（`CopyoTheme.swift:104`），**两端必须同一个**。

### 本章待确认

> 本章相关的待确认条目：见第八节第 29、30、32、33、34、45 条。

---

## 三、组件规格

本节数值逐字取自 `art/macos-design/2026-09-20/gen.py`（面板与卡片）与 `gen2.py`（组件板、Token 板、设置），
并与生成出的 `*.dc.html` 画板核对。设计稿里没有的值不在此文档中，含糊之处集中在第八节。

命名约定：`th[...]` 指主题字典 `L`（浅）/ `D`（深）里的键；`MONO` = `ui-monospace, 'SF Mono', Menlo, monospace`；
`accent` = `#0A84FF`。下表出现的 px 值在实现里即 pt。

---

### 3.1 ClipCard · dense

来源：`gen.py` `card()` / `body_*()`；组件板 `Card.dc.html`（1760 × 1180）。

**容器**

| 属性 | 值 |
| --- | --- |
| 尺寸 | 260 × 184（`w=260, h=184`，`flex: none`，`box-sizing: border-box`） |
| 内距 | 12（四边） |
| 圆角 | 12 continuous（组件板标题原文「圆角 12 continuous」） |
| 背景 | 来源淡染色 `tint`（浅 = `SRC[src][1]`，深 = `SRC[src][2]`） |
| 描边 | `th["cring"]`：浅 `inset 0 0 0 0.5px rgba(0,0,0,0.05)` / 深 `inset 0 0 0 0.5px rgba(255,255,255,0.06)` |
| 布局 | `display: flex; flex-direction: column; gap: 8px`（头行 / 正文 / 底行三段的列间距 = 8） |
| 定位 | `position: relative`（供悬停动作簇绝对定位） |
| 卡片之间 | 面板轨道 `track()` 的 `gap: 12px`，轨道高 184，`overflow: hidden` |

**头行**（高 18，`display: flex; align-items: center; gap: 6px`）

| 元素 | 值 |
| --- | --- |
| 类型角标 | 见 3.3，`flex: none` |
| meta | `flex-grow: 1; min-width: 0`，10pt，色 `th["meta"]`，`white-space: nowrap; overflow: hidden; text-overflow: ellipsis`；文案格式「来源 · 相对时间」。**截断方向不照画板做**，见 3.3「meta 截断规则」 |
| 已固定图钉 | 仅 `pinned` 时出现，`flex: none`，`PIN_I` 线图标 11pt、线宽 1.6、色 `accent`，`aria-label="已固定"` |

**正文区**（`flex-grow: 1; min-height: 0`，六种渲染方式）

| 类型 | 函数 | 渲染 |
| --- | --- | --- |
| 文本 | `body_text(th, txt, clamp=7)` | 12 / 16，色 `th["label"]`，`white-space: pre-line`，`overflow: hidden` + `-webkit-box` + `-webkit-line-clamp: 7` + `-webkit-box-orient: vertical`，`word-break: break-word` |
| 文本 · 等宽 | `body_text(..., mono=True)` | 同上，改 `font-family: MONO; font-size: 11px; line-height: 15px`（`body_text` 未设 font-weight） |
| 富文本 | 与「文本」同一函数 | 正文渲染完全等同文本；区别只在角标文字为「富文本」、`kind="rich"` |
| 链接 | `body_link(th, title, dom)` | 外层 `flex-direction: column; gap: 6px; overflow: hidden`；标题 12 / 16、`font-weight: 500`、色 `th["label"]`、`line-clamp: 3`；域名 11 / 15、色 `accent`、`nowrap` + 省略号 |
| 颜色 | `body_color(th, hexv)` | 外层 `flex-direction: column; gap: 8px`；色块 `flex-grow: 1`、圆角 10、背景 = 色值、`box-shadow: th["swatchring"]`；色值胶囊 `align-self: flex-start`、高 22、内距 `0 8px`、圆角 11、底 `th["fill2"]`、`MONO` 11pt `font-weight: 600`、色 `th["label"]`、文案 = 大写 hex |
| 图片 | `body_image(th, fill)` | `flex-grow: 1; min-height: 0`、圆角 10、背景 = 缩略图、`box-shadow: th["swatchring"]`。样例填充浅 `#F0E4BE` / 深 `#4A431F` |
| 文件 | `body_files(th, first, more)` | 外层 `flex-direction: column; gap: 8px`；顶部堆叠块 46 × 38 `position: relative`，内含三枚 30 × 30 圆角 7 方片，左 / 上依次 `(0, 6)`、`(7, 3)`、`(14, 0)`，前两枚底 `th["fill2"]`、第三枚底 `#1EA7FD`，三枚均带 `th["swatchring"]`；文件名 12 / 16 色 `th["label"]`、`line-clamp: 2`、`word-break: break-all`；计数行 11pt 色 `th["meta"]`（样例「另外 4 个文件」） |

**底行**（高 20，`display: flex; align-items: center; justify-content: flex-end`）

- 右对齐来源图标位：20 × 20、圆角 5、背景 = 来源实色 `SRC[src][0]`、`box-shadow: th["swatchring"]`。

**来源色与淡染**（`SRC`，值为 `(实色, 浅淡染, 深淡染)`）

| 来源 | 实色 | 浅淡染 | 深淡染 | `onband()` 前景 |
| --- | --- | --- | --- | --- |
| Xcode | `#147EFB` | `#E3F0FE` | `#273C57` | `#FFFFFF` |
| 微信 | `#07C160` | `#E1F8EC` | `#254A38` | `#FFFFFF` |
| Safari | `#1EA7FD` | `#E4F4FF` | `#294457` | `#FFFFFF` |
| Figma | `#A259FF` | `#F4EBFF` | `#443558` | `#FFFFFF` |
| 备忘录 | `#FFC300` | `#FFF8E0` | `#564A25` | `#16161A` |
| VS Code | `#0098FF` | `#E0F3FF` | `#234258` | `#FFFFFF` |
| 访达 | `#1EA7FD` | `#E4F4FF` | `#294457` | `#FFFFFF` |
| 本机 | `#8E8E93` | `#F1F1F2` | `#404042` | `#FFFFFF` |

无匹配来源时回退 `("#8E8E93", "#F1F1F2", "#404042")`（`card()` 的 `SRC.get` 默认值）。

**颜色类条目的例外**：`COLORCLIP = ("#FF2D55", "#FFE6EB", "#562E36")`。颜色条目的实色（角标底、底行来源图标）
与淡染均取剪贴内容自身的颜色，不取来源 App 的色。`gen.py` 里通过 `card(..., tint=..., srccol=COLORCLIP[0])` 覆盖。

---

### 3.2 卡片状态

来源：`gen.py` `card()` 的 `sel` / `hover` / `pinned` 分支；`gen2.py` `state_row()`。
`sel` 取值为 `None` / `"select"` / `"key-inactive"` / `"focus"` / `"lift"`。

| 状态 | `sel` | `box-shadow` | 其他 |
| --- | --- | --- | --- |
| 默认 | `None` | `th["cring"]` | —— |
| 悬停 | `hover=True` | `th["cring"]`（不变） | 右上角出现玻璃动作簇，见 3.4 |
| 选中 · 面板是 key window | `"select"` | `0 0 0 3px #0A84FF` | 环替换 `cring`，不叠加 |
| 选中 · 面板失焦 | `"key-inactive"` | `0 0 0 3px rgba(10,132,255,0.45)` | **macOS 才有的态，iOS 规格没有** |
| 键盘焦点 | `"focus"` | `0 0 0 2px #0A84FF, 0 0 0 7px rgba(10,132,255,0.32)` | 外圈 7pt 扩散，即 accent 环外再露出 5pt 光晕 |
| 拖起 | `"lift"` | `th["cring"], 0 12px 32px rgba(0,0,0,0.28)` | `transform: rotate(-2deg) scale(1.03)`；组件板上与 `pinned=True` 同时出现 |

`select` / `key-inactive` / `focus` 三态里 `cring` 被整体替换，卡片的 0.5px 内描边在这三态下不再绘制。

---

### 3.3 类型角标 KindBadge

来源：`gen.py` `badge(kind, bg, dense=True)`。底色 = 来源实色 `bg`，前景 = `onband(bg)`。

| 属性 | dense（面板 / 卡片） | regular |
| --- | --- | --- |
| 高 | 18 | 20 |
| 圆角 | 9 | 10 |
| 内距 | `0 6px 0 5px` | `0 7px 0 6px` |
| 图标与文字间距 | 3 | 4 |
| 字号 / 字重 | 10pt / 600 | 11pt / 600 |
| 图标尺寸 | 10 | 11 |
| 其他 | `display: inline-flex; align-items: center; white-space: nowrap; flex: none` | 同左 |

**前景色规则 `onband(hex)`**：`lum = (0.299R + 0.587G + 0.114B) / 255`；`lum > 0.62` 取 `#16161A`，否则取 `#FFFFFF`。
现有来源色中只有 `备忘录 #FFC300`（lum ≈ 0.748）与设置里的 `#FF9F0A`（lum ≈ 0.670）落在深字一侧。

**六种类型**（`ICON` 字典：中文标签 + 线图标；线图标 `stroke-width 1.7`、`stroke-linecap/linejoin: round`、`viewBox 0 0 16 16`）

| kind | 中文标签 | 图标绘制 |
| --- | --- | --- |
| `text` | 文本 | 描边 |
| `rich` | 富文本 | 描边 |
| `link` | 链接 | 描边 |
| `image` | 图片 | 描边 |
| `color` | 颜色 | **填充**（`filled = True`，用 `fill` 而非 `stroke`） |
| `file` | 文件 | 描边 |

**中文最紧的情形**（`gen2.py` `tight_row()` 第一张卡，`Card.dc.html`「排版最紧的几种情况」一行）

样例：`kind="rich"`、来源 `备忘录`（实色 `#FFC300`、淡染 `#FFF8E0`）、meta 文案「Microsoft Word · 昨天 18:42」。

| 量 | 计算 | 值 |
| --- | --- | --- |
| 卡内可用宽 | 260 − 12 × 2 | 236 |
| 「富文本」角标固有宽 | 5（左内距）+ 10（图标）+ 3（gap）+ 30（3 个全角字 × 10pt）+ 6（右内距） | 54 |
| 两字角标固有宽（文本 / 链接 / 图片 / 颜色 / 文件） | 5 + 10 + 3 + 20 + 6 | 44 |
| 头行 gap | `gap: 6px` | 6 |
| 「富文本」时 meta 可用宽 | 236 − 54 − 6 | **176** |
| 两字角标时 meta 可用宽 | 236 − 44 − 6 | **186** |
| 同时带已固定图钉时再扣 | gap 6 + 图钉 11 | −17（分别为 159 / 169） |

**meta 截断规则（题注与画板自相矛盾，实现按题注的目标行为做）**

先说画板**实际**是什么：`gen.py:137-138` 的 `meta_cell` 是**单个** `<span>`，整串「来源 · 相对时间」套一层
`flex-grow: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis`，
角标与图钉都是 `flex: none`。CSS 的 `text-overflow: ellipsis` 只能从**尾部**截，
所以画板上宽度不够时被吃掉的是**时间**（「Microsoft Word · 昨天 18…」），不是来源名。

再说题注写的是什么：`gen2.py:66` 的题注原文是「meta 行省略号从来源名开始吃，时间永不被截」——
方向与画板渲染**正好相反**。

裁定：**题注表达的是目标行为，画板本身做不到**（单 span + 尾部省略号这套结构不可能从头部截）。
本规格取题注的目标行为为准，画板此处视为生成脚本的表达力限制，不作为实现依据。
实现方**不要照画板的截断方向做**。

SwiftUI 落地方式：meta 行拆成两段，放进一个 `HStack(spacing: 0)`——

| 段 | 内容 | 布局 |
| --- | --- | --- |
| 来源名段 | 来源 App 名 | `.lineLimit(1)` + `.truncationMode(.tail)`，`.layoutPriority(0)`——独占截断 |
| 时间段 | `· ` + 相对时间 | `.lineLimit(1)` + `.fixedSize(horizontal: true, vertical: false)`，`.layoutPriority(1)`——不可压缩，永不被截 |

即：时间段 `layoutPriority` 高于来源名段，且用 `fixedSize` 锁住固有宽；剩余宽度全部给来源名段，
省略号只出现在来源名的尾部（「Microsoft Wo… · 昨天 18:42」）。
两段的字号、字色与画板一致（10pt、`th["meta"]`）。

截断阈值与最小缩放比设计稿未给，见第八节第 37 条。

**同卡的宽松对照**：meta 改为「Word · 昨天」即不触发截断（`tight_row()` 第二张）。

**无来源色回退**：`tight_row()` 第三张，来源「本机」，实色 `#8E8E93`、淡染 `#F1F1F2`、前景 `#FFFFFF`；
文案「这条是 iPhone 上存进来的，没有来源色，回退到中性灰 #8E8E93。」——即 iOS 存进来的条目在 Mac 上的表现。

**等宽长行**：`tight_row()` 第四张，`body_text(..., 7, True)` + `word-break: break-word`，长行按词断、不横向滚动。

---

### 3.4 悬停动作簇

来源：`gen.py` `card(..., hover=True)` 分支。

| 属性 | 值 |
| --- | --- |
| 定位 | `position: absolute; right: 8px; top: 8px` |
| 布局 | `display: flex; align-items: center; gap: 2px` |
| 高 | 28 |
| 内距 | `0 3px` |
| 圆角 | 9 |
| 背景 | `th["glass"]`：浅 `rgba(255,255,255,0.74)` / 深 `rgba(58,58,60,0.72)` |
| 模糊 | `backdrop-filter: blur(14px)`（含 `-webkit-` 前缀） |
| 阴影 | `th["ring"], 0 2px 8px rgba(0,0,0,0.14)`；`ring` 浅 `inset 0 0 0 0.5px rgba(0,0,0,0.06)` / 深 `inset 0 0 0 0.5px rgba(255,255,255,0.15)` |

**两枚图标按钮**：各 24 × 24、圆角 7、`display: flex; align-items: center; justify-content: center`。

| 按钮 | `aria-label` | 图标 | 尺寸 / 线宽 | 色 |
| --- | --- | --- | --- | --- |
| 固定 | 固定到 Pinboard | `PIN_I` | 14 / 1.5 | `accent` `#0A84FF` |
| 删除 | 删除 | `TRASH_I` | 14 / 1.5 | 浅 `#FF3B30` / 深 `#FF453A` |

动作簇只有固定与删除两枚，没有第三枚。

---

### 3.5 轻提示 Toast

来源：`A-hover-toast.dc.html` 里的 `toast` 块（`gen.py` 第 3 节）。

| 属性 | 值 |
| --- | --- |
| 高 | 36 |
| 内距 | `0 16px` |
| 圆角 | 18 |
| 图标与文字间距 | `gap: 7px` |
| 背景 | `th["glass"]`（浅 `rgba(255,255,255,0.74)`） |
| 模糊 | `backdrop-filter: blur(20px)` |
| 阴影 | `th["ring"], 0 6px 20px rgba(0,0,0,0.18)` |
| 字号 / 字重 | 13pt / 500（Medium） |
| 文字色 | `th["label"]` |
| 图标 | `CHECK_I` 对勾，14pt、线宽 2、色 `success`（浅 `#34C759` / 深 `#30D158`） |
| 水平定位 | `left: 50%; transform: translateX(-50%)`——与面板同一中线（画板 1360 宽、面板左 40 宽 1280，两者中线均为 x = 680） |
| 垂直定位 | 画板内 `bottom: 60px` |
| 文案 | `已复制 · 按 ⌘V 粘贴` |

**文案约束**：面板内任何位置都不得出现形似「粘贴按钮」的控件或措辞；toast 只陈述「按 ⌘V 粘贴」这一由用户自己完成的动作。

---

### 3.6 KeyCap

来源：`gen.py` `keycap(t, th)`。

| 属性 | 值 |
| --- | --- |
| 最小宽 | 20（`min-width: 20px`） |
| 高 | 20 |
| 内距 | `0 5px` |
| 盒模型 | `box-sizing: border-box` |
| 圆角 | 6 |
| 背景 | `th["fill2"]`：浅 `rgba(118,118,128,0.20)` / 深 `rgba(118,118,128,0.32)` |
| 字体 | `MONO`，11pt，`font-weight: 500` |
| 前景 | `th["meta"]`：浅 `rgba(60,60,67,0.78)` / 深 `rgba(235,235,245,0.72)` |
| 布局 | `display: inline-flex; align-items: center; justify-content: center` |

**全部用到的字符**

| 字符 | 出现处 |
| --- | --- |
| `↩` | 底部提示条、设置 · 快捷键（复制选中项） |
| `⇧↩` | 设置 · 快捷键（纯文本复制） |
| `空格` | 底部提示条、设置 · 快捷键（预览） |
| `⌘P` | 底部提示条、设置 · 快捷键（固定到 Pinboard） |
| `⌘⌫` | 底部提示条、设置 · 快捷键（删除） |
| `⌘F` | 设置 · 快捷键（聚焦搜索） |
| `⇥` | 设置 · 快捷键（在筛选间循环） |
| `⌘1–9` | 设置 · 快捷键（直接取第 N 张卡） |
| `esc` | 设置 · 快捷键（关闭面板） |
| `⇧⌘V` | 空态提示行（唤出面板；设置 · 唤出一栏用的是 3.12 的录制器，不是 keycap） |

---

### 3.7 底部提示条

来源：`gen.py` `hintbar(th, right=...)` 与 `hint(cap, text, th)`。

| 属性 | 值 |
| --- | --- |
| 高 | 24 |
| 布局 | `display: flex; align-items: center; gap: 14px` |
| 单项内部 | `display: inline-flex; align-items: center; gap: 5px`，keycap + 11pt 文字，文字色 `th["sec"]`（浅 `rgba(60,60,67,0.60)` / 深 `rgba(235,235,245,0.60)`） |
| 左右分隔 | 四项之后一个 `flex-grow: 1` 的弹性空白 |
| 右侧说明 | 11pt，色 `th["sec"]` |

**四项**（顺序固定）

| 次序 | keycap | 文字 |
| --- | --- | --- |
| 1 | `↩` | 复制 |
| 2 | `空格` | 预览 |
| 3 | `⌘P` | 固定 |
| 4 | `⌘⌫` | 删除 |

**右侧文案**

| 面板状态 | 文案 |
| --- | --- |
| 主态（默认，`hintbar()` 的默认参数） | `复制后回到原来的 App，按 ⌘V 粘贴` |
| 搜索态（`A-search.dc.html`） | `Esc 清空搜索 · 再按一次关闭面板` |
| 空态（`A-empty.dc.html`） | `Esc 关闭` |

---

### 3.8 搜索框与筛选胶囊

来源：`gen.py` `topbar(th, query=None, active="全部", showchips=True)` 与 `chip(text, th, on, chev)`。

**第一行**（`display: flex; align-items: center; gap: 8px; height: 32px`）

| 元素 | 值 |
| --- | --- |
| 搜索框 | `flex-grow: 1`，高 32，内距 `0 10px`，圆角 8，底 `th["fill"]`（浅 `rgba(118,118,128,0.12)` / 深 `rgba(118,118,128,0.24)`），`display: flex; align-items: center; gap: 6px`，`box-sizing: border-box` |
| 放大镜 | `SEARCH_I`，14pt、线宽 1.6、色 `th["sec"]` |
| 输入 | 13pt，色 `th["label"]`，占位文案 `搜索历史`，无边框无 outline；可访问名同为 `搜索历史`（视觉隐藏的 `<label>`） |
| 聚焦环 | `box-shadow: 0 0 0 2px #0A84FF, 0 0 0 6px rgba(10,132,255,0.28)` |
| 输入光标（画板示意） | 1.5 × 15，`margin-left: 1px`，`vertical-align: -3px`，背景 `accent` |
| iCloud 状态按钮 | 32 × 32，圆角 8，`CLOUD_OK_I` 17pt、线宽 1.5、色 `success`（浅 `#34C759` / 深 `#30D158`），`aria-label` / `title` = `iCloud 已同步` |
| 设置按钮 | 32 × 32，圆角 8，`GEAR_I` 17pt、线宽 1.5、色 `th["sec"]`，`aria-label` / `title` = `设置` |

**第二行**：与第一行之间固定 10pt 空白（`<div style="height: 10px">`）；本行 `height: 26px; gap: 8px`，
左侧筛选组 `display: flex; gap: 6px; flex-grow: 1`，右侧单独一枚 Pinboard 下拉胶囊。

**筛选胶囊 `chip()`**

| 属性 | 值 |
| --- | --- |
| 高 | 26 |
| 圆角 | 8 |
| 内距 | `0 11px`（带 chevron 时 `0 9px 0 11px`） |
| 内部 gap | 5 |
| 字号 | 12pt |
| 选中 | 底 `#0A84FF`，字 `#FFFFFF`，`font-weight: 600` |
| 未选中 | 底 `th["fill"]`，字 `th["label"]`，`font-weight: 500` |
| chevron | `CHEV_I`，11pt、线宽 1.8、色 `th["sec"]` |

**六项固定顺序**：`全部` `文本` `链接` `图片` `颜色` `文件`。富文本并入「文本」筛选，但卡片角标仍显示「富文本」。
右侧独立胶囊文案 `Pinboard`，带 chevron。

**搜索结果计数行**（`A-search.dc.html`）：位于 topbar 下方 12pt，高 18，`display: flex; align-items: center; gap: 8px`，
文字 11pt、色 `th["meta"]`，文案格式 `N 条结果`（样例 `2 条结果`）；其下 8pt 空白后接卡片轨道（该帧轨道高 158）。
搜索命中高亮：`background: rgba(10,132,255,0.22); color: inherit; border-radius: 3px; padding: 0 1px`。

---

### 3.9 面板外壳

来源：`gen.py:234-238` `panel(th, inner, w=1280, h=332)`。

| 属性 | 值 |
| --- | --- |
| 尺寸 | 1280 × 332，`box-sizing: border-box` |
| 内距 | 16（四边） |
| 圆角 | 26 |
| 背景 | `th["glass"]`：浅 `rgba(255,255,255,0.74)` / 深 `rgba(58,58,60,0.72)` |
| 模糊 | `backdrop-filter: blur(24px)`（含 `-webkit-` 前缀） |
| 阴影 | `<ring>, 0 1px 3px rgba(0,0,0,0.10), 0 24px 56px rgba(0,0,0,0.30)` |
| `<ring>` 浅 | `inset 0 0 0 0.5px rgba(0,0,0,0.06)` |
| `<ring>` 深 | `inset 0 0 0 0.5px rgba(255,255,255,0.15)` |
| 布局 | `display: flex; flex-direction: column` |

**内部竖向节奏**（内距后可用高 300）

| 帧 | 组成 | 合计 |
| --- | --- | --- |
| 主态（`Main.dc.html` / `A-panel-dark.dc.html`） | topbar 68（32 + 10 + 26）+ 12 + 轨道 184 + 12 + 提示条 24 | 300 |
| 搜索态（`A-search.dc.html`） | topbar 68 + 12 + 计数行 18 + 8 + 轨道 158 + 12 + 提示条 24 | 300 |
| 空态（`A-empty.dc.html`） | topbar 32（`showchips=False`，仅第一行）+ 12 + 空态块 222 + 12 + 提示条 24 | 302 |

**定位规则**

> 此前草稿此处写作「定位规则（A 版定稿）」，给出了宽 `min(visibleFrame.width − 48, 1280)`、底边内缩 24 等数值。
> 经核对：`gen.py` / `gen2.py` **全文没有 `visibleFrame`、没有 48、没有 24**（`grep` 零命中）。
> 那不是设计稿的规则，是规格自造的。此处已撤销「定稿」字样，按有无出处重新分列。

**有出处的部分**（数值来自 `gen.py:234` `panel(th, inner, w=1280, h=332)`，选屏来自现有实现）

| 项 | 规则 | 出处 |
| --- | --- | --- |
| 宽 | 1280 | `gen.py:234` `panel()` 形参默认值 `w=1280`；A 版全部帧均按此宽生成 |
| 高 | 332 | 同上，`h=332` |
| 圆角 | 26，四角全圆 | `gen.py:235` `border-radius: 26px` |
| 背景 | `th["glass"]` + `backdrop-filter: blur(24px)` | `gen.py:236` |
| 阴影 | `<ring>, 0 1px 3px rgba(0,0,0,0.10), 0 24px 56px rgba(0,0,0,0.30)`（三段） | `gen.py:237` |
| 形态 | **浮动窗**——四角全圆、带 24/56 的落地大阴影，说明它不贴屏幕任一边 | 由上两行推出；画板 `desktop_frame()` 亦把面板画在离底边有距离处 |
| 定位基准 | `visibleFrame`（排除菜单栏与 Dock 的可用区），**不是** `screen.frame` | 工程约束：贴 `frame` 会压在 Dock 下面，见下方差距表第 79–82 行 |
| 选屏 | `screenWithMouse()`，鼠标所在屏幕 | `Copyo/Panel/PanelController.swift:76`、`:130-133`（现有实现，本规格保留） |

**Cocoa 坐标系提示**：`NSScreen` 的坐标原点在**左下**，`visibleFrame.maxY` 是可用区的**上沿**，
底边是 `visibleFrame.minY`。「面板底边距可用区底边 N」写成代码是 `y = visibleFrame.minY + N`。
（此前草稿把 `maxY` 括注成「底边」，是坐标系错误，已改。）

**没有出处、待拍板的部分**

| 项 | 草稿曾写的值 | 现状 |
| --- | --- | --- |
| 横向内缩量（宽度上限公式里的 `− 48`） | `min(visibleFrame.width − 48, 1280)` | **本规格规定，设计稿未画**——48 在 `gen.py` / `gen2.py` 中不存在。画板上唯一的横向留白来自 `gen.py:254` `desktop_frame(..., px=80, py=92)`，即 1440 画布上左右各 80，那是**展示构图**，不是布局规则，不可直接换算成 48。见第八节第 1 条 |
| 底边内缩量（`24`） | 从可用区底边向上内缩 24 | **本规格规定，设计稿未画**——`gen.py` 里没有写下 24 这个定位参数。但画板构图上量得出一个 24：`desktop_frame(w=1440, h=520, px=80, py=92)` 里面板底边在 y = 92 + 332 = 424，装饰用的 Dock 矩形上沿在 y = 520 − 72 = 448，两者差 **24**。这只是**构图量出来的**，且基准是画板上那块装饰 Dock、不是真实的 `visibleFrame`，不能当成规则定稿。见第八节第 1 条 |
| 水平位置 | 在 `visibleFrame` 内水平居中 | **本规格规定，设计稿未画**。画板上面板左 80、右 80（1440 − 80 − 1280 = 80）确实居中，但那是构图巧合，多显示器与窄屏下的行为未定。见第八节第 1 条 |
| 窄屏 / 超宽屏行为 | —— | 可用区宽不足 1280 时如何退让、6K 上是锁 1280 还是按比例放大，设计稿未画。见第八节第 1 条 |

**禁止**把上表四项当作定稿实现。拍板前实现方应向设计方索取数值，不要从 `px=80` 反推。

**与今天实现的差距**（`/Users/alanyuan/Projects/copyo/Copyo/Panel/PanelController.swift`，工作区当前文件）

| 行 | 今天的做法 | 本规格要求 |
| --- | --- | --- |
| 15 | `static let panelHeight: CGFloat = 380` | 332 |
| 76 | `let screen = screenWithMouse() ?? NSScreen.main` | 保留 |
| 79–82 | `NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: height)`——**用的是 `screen.frame`**，贴满整屏宽、紧贴屏幕物理底边（Cocoa 原点在左下，`frame.minY` 即屏幕物理底边），会压在 Dock 下面 | 定位基准换成 `screen.visibleFrame`，宽 1280、做成离底浮动窗。**具体的横向上限公式、底边内缩量与水平对齐方式尚未拍板**（见上方「没有出处、待拍板的部分」与第八节第 1 条），此格不给数 |
| 83、101 | 出场 / 收起都是整屏高位移的滑入滑出 | 位移量随新的面板高度 332 调整 |
| 130–133 | `screenWithMouse()` 用 `NSMouseInRect(mouseLocation, $0.frame, false)` 命中屏幕——命中判定用 `frame` 是对的 | 保留；只有**布局**换成 `visibleFrame` |

面板仍为 `.borderless` + `.nonactivatingPanel` 的 `SlidePanel`（`canBecomeKey == true`），
`level = .statusBar`，`isOpaque = false`，`backgroundColor = .clear`（第 7–10、30、36–39 行），这些不变。

---

### 3.10 空态插画

来源：`A-empty.dc.html` 的 `plate` 块（`gen.py` 第 5 节）。整块 `position: relative; width: 96px; height: 96px; flex: none`，
内部全部绝对定位（`left` / `top` 相对插画左上角）。

| 层 | left | top | 宽 × 高 | 圆角 | 填充 | 其他 |
| --- | --- | --- | --- | --- | --- | --- |
| 骨白底板 | 0 | 0 | 96 × 96 | 22 | `#F7F3EA`（`brand.bone`） | `box-shadow: 0 8px 24px rgba(0,0,0,0.12)` |
| 红条 | 20 | 24 | 52 × 8 | 2 | `#FF2D55`（`brand.red`） | `opacity: 0.9` |
| 蓝条 | 24 | 28 | 52 × 8 | 2 | `#0A84FF`（`accent`） | `opacity: 0.85`，`mix-blend-mode: multiply` |
| 内容条 1 | 22 | 52 | 36 × 8 | 4 | `#16161A` | —— |
| 内容条 2 | 22 | 64 | 52 × 8 | 4 | `#16161A` | —— |
| 内容条 3 | 22 | 76 | 24 × 8 | 4 | `#16161A` | —— |

**空态整块**（面板内高 222，`display: flex; flex-direction: column`）

| 元素 | 值 |
| --- | --- |
| 外层 | `flex-grow: 1; display: flex; align-items: center; justify-content: center; gap: 24px`（插画与文字块横向并排） |
| 文字块 | `flex-direction: column; gap: 6px; max-width: 420px` |
| 标题 | 17pt / 700，色 `th["label"]`，文案 `还没有内容` |
| 正文 | 12 / 17，色 `th["meta"]`，文案 `复制任何东西，它都会出现在这里。Copyo 在后台自动记录，不需要你做任何事。` |
| 提示行 | `margin-top: 6px`，`gap: 6px`，11pt，色 `th["sec"]`，keycap `⇧⌘V` + 文案 `随时按 ⇧⌘V 唤出这个面板` |

空态帧的 topbar 隐藏筛选胶囊行（`showchips=False`），底部提示条右侧文案为 `Esc 关闭`。

---

### 3.11 设置行与彩色图标砖

来源：`gen2.py` `srow()` / `tile()` / `group()` / `seg()` / `toggle()` / `win()`；画板 `Settings.dc.html`（1240 × 600）。

**设置窗 `win(th, tab, content, w=540, h=460)`**

| 部位 | 值 |
| --- | --- |
| 窗口 | 540 × 460，圆角 11，`overflow: hidden`，底 `th["grouped"]`，`box-shadow: 0 0 0 0.5px rgba(0,0,0,0.2), 0 24px 56px rgba(0,0,0,0.34)` |
| 标题栏 | 高 38，内距 `0 14px`，`gap: 12`，底 `th["glass"]`，`border-bottom: 0.5px solid th["sep"]` |
| 红绿灯 | 三枚 12 × 12 圆角 6，`gap: 8`；关闭 `#FF5F57`，另两枚 `rgba(118,118,128,0.3)` |
| 标题文字 | 13pt / 600，色 `th["label"]`，`text-align: center` + `margin-left: -56px`（抵消红绿灯宽度以居中） |
| 分段区 | `padding: 12px 16px 4px`，居中 |
| 内容区 | `padding: 12px 16px 16px`，`display: flex; flex-direction: column; gap: 14px`，`overflow: hidden` |

**分段控件 `seg(items, active)`**

| 属性 | 值 |
| --- | --- |
| 容器 | `display: inline-flex; gap: 2px; padding: 3px`，圆角 8，底 `fill` |
| 每段 | 高 24，内距 `0 12px`，圆角 6，字号 12pt，字色 `label`（选中与否同色） |
| 选中 | `font-weight: 600`，底 `bg.card`，`box-shadow: 0 1px 2px rgba(0,0,0,0.12)` |
| 未选中 | `font-weight: 400`，底 `transparent`，无阴影 |
| 五项 | `通用` `同步` `快捷键` `历史` `关于` |

**分组 `group(th, rows)`**：圆角 10，`overflow: hidden`，底 `th["card"]`，`box-shadow: th["cring"]`。
分组标题走 `h2()`：11pt / 600、`letter-spacing: 0.4px`、色 `th["sec"]`、高 20；可带副标（11pt / 400、色 `th["ter"]`、`margin-left: 8px`）。
分组脚注走 `note()`：11 / 16，色 `th["meta"]`。

**设置行 `srow()`**

| 属性 | 值 |
| --- | --- |
| 最小高 | 40（`min-height: 40px`） |
| 内距 | `7px 12px` |
| 布局 | `display: flex; align-items: center; gap: 10px`，`box-sizing: border-box` |
| 分隔线 | `border-bottom: 0.5px solid th["sep"]`；组内最后一行 `last=True` 时无线 |
| 主文 | 13pt，色 `th["label"]` |
| 副文 | 10 / 14，色 `th["ter"]`，`margin-top: 1px` |
| 文字列 | `flex-grow: 1; min-width: 0` |
| 右值 | 12pt，色 `th["meta"]` |

**彩色图标砖 `tile(color, inner=None, glyph=None)`**

| 属性 | 值 |
| --- | --- |
| 尺寸 | 26 × 26，`flex: none` |
| 圆角 | 7 |
| 背景 | 指定实色 |
| 线图标形式 | `stroke(inner, onband(color), 15, 1.6)`——15pt、线宽 1.6、色 `onband(底色)` |
| 字形形式 | `MONO` 13pt / 600，色 `onband(底色)` |
| 布局 | `display: flex; align-items: center; justify-content: center` |

`TILE` 配色表（`gen2.py` 顶部声明）

| 键 | 底色 | 图标 |
| --- | --- | --- |
| `sync` | `#0A84FF` | `CLOUD_OK_I` |
| `key` | `#5856D6` | 无（用字形） |
| `hist` | `#FF9F0A` | `CLIP_I` |
| `start` | `#34C759` | 无 |
| `priv` | `#8E8E93` | 无 |
| `about` | `#30B0C7` | 无 |
| `danger` | `#FF3B30` | `TRASH_I` |

「通用」页实际使用的图标砖

| 行 | 图标砖 |
| --- | --- |
| 登录时启动 Copyo | `#34C759` + `CHECK_I` |
| 在菜单栏显示图标 | `#8E8E93` + `GEAR_I` |
| 自动记录剪贴板 | `#0A84FF` + `CLIP_I` |
| 忽略密码管理器 | `#FF9F0A` + 字形 `A` |

「通用」页文案

| 位置 | 文案 |
| --- | --- |
| 分组一标题 | `启动` |
| 分组二标题 | `捕获` |
| 「自动记录剪贴板」副文 | `Copyo 在后台记录，不需要任何权限` |
| 「忽略密码管理器」副文 | `来自 1Password、钥匙串的内容不会被记录` |
| 页脚注（宽 460） | `复制后 Copyo 把内容写回系统剪贴板并把焦点交还给原来的 App，由你自己按 ⌘V —— Copyo 从不代你粘贴。` |

**开关 `toggle(on)`**

| 属性 | 值 |
| --- | --- |
| 轨道 | 38 × 22，圆角 11，`flex: none`，`position: relative` |
| 轨道底 · 开 | `#34C759`（`success` 浅） |
| 轨道底 · 关 | `rgba(118,118,128,0.24)` |
| 把手 | 18 × 18，圆角 9，`#FFFFFF`，`box-shadow: 0 1px 3px rgba(0,0,0,0.2)` |
| 把手定位 | `top: 2px`；开 `left: 18px`，关 `left: 2px` |

---

### 3.12 快捷键录制器

来源：`gen2.py` `key_content`（设置 · 快捷键页）。

**「唤出面板」行**

| 属性 | 值 |
| --- | --- |
| 行容器 | `min-height: 44px`，内距 `8px 12px`，`display: flex; align-items: center; gap: 10px`，`box-sizing: border-box`；外层仍是 `group()`（圆角 10 / `bg.card` / `cring`） |
| 图标砖 | `tile("#5856D6", glyph="⌘")`——26 × 26、圆角 7、底 `#5856D6`、`MONO` 13pt / 600、前景 `#FFFFFF` |
| 行标题 | 13pt，色 `label`，文案 `唤出面板` |
| 分组标题 | `唤出`，副标 `点一下可以改` |

**录制器按钮**

| 属性 | 值 |
| --- | --- |
| 最小宽 | 88（`min-width: 88px`） |
| 高 | 26 |
| 内距 | `0 10px` |
| 圆角 | 7 |
| 背景 | `bg.card`（浅 `#FFFFFF`） |
| 环 | `box-shadow: 0 0 0 2px #0A84FF` |
| 字体 | `MONO` 12pt，`font-weight: 500` |
| 前景 | `label` |
| 布局 | `display: inline-flex; align-items: center; justify-content: center` |
| 当前值 | `⇧⌘V` |

**占用失败态**（紧接在分组下方的一行）

| 属性 | 值 |
| --- | --- |
| 布局 | `display: flex; align-items: center; gap: 6px` |
| 图标 | 13pt、线宽 1.6、色 `destructive` `#FF3B30`；绘制为 `<circle cx="8" cy="8" r="6.2"></circle><path d="M8 4.8v4M8 10.8v.4"></path>`（感叹号圆） |
| 文字 | 11pt，色 `destructive` `#FF3B30` |
| 文案 | `这个组合已被另一个 App 占用，Copyo 收不到它` |

**「面板内」快捷键表 `keyrow(label, cap, last)`**

| 属性 | 值 |
| --- | --- |
| 行高 | 34（固定 `height: 34px`，与 `srow()` 的 `min-height: 40px` 不同） |
| 内距 | `0 12px` |
| 布局 | `display: flex; align-items: center; gap: 10px`，`box-sizing: border-box` |
| 标签 | `flex-grow: 1`，13pt，色 `label` |
| 右侧 | keycap（见 3.6） |
| 分隔线 | `border-bottom: 0.5px solid separator`，最后一行无线 |
| 分组标题 | `面板内` |

九行内容（顺序固定，「唤出面板 ⇧⌘V」不在此表内，由上方录制器承担）

| 动作 | keycap |
| --- | --- |
| 复制选中项 | `↩` |
| 纯文本复制 | `⇧↩` |
| 预览 | `空格` |
| 固定到 Pinboard | `⌘P` |
| 删除 | `⌘⌫` |
| 聚焦搜索 | `⌘F` |
| 在筛选间循环 | `⇥` |
| 直接取第 N 张卡 | `⌘1–9` |
| 关闭面板 | `esc` |

---

### 本章待确认

> 本章相关的待确认条目：见第八节第 1、4、5、6、35、36、37 条。

---

## 四、交互 · 键盘 · 悬停 · 动效

> 引用格式 `文件:行号`。面板的复制流程是「写回系统剪贴板 + 把焦点交还给原来的 App，由用户自己按 ⌘V」，
> 全节不得出现任何形似「粘贴按钮 / 粘贴标签 / 粘贴动画」的表达。

---

### 4.1 焦点模型

**本次重设计最大的单点工程风险。必须在写第一行实现代码之前定下来，否则后面全部返工。**

#### 4.1.1 目标模型

| 项 | 规定 |
| --- | --- |
| 焦点持有者 | 面板根视图。根视图挂 `.focusable()`，键盘事件由根视图的 `.onKeyPress` 接收 |
| 焦点状态 | `@FocusState private var zone: Zone?`，`enum Zone { case search, cards, filters }` 三态 |
| ⇥ | 在 `.search → .cards → .filters → .search` 三者间循环；⇧⇥ 反向 |
| 默认态 | 面板每次呼出后为 `.search`（沿用今天呼出即聚焦搜索的行为） |
| `.cards` 内导航 | ← → 在卡片间移动，Home / End 跳首尾，⌘1–9 直取第 N 张 |
| `.filters` 内导航 | ← → 在 6 个筛选胶囊间移动，↩ 选中当前胶囊 |
| 焦点环视觉 | 卡片 `focus` 环 = `0 0 0 2px #0A84FF, 0 0 0 7px rgba(10,132,255,0.32)`（`gen.py:114-115`）；搜索框 focus 环 = `0 0 0 2px #0A84FF, 0 0 0 6px rgba(10,132,255,0.28)`（`gen.py:206`） |
| 选中环视觉 | `select`（面板是 key window）= `0 0 0 3px #0A84FF`（`gen.py:116-117`） |
| 失焦降级 | `key-inactive`（面板不是 key window）= `0 0 0 3px rgba(10,132,255,0.45)`（`gen.py:118-119`）。**macOS 独有，iOS 无此概念** |
| 自动隐藏抑制 | `suppressAutoHide` 必须覆盖**每一个**新增的浮层 / 弹出 / 菜单 / 预览，而不只是今天的新建 Pinboard alert |

#### 4.1.2 今天的做法（必须整体替换）

| 现状 | 位置 | 问题 |
| --- | --- | --- |
| 唯一的 `@FocusState` 是 `searchFocused: Bool` | `Copyo/Panel/PanelRootView.swift:30` | 只有二态，无法表达 cards / filters |
| `.focused($searchFocused)` 绑在搜索 `TextField` 上 | `PanelRootView.swift:191` | 焦点只能落在文本框 |
| **`handleKeyPress` 挂在 `TextField` 的 `.onKeyPress(phases: .down)` 上** | `PanelRootView.swift:193-195` | 所有键盘快捷键的唯一入口都在文本框内。焦点一旦离开文本框，← → / 空格 / esc / ⌘⌫ / ⌥↩ 全部失效 |
| `.onSubmit { pasteSelected(asPlainText: false) }` | `PanelRootView.swift:192` | ↩ 复制也绑在文本框上，同上 |
| **重聚焦循环**：`.onChange(of: searchFocused) { _, focused in if !focused && !showNewPinboardAlert { Task { @MainActor in searchFocused = true } } }` | `PanelRootView.swift:92-97` | 为了对抗上一条而存在：点卡片、点 Pinboard 标签都会让文本框失焦，这段把焦点无条件抢回来。**任何真正可聚焦的列表 / 网格 / 侧栏 / 筛选胶囊都会被它当场拽回搜索框** |
| 呼出时强制聚焦搜索 | `PanelRootView.swift:78`、`:84` | 目标模型保留此行为，但要改成设置 `zone = .search` |
| `suppressAutoHide` 的开关只围绕新建 Pinboard alert | `PanelRootView.swift:98-107`（读写）、`PanelController.swift:23`（声明） | alert 关闭后还要 `controller?.makePanelKey()`（`PanelController.swift:118-121`）+ 再次 `searchFocused = true`，是一段专为单一弹窗手写的补丁 |
| `windowDidResignKey` 无条件收起面板 | `Copyo/Panel/PanelController.swift:137-141` | 面板一旦不是 key window 就 `hide()`。新增任何会抢 key 的浮层（预览独立窗口、Pinboard 选择 popover、快捷键录制、右键菜单的某些实现）都会让面板在交互中途消失 |
| 面板可成为 key，但不能成为 main | `PanelController.swift:8-9` | 保留 |

#### 4.1.3 替换的硬性前提

1. `handleKeyPress` 必须从 `TextField` 上摘下来，改挂根视图；`.onSubmit` 的职责一并并入 `.onKeyPress` 的 `.return` 分支。
2. `PanelRootView.swift:92-97` 的重聚焦循环必须**整段删除**，不能保留任何「焦点丢了就抢回搜索框」的兜底。
3. `suppressAutoHide` 从「布尔补丁」升级为计数或栈（同时可能有多个浮层），并由 `PanelController` 暴露 `push/pop` 接口；`windowDidResignKey` 只在计数为 0 时 `hide()`。
4. 搜索框是 `.search` 区的唯一可编辑控件；`.cards` / `.filters` 区激活时，键入可打印字符应当把焦点送回 `.search` 并把该字符带过去（承接今天「呼出即打字即搜」的手感）。

---

### 4.2 键盘快捷键全表

「今天」列的依据全部在 `Copyo/Panel/PanelRootView.swift:307-332`（`handleKeyPress`）与 `:192`（`onSubmit`）。

| 键 | 动作 | 今天 | 出处 |
| --- | --- | --- | --- |
| ⇧⌘V | 唤出 / 收起面板（可在设置里改） | 有 | `HotkeyConfig.default = kVK_ANSI_V + cmdKey\|shiftKey`（`Copyo/Services/HotkeyManager.swift:9-10`），注册于 `Copyo/App/AppDelegate.swift:74`、改键后重注册 `:159` |
| ↩ | 复制选中项（写回剪贴板 → 收起面板 → 交还焦点） | 有，但绑在搜索框的 `.onSubmit` 上 | `PanelRootView.swift:192` → `pasteSelected(asPlainText:)` `:350-353` → `PanelController.copyAndDismiss` `:124-127` |
| ⇧↩ | 纯文本复制 | **没有**。今天纯文本复制绑在 **⌥↩** 上 | `PanelRootView.swift:326-328`：`case .return where press.modifiers.contains(.option)`。⇧↩ 不匹配任何分支，落到 `.ignored`（`:329-330`） |
| 空格 | 预览浮层开 / 关 | 有，且**仅当搜索框为空**时生效 | `PanelRootView.swift:320-322`：`case .space where search.isEmpty` |
| ⌘P | 固定到 Pinboard | **没有** | `handleKeyPress` 无此分支。固定只能走卡片右键菜单 `PanelRootView.swift:257-274`（`:256` 是 `Divider()`，`Unpin` 在 `:275-280`） |
| ⌘⌫ | 删除选中项 | 有 | `PanelRootView.swift:323-325`：`case .delete where press.modifiers.contains(.command)` |
| ⌘F | 聚焦搜索 | **没有** | 无分支。今天焦点恒在搜索框，所以此前不需要 |
| ⇥ | 在 search / cards / filters 三区循环 | **没有** | 无分支，落 `.ignored` |
| ← → | 在卡片间移动选中 | 有 | `PanelRootView.swift:309-314` → `moveSelection(±1)` `:334-338`（夹在 `0…count-1`，不循环；移动时关闭预览 `:337`） |
| ↑ ↓ | （目标：`.cards` 区内无动作；`.filters` 区切换筛选） | **被吞掉且无任何动作** | `PanelRootView.swift:315-316`：`case .upArrow, .downArrow: return .handled` —— 返回 `.handled` 却什么也不做，按键被静默丢弃 |
| ⌘1–9 | 直取第 N 张卡片并复制 | **没有** | 无分支 |
| Home / End | 跳到第一张 / 最后一张卡片 | **没有** | 无分支 |
| esc（多级） | 1) 关预览 → 2) 清空搜索 → 3) 关面板 | 有，三级完全一致 | `PanelRootView.swift:317-319` → `handleEscape()` `:340-348` |
| ⌘, | 打开设置 | 有，但**只在菜单栏右键菜单里**（`keyEquivalent: ","`），面板内无效 | `AppDelegate.swift:205-207`；原因见 4.2.1 |
| ⌘Q | 退出 | 同上，只在菜单栏菜单里 | `AppDelegate.swift:211` |

设计稿的设置窗口「快捷键」页把面板内快捷键固化成九行（`gen2.py:241-243`，`Settings.dc.html`）：
`复制 ↩` / `纯文本复制 ⇧↩` / `预览 空格` / `固定到 Pinboard ⌘P` / `删除 ⌘⌫` / `聚焦搜索 ⌘F` /
`在筛选间循环 ⇥` / `直接取第 N 张卡 ⌘1–9` / `关闭面板 esc`，加上顶部可改的 `唤出面板 ⇧⌘V`。
面板底部提示条只露四项：`↩ 复制` / `空格 预览` / `⌘P 固定` / `⌘⌫ 删除`（`hintbar()`，`gen.py:227-232`，四项在 `:231`）。

#### 4.2.1 全工程没有主菜单 —— 焦点模型改造时必须一并决定

核对结果（2026-09-20，全仓 `*.swift`）：

| 事实 | 证据 |
| --- | --- |
| `mainMenu` 在全仓 Swift 源码中出现 **0 次** | `grep -rn --include='*.swift' "mainMenu" .` → 0 |
| 全仓只有一个 `NSMenu()`，是菜单栏状态项的右键菜单 | `Copyo/App/AppDelegate.swift:189` |
| Mac target `Copyo` 的**三份构建配置**都是 `INFOPLIST_KEY_LSUIElement = YES` | `Copyo.xcodeproj/project.pbxproj:436`（Debug）、`:464`（Release）、`:510`（Release-AppStore）。三处的 `PRODUCT_BUNDLE_IDENTIFIER` 同为 `dev.vibemage.Copyo`，同属 `AB0000000000000000000007 /* Build configuration list for PBXNativeTarget "Copyo" */`（`:826-835`）。**这是一个 target 的三份配置，不是三个 target**；`LSUIElement` 是 macOS 专有键，工程里另外三个 target（`Copyo iOS` / `CopyoShareExtension` / `CopyoWidgets`）根本没有这个键 |

后果：AppKit 的 ⌘A / ⌘C / ⌘X / ⌘V / ⌘Z 是由 **Edit 菜单**提供的 key equivalent。没有主菜单 ⇒ 没有 Edit 菜单 ⇒
面板搜索框（`PanelRootView.swift:188-195`）里这五个组合**全部不工作**：`handleKeyPress` 对它们返回 `.ignored`（`:329-330`），
事件继续沿响应链上行，而链的尽头没有菜单可查询。

本次必须做出的决定（二选一，写进实现前）：

| 选项 | 内容 |
| --- | --- |
| A | 装一个最小主菜单：只含 Edit 菜单（撤销 / 重做 / 剪切 / 拷贝 / 粘贴 / 全选）与 App 菜单（设置 ⌘,、退出 ⌘Q）。`LSUIElement` 应用可以有主菜单，它只在应用被激活时显示——而面板呼出时 `NSApp.activate(ignoringOtherApps: true)`（`PanelController.swift:85`）正是激活状态 |
| B | 不装主菜单，在面板根视图的 `.onKeyPress` 里自行实现 ⌘A / ⌘C / ⌘X / ⌘V / ⌘Z 对搜索框的语义 |

选 A 会让菜单栏在面板呼出期间出现应用菜单（视觉上有变化，需确认可接受）；选 B 要自己维护撤销栈。
**无论选哪个，都必须在 4.1 的焦点模型落地时一起做完**——因为两者都要改动键盘事件的接收位置。

---

### 4.3 悬停

**今天：面板内零 hover、零 pressed。** 核对结果：`Copyo/Panel/` 与 `Copyo/Settings/` 中
`onHover` / `pointerStyle` / `NSCursor` / `hoverEffect` 出现 **0 次**；四个按钮全部是 `.buttonStyle(.plain)`
（`PanelRootView.swift:141, 160, 180, 204`），即无默认按下态、无默认悬停态。

| 对象 | 悬停表现 | 数值出处 |
| --- | --- | --- |
| 卡片 · 淡染加深 | 浅色 12% → 16%，深色 20% → 26%；另加来源色 40% 的 0.5pt 描边 | 移植图 §3.1 第 6 条。**设计稿的 hover 卡未画出加深后的淡染**（`gen.py:108-147` 的 `card()` 在 `hover=True` 时只加动作簇，底色与默认态同值），见第八节第 7 条 |
| 卡片 · 动作簇浮出 | 容器：`position: absolute; right: 8px; top: 8px`，`height: 28px`，`padding: 0 3px`，`border-radius: 9px`，背景 `glass`（浅 `rgba(255,255,255,0.74)` / 深 `rgba(58,58,60,0.72)`），`backdrop-filter: blur(14px)`，阴影 `<ring>, 0 2px 8px rgba(0,0,0,0.14)`，子项 `gap: 2px` | `gen.py:123-132` |
| 动作簇按钮 | 两枚，各 `24 × 24`，`border-radius: 7px`；图标 14px 线宽 1.5。左＝固定到 Pinboard，`#0A84FF`；右＝删除，浅色 `#FF3B30` / 深色 `#FF453A` | `gen.py:125-132` |
| 动作簇的 `aria-label` | `固定到 Pinboard` / `删除` | `gen.py:131-132` |
| 卡片 · 按压 | `scale(.98)`（iOS 的 `.96` 在桌面减幅） | 移植图 §2.5 |
| 筛选胶囊 / Pinboard 胶囊 | 未选中态底色 `fill` → 悬停提到 `fill2`（浅 `rgba(118,118,128,0.20)` / 深 `rgba(118,118,128,0.32)`）；选中态（`#0A84FF` 实底 + 白字 600）悬停不变 | 胶囊两档底色见 `gen.py:98-106`；**悬停档位由本规格规定，设计稿未画**，见第八节第 7 条 |
| 搜索框 | 常态底 `fill`；悬停提到 `fill2`；聚焦时改为焦点环 `0 0 0 2px #0A84FF, 0 0 0 6px rgba(10,132,255,0.28)`，底色回 `fill` | 底色与焦点环 `gen.py:206, 214`；悬停档位同上，见第八节第 7 条 |
| 顶栏图标按钮（同步状态、设置齿轮） | `32 × 32`，`border-radius: 8px`，常态无底；悬停加 `fill` 底 | 尺寸 `gen.py:210-213`（同步按钮 `:210-211`、齿轮 `:212-213`）；**悬停底由本规格规定，设计稿未画**，见第八节第 7 条 |
| 光标形态 | 所有可点元素（卡片、胶囊、动作簇按钮、顶栏图标按钮）→ macOS 15+ 用 `.pointerStyle(.link)`，macOS 14 回退 `NSCursor.pointingHand`；搜索框内 → `NSCursor.iBeam`（系统默认，不覆盖） | 移植图 §5.3。设计稿是静态 HTML，无光标信息 |
| 设计稿的 `cursor` 声明 | 画板全局 `button { cursor: default; }` | `gen.py:248`（`page()` 内联样式表里的 `button { … cursor: default; }`）。这是 HTML 画板的排版设定，**不作为产品光标规格**，以上一行为准 |

---

### 4.4 右键

设计稿没有画任何上下文菜单。下表 = 今天的实现 + 本轮要补的项。

#### 4.4.1 卡片

| 菜单项 | 今天 | 位置 |
| --- | --- | --- |
| 复制 | 有（`Copy`） | `PanelRootView.swift:254` |
| 纯文本复制 | 有（`Copy as Plain Text`） | `:255` |
| ——分隔—— | 有 | `:256` |
| 固定到 Pinboard | 有，两种形态：无 Pinboard 时是单项 `Pin to Pinboard…`（打开新建 alert）；有 Pinboard 时是子菜单 `Pin to`，列出全部 Pinboard + 分隔 + `New Pinboard…` | `:257-274` |
| 取消固定 | 有（`Unpin`），仅当 `item.pinboard != nil` 才出现 | `:275-280` |
| ——分隔—— | 有 | `:281` |
| 删除 | 有（`Delete`，`role: .destructive`） | `:282-284` |
| 预览 | **要补**：`预览`（空格），打开 `PreviewOverlay` | — |
| 在访达中显示 | **要补**，仅 `.file` 类型且路径可读时出现（可读性判定沿用 `FileManager.default.isReadableFile(atPath:)`，见 `:415-417`） | — |
| 拷贝色值 | **要补**，仅 `.color` 类型 | — |

结构保持与 iOS 上下文菜单同序（复制 / 纯文本复制 / 分享 / 固定 / 删除），macOS 去掉「分享」改由 `ShareLink` 承载（本轮不做，见第八节第 22 条）。

#### 4.4.2 Pinboard 胶囊

| 菜单项 | 今天 |
| --- | --- |
| 删除 Pinboard | 有（`Delete Pinboard`，`role: .destructive`），`PanelRootView.swift:127-131` |
| 重命名 | **要补** |
| 改颜色 / 改图标 | **要补**。`Pinboard` 模型已有 `iconName: String?` 与 `colorHex: String?`，Mac 端今天完全没用上 |

「历史」胶囊（`id: nil`，`PanelRootView.swift:124`）不挂右键菜单。

#### 4.4.3 面板空白处

**今天完全没有。** 本轮要补，两项：

| 菜单项 | 说明 |
| --- | --- |
| 清空历史… | 复用菜单栏菜单的 `clearHistory`（`AppDelegate.swift:201-203, 231`），带确认 |
| 设置… | 复用 `AppDelegate.openSettings()`（`:224`） |

弹出期间必须置 `suppressAutoHide`（见 4.1.3 第 3 条），否则面板会在菜单打开的瞬间收起。

#### 4.4.4 菜单栏图标

左键 = 切换面板（`panelController.toggle()`），右键 = 弹出菜单；实现是临时给 `statusItem.menu` 赋值、
`performClick(nil)`、随即置 nil（`AppDelegate.swift:179-186, 188-218`）。菜单内容今天已完整，本轮不改：

| 顺序 | 项 | keyEquivalent | 位置 |
| --- | --- | --- | --- |
| 1 | 打开 Copyo | 当前唤出快捷键（`config.keyEquivalentCharacter` + `config.cocoaModifiers`） | `AppDelegate.swift:192-198` |
| 2 | ——分隔—— | — | `:199` |
| 3 | 清空历史… | 无 | `:201-203` |
| 4 | 设置… | `,` | `:205-207` |
| 5 | ——分隔—— | — | `:209` |
| 6 | 退出 Copyo | `q` | `:211` |

---

### 4.5 拖放

#### 4.5.1 视觉

| 项 | 值 | 出处 |
| --- | --- | --- |
| 拖影 = 卡片 lift 态 | `transform: rotate(-2deg) scale(1.03)` | `gen.py:120` |
| lift 态阴影 | `<cring>, 0 12px 32px rgba(0,0,0,0.28)`；其中 `cring` 浅 `inset 0 0 0 0.5px rgba(0,0,0,0.05)` / 深 `inset 0 0 0 0.5px rgba(255,255,255,0.06)` | `gen.py:121-122`、`gen.py:13, 22` |
| lift 态卡片同时显示「已固定」图钉 | `Card.dc.html` 状态行第 6 张：`sel="lift", pinned=True`，图钉 11px 线宽 1.6，色 `#0A84FF` | `gen2.py:59`、`gen.py:133-136` |
| 原位 ghost | `opacity: .35` | 移植图 §5.10（设计稿未画 ghost，见第八节第 7 条） |

#### 4.5.2 数据表示

今天：`.onDrag { dragProvider(for: item) }`（`PanelRootView.swift:252`），`dragProvider` 在 `:401-427`，
按 `item.kind` 分派，**每种类型只注册一种表示**：

| kind | 今天注册的表示 | 位置 |
| --- | --- | --- |
| `.image` | `NSItemProvider(object: NSImage)` | `:403-406` |
| `.file` | `NSItemProvider(contentsOf: url)`；失败时返回空 `NSItemProvider()` | `:407-422`、`:426` |
| 其余（`.text` / `.richText` / `.link` / `.color`） | `NSItemProvider(object: NSString)`，内容是 `item.plainText ?? ""` | `:423-425` |

本轮要补齐多表示（`NSPasteboard` 原生支持，iPad 侧已在 iOS 规格里定义过 text / rtf / url / image / color）：

| kind | 应注册的表示（按优先级） |
| --- | --- |
| `.text` | `public.utf8-plain-text` |
| `.richText` | `public.rtf` → `public.utf8-plain-text` |
| `.link` | `public.url` → `public.utf8-plain-text` |
| `.image` | 原始图片 UTI（PNG / TIFF） → `public.utf8-plain-text`（可选，文件名或空） |
| `.color` | `com.apple.cocoa.pasteboard.color`（`NSColor`） → `public.utf8-plain-text`（色值字符串） |
| `.file` | `public.file-url` × N（多文件），字节可读时再附 `public.data` |

#### 4.5.3 沙盒下不可读文件的既有守卫（保留，不得删）

`PanelRootView.swift:410-418`（`#if APPSTORE`）：沙盒里 `filePaths` 里的路径通常读不了，
而 `NSItemProvider(contentsOf:)` 是惰性的，照样会声称能提供 `public.data`，接收方真去取字节时才拿到 `nil`——
拖拽看起来成功、落地是空的。守卫的做法是先 `FileManager.default.isReadableFile(atPath: path)`，
读不了就只登记 `file-url`（`:415-417`），让需要字节的目标当场拒绝。
补多表示时**必须把同一个可读性判定应用到新增的每一种文件表示上**。

---

### 4.6 动效

| 场景 | 参数 | 今天 | 出处 |
| --- | --- | --- | --- |
| 面板出现 | `duration = 0.22`，`CAMediaTimingFunction(name: .easeOut)`；从最终 frame 向下位移一个面板高度的位置滑入 | 有，**沿用，不改** | `Copyo/Panel/PanelController.swift:87-91`（位移起点 `:83`） |
| 面板消失 | `duration = 0.18`，`CAMediaTimingFunction(name: .easeIn)`；向下位移一个面板高度 | 有，**沿用，不改** | `PanelController.swift:101-105` |
| 选中项滚动跟随 | `.easeOut(duration: 0.15)`，`proxy.scrollTo(id, anchor: .center)` | 有，沿用 | `PanelRootView.swift:230-236` |
| 卡片按压 | `scale(.98)`，`spring(response: 0.35, dampingFraction: 0.8)` | **没有**（`CardView.swift` 全文无 `.animation`，选中态是瞬变） | 移植图 §2.5（iOS 是 `.96`，桌面减幅到 `.98`） |
| 选中 / 焦点环切换 | 同上 spring 0.35 / damping 0.8 | **没有** | 同上 |
| 轻提示进 | 从 `y +8` 上移到位 + 透明度 0 → 1，`0.22s easeOut` | **没有 toast** | 见第八节第 6 条 |
| 轻提示停留 | 1.2s | — | 移植图 §2.5（沿用 iOS） |
| 轻提示出 | 透明度 1 → 0，`0.18s easeIn` | — | 见第八节第 6 条 |
| 动作簇淡入 | 透明度 0 → 1 + `y −2 → 0`，`0.12s easeOut`；移出时 `0.10s easeIn` | **没有 hover** | 设计稿未给时长，本规格规定，见第八节第 7 条 |
| 同步图标「同步中」 | 图标连续旋转，周期 1s | **面板里没有同步状态** | 移植图 §2.5 / §3.6 |
| 新条目高亮 | focus 环显示 0.8s 后淡出 | **没有** | 移植图 §2.5 |
| 拖起 lift | `rotate(-2deg) scale(1.03)`，`0.15s easeOut` | 用系统默认拖影 | 变换值 `gen.py:120`；时长本规格规定 |

#### 4.6.1 减弱动态（强制）

**以上全部动效，在 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` 为真时一律降级为无动画。**

| 降级后的行为 | 说明 |
| --- | --- |
| 面板出现 / 消失 | 不做位移动画，直接 `orderFront` / `orderOut`（`NSAnimationContext` 的 `duration` 置 0） |
| 滚动跟随 | `proxy.scrollTo` 不包 `withAnimation` |
| 卡片按压、环切换、动作簇淡入、lift | 状态瞬变，不插值 |
| 轻提示 | 直接出现、停留 1.2s、直接消失（停留时长**不**缩短） |
| 同步「同步中」旋转 | 停止旋转，改为静态图标（保留三态的形状与颜色区分） |
| 新条目高亮 | 焦点环直接显示 0.8s 后直接消失，不淡出 |

该开关今天在全仓 `*.swift` 中出现 **0 次**（`grep -rn --include='*.swift' "accessibilityDisplayShould" .` → 0），
必须配合 `NSWorkspace.shared.notificationCenter` 的 `accessibilityDisplayOptionsDidChangeNotification` 监听，运行中改设置要即时生效。

---

### 4.7 辅助功能

**这是现状最差的一块。**

#### 4.7.1 现状核对（2026-09-20，全仓 `*.swift`）

| 范围 | `accessibility` 出现次数 | 说明 |
| --- | --- | --- |
| `Copyo/`（macOS 全部代码） | **2** | 两处都在菜单栏图标上：`Copyo/App/AppDelegate.swift:170`（`icon?.accessibilityDescription = "Copyo"`）与 `:172`（`NSImage(systemSymbolName:accessibilityDescription:)` 的回退）。**`Panel/` 与 `Settings/` 里一处也没有** |
| `CopyoIOS/` | **83**，分布在 28 个文件 | 卡片、Toast、空态、同步胶囊、筛选 chips、详情、设置、引导、iPad 侧栏全覆盖 |
| `CopyoShared/` | **16**，分布在 **3** 个文件 | `Share/ShareView.swift`（10）、`Share/SharePreviewCard.swift`（5）、`Share/CopyoMark.swift`（1） |
| `accessibilityDisplayShould*`（三个开关） | **0** | 全仓未读取 |
| `reduceMotion` / `reduceTransparency` / `increaseContrast` / `differentiateWithoutColor` | **0** | 全仓未出现 |
| `.help(...)`（tooltip） | `Copyo/` 中 **2**：`PanelRootView.swift:142`（`"New Pinboard"`）、`:161`（`"Settings"`） | **`.help()` 是 tooltip，不是 accessibility label**，不能拿它顶数 |

#### 4.7.2 本次必须补的

| 对象 | 规定 |
| --- | --- |
| 每张卡片的 `accessibilityLabel` | 四段，顺序固定：**类型 + 来源 + 时间 + 内容摘要**。例：`文本，来自 Xcode，2 分钟前，git rebase -i HEAD~3 && git push --force-with-lease`。图片条目摘要读「图片」，文件条目读首文件名 + `另外 N 个文件`，颜色条目读色值字符串 |
| 卡片摘要长度 | 截断到 120 个字符，超出补省略；正文里的换行读作空格。**120 这个阈值是本规格规定，设计稿未画**（画板上卡片正文走的是视觉行数截断 `-webkit-line-clamp: 7`，`gen.py:149-153`，与朗读长度无关），见第八节第 24 条 |
| 卡片选中态 | `.accessibilityAddTraits(.isSelected)`；卡片本身 `.accessibilityElement(children: .ignore)`，不让角标 / meta / 图标各自成为独立元素 |
| 卡片动作 | `.accessibilityAction(named: "复制")` / `"纯文本复制"` / `"预览"` / `"固定到 Pinboard"` / `"删除"`，与右键菜单同序同名（4.4.1） |
| 同步状态图标 | 三态各一个 label：`iCloud 已同步` / `iCloud 同步中` / `iCloud 未同步`。今天面板里没有这个图标；设计稿已给 `aria-label="iCloud 已同步"` + `title="iCloud 已同步"` 双写（`gen.py:210`，只画了已同步一态），实现上 `title` → `.help()`，`aria-label` → `accessibilityLabel`，**两者都要给** |
| 设置齿轮按钮 | `accessibilityLabel = "设置"`（设计稿 `gen.py:212`，同样是 `aria-label` + `title` 双写）。今天只有 `.help("Settings")`（`PanelRootView.swift:161`） |
| 新建 Pinboard 按钮 | `accessibilityLabel = "新建 Pinboard"`。今天只有 `.help("New Pinboard")`（`:142`） |
| 悬停动作簇两枚按钮 | `accessibilityLabel` = `固定到 Pinboard` / `删除`（设计稿 `gen.py:131-132` 已写死这两个字符串）。图标按钮无可见文字，label 是唯一可读内容 |
| 已固定图钉 | `accessibilityLabel = "已固定"`（设计稿 `gen.py:135` 的 `aria-label`）；若卡片整体 `children: .ignore`，则并入卡片 label 末尾 |
| 筛选胶囊 | `accessibilityAddTraits(.isSelected)`；选中胶囊是 `#0A84FF` 实底白字，未选中是 `fill` 底 —— **不能只靠颜色区分** |
| 搜索框 | 可见 label 是占位文字「搜索历史」，须另给 `accessibilityLabel = "搜索历史"`（设计稿用了视觉隐藏的 `<label for="q">搜索历史</label>`，`gen.py:203`） |
| 底部提示条 | 整条 `.accessibilityElement(children: .combine)`，读作「回车 复制，空格 预览，⌘P 固定，⌘⌫ 删除」，keycap 的符号要给可读文本而非符号字面量 |
| 轻提示 | `.accessibilityAddTraits(.isStaticText)` + 出现时发 `NSAccessibility.post(element:notification:.announcementRequested)`，播报「已复制，按 ⌘V 粘贴」 |

#### 4.7.3 增强对比度 `accessibilityDisplayShouldIncreaseContrast`

> **本节下表第三列（降级值）整列是本规格规定，设计稿未画。** `gen.py` / `gen2.py` 与 2026-09-20 的十张画板里
> 没有任何增强对比度变体（既没有第二套色字典，也没有 `prefers-contrast` 分支），所以「降到 0%」「0.5 → 1pt」
> 「0.32 → 0.60」「0.45 → 0.70」「`label.meta` 提到 `label`」这些数都是本规格自行推出来的。
> 第二列（常态）逐条有出处，见各行括注。整列待拍板，见第八节第 24 条。

| 元素 | 常态（有出处） | 增强对比度下（**本规格规定，设计稿未画**） |
| --- | --- | --- |
| 卡片淡染 | 浅 12% / 深 20%（`gen2.py:156`） | 淡染降到 **0%**，卡片底色改为 `bg.card`（浅 `#FFFFFF` / 深 `#2C2C2E`，`gen.py:9, 18`），来源身份只由类型角标的实心来源色承担 |
| 卡片描边 | `cring` 0.5pt（`gen.py:13, 22`） | 改为 `separator` 1pt（浅 `rgba(60,60,67,0.24)` / 深 `rgba(84,84,88,0.60)`，`gen.py:11, 20`） |
| 焦点环 | `2px #0A84FF + 5px @32%` | 外圈光晕不透明度 `0.32 → 0.60`，内圈保持 2pt 实色 |
| 选中环 | `3px #0A84FF` | 保持 3pt，不降级 |
| 面板失焦选中环 | `3px rgba(10,132,255,0.45)` | 提到 `rgba(10,132,255,0.70)` |
| `label.meta` | 浅 `rgba(60,60,67,0.78)` / 深 `rgba(235,235,245,0.72)`（`gen.py:10, 19`） | 提到 `label`（浅 `#000000` / 深 `#FFFFFF`） |
| 分隔线 | `separator` 0.5pt | 1pt |

#### 4.7.4 减弱透明度 `accessibilityDisplayShouldReduceTransparency`

> 同 4.7.3：**下表第三列整列是本规格规定，设计稿未画。** 画板上玻璃只有一套值（`glass` + `backdrop-filter`），
> 没有画不透明替身；「玻璃统一降级为 `bg.grouped` 实色」与「预览遮罩 0.35 → 0.55」都是本规格推的。
> 待拍板同见第八节第 24 条。

| 元素 | 常态（有出处） | 减弱透明度下（**本规格规定，设计稿未画**） |
| --- | --- | --- |
| 面板外壳 | `glass`（浅 `rgba(255,255,255,0.74)` / 深 `rgba(58,58,60,0.72)`）+ `backdrop-filter: blur(24px)`（`panel()`，`gen.py:234-238`，底色与 blur 在 `:236`）；实现是 `VisualEffectView(material: .hudWindow)`（`PanelRootView.swift:62`、`Copyo/Panel/VisualEffectView.swift:4-19`） | 玻璃整体降级为 **`bg.grouped` 实色**：浅 `#F2F2F7` / 深 `#1C1C1E`（`gen.py:9, 18`），去掉 `backdrop-filter` |
| 悬停动作簇 | `glass` + `blur(14px)`（`gen.py:127-129`） | 同上，`bg.grouped` 实色 + 保留 `0 2px 8px rgba(0,0,0,0.14)` 阴影 |
| 轻提示 | `glass` + `blur(20px)`（`gen.py:284-288`，blur 在 `:286`） | 同上 |
| 预览浮层 | 今天是 `.regularMaterial`（`Copyo/Panel/PreviewOverlay.swift:21`） | 同上 |
| 预览遮罩 | 今天 `Color.black.opacity(0.35)`（`PreviewOverlay.swift:12`） | 提到 `0.55` |

这条降级顺便给截图流水线的 `-opaquePanel` 提供了正规实现路径：今天它用硬编码的
`Color(red: 0.078, green: 0.066, blue: 0.098)` 顶替毛玻璃（`PanelRootView.swift:58-60`），
新语言下应当直接走「减弱透明度」这条分支，落到 `bg.grouped` 深色值 `#1C1C1E`。

#### 4.7.5 前置风险：VoiceOver 在这种窗口类型上是否可达，从未验证

**这是能让 §4.7.2 整份 label 清单白写的前置风险，必须先验证再动工。**

面板不是普通窗口。`Copyo/Panel/PanelController.swift` 里它被同时设成三件事：

| 设定 | 值 | 位置 |
| --- | --- | --- |
| `styleMask` | `[.borderless, .nonactivatingPanel]` | `PanelController.swift:30` |
| 窗口层级 | `level = .statusBar` | `PanelController.swift:36` |
| 可成为 key / main | `canBecomeKey = true`、`canBecomeMain = false` | `PanelController.swift:8-9` |

这三条叠在一起，正是 AppKit 里辅助功能最容易出问题的组合：`.borderless` 没有标题栏因而没有天然的窗口名；
`.nonactivatingPanel` 意味着面板取得 key 时**不激活应用**，而 VoiceOver 的游标通常跟随「激活的应用 + 主窗口」；
`canBecomeMain = false` 使面板永远不是 main window；`level = .statusBar` 又把它放在普通窗口层之上。
面板还只在 `⇧⌘V` 之后短暂存在、失焦即 `hide()`（`PanelController.swift:137-141`），
VoiceOver 游标能否跟进来、进来之后能否停住，都是未知数。

**核对结果：全文零命中。** 七章草稿里 `VoiceOver` / `旁白` 出现 **0 次**；
`Copyo/` 全部 Swift 源码里 `accessibility` 只有 2 处，且都在菜单栏图标上（§4.7.1），
也就是说这套窗口从来没有被辅助功能真正走通过一次。

| 项 | 内容 |
| --- | --- |
| 风险 | VoiceOver 游标可能根本进不了这块面板，或进得去但读不出卡片轨道；`.announcementRequested` 播报可能因为面板不是 main window 而被丢弃 |
| 影响面 | §4.7.2 全表（卡片 label / 卡片动作 / 同步图标 / 齿轮 / 新建 Pinboard / 动作簇两枚按钮 / 已固定图钉 / 筛选胶囊 / 搜索框 / 底部提示条 / 轻提示播报）；以及 §4.1 的三区焦点模型——`@FocusState` 的焦点与 VoiceOver 游标是两套东西，两者能否对齐同样未验 |
| 动作项（必须在写 §4.7.2 的实现代码之前做） | **真机 + VoiceOver 验证**：在一台开启 VoiceOver 的 Mac 上呼出面板，逐项确认 (a) VO 游标能否进入面板；(b) VO-→ 能否遍历搜索框 / 胶囊 / 卡片；(c) 卡片的 `accessibilityLabel` 与 `.isSelected` 是否被读出；(d) `.accessibilityAction` 能否通过 VO-⌘-空格 的动作菜单触发；(e) `NSAccessibility.post(…, .announcementRequested)` 在这块面板上是否真的播报 |
| 验证失败时的退路 | 若 VO 进不来，需要改窗口类型（去掉 `.nonactivatingPanel`，或允许 `canBecomeMain`），而这会反过来动到 §4.1 的焦点模型与 `windowDidResignKey` 的收起逻辑——**所以这次验证必须排在焦点模型定稿之前，不能等到 §4.7 实现阶段** |

验证结论出来之前，§4.7.2 的清单按「目标规格」保留，但不得被当成可直接照着实现的定稿。

---

### 本章待确认

> 本章相关的待确认条目：见第八节第 7、17、18、22、23、24、45 条；
> 属工程风险的见 7.5.1（快捷键注册无声失败）、7.5.3（没有主菜单）、7.5.10（VoiceOver 可达性）。

---

## 五、SF Symbols 对照表

> 设计稿里的图标一律是内联 SVG 近似画法（`gen.py` 的 `ICON` / `SEARCH_I` / `GEAR_I` / `CLOUD_OK_I` /
> `CHEV_I` / `PIN_I` / `TRASH_I` / `CHECK_I` / `CLIP_I`），只为把尺寸、线宽与取色钉死。
> **实现一律用 SF Symbols**，不得把设计稿的 SVG 路径搬进代码。
> 「尺寸 / 线宽」列给的是设计稿里的 SVG 值（viewBox 统一 `0 0 16 16`，`stroke-linecap` / `stroke-linejoin`
> 均为 `round`）；实现时尺寸照抄，线宽按 `Font.Weight` 近似（见第八节第 25 条）。

### 5.1 类型角标（六种 kind）

角标内图标由 `gen.py:40 icon()` 绘制：非填充类 `stroke-width 1.7`；`color` 是唯一 `fill` 的一种。
尺寸 dense 档 10、regular 档 11（A 版全部画板用的都是 dense）。取色一律 `onband(来源色)`——
来源色相对亮度 > 0.62 取 `#16161A`，否则取 `#FFFFFF`（`gen.py:76 onband()`）。

| 用途 | SF Symbol 名 | 设计稿 SVG 常量 | 尺寸 | 线宽 | 取色 | 出现在哪一帧 |
| --- | --- | --- | --- | --- | --- | --- |
| 角标 文本 | `text.alignleft` | `ICON["text"]` | 10 / 11 | 1.7 | `onband(来源色)` | Main、A-panel-dark、A-hover-toast、A-search、Card |
| 角标 富文本 | `textformat` | `ICON["rich"]` | 10 / 11 | 1.7 | `onband(来源色)` | Card（六种类型行、排版最紧行前两条） |
| 角标 链接 | `link` | `ICON["link"]` | 10 / 11 | 1.7 | `onband(来源色)` | Main、A-panel-dark、A-hover-toast、Card |
| 角标 图片 | `photo` | `ICON["image"]` | 10 / 11 | 1.7 | `onband(来源色)` | Main、A-panel-dark、A-hover-toast、Card |
| 角标 颜色 | `circle.lefthalf.filled` | `ICON["color"]`（唯一 `fill`，无描边） | 10 / 11 | —（填充） | `onband(剪贴内容自身的颜色)` | Main、A-panel-dark、A-hover-toast、Card |
| 角标 文件 | `doc` | `ICON["file"]` | 10 / 11 | 1.7 | `onband(来源色)` | Card（六种类型行） |

符号名与现有实现 `CopyoShared/UI/KindPresentation.swift:29-38 symbol(_:)`（六个 `case` 在 `:31-36`）逐条一致
（`text.alignleft` / `textformat` / `link` / `circle.lefthalf.filled` / `photo` / `doc`），macOS 直接复用，不另起一套。

`A-hover-toast.dc.html` 只替换了 `cs[0]`（Xcode，焦点态）与 `cs[1]`（微信，悬停态）两张卡（`gen.py:278-283`），
`cs[2]` 链接 / `cs[3]` 颜色 / `cs[4]` 图片原样留着，所以这三种角标在该帧各出现一枚——上表已计入。

### 5.2 面板与卡片

`stroke()`（`gen.py:48`）的默认值是 `size=14, w=1.6`，下表逐处给出实际调用值。
`th["sec"]` = 浅 `rgba(60,60,67,0.60)` / 深 `rgba(235,235,245,0.60)`。

| 用途 | SF Symbol 名 | 设计稿 SVG 常量 | 尺寸 | 线宽 | 取色 | 出现在哪一帧 |
| --- | --- | --- | --- | --- | --- | --- |
| 搜索 | `magnifyingglass` | `SEARCH_I` | 14 | 1.6 | `th["sec"]` | Main、A-panel-dark、A-hover-toast、A-search、A-empty |
| 设置（面板右上角） | `gearshape` | `GEAR_I` | 17 | 1.5 | `th["sec"]` | Main、A-panel-dark、A-hover-toast、A-search、A-empty |
| iCloud 已同步 | `checkmark.icloud` | `CLOUD_OK_I` | 17 | 1.5 | 浅 `#34C759` / 深 `#30D158` | Main、A-panel-dark、A-hover-toast、A-search、A-empty |
| iCloud 同步中 | `arrow.triangle.2.circlepath.icloud` | **本规格规定，设计稿未画** | 17 | 1.5 | 浅 `#34C759` / 深 `#30D158` | 无（A 版十张画板只画了已同步态） |
| iCloud 未同步 | `icloud.slash` | **本规格规定，设计稿未画** | 17 | 1.5 | `th["sec"]` | 无 |
| Pinboard 胶囊的下拉箭头 | `chevron.down` | `CHEV_I` | 11 | 1.8 | `th["sec"]` | Main、A-panel-dark、A-hover-toast、A-search |
| 悬停动作簇 固定到 Pinboard | `pin` | `PIN_I` | 14 | 1.5 | `#0A84FF` | A-hover-toast（第 2 张卡）、Card（状态行「悬停」） |
| 悬停动作簇 删除 | `trash` | `TRASH_I` | 14 | 1.5 | 浅 `#FF3B30` / 深 `#FF453A` | A-hover-toast（第 2 张卡）、Card（状态行「悬停」） |
| 卡片「已固定」标记 | `pin`（见第八节第 26 条） | `PIN_I` | 11 | 1.6 | `#0A84FF` | Card（状态行「拖起」那张） |
| 「已复制」轻提示的对勾 | `checkmark` | `CHECK_I` | 14 | 2 | `#34C759` | A-hover-toast |

#### 5.2.1 缺口：文件夹同步模式在顶栏没有任何符号

上表里所有同步相关的形状都是 **iCloud 云朵**（`CLOUD_OK_I`，`gen.py:210` 的按钮
`aria-label` / `title` 双写就是 `iCloud 已同步`）。但 macOS 的同步方式是**三选一**，不是开关：

`Copyo/Services/SyncMode.swift:11-14` 的 `enum SyncMode { case off, folder, icloud }`，
设置页选择器在 `Copyo/Settings/SettingsView.swift:202-206`（`Off` / `Shared Folder` / `iCloud` 三个 `Text` 标签）。
其中 `folder`（共享文件夹快照同步，走 iCloud Drive 或任意共享目录、**不传播删除**）是与 `icloud` **平级的第三种方式**，
iOS 侧没有对应物——所以 iOS 规格里找不到可抄的符号。

设计稿在这里是空的：A 版十张画板只画了「iCloud 已同步」一态，`folder` 与 `off` 两种模式下顶栏那一格
**画什么、要不要画**，`gen.py` / `gen2.py` 一个字都没有。三个候选方案（**均为本规格提出，设计稿未画**，
不得当定稿实现）：

| 方案 | 做法 | 代价 |
| --- | --- | --- |
| A · 另起一套文件夹符号 | 三态换成 `folder.badge.questionmark`（未选目录）/ `folder.badge.gearshape`（同步中）/ `folder`（已同步），失效态用 `exclamationmark.triangle` | 顶栏同一格在两种模式下形状完全不同，用户切模式时会以为按钮换了功能；要多维护一套符号与一套无障碍文案 |
| B · 同一套云朵符号，只换文案 | 形状仍用 `checkmark.icloud` / `arrow.triangle.2.circlepath.icloud` / `icloud.slash`，只把 `accessibilityLabel` 改成「文件夹已同步」等 | 画的是云、说的是文件夹，语义对不上；用户选的是「共享文件夹」（可能根本不在 iCloud Drive 里，比如公司盘），显示云朵是误导 |
| C · 该格隐藏 | `syncMode == .folder` 时顶栏不画这一格，同步状态只在设置 > 同步页显示 | 顶栏布局要能接受少一枚按钮（搜索框随之变宽）；文件夹失效（书签失效、目录被卸载）这种**必须让用户看见**的失败态在面板上就彻底没有出口 |

顺带：`off` 模式（只存本机）下这一格画什么同样没画。`FolderSyncSections`
（`Copyo/Settings/SettingsView.swift:361`，`#if APPSTORE` 那份在 `:458`）在设置页里区分了
「未选目录」（`:397` `No folder selected`）与「书签失效」（`:368` `lostAccess`，文案 `:382`）两种状态，
这两条要不要在面板顶栏有表达，一并列入待确认。

### 5.3 设置窗口

图标砖由 `gen2.py:183 tile()` 绘制：26 × 26、圆角 7、纯色底，内图标 `stroke(..., onband(砖色), 15, 1.6)`；
砖色见 `gen2.py:177 TILE`。少数砖内放的不是符号而是等宽文字字形（`13px / 600 / MONO`）。

| 用途 | SF Symbol 名 | 设计稿 SVG 常量 | 尺寸 | 线宽 | 取色 | 出现在哪一帧 |
| --- | --- | --- | --- | --- | --- | --- |
| 砖 · 登录时启动 Copyo | 见第八节第 12 条 | `CHECK_I` | 15 | 1.6 | `onband("#34C759")` = `#FFFFFF` | Settings（通用页） |
| 砖 · 在菜单栏显示图标 | `gearshape` | `GEAR_I` | 15 | 1.6 | `onband("#8E8E93")` = `#FFFFFF` | Settings（通用页） |
| 砖 · 自动记录剪贴板 | `doc.on.clipboard` | `CLIP_I` | 15 | 1.6 | `onband("#0A84FF")` = `#FFFFFF` | Settings（通用页） |
| 砖 · 忽略密码管理器 | 见第八节第 12 条 | 无（文字字形 `A`） | 13px 文字 | — | `onband("#FF9F0A")` = `#16161A` | Settings（通用页） |
| 砖 · 唤出面板 | `command` | 无（文字字形 `⌘`） | 13px 文字 | — | `onband("#5856D6")` = `#FFFFFF` | Settings（快捷键页） |
| 快捷键冲突警告 | `exclamationmark.circle` | `<circle r="6.2"> + <path>` 内联 | 13 | 1.6 | `#FF3B30` | Settings（快捷键页） |
| 砖 · 同步（`TILE["sync"]`） | `checkmark.icloud` | `CLOUD_OK_I` | 15 | 1.6 | `onband("#0A84FF")` = `#FFFFFF` | 未出现（TILE 表已定义，同步页未画） |
| 砖 · 历史（`TILE["hist"]`） | `doc.on.clipboard` | `CLIP_I` | 15 | 1.6 | `onband("#FF9F0A")` = `#16161A` | 未出现（同上） |
| 砖 · 清空历史（`TILE["danger"]`） | `trash` | `TRASH_I` | 15 | 1.6 | `onband("#FF3B30")` = `#FFFFFF` | 未出现（同上） |
| 砖 · 隐私（`TILE["priv"]`） | 见第八节第 12 条 | 未指定（`None`） | 15 | 1.6 | `onband("#8E8E93")` = `#FFFFFF` | 未出现（同上） |
| 砖 · 关于（`TILE["about"]`） | 见第八节第 12 条 | 未指定（`None`） | 15 | 1.6 | `onband("#30B0C7")` = `#FFFFFF` | 未出现（同上） |
| 砖 · 启动（`TILE["start"]`） | 见第八节第 12 条 | 未指定（`None`） | 15 | 1.6 | `onband("#34C759")` = `#FFFFFF` | 未出现（同上） |

`TILE` 砖色全表（`gen2.py:177-181`）：`sync #0A84FF` · `key #5856D6` · `hist #FF9F0A` · `start #34C759` ·
`priv #8E8E93` · `about #30B0C7` · `danger #FF3B30`。

`onband()` 逐条实算（`gen.py:76-79`，权重 0.299 / 0.587 / 0.114，阈值 `lum > 0.62` 取 `#16161A`）——
**七种砖色里只有 `#FF9F0A` 一种落在深字一侧，其余六种全是白字**：

| 砖色 | 相对亮度 | `onband()` |
| --- | --- | --- |
| `sync #0A84FF` | 0.430 | `#FFFFFF` |
| `key #5856D6` | 0.397 | `#FFFFFF` |
| `hist #FF9F0A` | 0.670 | `#16161A` |
| `start #34C759` | 0.559 | `#FFFFFF` |
| `priv #8E8E93` | 0.559 | `#FFFFFF` |
| `about #30B0C7` | 0.550 | `#FFFFFF` |
| `danger #FF3B30` | 0.456 | `#FFFFFF` |

同一口径下来源色总表（见 2.5 来源淡染）里只有 `备忘录 #FFC300`（0.748）取深字，其余八种（含 `COLORCLIP #FF2D55`，0.441）
全取白字——与第三节 §3.3 的结论一致。

设置窗口标签栏的五个符号来自现有实现 `Copyo/Settings/SettingsView.swift:60-68 var systemImage`
（五个符号本身在 `:62-66`），本轮换肤不改：
`gearshape`（通用）· `clock.arrow.circlepath`（历史）· `arrow.triangle.2.circlepath.icloud`（同步）·
`keyboard`（快捷键）· `info.circle`（关于）。设计稿把这五项画成了分段控件而非 `TabView` 标签栏，
且顺序是「通用 / 同步 / 快捷键 / 历史 / 关于」，与代码顺序不同（见第八节第 9 条）。

### 5.4 `textformat` 的中文变体（必须处理）

`textformat` 与 `bold` / `italic` 同族，带 zh / ja / ko 本地化变体：**跟随视图 locale 时会被渲染成「格式」两个汉字**，
把富文本角标画坏。iOS 侧的修复是把 `.environment(\.locale, Locale(identifier: "en"))` 只加在这一个 `Image` 上，
右边的 `Text` 仍走当前语言。

核对后的真实现状（工作区当前文件，非 git HEAD）：

| 位置 | 现状 |
| --- | --- |
| `CopyoShared/UI/KindBadge.swift:39` | `.environment(\.locale, Locale(identifier: "en"))`，作用于 `Image(systemName: KindPresentation.symbol(kind))`（同文件 `:34`）。三行说明注释在 `:36-38`。 |
| `CopyoShared/Share/SharePreviewCard.swift:25` | **已不再自己打补丁**，改为直接用 `KindBadge(kind:sourceHex:)`，从而继承上面那一处修复。 |

全仓库 `Locale(identifier:` 只剩 `KindBadge.swift:39` 这一处。

**macOS 侧必须同样处理**：面板卡片角标、设置页、预览浮层里任何画 `textformat` 的 `Image` 都要带同一条
`.environment(\.locale, Locale(identifier: "en"))`。最省事的做法是让 macOS 复用 `CopyoShared/UI/KindBadge.swift`
本身（它只 `import CopyoCore` 与 `SwiftUI`，不碰 UIKit），修复随之自动生效；若另写一份 Mac 角标视图，
则必须把这一行一并抄过去。

### 本章待确认

> 本章相关的待确认条目：见第八节第 9、12、13、14、25、26 条。

---

## 六、样例数据

> 本节供 `-demoData`（iOS 侧已完整落地，Mac target 一处都没有，见 7.5.13）与商店截图使用。
> 字段逐字取自 `gen.py` 的 `CARDS()`、`gen2.py` 的 `kind_row` / `state_row` / `tight_row`，以及 `A-search.dc.html`。
> 「来源色」= `gen.py:64 SRC` 里的第一个值；「淡染 浅 / 深」= 第二、三个值。卡片一律 260 × 184、dense 角标。

来源色总表（`SRC` 八条 + `COLORCLIP` 一条）**不在本节重复**，见 **2.5 来源淡染**；
本节下表只引用其中的「来源色 hex」一列。

`COLORCLIP` 是**剪贴内容自身的颜色**，不是来源 App 的色：颜色类条目的角标底、右下色块、淡染全部取它，
Figma 的 `#A259FF` 在这张卡上一处都不出现。

### 6.1 面板主态五条（`gen.py:186 CARDS()`；Main.dc.html · A-panel-dark.dc.html · A-hover-toast.dc.html）

| # | 类型 | 来源名 | 来源色 hex | 相对时间（meta 整行） | 正文 |
| --- | --- | --- | --- | --- | --- |
| 1 | text | Xcode | `#147EFB` | `Xcode · 2 分钟前` | 等宽，`git rebase -i HEAD~3 && git push --force-with-lease` |
| 2 | text | 微信 | `#07C160` | `微信 · 12 分钟前` | `周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。` |
| 3 | link | Safari | `#1EA7FD` | `Safari · 25 分钟前` | 标题 `Adopting Liquid Glass | Apple Developer Documentation`；域名 `developer.apple.com`（`#0A84FF`） |
| 4 | color | Figma | `#FF2D55`（取剪贴内容本身） | `Figma · 1 小时前` | 色块 `#FF2D55`；色值胶囊文字 `#FF2D55` |
| 5 | image | 备忘录 | `#FFC300` | `备忘录 · 昨天 18:42` | 缩略图纯色填充：浅 `#F0E4BE` / 深 `#4A431F` |

正文行数上限：文本类 `-webkit-line-clamp: 7`（`body_text` 默认 `clamp=7`）；链接标题 3 行 + 域名 1 行。

A-hover-toast.dc.html 在同一批数据上叠了两处状态：第 1 张（Xcode）为 `sel="focus"`，
第 2 张（微信）为 `hover=True`；轻提示文案 `已复制 · 按 ⌘V 粘贴`。

### 6.2 搜索态两条（`gen.py:299–305`；A-search.dc.html）

搜索词 `会议`，命中处包在 `<mark>` 里：底 `rgba(10,132,255,0.22)`、`color: inherit`、圆角 3、左右内距 1px。
选中的筛选是 `文本`；结果计数行 `2 条结果`（11px，`label.meta`）；卡片轨道高 158（比主态的 184 矮）；
底部提示条右侧文案 `Esc 清空搜索 · 再按一次关闭面板`。

| # | 类型 | 来源名 | 来源色 hex | 相对时间 | 正文 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | text | 微信 | `#07C160` | `微信 · 12 分钟前` | `周五下午三点在 3 楼小`**`会议`**`室对一下 Q4 的排期，记得把上周的漏斗数据带上。` | `sel="focus"` |
| 2 | text | 备忘录 | `#FFC300` | `备忘录 · 昨天 09:12` | `站`**`会议`**`纪要 9/4` ⏎ `· 登录页流程另开一稿` ⏎ `· 图标最终稿 8a 已定` ⏎ `· TestFlight 周三发` | 默认 |

注意第 1 条的正文是主态第 2 条的**截短版**（末句「顺便看看新江湾那边场地的报价。」被去掉），两者不可互换。

### 6.3 卡片组件板 · 六种类型（`gen2.py:36 kind_row()`；Card.dc.html，浅色一行 + 深色一行）

| # | 类型 | 来源名 | 来源色 hex | 相对时间 | 正文 | 板上说明文字 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | text | Xcode | `#147EFB` | `Xcode · 2 分钟前` | 等宽，`git rebase -i HEAD~3 && git push --force-with-lease`（clamp 7） | `文本 · 代码用等宽 11/15` |
| 2 | rich | 备忘录 | `#FFC300` | `备忘录 · 09:12` | `站会纪要 9/4` ⏎ `· 登录页流程另开一稿` ⏎ `· 图标最终稿 8a 已定` ⏎ `· TestFlight 周三发`（clamp 7） | `富文本 · 角标是最宽的中文` |
| 3 | link | Safari | `#1EA7FD` | `Safari · 25 分钟前` | 标题 `Adopting Liquid Glass | Apple Developer Documentation`；域名 `developer.apple.com` | `链接 · 标题 + 域名用 accent` |
| 4 | image | 备忘录 | `#FFC300` | `备忘录 · 昨天 18:42` | 缩略图填充 浅 `#F0E4BE` / 深 `#4A431F` | `图片 · 缩略图圆角 10` |
| 5 | color | Figma | `#FF2D55`（取剪贴内容本身） | `Figma · 1 小时前` | 色块 + 色值胶囊 `#FF2D55` | `颜色 · 淡染取剪贴内容本身` |
| 6 | file | 访达 | `#1EA7FD` | `访达 · 昨天 18:02` | 三方块堆叠（第三块 `#1EA7FD`）+ 首文件名 `Q3-复盘.key` + 附注 `另外 4 个文件` | `文件 · Mac 独有的多文件堆叠` |

深色行的板上小标题：`六种类型 · 深色`，附注 `底色从 #1C1C1E 抬到 #2C2C2E，20% 淡染才分得出来`。

同板的「状态」行（`gen2.py:50 state_row()`）六张卡用的是**同一条数据**——
text / 微信 / `#07C160` / `微信 · 12 分钟前` / 正文同 6.1 第 2 条——只换状态：

| 状态 | 板上说明文字 |
| --- | --- |
| 默认 | `默认` |
| `hover=True` | `悬停 · 玻璃动作簇 pin / delete` |
| `sel="select"` | `选中 · 面板是 key window，3pt accent` |
| `sel="key-inactive"` | `选中 · 面板失焦，降到 45% —— macOS 才有的态` |
| `sel="focus"` | `键盘焦点 · 2pt + 5pt @32%` |
| `sel="lift"` + `pinned=True` | `拖起 · rotate −2° scale 1.03 + 已固定图钉` |

### 6.4 排版最紧的四条（`gen2.py:63 tight_row()`；Card.dc.html 末行）

| # | 类型 | 来源名（决定角标底色） | 来源色 hex | meta 整行 | 正文 | 板上说明文字 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | rich | 备忘录 | `#FFC300` | `Microsoft Word · 昨天 18:42` | `第三季度复盘（终稿）—— 渠道、留存、以及那三个没做完的实验。`（clamp 6） | `最紧：富文本角标 44pt + 长来源名。meta 行省略号从来源名开始吃，时间永不被截`〔见表下更正〕 |
| 2 | rich | 备忘录 | `#FFC300` | `Word · 昨天` | `第三季度复盘（终稿）`（clamp 6） | `同一张卡的宽松情形` |
| 3 | text | 本机 | `#8E8E93` | `本机 · 3 分钟前` | `这条是 iPhone 上存进来的，没有来源色，回退到中性灰 #8E8E93。`（clamp 6） | `无来源色回退 —— iOS 存进来的条目在 Mac 上长这样` |
| 4 | text | Xcode | `#147EFB` | `Xcode · 2 分钟前` | 等宽，`Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value`（clamp 7） | `等宽长行按词断，不横向滚动` |

〔更正〕第 1 条的题注含两处已知错误，逐字保留仅为记录原文：「44pt」实为 **54pt**
（5 + 10 + 3 + 30 + 6，见第八节第 36 条）；「从来源名开始吃」是**目标行为**而非画板行为——
画板上 meta 是单个套 `text-overflow: ellipsis` 的 span，实际从尾部截，被吃掉的是时间（见 §3.3 与第八节第 37 条）。

第 1、2 条的来源键都是「备忘录」，但 meta 行写的是 `Microsoft Word` / `Word`——
这是刻意让角标底色（`#FFC300`）与 meta 文本脱钩，用来测最长来源名下的省略行为。

### 6.5 设置页文案清单（`gen2.py:176–271`；Settings.dc.html）

窗口 540 × 460、圆角 11；标题栏高 38、居中标题 `设置`；分段控件
`通用` / `同步` / `快捷键` / `历史` / `关于`。画板只画了「通用」与「快捷键」两页。

**通用页**

| 区 | 行 | 图标砖色 | 值 / 副文 |
| --- | --- | --- | --- |
| 组标题 `启动` | `登录时启动 Copyo` | `#34C759` | 无 |
| | `在菜单栏显示图标` | `#8E8E93` | 无 |
| 组标题 `捕获` | `自动记录剪贴板` | `#0A84FF` | 副文 `Copyo 在后台记录，不需要任何权限` |
| | `忽略密码管理器` | `#FF9F0A` | 副文 `来自 1Password、钥匙串的内容不会被记录` |

页脚说明（宽 460、11/16、`label.meta`）：
`复制后 Copyo 把内容写回系统剪贴板并把焦点交还给原来的 App，由你自己按 ⌘V —— Copyo 从不代你粘贴。`

**快捷键页**

- 组标题 `唤出`，附注 `点一下可以改`。
- 唤出行：图标砖 `#5856D6` + 字形 `⌘`，标题 `唤出面板`，右侧录制按钮 `⇧⌘V`
  （min-width 88、高 26、圆角 7、底 `bg.card`、`box-shadow: 0 0 0 2px #0A84FF`、等宽 12 Medium）。
- 冲突提示行（11px、`#FF3B30`）：`这个组合已被另一个 App 占用，Copyo 收不到它`。
- 组标题 `面板内`，九行（`gen2.py:241 key_rows` 去掉首行「唤出面板」后的全部）：

| 动作 | keycap |
| --- | --- |
| 复制选中项 | `↩` |
| 纯文本复制 | `⇧↩` |
| 预览 | `空格` |
| 固定到 Pinboard | `⌘P` |
| 删除 | `⌘⌫` |
| 聚焦搜索 | `⌘F` |
| 在筛选间循环 | `⇥` |
| 直接取第 N 张卡 | `⌘1–9` |
| 关闭面板 | `esc` |

画板底部两条说明文字（白 70%）：
`通用 · 540 × 460，结构不动，只换行样式与彩色图标砖`；
`快捷键 · 商店截图 04 就是这一页；keycap 转为共享组件，并补上「快捷键被占用」这个今天完全不存在的失败态`。

### 6.6 商店截图的启动参数与作废范围（`scripts/make-store-shots.py`）

现有启动参数（实现位置已核对工作区当前文件）：

| 参数 | 作用 | 实现位置 |
| --- | --- | --- |
| `-forceDark` | 强制深色外观 | `Copyo/App/AppDelegate.swift:89` |
| `-showSettings` | 启动即打开设置窗口 | `Copyo/App/AppDelegate.swift:92` |
| `-showPanel` | 启动即拉起面板（省去模拟 ⇧⌘V） | `Copyo/App/AppDelegate.swift:95` |
| `-settingsTab <0-4>` | 指定设置窗口初始标签页 | `Copyo/Settings/SettingsView.swift:13` |
| `-demoSearch <词>` | 预置搜索词 | `Copyo/Panel/PanelRootView.swift:15` |
| `-demoPreview` | 启动即打开预览 | `Copyo/Panel/PanelRootView.swift:20` |
| `-opaquePanel` | 面板底换成平涂纯色（无背景捕获时毛玻璃会渲染成灰条） | `Copyo/Panel/PanelRootView.swift:58` |

八张图 = 2 语言 × 4 张（`make-store-shots.py:55 TEXT`），输出到 `art/store/<名称>-<lang>.png`，
采集文件名 `ui_<编号>_<lang>.png`：

| 编号 | 采集参数 | kind | 中文主标题 / 副标题 | 英文主标题 / 副标题 |
| --- | --- | --- | --- | --- |
| 01-panel | `-forceDark -opaquePanel -showPanel` | panel | `复制过的一切，随叫随到` / `按下 ⇧⌘V，剪贴板历史从屏幕底部滑出` | `Everything you copied, one key away` / `Press ⇧⌘V — your clipboard history slides up` |
| 02-search | 同上 + `-demoSearch Q3` | panel | `即输即搜` / `按内容、来源应用、文件名过滤，不用先点搜索框` | `Type to filter` / `Search by content, source app or file name — no clicking first` |
| 03-preview | 同上 + `-demoPreview` | panel | `空格，先看一眼` / `大图预览文本、图片和文件，不用离开面板` | `Space to peek` / `Preview text, images and files without leaving the panel` |
| 04-shortcuts | `-forceDark -showSettings -settingsTab 3` | window | `手不离键盘` / `呼出、导航、复制、预览，全程快捷键；⇧⌘V 可自定义` | `Hands stay on the keyboard` / `Summon, search, copy, preview — and ⇧⌘V is yours to remap` |

合成版式（`make-store-shots.py:43–54`）：画布 2560 × 1600；图标 `(1194, 179)` 175 × 175；
主标题顶 448、副标题顶 590；主标题色 `(255,255,255)`、副标题色 `(190,192,197)`；
`kind == "panel"` 的截图按画布宽满宽贴底，`kind == "window"` 贴进 `WINDOW_RECT = (870, 738, 820, 689)`。

**两条硬约束：**

1. **04 号图拍的就是设置 > 快捷键页。** `-settingsTab 3` 按 `Copyo/Settings/SettingsView.swift:48`
   的 `case general, clipboard, sync, shortcuts, about` 数到 `shortcuts`。所以**设置换肤会连带作废这一整组
   8 张截图**——04 直接变样，01–03 也因为同一批必须在同一台机器、同一次采集里出（面板高度固定、屏幕越宽贴出来越扁，
   见 `make-store-shots.py:132–135`）而不能只补拍一张。
2. **`-opaquePanel` 要求每一种新材质都有平涂等价物。** 今天它是一个硬编码色：
   `Copyo/Panel/PanelRootView.swift:59` 的 `Color(red: 0.078, green: 0.066, blue: 0.098)`（≈ `#141119`），
   与 `VisualEffectView(material: .hudWindow)` 配对。新语言下这个平涂值应改为 `bg.grouped` 的深色值 **`#1C1C1E`**；
   面板外壳、悬停动作簇、轻提示这三处玻璃各自都要给出对应的平涂替身，否则 `-opaquePanel` 下会出现玻璃灰条。

另：副标题不得承诺应用做不到的事——1.0 (4) 移除自动粘贴后，初版截图里的
`then ↩ to paste` / `↩ 直接粘贴` / `粘贴` 全部作废（2.4.5 拒审点）。本节文案已是修订后的版本，
任何形似「粘贴按钮」的表达都不得重新出现。

### 本章待确认

> 本章相关的待确认条目：见第八节第 9、10、39、40 条；
> `-demoData` 在 Mac 端的移植属工程工作，见 7.5.13。

---

## 七、实现映射备注

本节按文件给出改动清单。引用**已删除**的文件时会就地注明 —— 那类路径 `git show HEAD:` 取不到，
要用删除它的提交，例如 `git show 0cda755^:CopyoShared/Share/ShareTheme.swift`。
Mac target `Copyo` 的同步组只有 `Copyo/` 一个目录（`Copyo.xcodeproj/project.pbxproj:182-184`），
所以下表之外的目录（`CopyoShared/`、`CopyoIOS/`）今天对 Mac 不可见。
规模口径：**S ≈ 半天，M ≈ 1–2 天，L ≈ 3 天以上**。

### 7.1 现有文件改动清单

| 文件（`Copyo/` 下） | 今天是什么 | 本轮要变成什么 | 规模 |
| --- | --- | --- | --- |
| `Panel/PanelRootView.swift`（434 行） | 顶栏一行 16/10 内距（`:164-165`）：Pinboard 标签胶囊（`:168-181`，12pt、选中 `Color.primary.opacity(0.14)`）+ 24×24 `plus` 圆钮（`:133-141`）+ 固定 240pt 宽搜索框（`:183-211`，radius 8、`Color.primary.opacity(0.08)`）+ `#if APPSTORE` 齿轮（`:148-162`）。**无类型筛选**。主体 `ScrollView(.horizontal)` + `LazyHStack(spacing: 14)`（`:221-229`），水平内距 16、底部 16。顶部 1pt `Color.primary.opacity(0.12)` 发丝线（`:66-68`）。空态是 36pt `doc.on.clipboard` SF Symbol + 13pt + 11pt 三行居中（`:288-303`）。**无底部提示条、无 Toast**。全部键盘事件挂在搜索框的 `.onKeyPress`（`:193-195`），并用 `onChange(of: searchFocused)` 强行夺回焦点（`:92-97`） | 拆成外壳 + 顶栏 + 筛选 + 轨道 + 提示条五层。顶栏改两行：row1 高 32（搜索框 flex-grow、radius 8、`fill`、左右内距 10、图标 14/1.6、文字 13；右侧 32×32 radius 8 同步按钮与 32×32 齿轮，图标 17/1.5），行间 10，row2 高 26（6 项筛选 chips，chip 高 26 / radius 8 / 12pt，选中 `#0A84FF` 底 + `#FFFFFF` 600，未选中 `fill` 底 + `label` 500，chips 间距 6；右端「Pinboard」带 chevron 的 chip，内距 `0 9px 0 11px`）。轨道 gap 12、行高 184。轨道与提示条间距 12。底部提示条高 24、组间距 14：`↩ 复制` / `空格 预览` / `⌘P 固定` / `⌘⌫ 删除`，右端 11pt `sec` 文案「复制后回到原来的 App，按 ⌘V 粘贴」。搜索态在顶栏与轨道之间插一行 11pt `meta` 的「N 条结果」（高 18，上下各 12 / 8），轨道降到 158。空态改为 96×96 品牌插画板 + 24 间距 + 右侧 17pt/700 标题、12/17 `meta` 正文、11pt `sec` + `⇧⌘V` keycap 提示（详见第三、四节）。删掉顶部发丝线（外壳改为浮动圆角后不再需要）。焦点模型从「永远焦点在搜索框」改为 search / cards / filters 三态 | **L** |
| `Panel/CardView.swift`（200 行） | 固定 224×268（`:10-11`）；`RoundedRectangle(cornerRadius: 12)` **非 `.continuous`**（`:28、:30`）；42pt 实色头带 + 白色来源名 12pt/600 + 24pt 真实应用图标（`:51-69`）；内容区底色 `Color(nsColor: .textBackgroundColor)`（`:24`）；26pt 灰页脚「类型 · 字符数 / 相对时间」（`:188-199`，`.windowBackgroundColor` 底）；仅 `isSelected` 一个状态（`:31-32`，3pt `Color.accentColor` / 1pt `Color.primary.opacity(0.1)`）；阴影 `radius 6, y 2`（`:34`）；`relativeFormatter` 是 `static let`（`:13-17`），视图不重绘时相对时间**冻结**；**正文今天没有 `lineLimit`** —— `textContent`（`:89-105`）只有 `.frame(maxWidth:maxHeight:alignment: .topLeading)`（`:102`）+ `.padding(10)`（`:103`）+ `.clipped()`（`:104`），靠**裁切**收场，末行会被切成半行；唯一的长度上限是 `:96` 的 `String((item.plainText ?? "").prefix(400))`，是字符数截断，不是行数截断；带 RTF 的富文本走 `:94` 的 `Text(AttributedString(...))`，连这 400 字都不过 | 重写为 260×184、内距 12、radius 12 `.continuous`、整卡淡染来源色（浅 mix 12% 入 `bg.card`，深 mix 20% 入 `bg.card`），列间 gap 8。头行高 18、gap 6：dense `KindBadge`（高 18、字 10/600、图标 10、gap 3、内距左 5 右 6、radius 9、底色 = 来源色本身、前景走 `onBand`）+ 单行 10pt `meta` 的「来源 · 相对时间」（省略号从来源名开始吃）+ 可选 11/1.6 图钉。底行高 20，右对齐 20×20 radius 5 的来源色方块（描边 `swatchring`）。**删掉 42pt 头带、删掉 24pt 应用图标、删掉页脚整条**（字符数移进预览浮层）。五个状态：默认 `cring`；选中（面板为 key window）`0 0 0 3px #0A84FF`；选中但面板失焦 `0 0 0 3px rgba(10,132,255,0.45)`；键盘焦点 `0 0 0 2px #0A84FF, 0 0 0 7px rgba(10,132,255,0.32)`；拖起 `rotate(-2deg) scale(1.03)` + `cring, 0 12px 32px rgba(0,0,0,0.28)`。悬停动作簇：右 8 上 8、高 28、内距 `0 3px`、radius 9、玻璃底 + `ring, 0 2px 8px rgba(0,0,0,0.14)`，内含两枚 24×24 radius 7 按钮（固定 = accent 图钉 14/1.5，删除 = `destructive` 垃圾桶 14/1.5）。正文按类型分六种：文本 12/16（代码 11/15 等宽）、clamp 7（`gen.py:149-153` 的 `body_text`，`-webkit-line-clamp: %d`）。**这是一次行为变更，不是换个数**：今天是 `.clipped()` 裁切，末行呈现为「半行被切」；改成行数截断后末行变成「整行 + 省略号」，SwiftUI 侧对应 `.lineLimit(7) + .truncationMode(.tail)`。同时 `:96` 那个 `prefix(400)` 的字符上限要重新评估（行数截断之后它只剩性能意义）。另需**重新估算 260 × 184 的正文区到底放得下几行 12/16**：卡内距 12、头行 18、底行 20、列间 gap 8 × 2，正文净高 = 184 − 12×2 − 18 − 20 − 8×2 = **106pt**（卡是 `flex-direction: column; gap: 8px`，三个在流子元素两道 gap），按 16pt 行高只装得下 **6 行**（6.625 行），clamp 7 在满行时第 7 行会被卡片自身的高度限制切掉 —— 画板上因为样例文案不够长看不出来。clamp 取 6 还是保留 7 并接受最后一行被容器裁切，见第八节第 38 条；链接 12/16 500 标题 + 11/15 accent 域名；颜色 radius 10 色块 + 高 22 radius 11 `fill2` 底的等宽 11/600 hex 胶囊；图片 radius 10 缩略图；文件 46×38 三层堆叠（30×30 radius 7，偏移 (0,6)/(7,3)/(14,0)）+ 12/16 clamp 2 文件名 + 11pt `meta` 的「另外 N 个文件」。相对时间改为定时重算 | **L** |
| `Panel/PanelController.swift`（147 行） | `panelHeight = 380`（`:15`）；从 `screen.frame` 的 `minX/minY` 起算、全屏宽、贴底方角（`:79-82`）；`styleMask [.borderless, .nonactivatingPanel]`（`:30`）、`level = .statusBar`（`:36`）、`hasShadow = true`（`:40`）；出现 0.22s easeOut、收起 0.18s easeIn（`:88-89、:103-104`）；`screenWithMouse()` 按鼠标所在屏（`:130-133`）；`windowDidResignKey` 自动收起（`:137-141`）；复制后 `hide(reactivatePrevious: true)` 把焦点交还原应用（`:124-127`） | 几何改为**内缩浮动**：从 `screen.visibleFrame` 内缩（不是 `screen.frame`，否则压 Dock），面板 radius 26。设计稿的画板尺寸是 1280 × 332（内距 16），所处桌面框 1440 × 520、面板左上角 (80, 92)。圆角后 `hasShadow = true` 的系统阴影会沿窗口矩形画，需改为透明窗口 + 自绘阴影（`0 1px 3px rgba(0,0,0,0.10), 0 24px 56px rgba(0,0,0,0.30)`）与 0.5px `ring` 描边。**保留** `.statusBar` 层级、`screenWithMouse()`、0.22/0.18 两条曲线、`resignKey` 自动收起、复制后交还焦点这条链路。多显示器下的宽度上限与内缩量需按 `visibleFrame` 重定 | **M** |
| `Panel/PreviewOverlay.swift`（102 行） | 固定 680×320（`:20`）；`.regularMaterial` + radius 14 + 1pt `Color.primary.opacity(0.15)` 描边（`:21-25`）；30pt 高页脚「来源 / 类型 · 字符数 / 绝对时间」11pt（`:88-101`）；内容在这里**第二次**实现，但只有**四个分支**（`previewContent`，`:30-78`：`.image` / `.color` / `.file` / `default`，文本与富文本合并在 `default` 里，`:64-71` 再按有无 RTF 分两路），不是六种 —— `CardView.content` 那边是 5 个分支。**这也正是「降级态缺失」只出现在 `.image` 一个分支的原因**（`:34` 的 `if let` 解不出图时整块渲染为空，没有兜底占位）；遮罩 `Color.black.opacity(0.35)`（`:12`） | 内容渲染改为复用同一套卡片正文（regular 档），只保留浮层外壳。承接从卡片页脚删掉的字符数统计。外壳 radius 与面板体系对齐（面板 26 / 卡片与预览块 12 / 缩略图与色块 10）。今天没有目标设计帧，尺寸与页脚版式见第八节第 2 条 | **M** |
| `Panel/VisualEffectView.swift`（20 行） | 20 行的 `NSViewRepresentable`，默认 `material: .hudWindow`、`blendingMode: .behindWindow`、`state: .active` | 结构不动。面板外壳改浮动圆角后需要 `maskImage` 或外层 `clipShape` 才能让材质跟着 radius 26 裁切；卡片**不透明**，不得使用这个视图 | S |
| `Settings/SettingsView.swift`（617 行） | `TabView` 五页，顺序为**英文原串** `General` / `Clipboard` / `Sync` / `Shortcuts` / `About`（即 通用 / 历史 / 同步 / 快捷键 / 关于，`:22-38`、`:47-56`；标签当前未中文化，中文化在本地化阶段做）；每页 `Form` + `.formStyle(.grouped)`；窗口尺寸 `SettingsLayout.width`（按最长标签标题实算，下限 540）× `height = 400`（`:73-94`）；所有说明文字硬编码 `.font(.system(size: 12))`；`ShortcutsSettingsView` 的固定快捷键表是 7 行（`:503-511`），键帽是 `Color.primary.opacity(0.08)` + radius 5（`:549-551`）；`AboutView` 图标 48pt、标题 22pt/bold（`:603-606`）；**无彩色图标砖、无快捷键占用失败态** | 换肤，结构大体不动。窗口 540 × 460。顶部 38pt 标题栏（玻璃底 + 0.5px `separator` 下边线 + 居中 13/600「设置」）。标签改为居中分段控件：容器内距 3、radius 8、`fill` 底、项间 2；每项高 24、内距 `0 12px`、radius 6、12pt，选中项 `bg.card` 底 + `0 1px 2px rgba(0,0,0,0.12)` + 600。内容区内距 `12 16 16`、组间 14。分组：radius 10、`bg.card` 底、`cring` 描边、行内 0.5px `separator` 分隔。设置行：最小高 40、内距 `7px 12px`、gap 10、主文 13pt、副文 10/14 `ter`、右值 12pt `meta`。行首 26×26 radius 7 彩色图标砖（符号 15/1.6，前景走 `onBand`）：同步 `#0A84FF`、快捷键 `#5856D6`、历史 `#FF9F0A`、启动 `#34C759`、隐私 `#8E8E93`、关于 `#30B0C7`、危险操作 `#FF3B30`。开关 38×22 radius 11、滑块 18 radius 9 白 + `0 1px 3px rgba(0,0,0,0.2)`、开启态 `#34C759`。小节标题 11pt/600、字距 0.4、高 20、`label.secondary`。快捷键页：录制按钮最小宽 88、高 26、内距 `0 10px`、radius 7、`bg.card` 底 + `0 0 0 2px #0A84FF`、等宽 12/500；其下补一行 11pt `destructive` 的**占用失败态**（13/1.6 警示图标 + 「这个组合已被另一个 App 占用，Copyo 收不到它」）；面板内快捷键表从 7 行扩到 9 行（行高 34、内距 `0 12px`），keycap 统一为最小宽 20、高 20、内距 `0 5px`、radius 6、`fill2` 底、等宽 11/500、`meta` 前景。设计稿的标签顺序是 通用 / 同步 / 快捷键 / 历史 / 关于，与代码现序不同（见第八节第 9 条）。`AboutView` 标题 22pt → 17pt | **M** |
| `Settings/SettingsWindowController.swift`（25 行） | `NSWindow(contentRect: … width: SettingsLayout.width, height: 440)`（`:9`），`styleMask [.titled, .closable]`，`window.center()` 后 `makeKeyAndOrderFront`（`:19-24`）。注意窗口高 440 与 `SettingsView` 内容 `.frame(height: 400)` 不一致 | 高度统一到设计稿的 460（内容与窗口取同一个常数，消除 440/400 的分叉）。`styleMask` 不变 | S |
| `Models/ClipKind+Label.swift`（16 行） | 六个 `String(localized:)`，`.richText` 的**英文原串**是 **`"Rich Text"`**（`:9`，中文译文「富文本」，见 `Copyo/Localizable.xcstrings:1477`）。**没有 SF Symbol 映射**（Mac 今天用应用图标代替类型符号） | 英文原串 `"Rich Text"` → `"Rich"`，中文译文仍是「富文本」，不变（见 7.4.4）。若采纳 7.3 的共享层建议，整个文件被 `CopyoShared/UI/KindPresentation.swift` 取代；否则需在本文件旁补一份与之逐字一致的符号映射，供新的 `KindBadge` 使用 | S |
| `Services/AppIconProvider.swift`（66 行） | 图标与来源色的唯一产地。`fallbackColor = NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1)`（`:10`）；`headerColor(forBundleID:)` 带字典缓存（`:26-32`）；`dominantColor(of:)` 12×12 粗采样、跳过 `brightness > 0.92 \|\| < 0.08` 的像素、末尾把饱和度 `×1.25 + 0.08`、亮度压到 `[0.35, 0.75]`（`:35-65`） | 采样与提纯算法**不动**（卡片淡染与角标底色都依赖它的输出分布）。两处要改：`fallbackColor` 统一到两端同一个 `#8E8E93`（`source.local`，见 7.4.7）；24pt 应用图标不再进卡片，`icon(forBundleID:)` 的调用点只剩预览浮层与（可能的）文件卡片 | S |
| `Services/HotkeyManager.swift`（161 行） | Carbon `RegisterEventHotKey` 注册（`:119-132`）。**`RegisterEventHotKey` 的返回值被丢弃**（`:126-131` 没有接 `OSStatus`），所以「组合已被别的 App 占用」这个失败今天**完全不存在**，用户只看到按了没反应。`displayString` 产出 `⇧⌘V` 这类展示串（`:51-58`）；`specialKeyNames` 已含 `⌫ ⌦ ⎋ ↩ ⇥` 等（`:66-76`） | 接住 `RegisterEventHotKey` 的 `OSStatus`，把失败向上抛给设置页的占用提示行。`HotkeyConfig.default` 仍是 `⇧⌘V`（`:9-10`），不变。展示串与 keycap 组件共用同一份字形（`⌘P` / `⌘⌫` / `⇧↩` / `⇥` / `esc`） | S |
| `Services/ClipboardMonitor.swift`（184 行） | 0.3s 轮询 `changeCount`（`:23`）；过滤 `org.nspasteboard.{Concealed,Transient,AutoGenerated}Type`（`:12-14、:59-61`）；**采集时就把来源色算成 hex 存进条目**：`let colorHex = AppIconProvider.headerColor(forBundleID: bundleID).srgbHexString`（`:76`，注释在 `:74-75`）；文本优先于图片（`:90-102`）；去重时连 `sourceColorHex` 一起刷新（`:153`） | 采集链路本身不改。唯一的设计相关改动在 7.4.7：当 `bundleID == nil` 时是否改写 `nil`（让两端走同一条回退分支），还是继续烤一个具体 hex 进行里。**颜色类条目的淡染改取内容自身颜色（7.4.2）不在这里落地** —— `sourceColorHex` 仍然记录来源 App 的色，取舍发生在卡片渲染层 | S |

**下列文件本轮不改，列出以免被顺手动到**：`Services/NSColor+Hex.swift`（14 行，`srgbHexString`，`:8-13`）、
`Services/PasteService.swift`（49 行，写回剪贴板，`:14-15` 读 `plainTextPaste`）、`Services/ThumbnailCache.swift`（33 行）、
`Services/SyncService.swift`（356 行）、`Services/SyncMode.swift`（98 行）、`App/CopyoApp.swift`（13 行）。
`App/AppDelegate.swift`（251 行）本轮只动两处：状态栏图标与右键菜单（`:164-217`）、首启 `NSAlert` 欢迎（`:125-155`，
商店版 / 直分发版两套 bullet 在 `:128-148`）**都不在本轮范围**。关于后者：iOS 侧有成形的引导页设计
（iOS 规格 §3.9：插图容器 180 × 180 radius 44、标题 28/34 Bold、说明行 radius 12 + 36 × 36 图标砖、
页码点 7 × 7、CTA 高 52 radius 26），macOS 是按它降档重做、还是维持 `NSAlert` 只做中文化，本轮未定——
见第八节第 47 条。此外，
但菜单里的「清空历史」确认框（`:231-`）用到的文案要与设置页的危险操作行对齐。

### 7.2 本轮新增的文件

| 新文件 | 内容 | 规模 |
| --- | --- | --- |
| `Panel/KindBadge.swift`（或由 7.3 的共享层提供） | dense 档类型角标：高 18、字 10/600、图标 10、gap 3、内距左 5 右 6、radius 9；底色 = 来源色本身，前景 = `onBand(来源色)` | S |
| `Panel/KeyCap.swift`（或由共享层提供） | 最小宽 20、高 20、内距 `0 5px`、radius 6、`fill2` 底、等宽 11/500、`meta` 前景。面板提示条与设置页快捷键表共用 | S |
| `Panel/PanelHintBar.swift` | 底部提示条：高 24、组间距 14、右端 11pt `sec` 说明文案 | S |
| `Panel/FilterChips.swift` | 6 项筛选（全部 / 文本 / 链接 / 图片 / 颜色 / 文件）+ 右端 Pinboard 下拉 chip；口径与 `KindPresentation.matches` 一致 | M |
| `Panel/HoverActionCluster.swift` | 卡片右上角的玻璃动作簇（固定 / 删除） | S |
| `Panel/CopyToast.swift` | 「已复制 · 按 ⌘V 粘贴」：高 36、内距 `0 16px`、radius 18、玻璃底 + `ring, 0 6px 20px rgba(0,0,0,0.18)`、13/500、前置 14/2 的 `success` 对勾；水平居中，垂直定位是**画板底 60px**（`gen.py:284` 的 `bottom: 60px`，参照系是 `A-hover-toast` 那张 1360 × 452 的画板，**不是** 1280 × 332 的面板）。换算后它压在面板下沿上、向下越出约 20pt（画板坐标 y 356–392，面板下沿 y 372）。**轻提示的实现基准（挂在面板内还是另开一个窗口）见第八节第 6 条** | S |
| `Panel/EmptyStatePlate.swift` | 96×96 radius 22 的品牌插画板（`brand.bone` 底 + `0 8px 24px rgba(0,0,0,0.12)`，内含 `brand.red` / `brand.blue` / `brand.ink` 条）；三种空态共用 | S |
| `Panel/NewPinboardAlert.swift` | 「新建 Pinboard」的输入弹窗。今天它是**面板内的 SwiftUI `.alert`**（`PanelRootView.swift:108-117`：`.alert("New Pinboard", isPresented: $showNewPinboardAlert)` + `TextField("Name")` + `Create` / `Cancel` + message `Pinboards keep the clips you use most within reach`，全部为**英文原串**，中文化待做），不是 `NSAlert`；正因为它在面板里弹，才需要 `:98-107` 的 `suppressAutoHide` + `makePanelKey()` 那套补丁（`PanelController.swift:23` 的 `var suppressAutoHide = false`）。它的入口是第一章 §03 右键菜单里「固定到 Pinboard → 分隔线 → 新建 Pinboard…」。**视觉归属本轮未定**（系统 alert 原样 / 按 iOS 规格 3.11 的 Alert 降 macOS 档 / 改成面板内联输入行），设计稿十张画板里没有画它 —— 见第八节第 20 条。**落地顺序**：必须**先**把 `suppressAutoHide` 从 `Bool` 改成计数（第四节 §4.1.3 第 3 条），**再**动这个 alert 的视觉；否则一旦改成内联输入行或叠第二层浮层，两处同时置位/复位会把这个布尔冲掉，面板在输入途中被 `resignKey` 收走 | S |
| `UI/CopyoTheme+macOS.swift`（若不走 7.3） | Mac 侧的 token 落地：语义色、淡染与 `onBand` 数学、radius 表（26 / 12 / 10 / 8 / 9 / 6）、字号表 | M |

### 7.3 共享 token 层（**建议，尚未拍板**）

**现状是两套，不是三套。** 2026-09-20 的重构已经把手抄稿删掉了：

- `CopyoShared/UI/CopyoTheme.swift`（231 行）—— 唯一的 theme，`import UIKit`（`:2`），由
  **iOS App + 分享扩展 + Widget** 三个 target 共用。文件头注释（`:9-12`）原文记下了这段历史：
  *「放在 `CopyoShared/` 而不是 `CopyoIOS/UI/`：分享扩展与 Widget 编译不到主应用的 target，
  此前的办法是在 `CopyoShared/Share/ShareTheme.swift` 里按 design-spec 第二节重抄一份，
  于是改一个 token 要记得改两处……那份手抄稿已删。」**`CopyoIOS/UI/Theme.swift` 与
  `CopyoShared/Share/ShareTheme.swift` 两个文件今天都已不存在。**
  同一轮里 `KindPresentation`（53 行）与 `KindBadge`（59 行）也移进了 `CopyoShared/UI/`，
  两份手抄的 `ShareKindPresentation` / `ShareKindBadge` 一并删除（见两份文件的头注释与 `docs/ios-plan.md` 第 3.5 节）。
- `Copyo/`（Mac target）—— **没有 theme**。`Copyo.xcodeproj` 的同步组已核实：
  `Copyo → [Copyo]`、`Copyo iOS → [CopyoIOS, CopyoShared]`、`CopyoShareExtension → [CopyoShareExtension, CopyoShared]`、
  `CopyoWidgets → [CopyoWidgets, CopyoShared]`（`project.pbxproj:182-184、208-211、232-235、256-259`）。
  所以 `Copyo/Panel/` 里全是字面量：`Color(nsColor: .textBackgroundColor)`（`CardView.swift:24`）、
  `Color.primary.opacity(0.08 / 0.1 / 0.12 / 0.14)`、`.font(.system(size: 10 / 11 / 12 / 13))` 等。

**建议：不新建 `CopyoUI` target，而是把 `CopyoShared/UI/` 扩成三端共用** —— 在 `Copyo.xcodeproj` 里给
Mac target 的 `fileSystemSynchronizedGroups` 加上 `CopyoShared`（与 iOS 三个 target 同一行写法），
再解掉 `CopyoTheme` 的 UIKit 依赖。承载内容：token（色 / 圆角 / 度量 / 字号）、tint 与 onBand 数学、
`KindPresentation`、`KindBadge`、`ClipCard`、`Toast`、`KeyCap`、空态插画。

**可行性证据（已逐个打开核对）**：

| 文件 | 行数 | `import UIKit` | 出现 UIKit 类型的行 |
| --- | --- | --- | --- |
| `CopyoIOS/UI/ClipCard.swift` | 376 | 无（只 `import CopyoCore` + `SwiftUI`，`:1-2`） | **1 行**：`:232` 的 `Image(uiImage: thumbnail)`，而 `thumbnail` 来自 `CopyoIOS/Model/ClipItem+Display.swift:185`（`var thumbnail: UIImage?`） |
| `CopyoShared/UI/KindBadge.swift` | 59 | 无 | **1 个表达式**：`:49` 的 `Color(uiColor: CopyoTheme.uiColor(…) ?? CopyoTheme.sourceLocalUI)` |
| `CopyoShared/UI/KindPresentation.swift` | 53 | 无（只 `CopyoCore` + `SwiftUI`） | 0 —— 已经跨平台 |
| `CopyoIOS/UI/Toast.swift` | 97 | 无 | 0 |
| `CopyoIOS/UI/EmptyState.swift` | 50 | 无 | 0 |
| `CopyoIOS/UI/MasonryGrid.swift` | 67 | 无 | 0 |
| `CopyoIOS/UI/GlassPill.swift` | 42 | 无 | 0 |

`CopyoIOS/UI/` 十个文件里只有 `PasteBanner.swift:2` 一处 `import UIKit`（它包的是 `UIPasteControl`，本来就不跨平台，不进共享层）。

**三个必须解掉的障碍**：

1. **动态色的构造**。`CopyoTheme.dynamicUIColor(light:dark:)` 用的是
   `UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }`（`CopyoTheme.swift:32-34`），
   macOS 对应写法是 `NSColor(name:dynamicProvider:)`，暗色判定走
   `appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua`。全文件 30 余个色都经由这一个入口，
   改一处即可。
2. **`getRed` 的色彩空间陷阱**。`CopyoTheme.mix(_:into:fraction:)`（`:121-131`）与
   `onBandUIColor(source:)`（`:134-139`）都直接调 `source.getRed(&r, …)`。
   `NSColor.getRed(_:green:blue:alpha:)` 在**非 sRGB 色彩空间会 trap**，而**动态 `NSColor` 根本转不了色彩空间**。
   所以移植后每个调用点在取分量前必须先 `usingColorSpace(.sRGB)`，并且
   `tintUIColor(source:)`（`:111-114`）「两个 `mix` 结果再合成一个动态色」的写法必须保留 ——
   `mix` 只能收具体色，不能收动态色。`Copyo/Services/AppIconProvider.swift:47` 今天已经是
   `rep.colorAt(…)?.usingColorSpace(.sRGB)` 的正确写法，可直接照抄这条纪律。
3. **字号平台化**。`CopyoTheme.Fonts`（`:204-224`）整套绑在 iOS 的动态字体样式上
   （`caption2` = 11、`caption` = 12、`footnote` = 13、`subheadline` = 15、`body` = 17……），
   文件头注释 `:183-203` 明确写了「一律走系统文本样式，**不要**写 `.font(.system(size:))`」。
   macOS 的 dense 档要的是 **17/22、13/18、12/16、11/15 等宽、10/13、10 Semibold、11**（见第二节字号表），
   与 iOS 的映射对不上（macOS 没有动态字体，`@ScaledMetric` 在 Mac 上恒为 1）。
   `Fonts` 必须按平台分叉，色与圆角不受影响。

**落地代价**：`ClipCard` 上收会牵出 `CopyoIOS/Model/ClipItem+Display.swift`（264 行，`import UIKit`，
含 `ImageMetadataCache`），这一层需要先拆出 UIKit 部分。`docs/ios-plan.md` 第 3.5 节已明确记过
「`ClipCard` 没有上收，而且不该上收」，理由是小组件的 `TimelineEntry` 装不下 `@Model`、
且 `ImageMetadataCache` 的 96MB `totalCostLimit` 会让扩展进程当场 jetsam。**那两条理由针对的是扩展与 Widget，
不针对 Mac App** —— Mac 是完整宿主进程，内存预算与 iOS 主应用同级。但这意味着共享的是
「`Copyo`（Mac）+ `Copyo iOS` 两个宿主 target 的 `ClipCard`」，扩展与 Widget 仍然各走各的扁平快照。

---

### 7.4 全平台修订

本节列本次 macOS 设计带出的、**必须同时改 iOS** 的条目。iOS 的冻结设计稿
（`art/ios-design/2026-09-05/`）不动；这里记的是规格层与实现层的修订。

**工期口径**：7.4.1–7.4.5 每条都给一个规模格，口径与 §7.1 / §7.2 相同（**S ≈ 半天，M ≈ 1–2 天，L ≈ 3 天以上**），
但**本节不计入 macOS 本轮工期** —— 它们落在 iOS target 上，排期上应作为一条独立的「iOS 跟进」任务，
与「面板重做 + 设置换肤」并列而不是包含在内。合计 **2 × M + 3 × S ≈ 3.5–5.5 人天**（按本节口径 S ≈ 半天、M ≈ 1–2 天；报排期时取整为 4–6 人天）。
之所以要单独说明：7.4.1 与 7.4.2 都写着「影响，且是全局的」，若并进 macOS 那一栏，
读排期的人会以为 §7.1 / §7.2 的 L + M 已经把 iOS 的回归测试包含进去了，实际没有。
**本节的规模格为本规格估算，非设计稿内容**，最终排期以工程侧确认为准（见 7.5.17）。

#### 7.4.1 深色基色三元组 —— 规模 **M**

**规模依据**：改动只有 5 行（`CopyoTheme.swift:62`、`:63`、新增 `bgRaised` 一行、`:113`、
`ClipItem+Display.swift:30`），但深色下**每一屏**的观感都变，要把历史页 / Pinboard / 详情页 /
分享扩展 / 三档小组件在深色下逐个回看一遍，并顺带裁掉 `rowOpaque`（见第八节第 33 条 (a)）。
工时全在回归，不在编码。
另注：`ClipItem+Display.swift:29-33` 的 `tintColor(for:)` **今天全仓没有调用方**
（已 `grep -rn "tintColor(for"` 核实，只命中定义本身），所以改它当下不影响任何渲染 ——
但它与 `:26` 的 `tintColor` 是同一个常量的两份拷贝，必须同时改，否则将来接上截图/小组件预览路径时会分叉。

**改什么**：深色基色整体抬离纯黑，并新增一档 `bg.raised`。

| token | 浅 | 深（今天） | 深（修订后） |
| --- | --- | --- | --- |
| `bg.grouped` | `#F2F2F7` | `#000000` | **`#1C1C1E`** |
| `bg.card` | `#FFFFFF` | `#1C1C1E` | **`#2C2C2E`** |
| `bg.raised` | `#FFFFFF` | *（不存在）* | **`#3A3A3C`**（新增） |

**为什么**：纯黑在 iPhone OLED 上是省电特性，在 Mac 窗口里是一个洞；且卡片淡染的深色基色从
`#1C1C1E` 抬到 `#2C2C2E` 后，20% 淡染在深色下才分得出来（`Card.dc.html` 的深色条带注释原文：
「底色从 `#1C1C1E` 抬到 `#2C2C2E`，20% 淡染才分得出来」）。

**影响哪些文件**：
- `CopyoShared/UI/CopyoTheme.swift:62`（`bgGrouped = dynamic(light: rgb(0xF2F2F7), dark: rgb(0x000000))`）、
  `:63`（`bgCard = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x1C1C1E))`）——两行都要改；新增 `bgRaised`。
- `CopyoShared/UI/CopyoTheme.swift:113`（`tintUIColor` 深色基色 `rgb(0x1C1C1E)`）与
  `CopyoIOS/Model/ClipItem+Display.swift:30`（`tintColor(for:)` 里第二份写死的 `rgb(0x1C1C1E)`）——
  **两处是同一个常量的两份拷贝，必须同时改**，否则截图路径与运行时路径颜色不一致。
- `CopyoShared/UI/CopyoTheme.swift:79-84` 的 `rowOpaque`（浅 `#FFFFFF` / 深 `#2C2C2E`）：
  它正是「`ShareTheme` 里那条没回流的补丁」被转正后的样子，`:82` 的注释原文记着撞色原因 ——
  *「也不能用 `bgCard`——深色下它与 `sheet` 同为 `#1C1C1E`，整行在深色里会完全看不见」*。
  修订后 `bgCard` 深色变成 `#2C2C2E`、`sheet`（`:77`）仍是 `#1C1C1E`，**撞色前提消失**，
  `rowOpaque` 与新的 `bgCard` 取值完全相同，应当合并（见第八节第 33 条 (a)）。

**是否影响已实现的 iOS UI**：**影响，且是全局的**。深色下所有分组背景、所有卡片底色、所有淡染都会变。
`sheet`（`:77`，深 `#1C1C1E`）与 `sidebarBg`（`:85`，深 `#141416`）是否跟随调整需一并定。

#### 7.4.2 颜色类条目的淡染取自身色 —— 规模 **M**

**规模依据**：本节五条里唯一需要**新增派生值**的一条。渲染色（`.color` 取 `plainText` 解析值、
否则取 `sourceColorHex`）要在 `ClipItem+Display.swift` 里新开一个属性，再顺着四个消费点改
（`ClipCard.swift:47`、`ClipDetailPreview.swift:30`、`KindBadge.swift:49` 与 `:57` 的 `init(item:)`）。
真正吃工时的是小组件那一路：`ClipSnapshot` 是扁平快照、拿不到 `ClipItem`，
`sourceColorHex`（声明 `:22`、从条目灌入 `:53`、成员式 `init` 的 `:77`/`:86`）要么改语义、
要么另加一个字段，消费点在 `SmallClipView.swift:43`（角标）、`:59`（`CopyoTheme.tint`）与
`MediumClipsView.swift:81`，另有 `RecentClipsProvider.swift:150/158/165/172` 四条占位数据要跟着核。
解析失败（`plainText` 不是合法 hex）时的回退分支设计稿没画，见第八节第 31 条。

**改什么**：`kind == .color` 的条目，整卡淡染与类型角标底色取**剪贴内容自身的颜色**，不取来源 App 的色。
设计稿的取值：`COLORCLIP = ("#FF2D55", "#FFE6EB", "#562E36")`（`gen.py:74`），即内容色 `#FF2D55`、
浅色淡染 `#FFE6EB`、深色淡染 `#562E36`；`Tokens.dc.html` 的淡染小节注释原文：
「颜色类条目取剪贴内容本身的颜色，不取来源 App —— 这是相对 iOS 的一处修订。」

**为什么**：一条颜色条目的身份就是那个颜色；用 Figma 的紫色去淡染一张内容为品牌红的卡片，
读出来是错的。Mac 的旧卡片其实已经这么做了（`Copyo/Panel/CardView.swift:39-49` 的 `headerColor`
对 `.color` 走 `Color(hexString: item.plainText)`），iOS 反而丢掉了这个区分。

**影响哪些文件**：
- `CopyoIOS/UI/ClipCard.swift:47` —— 今天是**无条件** `.background(item.tintColor)`，没有任何 kind 分支。
- `CopyoIOS/Model/ClipItem+Display.swift:19-21`（`sourceUIColor`）、`:26`（`tintColor`）、`:29-33`（`tintColor(for:)`）——
  三处都只认 `sourceColorHex`。需要一个「渲染色 = `.color` 时取 `plainText` 解析值，否则取 `sourceColorHex`」的派生值；
  `:143-146` 的 `colorValue` 已经有现成的解析逻辑可复用。
- `CopyoShared/UI/KindBadge.swift:49`、`:43` —— 角标底色与 `onBand` 前景同样走这个渲染色。
  `KindBadge` 的 `init(item:)`（`:56-58`）今天直接传 `item.sourceColorHex`，需要改成传渲染色。
- `CopyoIOS/Screens/Detail/ClipDetailPreview.swift:30` —— 同样是 `item.tintColor`。
- `CopyoWidgets/ClipSnapshot.swift` 的快照结构需要带上渲染色（而不是来源色），否则小组件里颜色条目仍是来源色。

**是否影响已实现的 iOS UI**：**影响**。历史页、Pinboard 页、详情页、分享预览、小组件里所有颜色条目的
卡片底色与角标底色都会变。非颜色条目逐像素不变。

#### 7.4.3 筛选统一 6 项 —— 规模 **S**

**规模依据**：核心改动是把 `KindPresentation.swift:42` 的 `compactFilters` 与 `:45` 的 `regularFilters`
合成一个数组（两行代码），`HistoryFilterChips.swift:16` 自动跟随；`matches(_:filter:)`（`:48-52`）不用动。
余下的是文案与横排复核：chips 从 5 个变 6 个（含「全部」），`HistoryFilterChips.swift:32` 的标签映射
与小屏下的横向排布要实机看一遍；`:40-41` 的注释作废需改写。

**改什么**：两端统一为 **全部 / 文本 / 链接 / 图片 / 颜色 / 文件**（6 项）。富文本并入「文本」，
但**角标仍然显示「富文本 / Rich」**，因为那是内容的真实属性。

**为什么**：文件条目在 iOS 上是 Mac 同步来的，不给筛选项等于永远找不到；而富文本独立成项在用户心智里是伪区分。

**影响哪些文件**：
- `CopyoShared/UI/KindPresentation.swift:42` —— 今天是
  `static let compactFilters: [ClipKind] = [.text, .link, .image, .color]`（4 项，**缺 `.file`**），
  加上 `.file` 后与 `:45` 的 `regularFilters = [.text, .link, .image, .color, .file]` 完全一致，
  两个数组应合并为一个。`:40-41` 的注释里「文件在手机上不单列——见 iOS 规格第八节第 1 条，
  两端口径尚未拍板」随之作废，要改写。
- `CopyoIOS/Screens/History/HistoryFilterChips.swift:16` —— `ForEach(KindPresentation.compactFilters…)`，
  自动跟随；但 chips 从 5 个（含「全部」）变 6 个，横向排布与 `:32` 的标签映射要复核。
- `CopyoIOS/Screens/iPad/SidebarView.swift:68-71` —— 走 `regularFilters`，合并后不变。
- `KindPresentation.matches(_:filter:)`（`:48-52`）**已经实现**了「`.text` 筛选包含 `.richText`」，不用改。
- Mac 侧是新建（今天面板无筛选），直接用同一个数组。

**是否影响已实现的 iOS UI**：**影响 iPhone 历史页**（筛选 chips 多一项）；iPad 侧栏不变。

#### 7.4.4 kind 标签统一 —— 规模 **S**

**规模依据**：代码只有一行（`Copyo/Models/ClipKind+Label.swift:9`），风险全在本地化表：
`Copyo/Localizable.xcstrings:1477` 的 `"Rich Text"` 这个键要整条迁到 `"Rich"`，
中文译文「富文本」必须跟着搬，不能丢；改键名不做迁移就是一条译文静默回落到英文。
若同时采纳 7.3（整个文件被 `KindPresentation` 取代），四份本地化目录的六个键要合并，
那属于 7.3 的账，不在本条。

**改什么**：`Copyo/Models/ClipKind+Label.swift:9` 的 `case .richText: String(localized: "Rich Text")`
改为 `"Rich"`，与 iOS 对齐。

**为什么**：`CopyoShared/UI/KindPresentation.swift:20-21` 的注释已经写清楚了原因 ——
*「设计 3.2 的英文角标是 `Rich`；`Rich Text` 在卡片头部与详情标题里都会被截断」*。
Mac 本轮新增类型角标，`Rich Text` 在 dense 档（高 18、10pt）里必然被截。

**影响哪些文件**：
- `Copyo/Models/ClipKind+Label.swift:9`（唯一一处）。
- `Copyo/Localizable.xcstrings` —— 键从 `Rich Text` 变成 `Rich`，中文译文（「富文本」）要跟着迁移，不能丢。
- 若采纳 7.3，整个 `ClipKind+Label.swift` 被 `KindPresentation` 取代，
  三份本地化目录（`Copyo/`、`CopyoIOS/`、`CopyoShareExtension/`，另加 `CopyoWidgets/`）里的六个键需要合并；
  `KindPresentation.swift:6-14` 的头注释已说明**为什么三处各存一份**（扩展进程的 `Bundle.main` 是它自己）。

**是否影响已实现的 iOS UI**：**不影响**。iOS 今天已经是 `Rich`（`KindPresentation.swift:21`）。

#### 7.4.5 删除键统一 —— 规模 **S**

**规模依据**：两处改动、两行（`HistoryScreen.swift:469` 的 `case .delete, .deleteForward:` 加修饰键判定、
`HistoryShortcutHints.swift:18` 的 `Hint(key: "⌫", …)` 改串），外加 `:415` 的注释改写。
需要一台接了硬件键盘的 iPad 实测一遍（裸 `⌫` 在搜索框里的误删是这条的起因）。
本条与 7.4.3 落在同一个文件簇上，宜与 7.4.3 合并到同一次提交里做。

**改什么**：两端删除都用 **⌘⌫**。

**为什么**：Mac 面板今天就是 `⌘⌫`（`Copyo/Panel/PanelRootView.swift:323`：
`case .delete where press.modifiers.contains(.command)`；设置页的说明也是 `⌘⌫`，
`Copyo/Settings/SettingsView.swift:509`），设计稿的提示条与快捷键表同样是 `⌘⌫`（`gen.py:231`、`gen2.py:242`）。
iOS 规格给的是裸 `⌫`，同一套键盘接两台设备时手指记忆会打架；且裸 `⌫` 在带搜索框的界面里有误删风险。

**影响哪些文件**：
- `CopyoIOS/Screens/History/HistoryScreen.swift:469` —— 今天是
  `case .delete, .deleteForward:` 后**不检查修饰键**，直接删。需加 `press.modifiers.contains(.command)` 判定。
  `:415` 的注释「方向键、↵、空格、⌫ 走 onKeyPress」要同步改写。
- `CopyoIOS/Screens/History/HistoryShortcutHints.swift:18` —— `Hint(key: "⌫", action: …)` → `"⌘⌫"`。
- Mac 侧无需改动。

**是否影响已实现的 iOS UI**：**影响 iPad 的硬件键盘行为与底部提示条文案**；iPhone 无硬件键盘路径时不受影响。

#### 7.4.6 品牌红蓝的使用边界

**裁决**（两端同一条，写进规格正文，作为 iOS 规格第八节第 16 条的答案）：

> **`brand.red` `#FF2D55` / `brand.blue` `#0A84FF` / `brand.bone` `#F7F3EA` / `brand.ink` `#16161A`
> 可以出现在：App 图标、空态插画、引导插图、设置页的彩色图标砖。
> 不得出现在：正文文字、描边、背景、控件、状态指示。**

上面给的是**两端共用的上限清单**。macOS 端是否按实际用法收紧（去掉「设置图标砖」与「引导」——
`gen2.py:177-181` 的 `TILE` 七色全是系统语义色，macOS 的设置图标砖一个品牌色都没有，也没有引导流程）
见第八节第 27 条；若收紧，macOS 的品牌色实际出现点只剩 App 图标与空态插画两处。

`Tokens.dc.html` 的色卡注释是同一口径：`brand.bone` 条「只在图标、空态、引导、设置图标砖」，
`brand.red` 条「同上 —— 正文、描边、控件一律不得使用」。

**影响哪些文件**（iOS 今天的实际用法，逐个核对后**全部落在允许清单内**，无需改动）：
- `CopyoIOS/Screens/History/HistoryEmptyState.swift:68、:72、:75、:80-82` —— 空态插画。
- `CopyoIOS/Screens/Settings/AboutScreen.swift:110、:113、:118` —— 关于页的品牌标识。
- `CopyoIOS/Screens/Settings/HowToSaveScreen.swift:33` —— `symbolColor: CopyoTheme.Brand.red`，引导性图文。
- `CopyoShared/Share/CopyoMark.swift:15、:17、:21` —— 品牌标识本身。

**注意**：`brand.blue` 与 `accent` 是同一个 `#0A84FF`（`CopyoTheme.swift:58` 的 `accentUI`
与 `:98` 的 `Brand.blue`）。这条规则约束的是**以品牌名义使用**（插画、图标砖），
不约束 `accent` 作为交互色的正常使用（选中环、链接域名、开启态 chip）。

**是否影响已实现的 iOS UI**：**不影响**。Mac 今天零使用，直接按这条执行。

#### 7.4.7 来源色的生产者不对称

**事实**（已打开文件核对）：`Copyo/Services/ClipboardMonitor.swift:76` 在**采集这一刻**就把来源色算成字符串存进条目：

```swift
let colorHex = AppIconProvider.headerColor(forBundleID: bundleID).srgbHexString
```

紧挨着的注释（`:74-75`）写明了原因：*「来源色在采集这一刻算好存进条目：iOS 的沙盒里取不到别的 App 的图标，
卡片的淡染色只能靠 Mac 端同步过去的这个值」*。这个 `colorHex` 随后被喂进四条插入路径
（文件 `:86`、文本 `:100`、图片 `:106`/`:113`→`:124`），去重命中时也会刷新（`:153`）。

**所以：Mac 是来源色的唯一生产者，iOS 是纯消费者。** 纯 Mac 历史是一片彩色，纯 iOS 历史是一墙 `#8E8E93` 灰。
（这也正是「整卡淡染」优于「顶部实色带」的理由：12% 的淡染在全灰时仍是克制的中性卡片，
而一条 42pt 的实色带全灰时看起来像坏了。）

**由此产生的两个问题**：

1. **iOS 的回退分支对 Mac 来的行永远走不到。**
   `AppIconProvider.headerColor(forBundleID:)`（`Copyo/Services/AppIconProvider.swift:26-32`）在
   `bundleID == nil` 时走 `key = "?"`，取 `NSWorkspace.shared.icon(for: UTType.application)`（`:20`）的主色，
   算不出来才落到 `fallbackColor = NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1)`（`:10`）。
   `NSColor+Hex.swift:8-13` 的 `srgbHexString` 只在 `usingColorSpace(.sRGB)` 失败时返回 `nil`，
   而这两种色都转得了。**结论：Mac 永远写一个具体 hex**，于是
   `CopyoIOS/Model/ClipItem+Display.swift:20` 的 `?? CopyoTheme.sourceLocalUI` 对 Mac 来的行**永远不触发**。
2. **回退色是在采集时烤进行里的。** 改 `AppIconProvider.fallbackColor` 修不了存量行 ——
   只会再造出第三个灰：iOS 的 `#8E8E93`（`CopyoTheme.swift:104` 的 `sourceLocalUI`）、
   Mac 旧行里烤进去的那个板岩蓝灰、Mac 新行里的新值。而且 macOS 上**根本不存在「本机 / This Mac」这个概念**
   （前台总是某个 App），`source.local` 这个 token 在 Mac 侧没有语义。

**两个可选处理（本轮标为待定，不在设计层拍板）**：

- **(a) 让两端走同一条回退分支。** `ClipboardMonitor.swift:76` 改成：`bundleID == nil`（或
  `headerColor` 未能得出有效主色）时写 `nil`，由渲染层统一回退到 `source.local #8E8E93`。
  好处是回退色只有一份、改一次两端同步生效；代价是需要一次存量数据迁移（把旧的板岩蓝灰行改写为 `nil`），
  且 `AppIconProvider.headerColor` 的「算不出主色」与「算得出但很灰」两种情况要能区分开。
- **(b) 接受两个硬编码的灰，并写进规格。** `AppIconProvider.fallbackColor` 改成 `#8E8E93`，
  存量行不迁移。好处是零迁移风险；代价是升级前后采集的条目在同一屏里会有两种灰，且永远不会收敛。

---

### 7.5 工程风险登记

本节只登记**已经在当前工作区源码里核对过**的缺陷与结构问题，每条都会影响本次「面板重做 + 设置换肤」的实现排期。

#### 7.5.1 全局快捷键冲突无声失败

| 项 | 内容 |
| --- | --- |
| 现象 | 录制器接受任意带 ⌘/⌥/⌃ 的组合并立即写盘，设置页随即显示新组合，菜单栏「打开 Copyo」也标上同一组合；但如果该组合已被别的 App（Raycast / Alfred / 其它剪贴板工具 / 系统服务）占用，`RegisterEventHotKey` 会失败，按下去毫无反应，界面上没有任何痕迹。 |
| 证据 | `Copyo/Services/HotkeyManager.swift:119-132`：`func register(_ config:)` 返回 `Void`；`RegisterEventHotKey(config.keyCode, config.carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)`（126–131 行）的 `OSStatus` 被整个丢弃。同文件 `installHandlerIfNeeded()` 里 `InstallEventHandler(...)`（139–144 行）的 `OSStatus` 同样被丢弃。<br>`Copyo/Settings/SettingsView.swift:560-580` `startRecording()`：569–572 行只校验「至少带一个 ⌘/⌥/⌃」，574 行 `config.save()`，575 行 `AppDelegate.shared?.reloadHotkey()`，576 行直接把 `hotkeyDisplay` 改成新组合，全程没有回读注册结果。<br>`Copyo/App/AppDelegate.swift:158-160` `reloadHotkey()` 也是 `Void`。<br>`Copyo/App/AppDelegate.swift:191-197`：菜单栏「打开 Copyo」的 `keyEquivalent` 直接取 `HotkeyConfig.load()`，注册没成功也照样标注。 |
| 对本次重设计的影响 | 设计稿 `art/macos-design/2026-09-20/Settings.dc.html`（由 `gen2.py:258` 生成）已经画出失败态：`唤出面板` 行下方一条警示行，文案「这个组合已被另一个 App 占用，Copyo 收不到它」。**检测逻辑在代码里完全不存在**，这一态目前无法点亮。换肤本身是纯视觉工作，但这一行要落地必须先改 `HotkeyManager` 的签名与调用链（3 个文件）。 |
| 建议处置 | `register(_:)` 改为返回 `OSStatus` 或 `Bool`；`AppDelegate.reloadHotkey()` 透传结果；`ShortcutsSettingsView` 保存后按返回值渲染 `gen2.py:258` 的警示行，并保留旧组合不写盘（或写盘但标红）。`InstallEventHandler` 的返回值一并检查。工期按「一个独立小改动 + 一条新本地化字符串」估。 |

#### 7.5.2 焦点模型（详见第四节 4.1，此处只登记工期影响）

| 项 | 内容 |
| --- | --- |
| 现象 | 面板是 `.borderless + .nonactivatingPanel` 的 `NSPanel`，但 `show()` 里又调了 `NSApp.activate(ignoringOtherApps: true)`，`hide(reactivatePrevious:)` 再把焦点还给 `previousApp`；`windowDidResignKey` 无条件收起，只有 `suppressAutoHide` 一个例外口子。 |
| 证据 | `Copyo/Panel/PanelController.swift:7-10`（`SlidePanel.canBecomeKey = true` / `canBecomeMain = false`）、`29-44`（styleMask 与 `level = .statusBar`）、`68-94`（`show()`，其中 85 行 `NSApp.activate`）、`98-115`（`hide`，112–114 行 `previousApp?.activate`）、`123-127`（`copyAndDismiss`）、`137-141`（`windowDidResignKey`）、`22-23`（`suppressAutoHide`）。 |
| 对本次重设计的影响 | 新设计新增了悬停动作簇（卡片右上角两枚玻璃按钮）、轻提示、`⌘P` 固定、`⌘F` 聚焦搜索。动作簇与轻提示都要求面板在鼠标操作后**不收起**，而固定到 Pinboard 的二级菜单一旦抢走 key window 就会命中 `windowDidResignKey`。现有的 `suppressAutoHide` 只在新建 Pinboard 的 alert 处手工置位，新增的每一个弹层都要记得成对置位/复位，漏一个就是「面板莫名消失」。 |
| 建议处置 | 面板重写时把 `suppressAutoHide` 换成引用计数或 `presentedCount`，由弹层统一进出；`hide()` 的自动收起改为「resignKey 且当前没有任何子弹层」。排期上归入面板重写本体，不单独计。 |

#### 7.5.3 没有主菜单，搜索框里的标准文本编辑快捷键全部失效

| 项 | 内容 |
| --- | --- |
| 现象 | 应用是 `LSUIElement`，`App` 场景只有一个空的 `Settings`，没有任何 `.commands`，所以 `NSApp.mainMenu` 里没有「编辑」菜单。搜索框里 `⌘A` 全选、`⌘C`/`⌘X`/`⌘V`、`⌘Z` 撤销全部无效。更糟的是方向键被面板抢走：光标无法在搜索词里左右移动。 |
| 证据 | `Copyo/App/CopyoApp.swift:3-12`：`@main struct CopyoApp: App`，`body` 只有 `Settings { EmptyView() }`，无 `.commands`。<br>`Copyo.xcodeproj/project.pbxproj:436`、`464`、`510`：`INFOPLIST_KEY_LSUIElement = YES`。<br>`Copyo/Panel/PanelRootView.swift:150` 的注释原文即确认此事：「LSUIElement 应用没有应用菜单，⌘, 也不生效」。<br>`Copyo/Panel/PanelRootView.swift:307-332` `handleKeyPress(_:)`：309–314 行 `.leftArrow` / `.rightArrow` **无条件** `return .handled`（不看修饰键），315–316 行 `.upArrow` / `.downArrow` 直接吞掉。搜索框在 `188-195` 行，`.onKeyPress(phases: .down)` 挂在 `TextField` 上。 |
| 对本次重设计的影响 | 新设计的快捷键表（`gen2.py:241-243` `key_rows`）又加了 `⌘F 聚焦搜索`、`⇥ 在筛选间循环`、`⌘1–9 直接取第 N 张卡`，并把纯文本复制从现有的 `⌥↩` 改成 `⇧↩`。这些都要在同一个 `handleKeyPress` 里处理，而该函数目前是「先截胡再说」的写法，加得越多，搜索框越不像一个可编辑的文本框。 |
| 建议处置 | 两件事分开：(a) 给 `CopyoApp` 加最小 `.commands`（或在 `AppDelegate` 里手搭一个只含「编辑」的 `NSApp.mainMenu`），恢复 `⌘A/C/X/V/Z`；(b) `handleKeyPress` 里左右方向键加 `press.modifiers.isEmpty` 守卫，带修饰键的交还文本框。另：`⌥↩ → ⇧↩` 是行为变更，需要在 7.5.8 的字符串清单与发布说明里一并处理。 |

#### 7.5.4 相对时间被冻结

| 项 | 内容 |
| --- | --- |
| 现象 | 卡片底部的「2 分钟前」在视图构建那一刻算一次，之后永不更新。面板常驻后台、一次打开几十秒到几分钟，用户会看到早就过期的时间；同一次打开里新旧卡片的时间基准还可能不一致。 |
| 证据 | `Copyo/Panel/CardView.swift:188-199` `footer`，其中 **192 行**：`Text(Self.relativeFormatter.localizedString(for: item.createdAt, relativeTo: Date()))` —— `Date()` 在 `body` 求值时取当下，而 `CardView` 没有任何随时间变化的依赖，SwiftUI 不会重绘。格式器本身是 `13-17` 行的 `static let relativeFormatter`（`unitsStyle = .short`）。<br>（移植图 `transfer-map.md` 给的行号与此不符，以本行为准。） |
| 对本次重设计的影响 | 新卡片的 meta 行是「来源 · 相对时间」单行（`gen.py:108` `card()` 的 `meta` 参数，样式见 `gen.py:137-138` 的 `meta_cell`，`font-size: 10px`、色 `th["meta"]`、单行省略）。设计稿里的取样全是「2 分钟前 / 12 分钟前 / 25 分钟前 / 1 小时前 / 昨天 18:42」，正是最容易被看出冻结的量级。 |
| 建议处置 | 随卡片重写一并修掉：用 `TimelineView(.periodic(from: .now, by: 60))` 包住 meta 行（只包这一行，不包整张卡，避免整卡每分钟重绘）。 |

#### 7.5.5 降级内容态没有设计也没有兜底

| 项 | 内容 |
| --- | --- |
| 现象 | 预览浮层的图片分支在取不到数据时**什么都不画**（整块空白）；颜色解析失败静默落成灰色；文件图标在 view body 里同步读磁盘，沙盒下常常读不到。 |
| 证据 | `Copyo/Panel/PreviewOverlay.swift:32-39`：`case .image:` 后面是 `if let data = item.imageData, let image = NSImage(data: data) { ... }`，**没有 `else`**。CloudKit 资源尚未下载完、或 `NSImage(data:)` 解码失败时，`previewContent` 返回空，浮层里只剩 680 × 320 的空玻璃板加一条 footer。<br>`Copyo/Panel/PreviewOverlay.swift:40-43`：`.fill(Color(hexString: item.plainText ?? "") ?? .gray)` —— 解析失败落到 `.gray`，与真正的灰色条目无法区分。<br>`Copyo/Panel/PreviewOverlay.swift:44-60`：`.file` 分支在 `ForEach` 里逐行 `Image(nsImage: NSWorkspace.shared.icon(forFile: path))`（**49 行**），同步 I/O 跑在 view body 里。<br>卡片侧同构：`Copyo/Panel/CardView.swift:130`（`?? .gray`）、`Copyo/Panel/CardView.swift:154-173` 的 `fileContent`，**157 行** 同样是 body 内的 `NSWorkspace.shared.icon(forFile:)`；只有图片分支有兜底（`144-148` 行退回 `photo` 符号）。<br>沙盒下路径不可读是已知状况，`Copyo/Panel/PanelRootView.swift:410-418` 的 `#if APPSTORE` 分支专门用 `FileManager.default.isReadableFile(atPath:)`（**`:415`** 的 `guard`）拦过一次（拖拽路径）。 |
| 对本次重设计的影响 | 设计稿十张画板里**没有一张**画降级态：图片卡只有正常缩略图（`gen.py:195-196` 的 `body_image`），颜色卡只有有效 hex，文件卡在 A 版面板里根本没出现（筛选胶囊里有「文件」，卡片取样里没有）。本轮如果只换皮，这三处空白会原样带进新面板，而新面板的卡片是**不透明**的，空白会比现在更显眼。 |
| 建议处置 | 三条都要补设计：图片加载中 / 失败的占位；颜色解析失败的专用画法（不能与灰色条目撞）；文件图标不可读时的降级（见第八节第 44 条）。实现上把 `NSWorkspace.icon(forFile:)` 挪出 body，走 `ThumbnailCache` 同构的异步缓存。列入本轮范围，需要设计补图。 |

#### 7.5.6 两套构建风味的分歧远不止一个齿轮

| 项 | 内容 |
| --- | --- |
| 现象 | `APPSTORE` 编译条件把 macOS 端切成两套行为，**共 9 处 `#if APPSTORE`，分布在 4 个文件**。设置页的「文件夹同步」那一段是两套**完全不同的 UI**，不是同一界面的细节差异。 |
| 证据 | 全仓 `grep -rn "#if APPSTORE" --include="*.swift"` 命中 9 处：<br>`Copyo/Settings/SettingsView.swift:357`、`Copyo/App/AppDelegate.swift:128`、`Copyo/Panel/PanelRootView.swift:148`、`Copyo/Panel/PanelRootView.swift:410`、`Copyo/Services/SyncService.swift:18`、`:37`、`:123`、`:161`、`:202`。<br>编译条件定义在 `Copyo.xcodeproj/project.pbxproj:519`、`623`、`720`、`817`：`SWIFT_ACTIVE_COMPILATION_CONDITIONS = "APPSTORE $(inherited)"`。<br>**设置页的两套 UI**：`Copyo/Settings/SettingsView.swift:357-494`，其中 `357` 是 `#if APPSTORE`、`456` 是 `#else`、`494` 是 `#endif`。<br>· 商店版 `FolderSyncSections`（**361–454 行**）：`Section("Sync Folder")`（395 行）里一行只读的等宽路径 + 「Choose Sync Folder…」按钮（403 行），走 `NSOpenPanel`（`chooseFolder()`，436–453 行）并存安全作用域书签（448 行 `SyncService.bookmarkKey`）；另有 `lostAccess` 失效态（368 行、381–385 行、421–426 行）与「Last synced …」（427–429 行）。<br>· 直接分发版 `FolderSyncSections`（**458–492 行**）：`Section("Custom Sync Folder (Optional)")`（481 行）里一个**自由文本框** `TextField("Leave empty to use iCloud Drive, e.g. ~/Shared/Copyo", ...)`（482 行），`onSubmit` 直接触发（484–486 行）；失败提示只有两条文字（472–476 行），没有 `lostAccess`，没有「上次同步时间」。<br>另外两处界面级差异：`PanelRootView.swift:148-166` 商店版在面板顶栏多一枚齿轮按钮（直接分发版只能右键菜单栏图标进设置）；`AppDelegate.swift:128-148` 首启欢迎 alert 的最后一条 bullet 两套文案不同。 |
| 对本次重设计的影响 | 「设置换肤」这一项的工作量要按**两套**算：同步页在两种风味下的行数、控件种类、失败态数量都不同，`gen2.py` 目前只画了「通用」与「快捷键」两页，同步页一页未画（见第八节第 10 条），也就无从判断两套要不要收敛成一套。面板顶栏的齿轮按钮同理：A 版设计稿（`gen.py:212`）**无条件**画了齿轮，与直接分发版当前行为不符。 |
| 建议处置 | 先拍板面板齿轮是否在两种风味下都显示（设计稿已经这么画了，倾向于都显示，顺带给直接分发版补上入口）；同步页设计出图时必须同时给两套稿，或者明确把「自定义同步目录」的自由文本框也改成 `NSOpenPanel`，让两套收敛。 |

#### 7.5.7 同步状态远不止三态

| 项 | 内容 |
| --- | --- |
| 现象 | 本轮要把同步状态搬到面板顶栏，设计稿只给了一枚 32 × 32 的图钮。但代码里可区分的同步状态至少 **11 种**，其中 6 种是需要用户动手的失败态，一枚图标收不下。 |
| 证据 | 逐条核对如下。<br>1. **无 iCloud entitlement**：`Copyo/App/AppDelegate.swift:41-44`（`CloudSyncStatus.hasCloudKitEntitlement` 为假时 `record(containerError:)`），展示在 `Copyo/Settings/SettingsView.swift:287-296`，文案「This copy of Copyo is not signed for iCloud sync.」；判定实现在 `Copyo/Services/SyncMode.swift:76-85`。<br>2. **CloudKit 容器建不起来**：`Copyo/App/AppDelegate.swift:48-54`（`catch where wantsCloudKit` → `record(containerError:)` 后退回本地容器），展示在 `SettingsView.swift:297-306`。<br>3. **推送注册失败**：`Copyo/App/AppDelegate.swift:109-112` `didFailToRegisterForRemoteNotificationsWithError` → `record(pushError:)`；成功路径在 `114-117`；注册发起在 `78-84`。展示在 `SettingsView.swift:307-311`（降级说明：变更只在启动时到达）。<br>4–8. **iCloud 账号状态 5 种**：`Copyo/Settings/SettingsView.swift:332-347` `accountDescription` 列出 `.available` / `.noAccount` / `.restricted` / `.temporarilyUnavailable` / `default`（无法确定），另有 `nil`（`Checking iCloud status…`，即「查询中」）。查询实现 `Copyo/Services/SyncMode.swift:89-97`。<br>9. **文件夹模式：未选目录**：`SettingsView.swift:372`、`397`（`folderPath == nil` → `No folder selected`）。<br>10. **文件夹模式：书签失效**：`SettingsView.swift:368`（`lostAccess`）、`381-385`、`421-426`；底层 `Copyo/Services/SyncService.swift:49` `enum SyncFailure { case noAccess }`，写入点 `SyncService.swift:163`、`169`，清除点 `SettingsView.swift:450`。<br>11. **改模式后需重启**：`SettingsView.swift:227-237`（整条 Section + 「Restart Copyo」按钮）、判定 `244-246` `needsRestart`；依赖 `AppDelegate.swift:18` 的 `cloudKitActive`。<br>另有非商店版独有两条：iCloud Drive 未开启 / 自定义目录父目录不存在，`SettingsView.swift:470-476`。<br>**设计侧**：`art/macos-design/2026-09-20/gen.py:207-216`（`topbar()` 的 `row1`）里顶栏共两枚图钮——同步（`:210`）与设置齿轮（`:212`）；其中**同步只有一枚按钮、只画了「已同步」一态**，`aria-label` / `title` 固定为「iCloud 已同步」，图标常量只有 `CLOUD_OK_I`（`gen.py:55`），着色固定 `SUCCESS_L #34C759`（深色 `SUCCESS_D #30D158`）。`gen.py:394-398`（B 版工具栏的同步图钮）同样只有这一态。**其余 10 种状态一张都没画。** |
| 对本次重设计的影响 | 面板顶栏的同步图钮目前只能表达「一切正常」。剩下的状态要么退化成一个橙色感叹号（用户看不出该做什么），要么要在面板里开出二级承载（弹出层 / 点击跳设置）。这是本轮**未设计**的部分，直接卡住顶栏右侧那一格的定稿。 |
| 建议处置 | 登记为待设计（见第八节第 13 条）。建议至少画三态图标 + 一条可点击的说明：正常（`#34C759` 云勾）/ 同步中 / 需要处理（橙 `#FF9F0A`），「需要处理」点开定位到设置·同步页对应行；设置页保留完整 11 态文案。**三态这个切分方式、以及「需要处理」用橙 `#FF9F0A`，均为本规格规定，设计稿未画**（见 7.5.11 的 A 行）。另注：三态都是 iCloud 形状的符号，文件夹同步模式在面板上仍无表达，见第八节第 14 条。 |

#### 7.5.8 本地化

| 项 | 内容 |
| --- | --- |
| 现状核对 | `Copyo/Localizable.xcstrings`：`version 1.0`，`sourceLanguage = en`，**共 114 条 key**。已有译文语言：`zh-Hans` 114 条、`fr` 114 条、`en` 3 条（源语言只对 3 条显式写了本地化）。即**源语言英文 + 简体中文 + 法语，共 3 种语言**。 |
| 影响 | 本次面板重做与设置换肤会新增约 **58 条**字符串，全部需要 zh-Hans 与 fr 两份译文（合计约 116 条译文），且其中 10 条（快捷键行名）是对现有 key 的**替换**——被它们顶掉的现有 key 实际是 **11 条**，两边不是一一对应，详见下方替换清单。 |

新增字符串清单（文案逐字取自 `gen.py` / `gen2.py`，中文为设计稿原文，英文源串待定）：

| 区域 | 条数 | 字符串 | 出处 |
| --- | --- | --- | --- |
| 搜索框占位 | 1 | `搜索历史`（同一串在视觉隐藏 `<label>` 与 `placeholder` 上各出现一次） | `gen.py:203`（`<label for="q">`）、`gen.py:204`（`placeholder`） |
| 同步图钮 accessibility / help | 3 | `iCloud 已同步` + 另两态（未设计，见第八节第 13 条） | `gen.py:210` |
| 设置图钮 accessibility / help | 1 | `设置` | `gen.py:212` |
| 筛选胶囊 | 6 | `全部` `文本` `链接` `图片` `颜色` `文件`（`names` 列表） | `gen.py:219` |
| Pinboard 胶囊 | 1 | `Pinboard`（专名，各语言不译，用 `Text(verbatim:)`） | `gen.py:224` |
| 类型角标 | 6 | `文本` `富文本` `链接` `图片` `颜色` `文件`（六个标签在 `ICON` 字典里，`富文本` 在 `gen.py:33`；富文本并入「文本」筛选但角标仍显示「富文本」。角标组件本身定义在 `gen.py:81` `badge()`） | `gen.py:32-37`（`ICON`）、`gen.py:81`（`badge()`） |
| 搜索结果计数 | 1 | `2 条结果`（需复数变体：zh-Hans 单式、fr 需 one/other） | `gen.py:308-309` |
| 提示条动作名 | 4 | `复制` `预览` `固定` `删除` | `gen.py:227-232` |
| 提示条右侧说明 | 3 | `复制后回到原来的 App，按 ⌘V 粘贴` / `Esc 清空搜索 · 再按一次关闭面板` / `Esc 关闭` | `gen.py:227`、`gen.py:311`、`gen.py:334` |
| 轻提示 | 1 | `已复制 · 按 ⌘V 粘贴` | `gen.py:287` |
| 空态 | 3 | `还没有内容` / `复制任何东西，它都会出现在这里。Copyo 在后台自动记录，不需要你做任何事。` / `随时按 ⇧⌘V 唤出这个面板` | `gen.py:327-330` |
| 悬停动作簇 `.help()` | 2 | `固定到 Pinboard` / `删除` | `gen.py:131-132` |
| 卡片 accessibility | 1 | `已固定` | `gen.py:135` |
| 设置 · 通用 | 9 | `启动` / `登录时启动 Copyo` / `在菜单栏显示图标` / `捕获` / `自动记录剪贴板` / `Copyo 在后台记录，不需要任何权限` / `忽略密码管理器` / `来自 1Password、钥匙串的内容不会被记录` / 底注 `复制后 Copyo 把内容写回系统剪贴板并把焦点交还给原来的 App，由你自己按 ⌘V —— Copyo 从不代你粘贴。` | `gen2.py:234-239`（组标题 `启动` 在 `:234`） |
| 设置 · 快捷键（章节与提示） | 4 | `唤出` / `点一下可以改` / `面板内` / `这个组合已被另一个 App 占用，Copyo 收不到它` | `gen2.py:250-260`（`唤出`、`点一下可以改` 在 `:250`，警示文案 `:258`，`面板内` `:260`） |
| 设置 · 快捷键（行名） | 10 | `唤出面板` `复制选中项` `纯文本复制` `预览` `固定到 Pinboard` `删除` `聚焦搜索` `在筛选间循环` `直接取第 N 张卡` `关闭面板` | `gen2.py:241-243`（`key_rows`） |
| 可本地化键名 | 2 | `空格` / `esc`（其余 keycap 为符号，不进本地化） | `gen2.py:241-243`（`key_rows` 的第二元素） |
| **合计** | **58** | 见下方「关于 58 这个数」 | |

**关于 58 这个数（口径必须先拍板，否则合计会变）**：表里「筛选胶囊 6 条」与「类型角标 6 条」中，`文本` `链接` `图片` `颜色` `文件` **5 个字面量完全相同**，只有 `全部`（仅胶囊）与 `富文本`（仅角标）不重。上表按 **12 条**计，是建立在「两处各起一套 key、不共用」这个**隐含假设**上的。

这个假设来自 iOS 侧的现成做法：`CopyoIOS/Screens/History/HistoryFilterChips.swift:24-26` 的注释原文——「chips 用复数（设计 01g：`All / Text / Links / Images / Colors`），卡片角标用单数（3.2 的 `Link / Image / Color`）——两处文案不共用一套 key。中文两边一样，只有英文分单复数」（实现见同文件 `:27-34` 的 `filterTitle(_:)`，其中 `:29-31` 三条走复数串，`default` 落回 `KindPresentation.label(kind)`）。

**macOS 要不要照搬这个分法，设计稿与本规格都没写**：`gen.py:219` 的胶囊名与 `gen.py:32-37` 的角标名在中文下逐字相同，画板上看不出分不分。若 macOS 决定**共用一套 key**，这两行合计从 12 降到 **7**（5 个共用 + `全部` + `富文本`），总计从 58 降到 **53**。见 7.5.11 的 B 行。

被替换 / 作废的现有 key，**共 11 条**（英文原串照录，中文为释义）：

| # | 英文原串 | 释义 | 出处 |
| --- | --- | --- | --- |
| 1 | `Move between cards` | 在卡片间移动 | `SettingsView.swift:504` |
| 2 | `Copy selected item` | 复制选中项 | `SettingsView.swift:505` |
| 3 | `Copy selected item as plain text` | 纯文本复制选中项 | `SettingsView.swift:506` |
| 4 | `Preview selected item (when search is empty)` | 预览选中项（搜索为空时） | `SettingsView.swift:507` |
| 5 | `Space` | 键位串「空格」——**本身就是一条 `String(localized:)`**，不是硬编码符号 | `SettingsView.swift:507`（同一元组的第二项） |
| 6 | `Search` | 搜索 | `SettingsView.swift:508` |
| 7 | `Just type` | 键位串「直接打字」——同样是一条 `String(localized:)` | `SettingsView.swift:508`（同一元组的第二项） |
| 8 | `Delete selected item` | 删除选中项 | `SettingsView.swift:509` |
| 9 | `Clear search / Close panel` | 清空搜索 / 关闭面板 | `SettingsView.swift:510` |
| 10 | `Open / Close panel` | 打开 / 关闭面板（不在 `fixedShortcuts` 里，是 `body` 里的独立 `Text`） | `SettingsView.swift:517` |
| 11 | `Type to search` | 搜索框 placeholder「打字即搜索」 | `Copyo/Panel/PanelRootView.swift:188` |

即 `fixedShortcuts`（`Copyo/Settings/SettingsView.swift:503-511`）里是**七个元组、九条 key**——七个动作名，外加 `:507` 的 `String(localized: "Space")` 与 `:508` 的 `String(localized: "Just type")` 这两条**被本地化的键位串**（其余键位 `← →` / `↩` / `⌥↩` / `⌘⌫` / `Esc` 是硬编码符号，不占 key）；再加 `:517` 的 `Open / Close panel` 与 `PanelRootView.swift:188` 的 `Type to search`，合计 11 条。

其中「纯文本复制」的键位由现有 `⌥↩`（实现在 `PanelRootView.swift:326-328` 的 `case .return where press.modifiers.contains(.option)`；设置页文案在 `SettingsView.swift:506`）改为设计稿的 `⇧↩`（`gen2.py:241` `key_rows` 第三项），属行为变更，发布说明需提（另见第八节第 17 条）。

建议处置：新字符串在面板重写的同一个提交里一次性进 `Localizable.xcstrings`；fr 一栏在 UI 定稿后统一送译，不要边做边补（现状 114 条 fr 是齐的，别在这轮打破）。

#### 7.5.9 设置窗口的尺寸与标签页顺序与设计稿不符

| 项 | 内容 |
| --- | --- |
| 现象 | 设计稿把设置窗口定为 **540 × 460**、标签顺序 `通用 / 同步 / 快捷键 / 历史 / 关于`；代码里**高度有两个互不相等的数**（窗口 440、内容 400），宽度是**按最长标签标题实时算出来**的（法语下会被顶到约 707pt），标签顺序是 `通用 / 历史 / 同步 / 快捷键 / 关于`。 |
| 证据 | 设计：`art/macos-design/2026-09-20/gen2.py:219` `def win(th, tab, content, w=540, h=460)`；`gen2.py:228` `seg(["通用", "同步", "快捷键", "历史", "关于"], tab)`；`gen2.py:268` 的画板注记原文「通用 · 540 × 460，结构不动，只换行样式与彩色图标砖」。<br>代码（宽度）：`Copyo/Settings/SettingsView.swift:73-93` `enum SettingsLayout`，`75` 行 `baseWidth = 540`，`85-92` 行 `width` 由 `SettingsTab.allCases` 的最长标题宽度算出（注释自述英文 504pt、简中 403pt、法语 707pt）。<br>代码（高度，**两个数**）：`SettingsView.swift:76` `static let height: CGFloat = 400`，只被 `SettingsView.swift:39` 的 `.frame(width: SettingsLayout.width, height: SettingsLayout.height)` 用于给 SwiftUI 内容定尺；而**真正的窗口**在 `Copyo/Settings/SettingsWindowController.swift:9` 用**硬编码的 440** 建：`NSWindow(contentRect: NSRect(x: 0, y: 0, width: SettingsLayout.width, height: 440), …)`。全仓 `grep -rn SettingsLayout --include='*.swift'` 只有这 4 处命中，`SettingsLayout.height` 从未参与窗口尺寸。<br>标签顺序：`Copyo/Settings/SettingsView.swift:47-48` `case general, clipboard, sync, shortcuts, about`，装配顺序见 `22-38` 行。<br>窗口样式：`Copyo/Settings/SettingsWindowController.swift:10` `styleMask: [.titled, .closable]`（不可缩放）。 |
| 对本次重设计的影响 | 「结构不动，只换行样式」这句前提不成立：窗口高度差 20pt（460 vs 440）、内容高度差 60pt（460 vs 400）、顺序差两格。而且窗口宽度是动态的，设计稿按固定 540 画的所有横向尺寸（分组卡宽、图标砖位置、底注宽 460）在法语下全部失真。商店截图 04 正是快捷键页，尺寸一改就要重拍。 |
| 建议处置 | 拍板三件事：窗口高度是否统一改到 460；**440 与 400 这两个数先收敛成一个**（现状是窗口比内容高 40pt，属代码缺陷，不是设计选择）；标签顺序按哪一份为准（改顺序会改变 `SettingsTab.rawValue`，而 `-settingsTab <0-4>` 这个截图参数依赖它，见 `SettingsView.swift:10-19`，要同步改截图脚本）。宽度动态计算建议保留，但设计稿需补一版「最宽标签」下的排布说明。 |

#### 7.5.10 VoiceOver 在这种窗口类型上的可达性从未验证

| 项 | 内容 |
| --- | --- |
| 现象 | 面板不是普通窗口：`SlidePanel` 是 `.borderless + .nonactivatingPanel` 的 `NSPanel`，`level = .statusBar`，`isFloatingPanel = true`、`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`、`canBecomeMain = false`。这几条叠在一起，VoiceOver 能不能进到面板里、进去之后光标在哪一层、`VO + 方向键` 能不能穿过卡片轨道，**全仓库没有任何一处验证过，也没有任何一行代码为此做过安排**。 |
| 证据 | `Copyo/Panel/PanelController.swift:7-10`（`SlidePanel`：`canBecomeKey = true` / `canBecomeMain = false`）、`:29-32`（`styleMask: [.borderless, .nonactivatingPanel]`，其中 **`:30`** 是 styleMask 本行）、`:35`（`isFloatingPanel = true`）、**`:36`**（`level = .statusBar`）、`:37`（`collectionBehavior`）、`:41`（`hidesOnDeactivate = false`）。<br>全仓 `grep -rin "voiceover\|旁白\|accessibilityElement\|NSAccessibility" --include="*.swift" Copyo/` **零命中**：Mac 端一条辅助功能相关的代码或注释都没有。 |
| 对本次重设计的影响 | 第四节 §4.7.2 为顶栏两枚图钮、六枚筛选胶囊、Pinboard 胶囊、卡片、悬停动作簇、轻提示开了一整张 `accessibilityLabel` 清单，7.5.8 也为它们各留了本地化字符串（同步图钮 3 条、设置图钮 1 条、悬停动作簇 2 条、卡片「已固定」1 条）。**如果 VoiceOver 根本到不了这个面板，这一整套标注就是白写的**——既花了实现工时，又占了 zh-Hans / fr 两份译文的额度。这是排在 §4.7.2 之前的前置风险，不是它的一个细节。 |
| 建议处置 | 开工前先做一次**真机 + VoiceOver 的可达性验证**（动作项，半天以内）：(a) 面板唤出后 VoiceOver 光标能否落进去；(b) `VO + →` 能否遍历顶栏 → 胶囊 → 卡片轨道；(c) 面板 `windowDidResignKey` 会不会被 VoiceOver 的焦点切换触发而自动收起（这一条与 7.5.2 的 `suppressAutoHide` 直接相关）。验证结论出来之前，§4.7.2 的清单按「**待验证**」挂起，不要按它排期。若结论是「不可达」，则要么面板改窗口类型，要么明确把辅助功能入口放在设置窗口（普通 `.titled` 窗口，`Copyo/Settings/SettingsWindowController.swift:10`）而不是面板上——这是一个需要拍板的产品决定，见 7.5.11 的 C 行。 |

---

#### 7.5.11 本节自造值与待验证项登记

7.5.1–7.5.10 正文里**由本规格自造、设计稿没有出处**的数值与口径，集中登记如下。属设计缺口的已并入第八节（见 A 行），属口径与验证的留在本节。

| 编号 | 事项 | 正文位置 | 性质 |
| --- | --- | --- | --- |
| A | 同步状态收敛成「正常 / 同步中 / 需要处理」**三态**这个切分方式，以及「需要处理」取橙 `#FF9F0A`——**本规格规定，设计稿未画**（`gen.py` 只有 `CLOUD_OK_I` 一个图标常量、只有 `SUCCESS_L #34C759` 一种着色）。 | 7.5.7 建议处置 / 第八节第 13 条 | 自造值，需补图或拍板 |
| B | 筛选胶囊与类型角标**是否各起一套本地化 key**。7.5.8 的「合计 58」建立在「分两套」这个隐含假设上；若共用则降到 **53**。macOS 侧**设计稿未写、本规格也未定**，此处照搬的是 iOS 的做法（`HistoryFilterChips.swift:24-26`）。 | 7.5.8 「关于 58 这个数」 | 口径未定，直接影响字符串预算 |
| C | 面板上 VoiceOver 是否可达——**未验证**，不是未设计。验证结论会决定第四节 §4.7.2 那张 `accessibilityLabel` 清单要不要做。 | 7.5.10 | 需先做验证动作项 |

---

#### 7.5.12 `Copyo` target 只编译 `Copyo/` 一个目录，共享 theme 层进不来

| 项 | 内容 |
| --- | --- |
| 现象 | Mac 侧 `Copyo/Panel/` 里的颜色、字号**全是字面量，没有任何 theme**。换肤的第一行 `CopyoTheme.bg.card` 今天写不出来。 |
| 证据 | 已核实 `Copyo.xcodeproj/project.pbxproj` 的 `fileSystemSynchronizedGroups`：`Copyo` → `[Copyo]`；`Copyo iOS` → `[CopyoIOS, CopyoShared]`；`CopyoShareExtension` → `[CopyoShareExtension, CopyoShared]`；`CopyoWidgets` → `[CopyoWidgets, CopyoShared]`（`project.pbxproj:182-184`）。统一 theme 在 `CopyoShared/UI/CopyoTheme.swift`（约 12k），但它 `import UIKit`。 |
| 选项 | (a) 不新建 target，把 `CopyoShared` 加进 Mac target 的同步组，并把 `CopyoTheme` 的 UIKit 依赖解掉（`Color(uiColor:)` / `UIColor` 改为跨平台封装）；(b) 新建一个 `CopyoUI` 库 target，四个 target 共同依赖；(c) macOS 端另写一份 theme（两端从此各自漂移）。§7.3 给出了这三条的取舍分析。 |
| 影响 | 面板换肤的第一行代码就卡在这里，是排在一切视觉工作之前的结构决定。注：`CopyoShared/UI/KindBadge.swift` 与 `CopyoShared/UI/KindPresentation.swift` 只 import `CopyoCore` 与 `SwiftUI`，**已可跨平台**，阻塞点只在 `CopyoTheme`。 |

#### 7.5.13 `-demoData` 只缺 Mac 这一端，iOS 侧已完整落地

| 项 | 内容 |
| --- | --- |
| 现象 | Mac target `Copyo/` 下**一处都没有**（`grep -rn demoData --include='*.swift' Copyo/` 零命中）：今天 Mac 的演示数据靠手工灌进 `~/Library/Application Support/Copyo/Copyo.store`（`scripts/make-store-shots.py:14`）。 |
| 证据（iOS 侧的现成模板） | `CopyoIOS/App/LaunchOptions.swift:7`（注释「`-demoData` 用内存容器 + 设计稿样例数据（不碰真实数据库）」）与 `:28` `useDemoData = arguments.contains("-demoData")` 解析开关；`CopyoIOS/App/StoreBootstrap.swift:18` 据此换成内存容器；`CopyoIOS/App/AppModel.swift:143-144` 启动时调 `DemoData.populate(in:)`；**`CopyoIOS/Model/DemoData.swift` 整个文件**是数据本体，其文件头注释（`:6`）明写「`-demoData` 用的样例数据，取自 design-spec 第六节」。周边配套：`CopyoIOS/Model/IOSSettings.swift:12/17`（换一次性演示 `UserDefaults` suite）、`CopyoIOS/App/CopyoIOSApp.swift:21` 与 `CopyoShared/SpotlightIndexer.swift:32`（停 Spotlight 索引）、`CopyoShared/WidgetRefresher.swift:36/41` 与 `AppModel.swift:136`（停小组件刷新）、`CopyoShared/AppGroup.swift:80-82` 与 `CopyoIOS/Intents/QuickSaveCoordinator.swift:47`（演示模式下不消费一键保存请求）、`CopyoIOS/Screens/History/HistoryScreen.swift:516-519`（`-demoScreen` 路由只在 `-demoData` 下生效）、`CopyoIOS/UI/Toast.swift:48`（说明 Toast 这里**没有**那道门禁）。 |
| 工作量性质 | **移植，不是设计**：照 `CopyoIOS/Model/DemoData.swift` 补一份 Mac 版，数据部分（文本、来源、kind、相对时间）按第六节 6.1–6.4 逐字搬。 |
| 需拍板的 | 哪些配套门禁在 Mac 上有对应物（Mac 无小组件、无 Spotlight 索引、无一键保存）；Mac 的演示是否同样走内存容器（走了就不会污染 `Copyo.store`，`make-store-shots.py:14` 那条路可以退役）。 |
| 一处不能直接照抄 | `DemoData.swift` 顶部 `import UIKit`，其缩略图是用 UIKit 现画并缓存的（`:252` 注释「只画一次并缓存：`-demoData` 里十条卡片共用同一张」，`:89` / `:95` 用 `DemoData.sampleImagePNG`）——Mac 版这一段要换成 AppKit 或改用一张随包资源。 |

#### 7.5.14 `Main.dc.html` 比 `gen.py` 旧，且 `gen.py` 现状跑不起来

| 项 | 内容 |
| --- | --- |
| 现象 | 浅色主态那张画板是脚本更早一版的产物：`gen.py` 的 `FILES` 字典里**已经没有生成它的那一段**（注释编号直接从 `# ---------- 2. A 版 面板 · 深色 ----------` 起步，第 1 节被删掉了）。 |
| 六处漂移 | ① **未选中筛选胶囊字色** `rgba(60,60,67,0.85)` vs `th["label"]` = `#000000`（`gen.py:102`）；② 搜索放大镜描边 `rgba(60,60,67,0.55)` vs `th["sec"]` = `rgba(60,60,67,0.60)`（`gen.py:214`）；③ 顶栏齿轮描边 `rgba(60,60,67,0.68)` vs 同上（`gen.py:216`）；④ keycap 底 + 色值胶囊底 `rgba(118,118,128,0.14)`（共 5 处）vs `fill2` = `rgba(118,118,128,0.20)`（keycap `gen.py:92`、色值胶囊 `gen.py:167`，`L` 字典在 `gen.py:11`）；⑤ keycap 字色 `rgba(60,60,67,0.8)` vs `meta` = `rgba(60,60,67,0.78)`；⑥ 提示条文字 `rgba(60,60,67,0.66)` vs `sec` = `rgba(60,60,67,0.60)`。另外 5 枚类型角标的 `<span>` 少了 `flex: none;`（`gen.py:86` 有，`A-panel-dark.dc.html` 里也有）。**最要紧的是第 ① 条**：`0.85` 与纯黑 `#000000` 肉眼可辨。 |
| 「重跑脚本补回来」为什么行不通 | (a) `gen.py` 的 `FILES` 里根本没有 `Main.dc.html` 这一项，重跑只会把这个文件原样留着；(b) `gen.py:5` 的 `OUT` 指向 `2026-09-20/project/`，**这个目录不存在**（十张画板都在 `2026-09-20/` 根下），照现状跑到 `gen.py:438` 的写文件那一步会直接抛 `FileNotFoundError`。 |
| 处置 | 要补回浅色主态帧，得先 (a) 修 `gen.py:5` 的 `OUT`，(b) 把被删掉的第 1 节（浅色 `desktop_frame(L, panel(L, inner))`）重新加回 `FILES`。在此之前 `Main.dc.html` **一律只作构图参考，取值全部以 `gen.py` 为准**（同一构图的深色版 `A-panel-dark.dc.html` 由现行 `gen.py` 生成，用的全是新值）。 |

#### 7.5.15 「清空历史」确认框在仓库里有两份实现

| 项 | 内容 |
| --- | --- |
| 现象 | `Copyo/App/AppDelegate.swift:231-239` 是 `NSAlert`（菜单栏那条路径，`:238` 还额外 `NSApp.activate`）；`Copyo/Settings/SettingsView.swift:170-175` 是 `.confirmationDialog`（设置页那条路径）。两处共用同一批 `String(localized:)`，删除逻辑一致，`Clear History?` 与那句 `This deletes every clipboard entry that isn't pinned to a Pinboard. This action cannot be undone.` 逐字相同。 |
| 对本次重设计的影响 | 第一章 §03b 新增的「面板空白处右键 → 清空历史」会成为**第三个入口**。两份实现不收敛，第三个入口就得在两者里挑一个抄，分歧会长期存在。 |
| 建议处置 | 抽出一个 `confirmClearHistory(from:)`，三处共用；形态（`NSAlert` / `.confirmationDialog` / 面板内联）属设计决定，见第八节第 21 条。 |

#### 7.5.16 `ClipCard` 上收到 `CopyoShared/UI/` 的分层边界

| 项 | 内容 |
| --- | --- |
| 现象 | §7.3 建议把 `ClipCard` 提到 `CopyoShared/UI/`，但 `docs/ios-plan.md` 第 3.5 节已明确记过「**没有上收，而且不该上收**」（`TimelineEntry` 装不下 `@Model`、`ImageMetadataCache` 的 96MB 上限会让扩展进程 jetsam）。 |
| 分歧点 | 那两条理由**只约束扩展与 Widget，不约束 Mac 宿主进程**——但这意味着共享层里会有一个**只给两个宿主 target 用**的文件。 |
| 需拍板 | 这种分层是否可接受；不接受的话 Mac 侧要另写一份 `ClipCard`，两端的卡片就此各自漂移。 |

#### 7.5.17 7.4 的规模格与工期口径需与工程侧确认

7.4.1–7.4.5 每条给出的规模格（**S ≈ 半天，M ≈ 1–2 天，L ≈ 3 天以上**，口径与 §7.1 / §7.2 相同）
**是本规格估算，不是设计稿内容**；7.4 整节「不计入 macOS 本轮工期」这一口径同样需要与工程侧确认。
若排期上要求 iOS 跟进与 macOS 同期交付，§7.1 / §7.2 的总量需要连同 7.4 的 **2 × M + 3 × S** 一起重算。

---

### 本章待确认

> 本章相关的待确认条目：见第八节第 1、2、6、9、10、13、14、16、17、20、21、30、31、32、33、37、38、44、45、47 条。
> 属工程缺陷或工具链问题的，就地登记在 7.5.1–7.5.17，不进第八节。

---

## 八、待确认

> **本节是全文唯一的集中待确认列表。** 各章末尾只留一行指针，指向这里的编号；编号一经分配不再变动，
> 新增条目一律追加在末尾。每条写明「**悬而未决的是什么 / 有哪些选项 / 不定会挡住什么 / 出处**」。
>
> 本节只收**设计稿的缺口**。属于工程缺陷、工具链问题或待验证事项的（快捷键注册失败无声、没有主菜单、
> 相对时间被冻结、VoiceOver 可达性、`Main.dc.html` 与 `gen.py` 漂移、`-demoData` 缺 Mac 端等）
> 一律登记在 **7.5 工程风险登记**，不重复列在这里。

### 面板几何与布局

1. **面板在屏幕上的定位规则，设计稿一个参数都没给。**
   - 悬而未决：(a) 可用区宽不足时的宽度上限公式；(b) 底边相对 `visibleFrame.minY` 的内缩量；
     (c) 水平对齐是居中 / 跟鼠标 / 跟上次位置；(d) 6K 等超宽屏上锁死 1280 还是按比例放大；
     (e) 逻辑宽度小于一张卡的最小可用宽（16 + 260 + 16 = **292pt**）时怎么退化；
     (f) **13 吋机器上（逻辑 1440 × 900 或 1470 × 956）1280 + 80 × 2 = 1440 恰好铺满**——
     一旦内缩量非零就必然要缩宽，`visibleFrame` 扣掉菜单栏与 Dock 后还剩多少要实测；
     (g) 1× 与 2× 缩放下卡片轨道是否换一套 `cardWidth`。
   - 选项：草稿里出现过的 `min(visibleFrame.width − 48, 1280)` 与「离底 24」**两个数都无出处**——
     48 在 `gen.py` / `gen2.py` 中不存在；24 是从画板上量出的面板底边到**装饰用 Dock 矩形**的距离，基准不是真实可用区。
     两者都不能当规则定稿。
   - 不定会挡住：面板几何是重写的第一行代码，不定就写不了 `show()`。拍板前 `PanelController` 只能落实
     「基准从 `screen.frame` 换成 `visibleFrame`、宽 1280、离底浮动」这三条。
   - 出处：`gen.py:234` `panel(th, inner, w=1280, h=332)`；`gen.py:254` `desktop_frame(..., w=1440, h=520, px=80, py=92)`（展示构图）；
     现状 `Copyo/Panel/PanelController.swift:15`（`panelHeight = 380`）、`:79-82`（`screen.frame` 满宽贴底）、`:130-133`（按鼠标选屏）。

2. **预览浮层（空格键 Quick Look）本轮重做，但设计未出。**
   - 悬而未决：尺寸、材质、页脚信息组成、五类内容的版式全部没有设计帧。
   - 选项：(a) 沿用现状尺寸只换 token；(b) 按新面板重画（圆角 26、玻璃外壳、meta 行统一成「来源 · 相对时间」）；
     (c) 本轮不动，顺延；(d) **按 iOS 规格 §3.13「详情页骨架」降 dense 档外推**——iOS 侧已画全：预览块 radius 12 /
     `padding 12` / 来源淡染底、色值胶囊高 30 / radius 15 / SF Mono 13、信息组 radius 12 / 行高 44 / 15pt label + 右值 /
     0.5px separator、底部玻璃工具栏高 64 radius 32 + 主按钮高 48 radius 24（`art/ios-design/design-spec.md:469–479`）。
     选 (d) 则本条从「设计未出」降级为「按既有来源换算」，工作量差一个量级，但**降档比例（行高 44 → ?、工具栏 64 → ?）仍需拍板**。
   - 不定会挡住：空格键这条交互在四张 A 版画板的提示条里都写着（`gen.py:227-232` 的 `hint("空格", "预览")`），
     面板定稿后浮层还是旧皮会很扎眼；7.5.5 的三处降级内容态也要在这张图里一并解决。
   - 出处：十张画板里没有预览浮层；现状读数 `Copyo/Panel/PreviewOverlay.swift:20-26`（680 × 320、radius 14、`.regularMaterial`）、
     `:88-101`（底部 30pt 信息条）。

3. **空态只画了「历史为空」一种。**
   - 悬而未决：「搜索有词但零结果」与「Pinboard 内容为空」两种空态显示什么——是否复用同一插画、文案如何写、
     筛选行与结果计数行是否保留。
   - 选项：(a) 两者复用同一插画换文案；(b) 搜索无结果退化为一行居中文字，不用插画。
   - 不定会挡住：搜索是本轮重点交互（`A-search.dc.html` 已定稿），输入到无结果这一步会掉进没有设计的地方。
   - 出处：`A-empty.dc.html`（`gen.py:314-335`）只有「历史为空」；现状搜索无结果走
     `Copyo/Panel/PanelRootView.swift:293` 的英文原串 `Nothing matches "…"`。

4. **空态帧的竖向合计对不上面板高 332。**
   - 悬而未决：16 + 32 + 12 + **222** + 12 + 24 + 16 = **334**，比面板高 2pt；01 主态与 01c 搜索态都正好 332。
   - 选项：(a) 空态块改为 220；(b) 面板在空态下放高 2pt。
   - 不定会挡住：空态帧的实现取哪个高度；两个数都写不进 `PanelRootView` 的布局。
   - 出处：`gen.py:314-335`（空态区 222）；`gen.py:234` 面板高 332。

5. **搜索态到底用不用矮卡片。**
   - 悬而未决：`A-search.dc.html` 把轨道高设成 **158**，但卡片本身仍是 `height: 184px; flex: none`——
     画板上是被 `overflow: hidden` 裁掉 26pt，末行正文**被切掉一半**而不是整行省略，不是真的换了一套矮卡片。
   - 选项：(a) 搜索态用真矮卡片（重排内容、clamp 下调）；(b) 沿用裁切（需接受半行被切）。
   - 不定会挡住：搜索态的卡片视图要不要第二套几何；也牵动第 38 条的 clamp 行数。
   - 出处：`A-search.dc.html` 的轨道高 158 与 `gen.py:108` `card()` 默认 `h=184`。

6. **轻提示只画了「已复制」一条，且定位基准有两个互相冲突的答案。**
   - 悬而未决：(a) 固定 / 删除 / 删除后撤销均无对应提示；(b) 实现基准是贴面板还是贴屏幕、越出多少。
   - 选项：(a) 只保留「已复制」，其余动作靠卡片本身的变化反馈；(b) 补「已固定」「已删除」两条同构提示。
     定位上：设计稿把 toast 画在 `left: 50%; bottom: 60px`，参照系是 **1360 × 452 的外层画板**（面板在画板内位于
     `left: 40px; top: 40px`），换算后 toast 占画板 y 356–392、面板下沿在 y 372，即**跨在面板底边上、向下越出约 20pt**；
     另一主张是它应当是一个独立的 `NSPanel`、出现在**菜单栏图标正下方**，理由是面板此时正在滑走。两者不能同时成立。
   - 不定会挡住：悬停动作簇里固定 / 删除两枚按钮按下后没有任何反馈的定义；`Panel/CopyToast.swift` 的窗口归属写不了。
   - 出处：`gen.py:284-288`（36pt 高胶囊、radius 18、`SUCCESS_L #34C759` 勾、`bottom: 60px`）、`gen.py:291-294`（画板外层 div）。
     进出时长（0.22s / 0.18s）为本规格自定，设计稿未给。

7. **悬停态的数值全部未经设计稿验证。**
   - 悬而未决：`gen.py:108-147` 的 `card()` 在 `hover=True` 时**只叠加玻璃动作簇，底色仍是默认淡染**；
     `Card.dc.html` 状态行第 2 张的说明也只写「悬停 · 玻璃动作簇 pin / delete」。
   - 选项：本规格第四节采用的一组值——淡染加深 12%→16% / 20%→26%、来源色 40% 的 0.5pt 描边（移植自 iOS 移植图 §3.1 第 6 条）、
     胶囊 / 搜索框 / 图标按钮悬停底色 `fill` → `fill2`、动作簇淡入 0.12s easeOut / 淡出 0.10s easeIn、
     拖放原位 ghost `opacity .35`（移植图 §5.10）——**要么整体采纳，要么补一版悬停卡画板核定**。
   - 不定会挡住：卡片是面板里唯一高频的悬停对象，悬停反馈定不下来，`ClipCard` 的状态机就少一档。
   - 出处：`gen.py:108-147`、`gen2.py:55`、`gen2.py:59`（拖起态）。

### 设置窗口

8. **「通用」页的四行开关没画出开关。**
   - 悬而未决：`gen2.py` 里定义了 `toggle()`（38 × 22、`#34C759` / `rgba(118,118,128,0.24)`），
     但 `Settings.dc.html` 的四行都没有用它，行右侧是空的。
   - 选项：(a) 画板漏画，按 `Toggle` 实现；(b) 有意改成别的控件形态（需给形态）。
   - 不定会挡住：通用页是已定稿的两页之一，行右侧留空就没法交付。
   - 出处：`gen2.py` 的 `toggle()` 定义与 `gen2.py:235-239` 的 `gen_content` 四行。

9. **设置窗口的尺寸与标签页顺序，设计与代码三处冲突。**（同一问题此前散在五处，已合并于此）
   - 悬而未决：(a) **高度**——设计 460（`gen2.py:219` `win(..., h=460)`）vs 代码内容高 400
     （`Copyo/Settings/SettingsView.swift:76` `SettingsLayout.height`）；注意代码里窗口高 440
     （`Copyo/Settings/SettingsWindowController.swift:9`）与内容高 400 **今天就不一致**，要先自我收敛。
     (b) **宽度**——设计固定 540，代码 `SettingsLayout.width`（`SettingsView.swift:85-92`）按最长标签标题实算
     （注释记着法语 `Synchronisation` 会把窗口顶到 707pt）。换成居中分段控件后这套算法是否还成立。
     (c) **标签顺序**——设计 `通用 / 同步 / 快捷键 / 历史 / 关于`（`gen2.py:228`）vs 代码
     `通用 / 历史 / 同步 / 快捷键 / 关于`（`SettingsView.swift:22-38`、`:47-48`）。
     (d) **容器形态**——代码用原生 `TabView` 标签栏（带 SF Symbol 图标、有宽度折叠风险，见 `SettingsView.swift:78-92` 注释），
     设计画的是居中的分段控件；换肤要不要连带换掉容器。
   - 不定会挡住：设置换肤的画板与代码对不上，一行都落不了地；标签顺序若改，`-settingsTab <0-4>` 的编号含义跟着变
     （见第六节 6.6），商店截图 04 是否重拍也取决于此。
   - 出处：`gen2.py:219`、`gen2.py:228`；`SettingsView.swift:22-38 / :47-48 / :73-93`；`SettingsWindowController.swift:9`。

10. **设置的「同步」「历史」「关于」三页未画。**
    - 悬而未决：`gen2.py` 只产出「通用」（`gen2.py:234-239` `gen_content`）与「快捷键」（`gen2.py:250-261` `key_content`）两页，
      装配在 `gen2.py:263-271`；`Settings.dc.html` 里也只有这两张。三页的文案清单同样缺失。
    - 选项：(a) 补齐三页再开工；(b) 只做已画的两页，其余三页沿用现状 `Form/.formStyle(.grouped)`；(c) 由实现方按两页的规则外推。
    - 不定会挡住：同步页是分歧最大的一页（两套构建风味的 UI 不同见 7.5.6、11 种可区分状态见 7.5.7），外推不出来；
      历史页有一个 80pt 高的 `TextEditor`（`SettingsView.swift:156-158`），换肤规则里没有对应控件。
    - 出处：`gen2.py:234-271`；`Settings.dc.html`。

11. **「在菜单栏显示图标」与「忽略密码管理器」两个新开关的行为未定义。**
    - 悬而未决：两者都出现在设计稿的「通用」页，代码里**都不存在**（全仓 grep 无 `showMenuBarIcon` 一类的 key）；
      「忽略」能力现状是历史页里的一个自由文本框 `ignoredApps`（`SettingsView.swift:137`、`:155-162`，按 bundle ID 逐行填）。
    - 选项：(a) 关掉菜单栏图标后唯一入口只剩全局快捷键，是否允许（关了又忘记快捷键就彻底进不去了）；
      (b) 「忽略密码管理器」是一个内置 bundle ID 列表的开关，还是 `ignoredApps` 的一个预设？两者与历史页那个文本框如何并存。
    - 不定会挡住：通用页是已定稿的两页之一，这两行落不了地这一页就换不完。
    - 出处：`gen2.py:235-238`。

12. **设置图标砖有四处内容是占位。**
    - 悬而未决：`TILE["start"]` / `TILE["priv"]` / `TILE["about"]` 的 `inner` 是 `None` 且从未被渲染；
      「登录时启动 Copyo」砖用的是 `CHECK_I`（一个裸对勾）；「忽略密码管理器」砖用的是 `tile("#FF9F0A", None, "A")`，
      即一个等宽字形「A」，不像最终图标。
    - 选项：四个都需要补定真实 SF Symbol 名。
    - 不定会挡住：通用页与（将来的）关于页的图标砖画不出来。
    - 出处：`gen2.py:177-181` `TILE`、`gen2.py:238`。

### 面板顶栏右侧那一格（第 13–16 条共用同一块 32 × 32 的空间，须一起拍板）

13. **面板上的同步状态表达。**
    - 悬而未决：设计只有「已同步」一态（`gen.py:210` 的 `aria-label` / `title` 是「iCloud 已同步」，图标是 `gen.py:55` 的 `CLOUD_OK_I`），
      代码有 **11 种**可区分状态。
    - 选项：(a) 面板只画三态（正常 / 同步中 / 需要处理），点「需要处理」跳设置·同步页对应行；
      (b) 面板只在异常时才出现图标，正常时不占位；(c) 面板完全不显示同步状态，只留在设置里。
      **注意「三态」这个切分方式、以及「需要处理」取橙 `#FF9F0A`，均为本规格规定、设计稿未画**
      （`gen.py` 只有 `CLOUD_OK_I` 一个图标常量、只有 `SUCCESS_L #34C759` 一种着色），采纳前需补图。
    - 不定会挡住：顶栏右侧那一格定不下来；三态图标与文案也要出图；第五节 §5.2 表里这两行的符号名目前是本规格规定的。
    - 出处：`gen.py:55 / :210`；现状见 7.5.7。

14. **文件夹同步模式在面板顶栏没有任何符号与状态。**
    - 悬而未决：macOS 的同步方式是**三选一**（`Copyo/Services/SyncMode.swift:11-14` `enum SyncMode { case off, folder, icloud }`，
      设置页选择器在 `SettingsView.swift:202-206`），不是「开 / 关 iCloud」；而第 13 条的三态与第五节 §5.2 给出的
      `checkmark.icloud` / `arrow.triangle.2.circlepath.icloud` / `icloud.slash` **三个全是 iCloud 形状**。
      用户选了「共享文件夹」时，顶栏画一朵云是错的信息。**iOS 侧没有对应物，不能照搬 iOS 的符号表。**
    - 选项：(a) 另起一套文件夹形状的符号（如 `folder` / `folder.badge.gearshape` / `folder.badge.questionmark`）；
      (b) 沿用同一套形状只换文案；(c) 该格在文件夹模式下隐藏。三个方案**均为本规格提出，设计稿未画**。
      一并要定：`off` 模式下这一格是否整格不出现；以及文件夹模式的**两个失败态**怎么在面板上表达——
      · **「未选目录」**（`SettingsView.swift:372` 的 `folderPath != nil` 判定、`:380-385` 的 footer 分支、
      `:397` 的 `String(localized: "No folder selected")`）：同步开着但一个字节都没同步过，是「未配置」不是「出错」，用橙色警告过重；
      · **「书签失效」**（`SettingsView.swift:368` 的 `lostAccess`、`:381-385`、`:421-426` 的 `statusLine`，
      现状 `exclamationmark.triangle.fill` + `.orange`；底层 `Copyo/Services/SyncService.swift:49` `enum SyncFailure { case noAccess }`，
      写入点 `:163` / `:169`，清除点 `SettingsView.swift:450`）：真的坏了、必须用户重选目录，需要能点进设置。
      **另注：这两态只在商店版存在**——直接分发版的同步页是一个自由文本框，没有 `lostAccess`（见 7.5.6），
      所以「面板上怎么表达」的答案在两套构建风味下可能不同。
    - 不定会挡住：与第 13 / 15 条是同一格空间，三条不一起拍板就定不下那一格；会反过来决定第五节 §5.2 要不要再补一组符号。
    - 出处：`SyncMode.swift:6-14`；`SettingsView.swift:202-206 / :368-397 / :421-426 / :450`；`SyncService.swift:49 / :163 / :169`。

15. **面板顶栏的齿轮按钮在直接分发版是否显示。**
    - 悬而未决：设计稿**无条件**画了齿轮（`gen.py:212`），代码里它在 `#if APPSTORE` 里（`Copyo/Panel/PanelRootView.swift:148-166`）。
    - 选项：(a) 两套风味都显示（需删掉那段条件编译）；(b) 保持差异，直接分发版顶栏右侧只有同步图钮。
    - 不定会挡住：顶栏右侧是 `32 + 8 + 32` 还是 `32` 一格，直接影响搜索框的可用宽度。
    - 出处：`gen.py:212`；`PanelRootView.swift:148-166`。

16. **两套构建风味下的同步页是否收敛成一套。**
    - 悬而未决：商店版走 `NSOpenPanel` + 安全书签（有 `lostAccess` 失败态），直接分发版是一个自由文本框（无失败态）。
    - 选项：(a) 出两套设计稿；(b) 把直接分发版的自由文本框也改成 `NSOpenPanel`，收敛成一套；(c) 直接分发版同步页维持现状不换肤。
    - 不定会挡住：设置换肤的工作量估不准（两套 vs 一套）；也决定第 10 条同步页能不能外推。
    - 出处：详见 7.5.6。

### 键盘与交互

17. **纯文本复制的键位：`⌥↩` 还是 `⇧↩`。**（三处不一致，此前散在四处待确认里）
    - 悬而未决：设计稿写 `⇧↩`（`gen2.py:241` `key_rows` 第三项 `("纯文本复制", "⇧↩")`）；
      Mac 今天实现的是 `⌥↩`（`Copyo/Panel/PanelRootView.swift:326-328` 的
      `case .return where press.modifiers.contains(.option)`，设置页文案 `Copyo/Settings/SettingsView.swift:506`，
      通用页脚注 `:120` 的「⌥↩ always copies as plain text.」）；iOS 侧是 `⇧↩`
      （`CopyoIOS/Screens/History/HistoryScreen.swift:459-460`、`HistoryShortcutHints.swift:15`）。
    - 选项：(a) 按设计改，并在发布说明里提；(b) 两个都接受一段时间（`⌥↩` 作为过渡期别名）；(c) 设计稿改回 `⌥↩`。
    - 不定会挡住：快捷键页是已定稿的两页之一，keycap 上印哪个字得先定；底部提示条与通用页脚注也要跟着改；
      牵动 7.5.8 的字符串替换清单。
    - 出处：`gen2.py:241`；`PanelRootView.swift:326-328`；`SettingsView.swift:120 / :506`。

18. **四条键盘语义未定：`⇥` / `↑↓` / `⌘1–9` / 搜索框有内容时的空格。**
    - 悬而未决：
      (a) **`⇥`**——设计稿的设置页写「**在筛选间循环**」（`gen2.py:242`），第四节 §4.1.1 的目标焦点模型要求它在
      **search / cards / filters 三区**循环，两者不是一回事；拍板后设置页的行名要跟着改（它是只读说明页，写错就是对用户说谎）。
      (b) **`↑↓`**——今天被 `case .upArrow, .downArrow: return .handled` 静默吞掉（`PanelRootView.swift:315-316`），
      设计稿的快捷键表与底部提示条都没有 `↑↓`；面板是单行横轨，`↑↓` 在 `.cards` 区没有天然含义。
      选项：继续吞掉 / 改为在 `.filters` 与 `.cards` 之间纵向切换。
      (c) **`⌘1–9`**——设计稿只写「直接取第 N 张卡」（`gen2.py:243`），未说是「选中第 N 张」还是「选中并立即复制收起」。
      (d) **空格预览**——今天有条件限制（`PanelRootView.swift:320`：`case .space where search.isEmpty`），
      设计稿没画「搜索框有内容时空格怎么办」。
    - 不定会挡住：`⌘F` / `⇥` / `⌘1–9` 三项 Mac 今天完全不存在，是本轮新增；焦点模型改造要一次做对，四条不定就要返工。
    - 出处：`gen2.py:241-243`；`PanelRootView.swift:315-316 / :320`。

19. **快捷键被占用后的恢复流程未定。**
    - 悬而未决：设计稿只画了警示行本身（`gen2.py:258`，文案「这个组合已被另一个 App 占用，Copyo 收不到它」）。
      按下去之后呢——保留旧组合，还是把失效的新组合留在界面上？重试入口在哪？
    - 选项：(a) 保存失败即回滚到旧组合并弹警示；(b) 保存新组合但标红，菜单栏与提示条都不再标注该组合。
    - 不定会挡住：7.5.1（注册结果被丢弃）的修法取决于这条；快捷键页的失败态目前无法点亮。
    - 出处：`gen2.py:258`。

20. **「新建 Pinboard…」对话框的视觉归属未定，设计稿十张画板一张都没画。**
    - 悬而未决：它**不是** `NSAlert`，是**面板内弹的 SwiftUI `.alert`**（`Copyo/Panel/PanelRootView.swift:108-117`：
      `.alert("New Pinboard", isPresented:)` + `TextField("Name")` + `Create` / `Cancel` + message
      `Pinboards keep the clips you use most within reach`）。正因为在面板里弹、会抢走 key window，
      才需要 `:98-107` 那套 `suppressAutoHide` + `makePanelKey()` 补丁。入口在右键菜单
      「固定到 Pinboard → 分隔线 → 新建 Pinboard…」（第一章 §03）。**没有任何一章说过它要不要换肤、换成什么样。**
    - 选项：(a) 系统 alert 原样不动（最省，但新面板是玻璃 + radius 26，中间弹一个系统方框很突兀）；
      (b) 按 iOS 规格 §3.11 的 Alert 规格降 macOS 档；(c) 改成**面板内联的一行输入**（贴在 Pinboard 胶囊下方），
      既躲开 alert，也顺带消掉那个焦点补丁。
      配套两件：**文案中文化**——现有五条英文原串（`New Pinboard` / `Name` / `Create` / `Cancel` + message），
      **不在** 7.5.8 的 58 条新增清单里（那张表只覆盖 `gen.py` / `gen2.py` 画到的部分）；
      **落地顺序**——第四节 §4.1.3 第 3 条要把 `suppressAutoHide` 升级成引用计数，若选 (c) 这个 alert 就不再是计数的第一个使用者，两件事的先后要重排。
    - 不定会挡住：右键菜单里「新建 Pinboard…」点下去之后长什么样是空白；面板重写时那段补丁是删是留也取决于选哪个方案。
    - 出处：`PanelRootView.swift:98-117`；`PanelController.swift:23` `var suppressAutoHide = false`。

21. **「清空历史」确认框的形态与入口统一。**
    - 悬而未决：仓库里现有**两份**实现，共用同一批 `String(localized:)`、删除逻辑一致——
      `Copyo/App/AppDelegate.swift:231-239` 的 `NSAlert`（菜单栏路径，`:238` 还额外 `NSApp.activate`）与
      `Copyo/Settings/SettingsView.swift:170-175` 的 `.confirmationDialog`（设置页路径）；两处的 `Clear History?`
      与那句 `This deletes every clipboard entry that isn't pinned to a Pinboard. This action cannot be undone.` 逐字相同。
      第一章 §03b 新增的「面板空白处右键 → 清空历史」会成为**第三个入口**。
    - 选项：三个入口统一走哪一种形态（`NSAlert` / `.confirmationDialog` / 面板内联确认）；
      面板内弹出时是否同样需要第 20 条那套 `suppressAutoHide` 补丁。
      （实现层面的「两份代码是否收敛成一处」登记在 7.5.15。）
    - 不定会挡住：面板空白处右键菜单的最后一项点下去之后没有定义。
    - 出处：`AppDelegate.swift:231-239`；`SettingsView.swift:170-175`。

22. **卡片右键菜单的三个新增项需确认。**
    - 悬而未决：`03` / `03b` 上下文菜单**没有设计帧**，菜单项文案是按 iOS 规格 3.11 与现有
      `PanelRootView.swift:253-285` 归并出来的。其中 **`分享`**（现有 macOS 代码里没有；原生答案是 `ShareLink`，
      但不在本轮「面板重做 + 设置换肤」的范围内）、**`清空历史`**、**面板空白处右键**这三项都是本轮新增。
    - 选项：逐项确认本轮补还是顺延；`分享` 若补，要定它出现在卡片菜单的哪个位置。
    - 不定会挡住：右键菜单的行数决定菜单宽度与分隔线位置，第一章 §03 的两张清单落不了地。
    - 另：**面板上下文菜单的完整图标集，A 版十张画板一张都没画。** §4.4.1 新增的
      `预览` / `在访达中显示` / `拷贝色值` 三项尤其没有交代用什么符号，第五节的符号表也没有它们。
      需要与菜单行数一并定下（macOS 的 `NSMenu` 可以不带图标，这本身也是一个选项）。
    - 出处：iOS 规格 §3.11；`PanelRootView.swift:253-285`；第五节符号表。

23. **多选未设计。**
    - 悬而未决：今天 `selectedIndex: Int` 是单一整数（`PanelRootView.swift:24`），面板不支持多选，
      右键菜单与悬停动作簇也都按单条设计。
    - 选项：(a) 1.1 不做多选；(b) 现在就把焦点模型做成支持多选。
    - 不定会挡住：不挡本轮；但若 1.2 要做批量删除 / 批量固定，焦点模型需要再改一次，代价在那时。
    - 出处：`PanelRootView.swift:24`。

24. **增强对比度 / 减弱透明度的降级数值，全是本规格自造。**
    - 悬而未决：`gen.py` / `gen2.py` 与十张画板里**都没有**对比度 / 透明度降级的变体可查。本规格自定的值是：
      增强对比度下「卡片淡染降到 0%」「`cring` 0.5pt → `separator` 1pt」「焦点环外圈 0.32 → 0.60」
      「失焦选中环 0.45 → 0.70」「`label.meta` 提到 `label`」「分隔线 0.5 → 1pt」；
      减弱透明度下「玻璃统一降级为 `bg.grouped` 实色」「预览遮罩 0.35 → 0.55」；
      以及第四节 §4.7.2 的「卡片摘要截断到 120 个字符」这个阈值。
    - 选项：(a) 整体采纳本规格的值；(b) 补一版「增强对比度 + 减弱透明度」的降级画板核定。
    - 不定会挡住：这两个系统开关打开时面板会怎样，今天没有任何可验收的标准。
    - 出处：本规格第四节 §4.7.2 / §4.7.3 / §4.7.4，设计稿无对应。

### 符号与品牌

25. **SVG 线宽到 SF Symbols 字重的换算表没定。**
    - 悬而未决：设计稿只给了描边宽度（1.5 / 1.6 / 1.7 / 1.8 / 2），没给对应的
      `.light` / `.regular` / `.medium` / `.semibold`。
    - 选项：需要一张逐档对照表，或改为逐个符号指定 `Font.Weight`。
    - 不定会挡住：第五节整张符号表的「线宽」列无法翻译成实现代码。
    - 出处：`gen.py` 的 `icon()` 与各图标常量。

26. **卡片「已固定」标记取 `pin` 还是 `pin.fill`。**
    - 悬而未决：设计稿两处（悬停动作簇、拖起态标记）用的都是同一个描边 `PIN_I`，即 `pin`；
      而 iOS 规格第五节写的是「已固定 = `pin.fill`」。
    - 选项：两端统一到 `pin.fill`（填充）/ 两端统一到 `pin`（描边）/ 允许分叉（动作簇用描边、状态标记用填充）。
    - 不定会挡住：同一条目在 Mac 和 iPhone 上的「已固定」标记形状不同。
    - 出处：`gen.py` 的 `PIN_I`；iOS 规格第五节。

27. **品牌红蓝在 macOS 的使用边界未定。**
    - 悬而未决：`Tokens.dc.html` 的 token 表把 `brand.bone` / `brand.red` 的允许范围写成
      「只在图标、空态、引导、设置图标砖」（`gen2.py:115-116`），但 macOS 的设置图标砖 `TILE`（`gen2.py:177-181`）
      用的**全是系统语义色，一个品牌色都没有**；macOS 也没有引导流程。
      也就是说 macOS 实际的品牌色出现点只有 **App 图标**与 **空态插画**两处。
      空态插画沿用了 iOS 的品牌红蓝错位骨白卡（`gen.py:316-324`，`BONE #F7F3EA` / `BRED #FF2D55` / `BBLUE #0A84FF` /
      `INK #16161A`，96 × 96、radius 22），iOS 规格称它是「**全 App 唯一在正文界面使用品牌红蓝的地方**」——
      这是 iOS 规格的结论，macOS 是否照搬未确认。
    - 选项：(a) 把允许清单按 macOS 实际收紧（去掉「设置图标砖」「引导」）；(b) 保留宽口径备将来用。
    - 不定会挡住：token 表的「允许范围」一列写不准；也决定将来设置图标砖能不能用品牌红。
    - 出处：`gen2.py:115-116`、`gen2.py:177-181`、`gen.py:316-324`。

28. **菜单栏模板图标未重新构思。**
    - 悬而未决：现状是 `Copyo/Assets.xcassets/MenuBarIcon.imageset` 下的 `menubar-template-18.png` /
      `menubar-template-36.png`，`Copyo/App/AppDelegate.swift:167-172` 设 `isTemplate = true`，
      取不到时回退到 SF Symbol `doc.on.clipboard.fill`。本轮明确不重做。
    - 选项：(a) 原样留到下一轮；(b) 本轮顺手按新品牌标识（`CopyoShared/Share/CopyoMark.swift`）出一版模板图。
    - 不定会挡住：不挡实现，但菜单栏图标是这个 App 唯一的常驻可见面，和新面板并排出现时风格是否割裂需要有人看过一眼再定。
    - 出处：`AppDelegate.swift:167-172`。

### Token 与取色

29. **来源淡染的舍入规则未写明，且字典与公式有三处对不上。**
    - 悬而未决：按 `round(0.12·s + 0.88·255)`（浅）与 `round(0.2·s + 0.8·base)`（深，`base` = `#2C2C2E` = 44,44,46）
      对 `SRC` 八条 + `COLORCLIP` 一条共 **18 个淡染值**逐条实算（round-half-up），对不上的是**三处**：
      Xcode 浅 `#E3F0FE` 的 B（字典 254 / 公式 254.52 → 255）、Safari 与访达 深 `#294457` 的 G（字典 68 / 公式 68.6 → 69）、
      `COLORCLIP` 深 `#562E36` 的 G（字典 46 / 公式 44.2 → 44，差 2）。
      **换一种舍入也救不回来**：改成截断时前两处对上了，但「微信」浅色 `#E1F8EC` 的 G 与 B 反过来对不上，
      整体命中率从 14 / 18 掉到 4 / 18；`COLORCLIP` 深色 G 的 2 之差在两种舍入下都存在。
      **结论是没有任何一种舍入方式能同时满足全表，字典是手算的。**
    - 选项：(a) 舍入规则取 round-half-up 还是 truncate，规格必须点名一种
      （注意 `CopyoShared/UI/CopyoTheme.swift:121-131` 的 `mix` 今天**根本不量化**：按 `CGFloat` 线性插值后直接构造
      `UIColor`，8 位取整只发生在最终光栅化，所以 iOS 侧今天既不是 round 也不是 truncate 而是「不取整」；
      只有当某一端改为硬编码 hex 字面量时，舍入才变成可观测的选择）；
      (b) 上述三处偏差以公式算出值为准（需同步改 `gen.py:65 / 67 / 71 / 74` 四个字面量），还是以字典字面值为准（需在实现里硬编码三个例外）；
      (c) 两端（`CopyoTheme.swift` 的 `mix` 与 macOS 侧实现）必须落到**同一种**舍入。
    - 不定会挡住：一端硬编码 hex、另一端浮点插值的话，同一条目在 Mac 和 iPhone 上会差 1，
      在卡片这种大面积淡染上**肉眼可辨**。
    - 出处：`gen.py` 的 `SRC` / `COLORCLIP` 字典（`:65 / :67 / :71 / :74`）；`CopyoTheme.swift:121-131`。

30. **取不到来源色时的回退色，两端不一致。**
    - 悬而未决：Mac 侧 `AppIconProvider.fallbackColor`（`Copyo/Services/AppIconProvider.swift:10`，
      `NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.58, alpha: 1)`）转 sRGB **已实测为 `#7E8EA5`**
      （换算见 §2.5）；规格要求的 `source.local` 是 `#8E8E93`（`CopyoTheme.swift:104`）。
      悬而未决的不是这个值，而是**统一到哪一个**，以及 `bundleID == nil` 时是继续把具体 hex 烤进条目
      还是改写 `nil`（见 7.4.7 的 (a)/(b)，其中 (a) 需要一次存量数据迁移）。
      另有一层：`bundleID == nil` 时是继续烤一个具体 hex 进条目，还是改写 `nil` 让两端走同一条回退分支（7.4.7 的 (a) / (b)），
      其中 (a) 需要一次**存量数据迁移**方案。
    - 选项：建议把 `fallbackColor` 直接改成 `NSColor(srgbRed:…)` 写 `#8E8E93`——这个值会经
      `Copyo/Services/ClipboardMonitor.swift:76` 的 `AppIconProvider.headerColor(forBundleID:).srgbHexString`
      写进条目并同步给 iOS，两端不一致时同一条目在 Mac 和 iPhone 上淡染不同色。
    - 不定会挡住：卡片淡染与角标底色都依赖它；不定就会持续产出两端不一致的存量数据。
    - 出处：`AppIconProvider.swift:10`；`ClipboardMonitor.swift:76`；`CopyoTheme.swift:104`；本文 7.4.7。

31. **颜色类条目解析失败时的淡染回退未画。**
    - 悬而未决：`plainText` 不是合法 hex 时，渲染色是落回 `sourceColorHex`，还是落回 `source.local #8E8E93`？
    - 选项：两者二选一，或给一条专用画法（不能与灰色条目撞，见 7.5.5）。
    - 不定会挡住：`ClipItem+Display.swift:143-146` 的 `colorValue` 今天返回 `Color?`，失败即 `nil`，**没有兜底**，
      7.4.2「颜色类条目的淡染取自身色」落地后这条路径会直接露出来。
    - 出处：`ClipItem+Display.swift:143-146`；本文 7.4.2。

32. **两端 token 的五处分歧，需逐条定「统一」还是「分叉」。**
    | # | token | macOS 设计稿 | iOS 规格 / `CopyoTheme.swift` | 待定 |
    | --- | --- | --- | --- | --- |
    | a | `label.tertiary` | `.34`（`gen.py` 的 `ter`） | `.3`（`CopyoTheme.swift:66`） | macOS 有意提浓还是笔误？若有意，iOS 是否同步到 `.34` |
    | b | 角标文字色（亮色带上） | 不透明 `#16161A` | `rgba(0,0,0,.78)` | 统一到哪一个 |
    | c | `glass` | 浅 `rgba(255,255,255,0.74)` + blur24 / 深 `rgba(58,58,60,0.72)` + blur24 | 浅 `rgba(255,255,255,.72)` + blur20 / 深 `rgba(120,120,128,.28)` + blur20 | 深色差异尤其大（不透明灰 vs 半透明中性灰），是平台差异还是需要对齐 |
    | d | `cring`（卡片 0.5px 描边）与 `swatchring` | macOS 新增 | iOS 卡片明确「无边框」 | iOS 是否补上，还是就此分叉 |
    | e | 卡片 meta 行颜色 | 新增 `label.meta`（`.78` / `.72`） | `labelSecondary`（`.6` / `.6`） | iOS 是否一并抬档；不抬的话同一条目两端浓度不同 |

33. **五个 token 的归宿未定（`rowOpaque` / `bg.raised` / `sheet` / `menu` / `sidebarBg`）。**
    - 悬而未决：
      (a) **`rowOpaque`**——7.4.1 修订后 `bgCard` 深色变成 `#2C2C2E`，与 `CopyoTheme.swift:84` 的 `rowOpaque` 深色取值**完全相同**，
      `:82` 记录的撞色前提消失。并进 `bgCard` / 并进 `bg.raised`（深 `#3A3A3C`）/ 保留为独立别名？
      (b) **`bg.raised`**——设计稿只在 `Tokens.dc.html` 给了色值（浅 `#FFFFFF` / 深 `#3A3A3C`）与一句
      「把 `ShareTheme` 里那条没回流的补丁转正」，**十张画板里没有任何一处实际用到它**；
      它在 Mac 面板里的用途（悬停行？分组内的第二层？）未定，以及是否值得现在就进 macOS 的 token 表（而非等 1.2）。
      (c) **`sheet`**（`CopyoTheme.swift:77`，深 `#1C1C1E`）——7.4.1 之后与 `bg.grouped` 同值，合并为一个 token 还是保留两个？
      (d) **`menu`**（`CopyoTheme.swift:75`，深 `rgba(44,44,46,.86)`）——`bgCard` 抬到 `#2C2C2E` 后同色相，
      分享面板的上下文菜单层级是否还分得出来，**未在设备上验证**。
      (e) **`sidebarBg`**（`CopyoTheme.swift:85`，深 `#141416`）——比新的 `bg.grouped` 还暗；未出现在 macOS 设计稿里，取值未定。
    - 不定会挡住：token 表的条目数与别名关系定不下来，共享 theme 层（7.3）就没法定稿。
    - 出处：`CopyoTheme.swift:75 / :77 / :82-85`；`Tokens.dc.html`；本文 7.4.1。

34. **macOS 是否响应系统「文字大小」设置。**
    - 悬而未决：设计稿给的是死点数；`CopyoTheme.swift:183-203` 那套 Dynamic Type 约束是 iOS 侧的，macOS 侧未表态。
    - 选项：(a) macOS 固定点数不响应；(b) 按系统设置做有限档位缩放（面板高度与卡片几何都要跟着变）。
    - 不定会挡住：若要响应，第一条（面板几何）与卡片 260 × 184 全部要改成可变；这是一个前置决定。
    - 出处：`CopyoTheme.swift:183-203`。

### 排版与文案

35. **等宽正文的字重取 Medium 还是 Regular。**
    - 悬而未决：`Tokens.dc.html` 的字号表把「11 / 15 mono」标成 Medium（`font-weight: 500`），
      但 `body_text(..., mono=True)` **没有设 `font-weight`**，实际渲染是 Regular。
    - 选项：两者二选一；若取 Medium，生成脚本要一并改。
    - 不定会挡住：颜色类与代码类卡片的正文字重定不下来。
    - 出处：`Tokens.dc.html` 字号表；`gen.py` 的 `body_text()`。

36. **两处题注与代码矛盾，需定要不要回改生成脚本。**
    - 悬而未决：
      (a) **「富文本角标 44pt」**（`gen2.py:66` 的题注）**与事实不符**：按 `badge()` 的几何，
      44pt 是**两个全角字**角标的固有宽（`5 + 10 + 3 + 20 + 6`）；中文「富文本」是三个全角字 = 30pt，
      整枚角标 = `5 + 10 + 3 + 30 + 6` = **54pt**，meta 行可用宽 = `260 − 24 − 54 − 6` = **176pt**（无图钉时）。
      **本文一律按 54 / 176 写，引用该题注时必须连同这条更正一起引。**
      (b) **键盘焦点环题注「2pt + 5pt @32%」**（`gen2.py` 的 `state_row()`）与 `card()` 里的
      `0 0 0 2px accent, 0 0 0 7px rgba(10,132,255,0.32)` 对不上——7pt 是**总扩散量**，减去内层 2pt 后露出 5pt。
      **本文按代码的 `2px / 7px` 写**，实现时按 CSS 语义换算成 SwiftUI 的两层描边。
    - 选项：题注就地改正 / 保留题注并在规格里长期挂更正。
    - 不定会挡住：不挡实现（取值已裁定），但下一轮重跑画板仍会印出错的题注。
    - 出处：`gen2.py:66`；`gen2.py` 的 `state_row()`；`gen.py:83` `pad="0 6px 0 5px"`、`gen.py:108-147` `card()`。

37. **meta 行的截断阈值未给，且生成脚本与目标行为相反。**
    - 悬而未决：题注说的「省略号从来源名开始吃、时间永不被截」是**目标行为**，画板本身做不到——
      `meta_cell` 是单个 `text-overflow: ellipsis` 的 span（`gen.py:137-138`），实际**从尾部截掉时间**。
      本文已裁定按题注的目标行为做（时间不可压缩、来源名独占截断），但还有两件没定：
      (a) `gen.py:137-138` 的渲染**要不要改**——若不改，下一轮重跑画板仍会画出从尾部截时间的样子，规格与画板会长期对不上；
      (b) 来源名段截到多短就整段隐藏，以及是否允许 `minimumScaleFactor`（iOS 侧用的是 `minimumScaleFactor`）。
      按第三节 §3.3 的几何，「富文本」角标 + 图钉同时在场时来源名段最窄只剩 `159 − 时间段固有宽`，
      这个下限下来源名可能只剩两三个字，需要设计方给一个「宁可整段不显示」的阈值。
    - 不定会挡住：SwiftUI 侧必须把 meta 行拆成两段实现，拆点的阈值不定就写不了。
    - 出处：`gen.py:137-138`；`gen2.py:66`；本文第三节 §3.3。

38. **文本卡正文的 clamp 取 7 行还是 6 行。**
    - 悬而未决：`gen.py:149-153` 的 `body_text` 默认 `-webkit-line-clamp: 7`，但按 `gen.py` 自己的卡片几何实算，
      260 × 184 的正文净高只有 **106pt**（`184 − 内距 12×2 − 头行 18 − 底行 20 − 两道 gap 8×2`），
      12/16 只装得下 **6 行**。画板上看不出来，是因为样例文案没有一条真的到第 7 行。
      **这个 106pt 与 6 行是本规格按 `gen.py` 数值实算的推论，设计稿未标注。**
    - 选项：(a) 把 clamp 改成 6；(b) 保留 7 并接受第 7 行被卡片高度切掉（那就等于没有真正消除「半行被切」）。
    - 不定会挡住：与第 5 条（搜索态是否换矮卡片）是同一处几何，宜一起定。
    - 出处：`gen.py:149-153`、`gen.py:108`。

39. **相对时间的显示阈值未定。**
    - 悬而未决：6.1 / 6.3 的「相对时间」在设计稿里是写死的字符串（`2 分钟前` / `昨天 18:42`），
      真实实现要用相对时间格式化；从「N 分钟前」切到「昨天 HH:mm」再切到日期的阈值，设计稿没给。
    - 选项：给一套三段阈值，或直接采用 `RelativeDateTimeFormatter` 的默认行为。
    - 不定会挡住：卡片 meta 行的右半段写不出来。（相对时间**被冻结不刷新**是另一回事，属工程缺陷，见 7.5.4。）
    - 出处：第六节 6.1 / 6.3 的样例串。

40. **文件卡「另外 N 个文件」的英文文案未给。**
    - 悬而未决：6.3 第 6 条的「另外 4 个文件」是中文写死串，英文版文案未给。
    - 选项：沿用现状 `"\(count) files"`（`Copyo/Panel/CardView.swift:154-173`），或另拟。
    - 不定会挡住：本地化清单少一条；英文商店截图里这张卡没有文案。
    - 出处：第六节 6.3 第 6 条；`CardView.swift:154-173`。

### 顺延与暂不影响本轮的

41. **历史上限的可选值未随新设计复核。**
    - 悬而未决：现状五档 `100 / 300 / 500 / 1000 / 无限`，默认 500；设计稿的「历史」页未画（见第 10 条），无从核对。
    - 不定会挡住：设置·历史页出图时才需要，不挡面板。
    - 出处：`Copyo/Settings/SettingsView.swift:136`（`@AppStorage("historyLimit") = 500`）、`:143-149`（选项）；
      默认注册在 `Copyo/App/AppDelegate.swift:26-29`。

42. **排序维度未列举。**
    - 悬而未决：面板当前只按创建时间倒序；设计稿里没有出现任何排序控件（A 版顶栏只有搜索框 + 两枚图钮 +
      六枚筛选胶囊 + 一枚 Pinboard 胶囊）。iOS 侧同样悬空（iOS 规格第八节第 6 条）。
    - 选项：(a) 本轮不做排序；(b) 在 Pinboard 胶囊旁加一个排序菜单。
    - 不定会挡住：不挡本轮；但若要加，顶栏那一行 32pt 高的横向空间已经排满，要重排。
    - 出处：`gen.py:199-224`。

43. **「关于」与「隐私说明」二级页未画。**
    - 悬而未决：现状「关于」页是一段居中的图标 + 版本 + 两句说明，没有独立的隐私说明页。
      iOS 侧同样悬空（iOS 规格第八节第 9 条）。
    - 选项：(a) 沿用单段文字；(b) 按 iOS 补一个二级页，两端共用文案。
    - 不定会挡住：不挡本轮实现；但商店审核要求的隐私描述如果要在 App 内可达，得提前定。
    - 出处：`Copyo/Settings/SettingsView.swift:593-617`（`:610` 是隐私那句）。

44. **多文件卡片在沙盒下图标不可读时的降级画法未定。**
    - 悬而未决：卡片 `fileContent` 单文件显示图标 + 文件名（两行截断），多文件显示图标 + `"\(count) files"`；
      沙盒下这些路径常常读不到——同一问题在拖拽路径上已被显式拦过（`PanelRootView.swift:410-418`（`isReadableFile` 的 guard 在 `:415`））。
      A 版面板的卡片取样里**没有文件卡**。
    - 选项：(a) 读不到时退到统一的通用文件符号 + 文件名；(b) 按扩展名给一组内置图标；(c) 整张卡退化成「文件 · N 个」的纯文字卡。
    - 不定会挡住：文件类卡片在新面板里画不出来；而筛选胶囊第六项就是「文件」（`gen.py:219` 的 `names` 列表末项），
      点进去必须有东西可看。
    - 出处：`Copyo/Panel/CardView.swift:154-173`（图标取自 `:157` 的 `NSWorkspace.shared.icon(forFile:)`）；`PanelRootView.swift:410-418`（`isReadableFile` 的 guard 在 `:415`）。

45. **B 版主窗口的处置与边界。**
    - 悬而未决：`B-window-light.dc.html` / `B-window-dark.dc.html`（各 26k，1180 × 800 画布，228pt 侧栏 + 三列 268pt 网格；
      B 版整段起于 `gen.py:337` 的注释，窗体函数 `b_window()` 在 `gen.py:358`）本轮**未采纳、顺延到 1.2**。
      但其中部分元素与 A 版共用：侧栏筛选行带**条目计数**（`gen.py:338-349` `sidebar_row`）、
      Pinboard 行带色点与计数（`gen.py:351-356` `pin_row`）、工具栏 52pt 带同步图钮（`gen.py:379-398`，高 52 在 `:379`，图钮在 `:394-398`）。
      B 版还额外用到一组侧栏分类点的固定色（`b_window()`：全部 `#8E8E93` / 文本 `#147EFB` / 链接 `#30B0C7` /
      图片 `#FF9F0A` / 颜色 `#FF2D55` / 文件 `#8E8E93`，Pinboard 行 `#0A84FF` / `#30D158` / `#FF9F0A`），
      其中 **`#30B0C7` 不在第二节任何一张表里**；这些色是否进 token 表未定，第二节暂不收录。
      另注：B 版侧栏底走的是 `bg.grouped`，没有用到 iOS 那边的 `sidebarBg`（`CopyoTheme.swift:85`）。
    - 选项：(a) 1.1 只做面板，B 版的一切（含条目计数、侧栏分组）都不实现；
      (b) 把「条目计数」这类**数据层**能力先做进 1.1，UI 留到 1.2。
      另需确认这两张稿是**原地保留**（作为 1.2 的起点）还是移入归档目录，以免后续有人误当本轮依据。
    - 不定会挡住：`PinboardListScreen` 式的计数查询要不要在本轮进数据层；也影响 1.1 的筛选胶囊是否需要显示数量
      （A 版胶囊 `gen.py:105-106` 不带数量）。B 版侧栏分类与 7.4.3 的 6 项筛选是同一套分类法，届时不需要二次拍板；
      其侧栏的键盘导航、三列网格的 `↑↓` 语义与多选（`⇧` 点选 / `⌘` 点选）均未展开。
    - 出处：`gen.py:337-398`；`canvas.json` 的便签 `n1`（2026-09-20 拍板原文）。

46. **成品深色帧只有 01 一张。**
    - 悬而未决：十张画板里只有 `A-panel-dark.dc.html`（01 主态）是成品深色整帧。另有两处深色内容**不构成整帧**：
      `Card.dc.html` 的「六种类型 · 深色」类型行（`dark_strip(kind_row(D))`，`gen2.py:84-85`）与
      `Tokens.dc.html` 每个 token 右半格的深色值（`gen2.py:153` 题注「左半格 = 浅色，右半格 = 深色」）；
      `B-window-dark.dc.html` 是深色整帧但 B 版本轮未采纳（见第 45 条）。
      **01b（悬停 + 轻提示）/ 01c（搜索）/ 01d（空态）/ 04（设置 · 通用）/ 04b（设置 · 快捷键）的深色版都没有画。**
    - 选项：(a) 按 `D` 字典逐帧换算导出，交设计方核定；(b) 只交付浅色帧，深色由实现按 token 表推导、不再出图。
      其中 **01d 空态插画**需要单独看一眼：三条 `#16161A` 内容条压在 `#F7F3EA` 骨白卡上在深色下不受影响，
      但**骨白卡本身与深色面板的对比需实机确认**。
    - 不定会挡住：深色是 macOS 上的常见设置，五张缺帧覆盖了本轮全部交付界面；不出图就没有深色的验收标准。
    - 出处：`canvas.json` 的 `boards` 列表；`gen2.py:84-85`、`gen2.py:153`。

47. **首启欢迎：按 iOS 引导页降档重做，还是维持 `NSAlert` 只做中文化。**
    - 悬而未决：macOS 今天的首启是一个英文 `NSAlert`（`Copyo/App/AppDelegate.swift:125-155`，
      商店版 / 直分发版两套 bullet 在 `:128-148`），既不是设计过的界面，也未本地化。
      iOS 侧有成形的三页引导（iOS 规格 §3.9：插图容器 180 × 180 radius 44、标题 28/34 Bold、
      说明行 radius 12 + 36 × 36 图标砖、页码点 7 × 7、CTA 高 52 radius 26），A 版十张画板没有对应帧。
    - 选项：(a) 维持 `NSAlert`，本轮只做中文化（最小改动，但首启是 Mac 版唯一一次讲清「⇧⌘V 唤出」
      与「复制后自己按 ⌘V」的机会，一个纯文本 alert 讲不动）；(b) 按 iOS §3.9 降 macOS 档重做成一个
      单窗口引导（需要新出设计帧，降档比例同第 2 条的问题）；(c) 顺延到 1.2，与菜单栏模板图标一起做。
    - 不定会挡住：不挡面板与设置的实现；但 7.4 的「品牌红蓝可出现在引导插图」这一条在 macOS 上
      是否成立取决于此（见第 27 条），且首启是安装后第一眼，与本轮重做的面板放在一起看会很割裂。
    - 出处：`Copyo/App/AppDelegate.swift:125-155`；iOS 规格 §3.9；A 版画板无对应帧。
