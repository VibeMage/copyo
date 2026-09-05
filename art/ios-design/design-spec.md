# Paster iOS / iPadOS 设计规格

创建日期：2026-09-05 · 最后更新：2026-09-05 · 来源：Claude Design 项目 Paster iOS Screens

> 本文是把 `art/ios-design/2026-09-05/Paster iOS Screens.dc.html`（含页尾「规格」节）与 `PasterCard.dc.html`
> 整理成的实现依据。数值逐字取自设计稿，未做取整或推断。设计稿里没有的内容不在此文档中，
> 含糊之处集中列在文末「待确认」。
>
> 原始文件（只读，不得改动）：
> - `art/ios-design/2026-09-05/Paster iOS Screens.dc.html` —— 01–10 全部界面 + 页尾规格节
> - `art/ios-design/2026-09-05/PasterCard.dc.html` —— 卡片组件的精确样式与状态
> - `art/ios-design/2026-09-05/Paster iOS.dc.html` —— 第一轮的三个方向探索（1a 套印 / 1b 细边 / 1c 染色），**1c 染色为最终方向**
> - `art/ios-design/2026-09-05/ios-frame.jsx`、`support.js`、`assets/` —— 画布外框与素材
>
> 方向定稿（设计稿原文）：iOS 26 大标题 + 浮动 Liquid Glass 标签栏；卡片 = 整卡淡染来源色（浅 12% / 深 20%）
> + 实心类型角标 + 「来源 · 相对时间」；圆角 12；双列瀑布流。本机条目中性灰 `#8E8E93`。
> 手机侧只画平台允许的三条保存通道与三条送出通道。

**画布尺寸**：iPhone 440 × 956 pt（6.9 英寸）；iPad 1376 × 1032（含 22pt 机身留白，内屏 1332 × 988，13 英寸横屏）。
每帧浅色 / 深色各一版。

---

## 一、界面清单（01–10）

导出文件名一律 `<编号>-<名称>-<light|dark>.png`，下表给出 light 版，dark 版同名替换后缀。

### 01 历史主屏

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 01 | 正常 · iCloud 已同步 | `01-history-light.png` / `01-history-dark.png` |
| 01b | 空态 · 首次启动，尚无 Mac 同步 | `01-history-empty-light.png` |
| 01c | 横幅「剪贴板有新内容」（回到前台、未允许自动读取）· iCloud 同步中 | `01-history-banner-light.png` |
| 01d | 「已保存」轻提示（一键保存后打开 App）· 新条目高亮插入顶部 | `01-history-saved-light.png` |
| 01e | 长按上下文菜单 · 「已复制」轻提示叠加 | `01-history-menu-light.png` |
| 01f | 滑动手势 · 左滑删除（上）/ 右滑固定（下）· 搜索中 | `01-history-swipe-light.png` |
| 01g | English | `01-history-en-light.png` |

**01 文案**：`已同步`（右上胶囊）· `历史`（大标题）· `搜索历史`（搜索栏占位）·
筛选 chips `全部` `文本` `链接` `图片` `颜色` · 标签栏 `历史` `Pinboard` `设置`。卡片内容见第六节 `raw` 十条。

**01b 文案**：`未同步` · `历史` · `搜索历史` · 空态标题 `还没有内容` ·
空态正文 `在 Mac 上复制过的内容，会通过 iCloud 出现在这里。手机上想留住的，用「分享」或「一键保存」存进来。` ·
主按钮 `开启 iCloud 同步` · 次按钮 `怎样保存剪贴板`。
空态插画：96 × 96 骨白卡片（`#F7F3EA`，radius 22，shadow `0 8px 24px rgba(0,0,0,.12)`），
上面一条 52 × 8 红 `#FF2D55`（opacity .9，位移 −2/−2）与一条同尺寸蓝 `#0A84FF`（opacity .85，位移 +2/+2，`mix-blend-mode: multiply`）错位套印，
下方三条 `#16161A` 内容条（宽 36 / 52 / 24，高 8，radius 4）。**这是全 App 唯一使用品牌红蓝错位的正文界面。**

**01c 文案**：`同步中…` · 横幅标题 `剪贴板有新内容` · 副文 `粘贴后保存到历史` · 按钮 `粘贴`（系统 UIPasteControl）+ 关闭 ×。
横幅位于筛选 chips 下方、卡片流上方。

**01d 文案**：轻提示 `已保存`。顶部插入的新卡片 = `savedItem`（见第六节），带 focused 蓝环。此帧顶部操作行留空（无 iCloud 胶囊）。

**01e 文案**：轻提示 `已复制`；菜单项 `复制` / `纯文本复制` / `分享` / `固定到 Pinboard` / `删除`（红）。
底层界面 `blur(14) opacity .6` + `t.dim` 遮罩；被长按卡片以 lift 态浮在菜单上方。

**01f 文案**：搜索框内容 `会议` + 光标 · `取消` · chips `全部` `文本` `链接` · 结果计数 `2 条结果` ·
左滑动作 `删除`（白字白图标，红底）· 右滑动作 `固定`（白字白图标，蓝底）。
下方是系统中文键盘（`qwertyuiop` / `asdfghjkl` / `zxcvbnm`，`123`、`空格`、蓝色 `搜索` 键，底排地球 + 麦克风）。
搜索态列表退化为单列，卡片间距 12。

**01g 文案（English）**：`Synced` · `History` · `Search history` · `All` `Text` `Links` `Images` `Colors` ·
标签栏 `History` `Pinboard` `Settings`。卡片内容见第六节 `itemsEn`。

**01 特有交互**：轻点卡片复制；长按上下文菜单；左滑删除、右滑固定；顶部筛选 chips 单选；下拉搜索。

### 02 详情

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 02 | 文本详情 · 底部操作工具栏 | `02-detail-light.png` |
| 02b | 颜色详情（图片详情同构：大图替换色块，字数行改为尺寸） | `02-detail-color-light.png` |

**02 文案**：返回 `历史` · 标题 `文本` · 更多 ⋯ ·
预览块角标 `文本` + `微信 · 12 分钟前` + 全文 `周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。` ·
信息组 `字数` → `54 字`；`来源` → `微信 · MacBook Pro`（前置 mac 图标）；`时间` → `今天 14:32`；`Pinboard` → `未固定` + chevron ·
工具栏 `复制`（蓝色主按钮）+ 纯文本 / 分享 / 固定 / 删除 四个图标按钮。

**02b 文案**：返回 `历史` · 标题 `颜色` · 更多 ⋯ ·
预览块角标 `颜色` + `Figma · 1 小时前` + pin 图标 + 220pt 色块 `#FF9F0A` ·
色值胶囊 `#FF9F0A`（加粗）/ `rgb(255,159,10)` / `hsl(36 100% 52%)` ·
信息组 `来源` → `Figma · MacBook Pro`；`时间` → `今天 13:05`；`Pinboard` → `设计 Token` + chevron ·
工具栏同 02，其中「固定」图标为蓝色（已固定态）。

**02 特有交互**：从卡片 zoom 转场进入；返回手势同源。

### 03 Pinboard

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 03 | 列表 · 右上「更多」打开排序 / 编辑；「+」新建 | `03-pinboard-light.png` |
| 03b | Pinboard 内容页 · 标题菜单（重命名 / 排序 / 删除） | `03-pinboard-content-light.png` |
| 03c | 新建 Pinboard · 系统 Alert | `03-pinboard-new-light.png` |

**03 文案**：大标题 `Pinboard` · 右上排序按钮 + `+` ·
四行 `设计 Token 6` / `常用地址 3` / `命令 12` / `发票信息 2` ·
脚注 `Pinboard 与 Mac 共用同一份。右滑固定卡片时默认进入第一个 Pinboard，长按可选。`

**03b 文案**：返回 `Pinboard` · 标题 `设计 Token` +（向下 chevron，示意可点开菜单）· 更多 ⋯ ·
副行 `6 条 · 按固定时间` · 菜单项 `重命名` / `排序方式` / `全部复制为纯文本` / `删除 Pinboard`（红）。
内容为 `boardItems` 六条，双列瀑布流。

**03c 文案**：Alert 标题 `新建 Pinboard` · 副文 `会同步到 Mac 上的 Pinboard 标签` ·
输入框内容 `常用地址` + 光标 · 按钮 `取消` / `创建`（加粗）。底层列表 `blur(6) opacity .7` + dim。

### 04 设置

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 04 | 设置总览 | `04-settings-light.png` |
| 04b | 一键保存 · 分段选择入口，各给图文步骤 | `04-settings-quicksave-light.png` |
| 04c | 怎样保存剪贴板 · 三条通道 | `04-settings-howto-light.png` |
| 04d | 允许从其他 App 粘贴 · 引导 | `04-settings-paste-light.png` |
| 04e | 启用 Paster 键盘 · 指引 | `04-settings-keyboard-light.png` |

**04 文案**：大标题 `设置`。
分组一 `同步`：`iCloud 同步`（开关，开）；子行 `状态` → `已同步 · 刚刚`；
脚注 `Mac 与 iPhone 登录同一 Apple 账户即可。内容只经过 iCloud，不经过任何第三方服务器。`
分组二 `剪贴板`：`怎样保存剪贴板` ›；`一键保存` → `操作按钮` ›；`允许从其他 App 粘贴` → `询问`（橙色 `#FF9F0A`）›；
`Paster 键盘` → `未启用` ›；`历史上限` → `500 条` ›。
分组三（无标题）：`开源 · GitHub` ↗；`隐私说明` ›；`关于` → `1.0 (12)` ›。
图标砖底色依次：`#0A84FF`（云）、`#FF9F0A`（问号）、`#FF2D55`（闪电）、`#8E8E93`（剪贴板）、`#5856D6`（键盘）、`#34C759`（时钟）、`#48484A`（代码）、`#0A84FF`（手）、`#8E8E93`（信息）。

**04b 文案**：返回 `设置` · 标题 `一键保存` ·
说明 `按一下就把当前剪贴板存进 Paster。系统会打开 Paster 并显示「已保存」。三种入口都靠同一个快捷指令。` ·
分段控件 `操作按钮`（选中）/ `敲击背面` / `控制中心` ·
主按钮 `添加「保存剪贴板」快捷指令` ·
步骤 1 `点上方按钮，在「快捷指令」里确认添加` / `只需一次，三种入口共用`；
步骤 2 `前往「设置 › 操作按钮」，选择「快捷指令」` / `iPhone 15 Pro 及之后机型`（右侧 64 × 100 手机示意图，左侧一段橙色 `#FF9F0A` 侧键）；
步骤 3 `在快捷指令列表里选「保存剪贴板」` / `长按操作按钮即可保存` ·
底部按钮 `打开「操作按钮」设置`。

**04c 文案**：返回 `设置` · 标题 `怎样保存剪贴板` ·
导语 `iOS 不允许 App 在后台读剪贴板，所以 Paster 只在这三种时刻保存内容。` ·
卡片一 `打开 Paster 时` / `每次打开或回到 Paster，自动读取当前剪贴板并存入历史。需要把「从其他 App 粘贴」设为允许。` / 行动胶囊 `前往设置` ›；
卡片二 `分享面板` / `在任何 App 里选中文字或图片，点「分享」，再点「保存到 Paster」。可以顺手选 Pinboard。`；
卡片三 `一键保存` / `复制后按操作按钮、敲两下手机背面，或点控制中心按钮。Paster 会打开并提示「已保存」。` / 行动胶囊 `设置一键保存` ›（图标为品牌红 `#FF2D55` 闪电，底色 `tintRed`）·
脚注 `Mac 上复制的内容不需要任何操作，会自动通过 iCloud 出现在历史里。`

**04d 文案**：返回 `设置` · 标题 `允许从其他 App 粘贴` ·
状态卡 橙点 + `当前：每次询问` + `系统每次弹窗确认` ·
说明 `设为「允许」后，打开 Paster 时自动读取剪贴板，不再弹窗。这是 iOS 的隐私设置，只能在系统「设置」里更改。` ·
步骤 1 `打开「设置 › App › Paster」`；2 `点「从其他 App 粘贴」`；3 `选择「允许」` +
内嵌系统选项示意 `询问` / `拒绝` / `允许 ✓` ·
主按钮 `打开 Paster 的系统设置` ·
脚注 `未允许时，历史顶部会显示「剪贴板有新内容」横幅，用系统粘贴按钮手动保存。`

**04e 文案**：返回 `设置` · 标题 `Paster 键盘` ·
键盘预览（搜索行 `搜索` + 三张 dense 卡片 `kbCards`）·
说明 `在任何输入框里切换到 Paster 键盘，点卡片直接输入内容，不用来回切 App。` ·
步骤 1 `「设置 › 通用 › 键盘 › 键盘」`；2 `「添加新键盘…」，选择 Paster`；
3 `打开「允许完全访问」` + 附注 `键盘扩展需要它才能读取历史。Paster 不联网、不记录按键。` ·
主按钮 `打开键盘设置`。**（键盘扩展本身是 Phase 2；此设置页可随 Phase 2 一并实现。）**

### 05 首次启动引导（可跳过）

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 05a | 与 Mac 互通 | `05-onboarding-1-light.png` |
| 05b | 怎么保存（三条通道） | `05-onboarding-2-light.png` |
| 05c | 开启 iCloud 与「允许粘贴」 | `05-onboarding-3-light.png` |

**05a 文案**：跳过按钮 `跳过` · 标题 `Mac 剪贴板，随身带着` ·
正文 `在 Mac 上复制过的一切，会通过 iCloud 出现在这里。随时搜，轻点即复制。` · CTA `继续` ·
插图：mac 图标 44 → 双向箭头 26（灰 `#8E8E93`）→ iphone 图标 40，均为 `#0A84FF`。

**05b 文案**：`跳过` · 标题 `手机上想留住的，三种方式存进来` ·
正文 `iOS 不允许 App 在后台读剪贴板，Paster 只在这三种时刻保存。` ·
三行：`打开 Paster 时` / `自动读取当前剪贴板`；`分享面板` / `任何 App 里「保存到 Paster」`；
`一键保存` / `操作按钮 / 敲击背面 / 控制中心` · CTA `继续` · 插图 tray 64。

**05c 文案**：跳过按钮 `以后再说` · 标题 `两个开关，打开就好` · 正文 `都可以稍后在「设置」里更改。` ·
两行：`iCloud 同步` / `与 Mac 共用同一份历史` + 右侧开关（开，`#34C759`）；
`允许从其他 App 粘贴` / `在系统设置里设为「允许」，不再弹窗` + 右侧胶囊按钮 `前往设置` ·
CTA `开始使用` · 插图 cloudCheck 64。

### 06 分享扩展 · 紧凑 sheet

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 06 | 「保存到 Paster」· 内容预览 + 可选 Pinboard + 保存 | `06-share-light.png` |

**文案**：`取消` · 标题 `保存到 Paster`（左侧 26 × 26 App 图标）·
预览卡（中性灰淡染）角标 `文本` + `本机 · 现在` + 正文
`Liquid Glass 是一种动态材质，会根据背后的内容折射光线并实时响应移动。标签栏、工具栏与搜索栏默认采用该材质。`（4 行截断）
+ 脚注 `63 字 · 纯文本` · 行 `固定到 Pinboard` → `不固定` › · 主按钮 `保存`。
宿主界面在 sheet 后 `blur(2) opacity .6` + dim。

### 07 键盘扩展 —— **Phase 2，本轮不做**

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 07 | 正常态 · 横向卡片条 + 搜索 + 最小打字行；宿主为任意 App 输入框 | `07-keyboard-light.png` |
| 07b | 未开启「完全访问」提示态 | `07-keyboard-noaccess-light.png` |

**07 文案**：宿主 `取消` / `新信息` / `发送`；`收件人：` + `小林`；正文 `地址发你：` + 光标 ·
键盘区搜索行 `搜索历史` + 右提示 `↑ 长按卡片预览` · 横向 dense 卡片条 `kbStrip` 四条 ·
底排 地球 / `↑` / `空格` / 删除 / `换行`。

**07b 文案**：锁图标 + `需要「允许完全访问」才能显示历史` ·
`设置 › 通用 › 键盘 › 键盘 › Paster。Paster 不联网，也不记录你的输入。` · 按钮 `打开设置` · 底排同上。

### 08 小组件与控件 —— **小 / 中尺寸小组件属 Phase 2；「保存剪贴板」控件（控制中心 / 锁屏）本轮要做**

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 08 | 小尺寸（最近 1 条）· 中尺寸（最近 4 条）· 点按复制 · 锁屏 / 控制中心「保存剪贴板」控件 | `08-widgets-light.png` |

**文案**：小尺寸 头部 `最近` + `刚刚`；角标 `文本`；正文 `【抖音】验证码 482913，5 分钟内有效，请勿泄露给他人。`（3 行截断）；脚注 `点按复制`。
中尺寸 头部 `最近` + `已同步`；2 × 2 四条（见第六节 `widgetItems`）。
右侧控件：60 × 60 玻璃圆钮 + 说明 `控制中心 / 保存剪贴板`；51 × 51 锁屏圆钮 + 说明 `锁屏控件`。
一帧画在壁纸底上（浅 `linear-gradient(160deg,#dfe7f2,#e9dfd3)` / 深 `linear-gradient(160deg,#1B1620,#08060B)`）。

### 09 / 10 iPad 13 英寸横屏

| 帧 | 状态 | 导出文件名 |
| --- | --- | --- |
| 09 | Split View：左 Paster（选中态 · 硬件键盘焦点态 · 拖动中间态）· 右 任意文稿 App 接收拖放 | `09-ipad-grid-light.png` |
| 10 | Slide Over / 紧凑宽度 → 退化为 iPhone 布局（浮动标签栏、双列流） | `10-ipad-slideover-light.png` |

**09 文案**：状态条 `9:41 · 9 月 5 日 周五` / `iCloud 已同步 · 100%` ·
侧栏标题 `Paster` + 侧栏图标；搜索 `搜索` + 快捷键提示 `⌘F`；
分类行 `历史 1 284`（选中）/ `文本 902` / `链接 211` / `图片 96` / `颜色 41` / `文件 34`；
分组标题 `PINBOARD` + `+`；四个 Pinboard 行（名称 + 计数）；底部 `设置` ·
内容区标题 `历史` + `已同步` 胶囊 + 排序按钮；三列网格十张卡片，其中第 2 张 selected、第 3 张 ghost（被拖走的原位）、第 4 张 focused ·
底部快捷键条 `↵ 复制` / `⇧↵ 纯文本` / `空格 预览` / `⌘P 固定` / `⌫ 删除` ·
右侧接收 App：`会议准备.txt`、`Q4 排期会`、`时间地点待确认。上周漏斗数据见附件。` + 蓝色插入指示条 ·
拖动中卡片（`raw[2]` 微信条目）旋转 −3°，右上绿色 `+` 徽标。

**10 文案**：状态条 `9:41 · 9 月 5 日 周五` / `100%` ·
背景 App `会议准备.txt` / `Q4 排期会` / `时间地点待确认。上周漏斗数据见附件。周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上。` ·
Slide Over 面板：grabber、`已同步` 胶囊、大标题 `历史`、`搜索历史`、chips `全部` `文本` `链接` `图片` `颜色`、
dense 双列卡片流、浮动标签栏 `历史` `Pinboard` `设置`。

---

## 二、Tokens

### 2.1 语义色（页尾规格节原文）

| token | light | dark |
| --- | --- | --- |
| accent | `#0A84FF` | `#0A84FF` |
| destructive | `#FF3B30` | `#FF453A` |
| success | `#34C759` | `#30D158` |
| bg.grouped | `#F2F2F7` | `#000000` |
| bg.card | `#FFFFFF` | `#1C1C1E` |
| label | `#000000` | `#FFFFFF` |
| label.secondary | `rgba(60,60,67,.6)` | `rgba(235,235,245,.6)` |
| label.tertiary | `rgba(60,60,67,.3)` | `rgba(235,235,245,.3)` |
| fill | `rgba(118,118,128,.12)` | `rgba(118,118,128,.24)` |
| separator | `rgba(60,60,67,.24)` | `rgba(84,84,88,.6)` |
| glass | `rgba(255,255,255,.72)` + blur20 | `rgba(120,120,128,.28)` + blur20 |
| card.tint | `mix(source 12%, #FFF)` | `mix(source 20%, #1C1C1E)` |
| source.local | `#8E8E93` | `#8E8E93` |
| brand.red / blue | `#FF2D55` / `#0A84FF` | 仅图标、空态、引导 |
| brand.bone / ink | `#F7F3EA` / `#16161A` | 同上 |

> **角标文字色**：来源色亮度 > 0.62 用 `rgba(0,0,0,.78)`，否则 `#FFF`。Mac 端算好的来源色随条目同步。
> 亮度公式（取自卡片组件）：`lum = (0.299·R + 0.587·G + 0.114·B) / 255`。

### 2.2 主题对象补充值（设计稿 JS 里定义、规格表未列的）

| 名称 | light | dark | 用途 |
| --- | --- | --- | --- |
| fill2 | `rgba(118,118,128,.2)` | `rgba(118,118,128,.32)` | 次级填充 |
| glassRing | `inset 0 0 0 .5px rgba(0,0,0,.06)` | `inset 0 0 0 .5px rgba(255,255,255,.15)` | 玻璃描边 |
| glassSh | `0 1px 3px rgba(0,0,0,.08), 0 8px 24px rgba(0,0,0,.08), inset 0 0 0 .5px rgba(0,0,0,.06)` | `0 8px 24px rgba(0,0,0,.3), inset 0 0 0 .5px rgba(255,255,255,.15)` | 玻璃阴影 |
| fade | `linear-gradient(rgba(242,242,247,0), rgba(242,242,247,.92) 60%)` | `linear-gradient(rgba(0,0,0,0), rgba(0,0,0,.92) 60%)` | 列表底部渐隐（高 140） |
| tabOn | `rgba(0,0,0,.07)` | `rgba(255,255,255,.12)` | 标签栏选中底 |
| dim | `rgba(0,0,0,.18)` | `rgba(0,0,0,.5)` | 模态遮罩 |
| menu | `rgba(250,250,250,.86)` | `rgba(44,44,46,.86)` | 上下文菜单 / Alert 底 |
| menuSep | `rgba(60,60,67,.12)` | `rgba(255,255,255,.08)` | 菜单破坏项前的 8pt 分隔块 |
| sheet | `#F2F2F7` | `#1C1C1E` | 分享 sheet 底 |
| green | `#34C759` | `#30D158` | 开关开启态 |
| kb / key / keyDark / keySh | `#D1D3D9` / `#FFFFFF` / `#ABB0BA` / `rgba(0,0,0,.3)` | `#2A2A2C` / `#6B6B6F` / `#464649` / `rgba(0,0,0,.5)` | 键盘底 / 键帽 / 功能键 / 键阴影 |
| sideBg | `#EBEBF0` | `#141416` | iPad 侧栏底 |
| wallpaper | `linear-gradient(160deg,#dfe7f2,#e9dfd3)` | `linear-gradient(160deg,#1B1620,#08060B)` | 08 小组件底 |
| lockFill | `rgba(0,0,0,.08)` | `rgba(255,255,255,.18)` | 锁屏控件底 |
| tintBlue | `rgba(10,132,255,.12)` | `rgba(10,132,255,.22)` | 蓝色图标砖底 |
| tintRed | `rgba(255,45,85,.12)` | `rgba(255,45,85,.22)` | 红色图标砖底 |
| tintGray | `color-mix(in srgb,#8E8E93 12%,#fff)` | `color-mix(in srgb,#8E8E93 20%,#1C1C1E)` | 本机条目淡染（tint 公式的实例） |
| blend | `multiply` | `screen` | 品牌红蓝套印的混合模式 |

### 2.3 圆角 · 间距（页尾规格节原文）

| token | 值 |
| --- | --- |
| radius.card | 12 |
| radius.inner | 8（色块、缩略图） |
| radius.badge | 10（高 20 胶囊） |
| radius.group | 12（设置分组） |
| radius.sheet | 38 |
| radius.glass | 全圆（tab 32 / 按钮 20） |
| space | 4 · 8 · 12 · 16 · 20 · 24 |
| page.inset | 20（iPhone）/ 24（iPad） |
| grid.gap | 12（iPhone 双列）/ 12（iPad 三列） |
| card.pad | 12（dense 10） |
| tab.bar | 高 64，底距 26 |
| hit.min | 44 × 44 |

### 2.4 字号（页尾规格节原文）

| token | 值 |
| --- | --- |
| largeTitle | 34/41 Bold |
| title1 | 28/34 Bold（引导） |
| title2 | 22/28 Bold |
| headline | 17/22 Semibold |
| body | 17/24 |
| card.body | 15/20（dense 13/17） |
| card.mono | SF Mono 13/18（dense 11/15） |
| subhead | 15/20 |
| footnote | 13/18 |
| caption | 11/13 · 角标 11 Semibold |
| tab.label | 10 Semibold |

> 全部用 Dynamic Type 文本样式对应，中文回落苹方。

Dynamic Type 对应（按上表字号推）：largeTitle → `.largeTitle`；title1 → `.title`；title2 → `.title2`；
headline → `.headline`；body → `.body`；card.body / subhead → `.subheadline`；footnote → `.footnote`；
caption / 角标 → `.caption2`；tab.label → `.caption2` Semibold。字体族：SF Pro / 苹方（`-apple-system` → `PingFang SC`），
等宽用 SF Mono（回落 Menlo）。

---

## 三、组件规格

### 3.1 卡片 PasterCard

组件属性：`item`（ClipItem）、`t`（Theme）、`dense`、`en`、`sel`、`foc`、`lift`、`pressed`、`ghost`。

**容器**：`radius 12`、`overflow hidden`、`padding 12`（dense `10`）、
`background = card.tint`（浅 `color-mix(in srgb, 来源色 12%, #fff)`；深 `color-mix(in srgb, 来源色 20%, #1C1C1E)`）、
无边框、高度由内容决定。

**头部行**：`display flex; align-items center; gap 6; margin-bottom 10`（dense `6`）。
- 类型角标：高 20，`padding 0 7px 0 6px`，radius 10，字号 11 Semibold，背景 = 来源色实心，文字 = `onBand`；内含 11pt 线图标（stroke 2.4）。
- 元信息：`来源 · 相对时间`，字号 11，`label.secondary`，单行省略，占满剩余宽度。
- pin 图标：仅 `pinned` 时出现，12pt，stroke 2.2，`label.secondary` 色。

**六种内容布局**：

| 类型 | 布局 |
| --- | --- |
| 文本 text | 字号 15/20（dense 13/17），`label` 色，6 行截断（dense 3），`word-break: break-word`，保留换行 |
| 文本 · 等宽 text+mono | SF Mono/Menlo 13/18（dense 11/15），6 行截断（dense 3），`word-break: break-all`；代码 / 命令自动识别 |
| 富文本 richText | 标题行 15/20 Bold（`font-weight 700`）+ 正文 14（dense 12）、色 `rgba(60,60,67,.9)` / 深色 `rgba(235,235,245,.85)`、6 行截断（dense 3）、保留换行 |
| 链接 link | 标题 15/20 Semibold，3 行截断；域名 12，`#0A84FF`，单行省略；两行间距 4 |
| 颜色 color | 色块 高 80（dense 40）、radius 8、填充色值；下方 SF Mono 15（dense 13）Semibold 色值；间距 8 |
| 图片 image | 缩略图 高 160（dense 70）、radius 8；下方 `1284 × 2778 · PNG` 之类 12 `label.secondary`；间距 8 |
| 文件 file | 文件名 15 Semibold 单行省略；下方 `仅 Mac` 灰标：高 18、`padding 0 6`、radius 5、字号 11 Semibold、`label.secondary` 色、底 `rgba(0,0,0,.06)` / 深 `rgba(255,255,255,.1)`，前置 desktopcomputer 图标；间距 6 |

图片占位渐变（设计稿的样例缩略图）：浅 `linear-gradient(160deg,#d9e6f5,#f3e7d6 60%,#e6dcef)`，
深 `linear-gradient(160deg,#2b3646,#3d3630 60%,#352d3f)`。

**状态**：

| 状态 | 表现 |
| --- | --- |
| pressed | `scale(.96)` |
| selected | `box-shadow: 0 0 0 3px #0A84FF`（3pt accent 环） |
| focused | `box-shadow: 0 0 0 2px #0A84FF, 0 0 0 5px rgba(10,132,255,.35)`（2pt + 5pt 35% 光晕） |
| lift（拖拽 / 长按预览） | `scale(1.04) rotate(-2deg)` + `box-shadow: 0 12px 32px rgba(0,0,0,.28)` |
| ghost（拖走后的原位） | `opacity .35` |

本机条目来源固定 `本机`（英文 `This iPhone`）、色 `#8E8E93`。

### 3.2 类型角标

6 种：`文本 / 富文本 / 链接 / 颜色 / 图片 / 文件`（英文 `Text / Rich / Link / Color / Image / File`）。
高 20，圆角 10，左内距 6、右内距 7，图标 11 + 文字 11 Semibold，实心来源色底。

### 3.3 来源淡染

色 = 同步来的来源色；淡染比例浅 12% / 深 20%；角标即色带的实心表达（1c 方向把 Mac 版的顶部色带转成整卡淡染）。

### 3.4 轻提示（Toast）

玻璃胶囊，高 40，圆角 20，顶部距安全区 6（设计稿绝对定位 `top: 66`），水平居中；
`padding 0 16px 0 12px`、`gap 6`；图标 22 success 色（`checkmark.circle.fill`）+ 15 Semibold `label` 文字；
背景 glass + `blur(20) saturate(180%)` + glassSh；停留 1.2s。
文案：`已复制` / `已保存` / `已固定`。

### 3.5 横幅（剪贴板有新内容）

卡片底 `bg.card`，圆角 14，内距 `12 / 14`（右 12、左 14），阴影 `0 1px 3px rgba(0,0,0,.08)` + glassRing，
位于筛选 chips 下方 14pt；
左 clipboard 图标 accent 24；标题 15 Semibold + 副文 12 `label.secondary`；
右侧系统 UIPasteControl（accent 胶囊「粘贴」，高 34、`padding 0 14px 0 11px`、radius 17、15 Semibold 白字）+ 关闭按钮（28 × 28 圆、`fill` 底、× 图标 18）。
仅在回到前台且「从其他 App 粘贴」≠ 允许时出现；粘贴后原位替换为「已保存」并 0.4s 后收起。

### 3.6 iCloud 状态胶囊

右上角，高 40、`padding 0 12px 0 10px`、radius 20、`gap 5`、字号 13 Medium、`label.secondary` 色，
背景 glass + `blur(12)` + glassSh，图标 18。
三态：`已同步`（checkmark.icloud）/ `同步中…`（arrow.triangle.2.circlepath.icloud，图标 1s 旋转）/ `未同步`（icloud.slash，点按去设置）。
iPad 内容区版本：高 36、`padding 0 12`、radius 18、字号 13。
Slide Over 版本：高 34、`padding 0 10px 0 8px`、radius 17、字号 12。

### 3.7 Pinboard 行

分组卡片 radius 12、`bg.card`；行高 56、`padding 0 16`、`gap 12`；
图标砖 32 × 32、radius 8、底色 = 主题色 15% 透明、内含 18pt 彩色图标；
名称 17 `label`；右侧条目数 17 `label.secondary`；chevron。分隔线 `.5px separator`。

### 3.8 设置分组

分组标题 13 `label.secondary`，`padding 0 16px 7px`；分组卡片 radius 12、`bg.card`；组间距 22。
行高 52、`padding 0 16`、`gap 12`；图标砖 30 × 30、radius 7、实色底 + 18pt 白色图标；
标题 17 `label`；右侧值 17 `label.secondary`（警示值用 `#FF9F0A`）；chevron / 外链箭头。
子行（如「状态」）行高 44、`padding 0 16px 0 58px`、字号 15。
分组脚注 13/18 `label.secondary`、`padding 7px 16px 0`。
开关：51 × 31、radius 16、开启 success 色，把手 27 圆、白色、`shadow 0 2px 4px rgba(0,0,0,.2)`。
步骤条目：`padding 14px 16px`、`gap 14`；序号圆 28、`fill` 底、15 Semibold；标题 15、副文 13 `label.secondary`（`margin-top 3`）。
行动主按钮：高 52、radius 14（引导页 CTA 为 radius 26）、accent 底、17 Semibold 白字、`gap 8`。
次级按钮：高 50、radius 12、`bg.card` 底、17 accent 字。
内联行动胶囊：高 30、`padding 0 12`、radius 15、`fill` 底、14 Semibold accent 字。

### 3.9 引导页

顶部 `padding 66px 20px 0`，右上跳过按钮 17 accent（高 40）。
插图容器 180 × 180、radius 44、`bg.card`、`shadow 0 16px 40px rgba(0,0,0,.12)`、下留白 36；插图本体 `padding-top 34`。
标题 28/34 Bold；正文 17/24 `label.secondary`、`margin-top 12`；两侧留白 36，居中对齐。
说明行（05b / 05c）：`padding 12px 14px`、radius 12、`bg.card`、`gap 12`、左对齐；
图标砖 36 × 36、radius 10、`tintBlue` 底、20pt accent 图标；标题 15 Semibold、副文 13 `label.secondary`；
右侧可放开关或胶囊按钮（高 30、`padding 0 12`、radius 15、`rgba(10,132,255,.12)` 底、14 Semibold accent）。
底部 `padding 0 20px 50px`、`gap 22`：页码点 7 × 7、radius 4、间距 7（当前 accent，其余 `label.tertiary`）；
CTA 全宽、高 52、radius 26、accent 底、17 Semibold 白字。

### 3.10 分享 sheet

贴底，`radius 38 38 0 0`、底色 `sheet`、`shadow 0 -8px 40px rgba(0,0,0,.2)`、`padding 0 20px 44px`、`gap 16`。
grabber 36 × 5、radius 3、`label.tertiary`，上距 8。
头部：左 `取消` 17 accent（宽 60）、中 App 图标 26（radius 7）+ 标题 17 Semibold、右侧 60 空占位保持居中。
预览卡：radius 12、`padding 12`、来源淡染底；角标 + 元信息同卡片；正文 15/20，4 行截断；底部统计 11 `label.secondary`（`margin-top 8`）。
选项行：高 48、`padding 0 16`、17 `label` + 右值 `label.secondary` + chevron。
保存按钮：高 52、radius 26、accent 底、17 Semibold 白字 + tray 图标。

### 3.11 上下文菜单 / Alert

**上下文菜单**：宽 250（03b 的标题菜单 230），radius 14，底 `menu` + `blur(30) saturate(180%)`，
`shadow 0 12px 40px rgba(0,0,0,.25)` + glassRing；
行高 44、`padding 0 16`、字号 17、左文右图标；行间 `.5px separator`；破坏项前用 8pt `menuSep` 分隔块，文字与图标 `#FF3B30`。
背景层 `blur(14) opacity .6` + `dim` 遮罩。

**Alert（新建 Pinboard）**：宽 270，radius 26，底 `menu` + `blur(30) saturate(180%)`，居中偏上（`translate(-50%,-60%)`）；
标题 17 Semibold（`padding 20px 16px 0`）+ 副文 13 `label.secondary`（`padding 6px 16px 0`）；
输入框 `margin 16px 16px 18px`、高 32、radius 8、`bg.card` + `.5px separator` 边、字号 13；
按钮行高 44、17 accent，确认项 Semibold，中间与顶部 `.5px separator`。
背景层 `blur(6) opacity .7` + `dim`。

### 3.12 iPhone 主屏骨架

顶部 `padding 62px 20px 0`；操作行高 44（放 iCloud 胶囊或右上按钮）；
大标题 34/41 Bold、`letter-spacing .4`、`margin-top 4`；
搜索栏高 36、radius 18、`fill` 底、`padding 0 10`、`gap 6`、字号 17 `label.secondary`（`margin-top 10`）；
筛选 chips 高 32、`padding 0 14`、radius 16、`gap 8`、`margin-top 12`：选中 accent 底 + 白字 14 Semibold，未选 `fill` 底 + `label` 字 14 Medium；
卡片流 `padding 16px 20px 0`、双列、列间距 12、卡片下距 12；
底部渐隐高 140（`fade`）；
浮动标签栏：底距 26、高 64、`padding 0 6`、radius 32、glass + `blur(20) saturate(180%)` + glassSh；
每项 92 × 52（选中 radius 26 + `tabOn` 底），图标 24 + 文字 10（选中 accent Semibold，未选 `label.secondary` Medium），`gap 3`。

**搜索激活态（01f）**：搜索行高 44，搜索框占满剩余宽度（内含 2 × 20 accent 光标），右侧 `取消` 17 accent；
chips 上距 8；结果计数 13 `label.secondary`、上距 14；结果单列、`gap 12`、`padding 10px 20px 0`；
系统键盘高 300（键帽 36 × 42、功能键 46 × 42、radius 6、`shadow 0 1px 0 keySh`，`空格` 键自适应，回车键为蓝色 `搜索`）。

### 3.13 详情页骨架

导航区 `padding 62px 16px 0`、总高 106；
返回胶囊 高 40、`padding 0 14px 0 8px`、radius 20、glass + glassSh、17 accent；
标题 17 Semibold 居中；右上更多按钮 40 × 40 圆、glass。
内容 `padding 8px 20px 0`、`gap 20`；预览块 radius 12、`padding 12`、来源淡染底，正文 17/24。
颜色详情：色块高 220、radius 10；色值胶囊高 30、`padding 0 10`、radius 15、`fill` 底、SF Mono 13（首个 `label` Semibold，其余 `label.secondary`）。
信息组 radius 12、`bg.card`；行高 44、`padding 0 16`、15 `label` + 右值 `label.secondary`；行间 `.5px separator`。
底部工具栏：底距 26、高 64、`padding 0 8`、`gap 2`、radius 32、glass；
主按钮高 48、`padding 0 18`、radius 24、accent 底、15 Semibold 白字 + 图标；其余四个图标按钮 50 × 48，图标 20（已固定时 pin 图标为 accent 色）。

### 3.14 iPad 侧栏与网格（09）

设备外框 1376 × 1032、radius 40、`padding 22`、底 `#111`；内屏 radius 22。
状态条高 24、`padding 0 24`、13 Semibold（09 用 `mix-blend-mode: difference` 压在壁纸上）。
左窗格固定 880 宽；分栏手柄 5 × 60、radius 3、`rgba(255,255,255,.6)`；右窗格占满剩余。
**侧栏**：宽 280、底 `sideBg`、右边 `.5px separator`、`padding 44px 14px 0`、行间 `gap 4`；
标题 `Paster` 22 Bold + 侧栏图标；搜索行高 36、radius 10、`fill` 底、15、右侧 `⌘F` 11 `label.tertiary`（下距 10）；
分类行高 38、radius 10、`padding 0 10`、`gap 10`、15；选中 accent 底 + 白字 Semibold + 计数 `opacity .8`；未选 `label` + 计数 `label.secondary`；
分组标题 `PINBOARD` 13 Semibold `label.secondary`、`padding 22px 10px 6px`、右侧 `+`；
底部「设置」`margin-top auto`、`padding 0 10px 18px`、15 `label.secondary`。
**内容区**：`padding 44px 24px 0`；标题 28 Bold；右上同步胶囊 + 36 × 36 排序按钮（glass）；
三列网格（`repeat(3,1fr)`）、`gap 12`、顶对齐；
底部快捷键条：左 24、底 22、`gap 14`、12 `label.secondary`，键名 `label` Semibold。
**拖动中间态**：卡片宽 280、`rotate(-3deg)`、`drop-shadow(0 18px 40px rgba(0,0,0,.3))`，
右上角 `plus.circle.fill` 绿色徽标 28（偏移 −10 / −10）；原位卡片 ghost。
**接收方 App**（示意）：`bg.card` 底、radius `22 0 0 22`、`padding 44px 32px 0`；
插入指示条 高 2、radius 1、accent、外发光 `0 0 0 6px rgba(10,132,255,.15)`。

### 3.15 iPad Slide Over（10）

浮层面板：右 18、上下各 40、宽 400、radius 24、底 `bg.grouped`、
`shadow 0 20px 60px rgba(0,0,0,.35)` + glassRing；顶部 grabber 36 × 5。
内容 `padding 8px 18px 0`；同步胶囊高 34；大标题 30/36 Bold；搜索栏高 36、字号 16；
chips 高 30、`padding 0 12`、radius 15、字号 13；
卡片流 `padding 14px 18px 0`、双列、列间距 10、卡片下距 10，**卡片用 dense**；渐隐高 120；
标签栏底距 16、高 58、radius 29，每项 84 × 46（选中 radius 23），图标 20 + 文字 10。

### 3.16 小组件与控件（08，Phase 2 参考）

小尺寸 170 × 170、radius 38、`bg.card`、`padding 14`、`gap 8`；头部 12 Semibold `label.secondary`；
内容块 radius 12、`padding 10`、来源淡染底；角标缩小版：高 18、`padding 0 6px 0 5px`、radius 9、字号 10 Semibold；
正文 13/17、3 行截断；脚注 `点按复制` 11 `label.tertiary` 居中。
中尺寸 364 × 170，同外框；内容为 2 × 2 网格、`gap 8`；单元 radius 10、`padding 8px 10px`、`gap 8`、底色 = 来源色 14% 透明；
左侧 6 × 28 色条（radius 3，来源色）；单行文本 12/15 省略；元信息 10 `label.secondary`。
控制中心控件：60 × 60 圆、glass + `blur(20)` + glassSh，内含 28pt tray 图标；说明 11 `label.secondary`。
锁屏控件：51 × 51 圆、`lockFill` 底，内含 20pt 图标。

---

## 四、交互 · 手势 · 动效（页尾规格节原文，逐条保留）

- **轻点卡片**：复制到剪贴板 → 卡片 `scale .96 → 1`（spring 0.35, damping .8）+ 顶部「已复制」轻提示 + 轻触感（`.success`）。
- **长按**：系统上下文菜单，预览为卡片本体放大 1.04；菜单项：复制 / 纯文本复制 / 分享 / 固定到 Pinboard（子菜单列 Pinboard）/ 删除。
- **左滑**：删除（红，全滑直接删）；**右滑**：固定到默认 Pinboard（蓝，全滑立即固定并轻提示「已固定」）。
  滑动动作层：radius 12，删除红底右对齐（右内距 22），固定蓝底左对齐（左内距 22），24pt 白图标 + 12 Semibold 白字；卡片位移 ±96pt。
- **详情**：从卡片 zoom 转场（iOS 18+ `navigationTransition .zoom`）；返回手势同。
- **面板出现**：无全局呼出；App 冷启动直接落历史页；一键保存唤起时历史顶部新卡片从 y −12 / 0 透明淡入并短暂 focused 环 0.8s，同时「已保存」提示。
- **回到前台**：若「允许粘贴」= 允许，静默读取、有新内容则新卡片插入顶部（同上动效）；否则显示横幅（从 −8 下滑淡入 .25s）。
- **iCloud 状态**：右上玻璃胶囊：已同步 / 同步中（图标 1s 旋转）/ 未同步（点按去设置）。
- **iPad**：单指拖卡片到旁边 App = 系统拖放，提供 text / rtf / url / image / color 多表示；
  硬件键盘 `↑↓←→` 移焦、`↵` 复制、`⇧↵` 纯文本、`空格` Quick Look、`⌘F` 搜索、`⌘P` 固定、`⌫` 删除、`⌘1-3` 切侧栏。
  宽度 < 600pt（Slide Over / 1/3 分屏）切到 iPhone 布局。
- **键盘扩展**（Phase 2）：点卡片 = 插入文本（图片/颜色插入色值或提示需在 App 内复制）；长按 = 预览；
  地球键切键盘；搜索框输入走键盘自身的最小键位或系统词典。

补充（从帧内读到、规格节未重复的）：
- 横幅粘贴后「原位替换为『已保存』并 0.4s 后收起」（见 3.5）。
- 上下文菜单出现时底层 `blur(14) opacity .6` + dim；Alert 出现时底层 `blur(6) opacity .7` + dim；分享 sheet 宿主 `blur(2) opacity .6` + dim。
- 09 帧里同时展示 selected / focused / ghost 三种卡片状态，说明 iPad 上选中与键盘焦点是两套独立视觉。

---

## 五、SF Symbols 对照表（页尾规格节原文，完整保留）

| 用途 | 符号 |
| --- | --- |
| 标签栏 历史 | `clock.arrow.circlepath` |
| 标签栏 Pinboard | `pin.fill` / `pin` |
| 标签栏 设置 | `gearshape.fill` |
| 搜索 | `magnifyingglass` |
| iCloud 已同步 | `checkmark.icloud` |
| iCloud 同步中 | `arrow.triangle.2.circlepath.icloud` |
| iCloud 未同步 | `icloud.slash` |
| 角标 文本 | `text.alignleft` |
| 角标 富文本 | `textformat` |
| 角标 链接 | `link` |
| 角标 颜色 | `circle.lefthalf.filled` |
| 角标 图片 | `photo` |
| 角标 文件 | `doc` |
| 仅 Mac | `desktopcomputer` |
| 已固定 | `pin.fill` |
| 复制 | `doc.on.doc` |
| 纯文本复制 | `doc.plaintext` |
| 分享 | `square.and.arrow.up` |
| 固定 / 取消固定 | `pin` / `pin.slash` |
| 删除 | `trash` |
| 轻提示 已复制/已保存 | `checkmark.circle.fill` |
| 横幅 | `doc.on.clipboard` |
| 粘贴按钮 | `UIPasteControl`（系统） |
| 关闭 | `xmark` |
| 更多 | `ellipsis.circle` |
| 返回 | `chevron.left` |
| 披露 | `chevron.right` |
| 新建 | `plus` |
| 重命名 | `pencil` |
| 排序 | `arrow.up.arrow.down` |
| 设置 iCloud | `icloud.fill` |
| 设置 怎样保存 | `questionmark.circle.fill` |
| 设置 一键保存 | `bolt.fill` |
| 操作按钮 | `button.horizontal.top.press` |
| 敲击背面 | `hand.tap.fill` |
| 控制中心 | `switch.2` |
| 允许粘贴 | `doc.on.clipboard.fill` |
| 键盘 | `keyboard.fill` |
| 历史上限 | `clock.fill` |
| 开源 | `chevron.left.forwardslash.chevron.right` |
| 隐私 | `hand.raised.fill` |
| 关于 | `info.circle.fill` |
| 添加快捷指令 | `plus.square.on.square` |
| 跳转系统设置 | `arrow.up.forward.app` |
| 分享扩展 保存 | `tray.and.arrow.down.fill` |
| 控件 保存剪贴板 | `tray.and.arrow.down.fill` |
| 键盘 地球 | `globe` |
| 键盘 删除 | `delete.left` |
| 键盘 换行 | `return` |
| 键盘 未授权 | `lock.fill` |
| 引导 互通 | `macbook.and.iphone` |
| 拖放 徽标 | `plus.circle.fill`（系统） |
| iPad 侧栏 | `sidebar.left` |
| Pinboard 图标可选 | `paintpalette` / `mappin` / `terminal` / `doc.text` |

---

## 六、样例数据（实现 `-demoData` 与截图用）

### 6.1 `raw` —— 历史十条（中文）

| # | kind | mono | source / sourceEn | color | time / timeEn | 内容字段 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | text | – | 本机 / This iPhone | `#8E8E93` | 刚刚 / now | text `【抖音】验证码 482913，5 分钟内有效，请勿泄露给他人。` |
| 1 | text | ✓ | 终端 / Terminal | `#48484A` | 3 分钟前 / 3m | text `git rebase -i HEAD~3 && git push --force-with-lease` |
| 2 | text | – | 微信 / WeChat | `#07C160` | 12 分钟前 / 12m | text `周五下午三点在 3 楼小会议室对一下 Q4 的排期，记得把上周的漏斗数据带上，顺便看看新江湾那边场地的报价。` |
| 3 | link | – | Safari / Safari | `#1B8EF1` | 25 分钟前 / 25m | domain `developer.apple.com`；title `Adopting Liquid Glass \| Apple Developer Documentation`；text `https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass` |
| 4 | color | – | Figma / Figma | `#A259FF` | 1 小时前 / 1h | hex `#FF9F0A`；`pinned: true` |
| 5 | image | – | 预览 / Preview | `#5B8DC9` | 1 小时前 / 1h | meta `1284 × 2778 · PNG` |
| 6 | richText | – | 备忘录 / Notes | `#F7C600` | 2 小时前 / 2h | title `站会纪要 9/4`；text `· 登录页改版下周灰度\n· 图标最终稿 8a 已定\n· TestFlight 周三发` |
| 7 | file | – | 访达 / Finder | `#1E9BF0` | 昨天 18:42 / Yesterday | title `Q3-复盘.key` |
| 8 | text | ✓ | VS Code / VS Code | `#0078D4` | 昨天 16:10 / Yesterday | text `pnpm dlx shadcn@latest add button dialog` |
| 9 | text | – | 本机 / This iPhone | `#8E8E93` | 昨天 09:30 / Yesterday | text `上海市徐汇区漕溪北路 331 号中金国际广场 B 座 12 层` |

### 6.2 `itemsEn` —— 01g 英文版十条

| # | kind | mono | source | color | time | 内容 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | text | – | This iPhone | `#8E8E93` | now | `Your verification code is 482913. It expires in 5 minutes.` |
| 1 | text | ✓ | Terminal | `#48484A` | 3m | `git rebase -i HEAD~3 && git push --force-with-lease` |
| 2 | text | – | Messages | `#34C759` | 12m | `Let's sync on the Q4 roadmap Friday 3pm, room 3B. Bring last week's funnel numbers.` |
| 3 | link | – | Safari | `#1B8EF1` | 25m | 同 `raw[3]`（原样复用） |
| 4 | color | – | Figma | `#A259FF` | 1h | `raw[4]`，source 覆盖为 `Figma`，`pinned: true` |
| 5 | image | – | Preview | `#5B8DC9` | 1h | `raw[5]`，source 覆盖为 `Preview`，meta `1284 × 2778 · PNG` |
| 6 | richText | – | Notes | `#F7C600` | 2h | title `Standup 9/4`；text `· Login redesign ships next week\n· Icon 8a final\n· TestFlight Wed` |
| 7 | file | – | Finder | `#1E9BF0` | Yesterday | title `Q3-Review.key` |
| 8 | text | ✓ | VS Code | `#0078D4` | Yesterday | `pnpm dlx shadcn@latest add button dialog` |
| 9 | text | – | This iPhone | `#8E8E93` | Yesterday | `331 Caoxi North Rd, Tower B, 12F, Xuhui, Shanghai` |

> 卡片组件的英文回退逻辑：`en` 为真时取 `sourceEn ?? source`、`timeEn ?? time`。
> `itemsEn` 里就地定义的条目没有 `sourceEn` / `timeEn`，直接落到 `source` / `time`。

### 6.3 `boards` —— Pinboard 四个

| 名称 | 条目数 | 图标砖底色 | 图标 / 色 |
| --- | --- | --- | --- |
| 设计 Token | 6 | `rgba(162,89,255,.15)` | palette · `#A259FF` |
| 常用地址 | 3 | `rgba(52,199,89,.15)` | text · `#34C759` |
| 命令 | 12 | `rgba(72,72,74,.15)` | code · `#8E8E93` |
| 发票信息 | 2 | `rgba(255,159,10,.15)` | doc · `#FF9F0A` |

### 6.4 `boardItems` —— 「设计 Token」内容页六条（全部 `pinned`）

| # | kind | source | color | time | 内容 |
| --- | --- | --- | --- | --- | --- |
| 0 | color | Figma | `#A259FF` | 1 小时前 | hex `#FF9F0A`（= `raw[4]`） |
| 1 | color | Figma | `#A259FF` | 3 天前 | hex `#0A84FF` |
| 2 | color | Figma | `#A259FF` | 3 天前 | hex `#FF2D55` |
| 3 | text（mono） | Xcode | `#1575F9` | 上周 | `Color(red: 0.97, green: 0.95, blue: 0.92)` |
| 4 | color | Figma | `#A259FF` | 上周 | hex `#F7F3EA` |
| 5 | color | Figma | `#A259FF` | 上周 | hex `#16161A` |

### 6.5 `savedItem` —— 01d 顶部新插入的条目

kind `text`；source `本机`；color `#8E8E93`；time `刚刚`；
text `订单号 SF1364 0027 8891，预计今天 18:00 前送达，请保持电话畅通。`

### 6.6 其它取样集合

- `menuItem` = `raw[2]`（微信长文本），用于 01e 的长按预览。
- `swipeItems` = `[raw[2], raw[6]]`，01f 上卡演示左滑删除、下卡演示右滑固定。
- `kbCards` = `[raw[0], raw[9], raw[3]]`（04e 键盘预览，dense，宽 150）。
- `kbStrip` = `[raw[9], raw[0], raw[2], raw[3]]`（07 键盘卡片条，dense，宽 168）。**Phase 2**
- 09 iPad 网格取样顺序：`items 0,1,2,3,4,6,7,8,9,5`（第 2 张 selected、第 3 张 ghost、第 4 张 focused）。
- 09 / 10 的拖放接收方文稿：文件名 `会议准备.txt`、标题 `Q4 排期会`、正文 `时间地点待确认。上周漏斗数据见附件。`

### 6.7 `widgetItems` —— 中尺寸小组件四条（**Phase 2**）

| # | 色条色 | 单行文本 | 元信息 | 底色 | 字体 |
| --- | --- | --- | --- | --- | --- |
| 0 | `#8E8E93` | `【抖音】验证码 482913，5 分钟内有效` | `本机 · 刚刚` | `rgba(142,142,147,.14)` | 系统 |
| 1 | `#48484A` | `git rebase -i HEAD~3 && git push --force-with-lease` | `终端 · 3 分钟前` | `rgba(72,72,74,.14)` | SF Mono |
| 2 | `#07C160` | `周五下午三点在 3 楼小会议室对一下 Q4 的排期…` | `微信 · 12 分钟前` | `rgba(7,193,96,.14)` | 系统 |
| 3 | `#1B8EF1` | `Adopting Liquid Glass \| Apple Developer` | `Safari · 25 分钟前` | `rgba(27,142,241,.14)` | 系统 |

### 6.8 `onboard` —— 引导三页字段

| 页 | id | 跳过 | CTA | 标题 | 正文 | 行 | 插图 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 05a | 跳过 | 继续 | Mac 剪贴板，随身带着 | 在 Mac 上复制过的一切，会通过 iCloud 出现在这里。随时搜，轻点即复制。 | 无 | mac 44 + 双向箭头 26 + iphone 40 |
| 2 | 05b | 跳过 | 继续 | 手机上想留住的，三种方式存进来 | iOS 不允许 App 在后台读剪贴板，Paster 只在这三种时刻保存。 | 三行（见下） | tray 64 |
| 3 | 05c | 以后再说 | 开始使用 | 两个开关，打开就好 | 都可以稍后在「设置」里更改。 | 两行（见下） | cloudCheck 64 |

第 2 页三行：`打开 Paster 时` / `自动读取当前剪贴板`（clipboard 图标）；
`分享面板` / `任何 App 里「保存到 Paster」`（share）；`一键保存` / `操作按钮 / 敲击背面 / 控制中心`（bolt）。

第 3 页两行：`iCloud 同步` / `与 Mac 共用同一份历史`（cloud 图标，右侧开关开启）；
`允许从其他 App 粘贴` / `在系统设置里设为「允许」，不再弹窗`（clipboard 图标，右侧胶囊按钮 `前往设置`）。

---

## 七、实现映射备注

| 界面 | SwiftUI 结构建议 |
| --- | --- |
| 全局骨架 | `TabView`（历史 / Pinboard / 设置），iOS 26 原生浮动玻璃标签栏；每个 tab 内一层 `NavigationStack` |
| 01 历史 | `NavigationStack` + `.navigationTitle("历史").navigationBarTitleDisplayMode(.large)` + `.searchable(text:)`；筛选 chips 用横向 `ScrollView` + 自定义胶囊按钮；双列瀑布流用两个 `LazyVStack` 手工分列（`LazyVGrid` 不做等高破列），列间距 12 |
| 01b 空态 | `ContentUnavailableView` 的自定义 label（插画为自绘 `Canvas`/`ZStack` 矩形，非 SF Symbol）+ 两个按钮 |
| 01c 横幅 | 列表顶部 `safeAreaInset(edge: .top)` 或首个 section；粘贴按钮用 `UIViewRepresentable` 包 `UIPasteControl` |
| 01d 轻提示 | `.overlay(alignment: .top)` 的玻璃胶囊 + `withAnimation` 定时 1.2s 收起；新条目 `.transition(.move + .opacity)` + 临时 focused 环 |
| 01e 长按菜单 | `.contextMenu { … } preview: { PasterCard(item:) }`；固定到 Pinboard 用嵌套 `Menu` 列出 Pinboard |
| 01f 左右滑 | 瀑布流不是 `List`，`swipeActions` 不可用 → 自定义 `DragGesture` + 底层动作层（红/蓝），阈值触发后 `withAnimation` 移除；搜索态改单列 `LazyVStack` |
| 02 详情 | `NavigationStack` push；`.navigationTransition(.zoom(sourceID:in:))`（iOS 18+）；底部工具栏用 `.safeAreaInset(edge: .bottom)` 放玻璃胶囊条（非 `.toolbar`，因设计为浮动胶囊） |
| 03 Pinboard 列表 | `List`（`.insetGrouped`）+ `.toolbar` 放排序与 `+`；新建用 `.alert(_:isPresented:) { TextField … }` |
| 03b 内容页 | 同 01 的双列流；标题旁下拉用 `Menu`（`.navigationTitle` + toolbar `Menu`） |
| 04 设置 | `List` + `Section`；行图标砖自绘 `RoundedRectangle(cornerRadius: 7)` + `Image(systemName:)`；跳系统设置用 `UIApplication.openSettingsURLString` |
| 04b 一键保存 | `Picker(.segmented)` 切三种入口；「添加快捷指令」跳 iCloud 分享链接；「打开『操作按钮』设置」走系统设置深链 |
| 04c / 04d / 04e | 纯静态 `ScrollView` + 卡片；步骤条目为自定义 Row |
| 05 引导 | `TabView(.page)`（隐藏原生指示器，自绘 7pt 圆点）+ 底部固定 CTA；首启动用 `@AppStorage` 判断 |
| 06 分享扩展 | 独立 Share Extension target，SwiftUI 根视图 + `.presentationDetents`；预览卡复用 `PasterCard` |
| 07 键盘扩展 | **Phase 2**：`UIInputViewController` 承载 SwiftUI；横向 `ScrollView` + dense 卡片；需「允许完全访问」读 App Group |
| 08 控件 | 本轮做 `ControlWidget` + `ControlWidgetButton(action: SaveClipboardIntent())`（`openAppWhenRun = true`），一次实现操作按钮 / 控制中心 / 锁屏；小 / 中尺寸 `WidgetKit` 小组件为 **Phase 2** |
| 09 iPad | `NavigationSplitView`（sidebar + detail）；网格 `LazyVGrid(columns: 3)`；卡片 `.draggable`（`Transferable` 提供 text / rtf / url / image / color 多表示）；键盘快捷键用 `.focusable()` + `.onKeyPress` 与 `.keyboardShortcut`（⌘F / ⌘P / ⌘1-3）；空格预览走 `.quickLookPreview` |
| 10 紧凑宽度 | `@Environment(\.horizontalSizeClass)` 或 `GeometryReader` 宽度 < 600pt → 切回 01 的 iPhone 布局（同一 `HistoryView`，仅列数与 dense 开关不同） |
| 卡片 | 单个 `PasterCard` 视图，参数对应 `dense` / `isSelected` / `isFocused` / `isDragging` / `isGhost`；淡染用 `Color(sourceColor).mix(with: base, by: 0.88/0.80)`（iOS 18 无 `mix` 时手工按分量插值） |

**iOS 26 API 与 iOS 18 回退**（最低支持 iOS 18）：

| iOS 26 | iOS 18 回退 |
| --- | --- |
| `.glassEffect(_:in:)` / `GlassEffectContainer`（iCloud 胶囊、浮动工具栏、控件圆钮） | `.background(.ultraThinMaterial, in: Capsule())` + `.overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))` + `.shadow`，即 `glass` / `glassRing` / `glassSh` 三个 token 的手工组合 |
| 原生浮动玻璃 `TabView` | 自绘胶囊标签栏：`ZStack(alignment: .bottom)` + 材质胶囊（高 64、radius 32、底距 26），内容区加 `safeAreaInset` 让位 |
| iOS 26 搜索栏放进标签栏的样式 | 保持设计稿的形态：大标题下方 `fill` 胶囊搜索栏（`.searchable` 默认样式即接近） |
| `Color.mix(with:by:)` | 手工按 sRGB 分量线性插值实现 `card.tint` |
| `.symbolEffect(.rotate)`（同步中图标） | `.rotationEffect` + `.repeatForever` 动画（周期 1s） |

`navigationTransition(.zoom)`、`ControlWidget`、`.draggable`、`.contextMenu(preview:)` 均为 iOS 18 已有，无需回退。

---

## 八、待确认

1. **筛选项不一致**：iPhone 筛选 chips 是 `全部 / 文本 / 链接 / 图片 / 颜色`（5 项，无富文本、无文件），
   iPad 侧栏是 `历史 / 文本 / 链接 / 图片 / 颜色 / 文件`（无富文本）。两端是否统一、富文本与文件归到哪一类，需定。
2. **卡片高度与分列算法**：设计稿用 `column-count: 2` 自动分列（占位高度 110 / 140 / 160 只是提示），
   SwiftUI 侧要自己决定「按内容估高交替入列」还是「等分两列顺序填」。设计未规定。
3. **01f 的双滑动态**：一帧里同时画了左滑与右滑两张卡片，实际运行时同一时刻只应有一张处于滑动态；此帧为示意。
4. **「已固定」轻提示**没有单独帧，只在规格与 SF Symbols 里出现；其触发时机（右滑全滑固定后）已有文字说明，视觉沿用 3.4。
5. **详情页右上「更多」菜单**内容未画（02 / 02b 都只画了按钮）。
6. **排序选项未列举**：03 的排序按钮、03b 的「排序方式」子菜单具体维度未给；只知道 03b 当前是「按固定时间」。
7. **历史上限的可选值**未列（设置页只显示当前值 `500 条`）。
8. **一键保存三段只画了「操作按钮」**：`敲击背面`、`控制中心` 两段的三步图文缺失。
9. **「关于」「隐私说明」二级页**未画。
10. **文件卡片「仅 Mac」的点按提示文案**未给（规格只写「点按提示到 Mac 上粘贴」）。
11. **图片条目的加载态**未画：CloudKit 资源尚未下载完时的占位 / 失败态缺（设计稿里的缩略图是渐变占位块）。
12. **英文文案只覆盖 01g 一帧**，其余界面的英文需要在本地化阶段补齐；`itemsEn` 未提供 `sourceEn` / `timeEn` 字段，
    实现时按 6.2 的回退逻辑处理。
13. **iPad 上没有设置页与详情页**：09 侧栏底部有「设置」入口，但推入 detail 还是弹 sheet 未定；详情在 iPad 上是否用 detail 栏也未定。
14. **06 分享 sheet 的 detent 高度**未标注（画成贴底 radius 38 的固定高度面板）。
15. **09 的快捷键提示条**只列了 `↵ / ⇧↵ / 空格 / ⌘P / ⌫` 五项，规格节另有 `⌘F`、方向键、`⌘1-3`；提示条是否要展开显示全部，未定。
16. **品牌红的使用边界**：token 表写「brand.red / blue 仅图标、空态、引导」，但设置页「一键保存」的图标砖用了 `#FF2D55`、
    04c 的「一键保存」卡片图标也是品牌红。按实际帧执行（即一键保存这一功能允许用品牌红），或收紧到规格文字，需拍板。
17. **引导页的页码点未做深色适配**：设计稿里非当前页的圆点固定取浅色主题的 `label.tertiary`；实现应按当前主题取值。
18. **08 小组件**：小尺寸的「点按复制」在扩展进程能否写剪贴板尚未验证（见 `docs/ios-plan.md` 第五节第 3 条），
    结论会影响这张设计是否成立；Phase 2 开工前需先验证。
