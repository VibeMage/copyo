# Privacy Policy / 隐私政策

**Effective date / 生效日期: 2026-09-27**

## English

This policy covers Copyo for Mac and Copyo for iPhone and iPad.

Copyo does not collect, transmit, or sell any data. We operate no server of our
own and cannot read your clipboard or your history.

### On every device

- **No analytics, no telemetry, no crash reporting, no advertising, no tracking,
  no accounts, and no third-party SDKs of any kind.** The app's own code contains
  no networking.
- **iCloud sync**, when it is on, mirrors your history into **your own private
  CloudKit database** under your Apple Account, using Apple's CloudKit framework.
  Your Macs, iPhones and iPads share that database when they are signed in to the
  same Apple Account and have iCloud sync on. Copyo also registers for Apple Push
  Notification service, purely so CloudKit can signal that another of your
  devices made a change; those pushes are silent and Copyo never displays a
  notification. A private database is readable only by you — not by us.
- **Changing the sync setting takes effect after you quit and reopen Copyo.** The
  app tells you this in Settings; until you restart it, the mode chosen at launch
  is still the one in effect.

### On Mac

- **Clipboard history** is stored on your Mac. **Syncing is off by default**, and
  with it off nothing leaves your Mac.
- **Concealed content** — what password managers and similar apps mark as
  concealed, transient or auto-generated — is never recorded. You can also list
  apps to ignore by bundle ID.
- **Copied files** are recorded as file paths only. Their contents are never
  copied into Copyo's database and are never synced.
- **Recording a global shortcut**: only while you are recording a new shortcut in
  Settings, and only while Copyo is the frontmost app, Copyo checks about every
  20 ms which keys are held down, so it can tell you when macOS or another app has
  taken the combination you pressed. Each check reads whether each key is up or
  down, but only a key pressed while ⌘, ⌥ or ⌃ is held is ever acted on; the rest
  are ignored. It keeps nothing and stops as soon as recording ends (if you switch
  away mid-recording, it checks once more as you leave, then stops). Copyo does not
  ask for Input Monitoring or Accessibility access. At any other time it receives
  only what any app receives: the keys you type into its own windows and the press
  of its own global shortcut.
- **Optional sync — you pick one of two, or neither:**
  - *Shared Folder*: Copyo reads and writes files only inside a folder you choose
    yourself. In the Mac App Store build that access comes from the standard
    macOS open panel and is limited to that folder. Copyo makes no network
    request in this mode; if the folder you picked happens to live in iCloud
    Drive or another synced folder, that provider moves the files, as it would
    for any folder.
  - *iCloud*: as described above.

### On iPhone and iPad

- **Copyo reads the clipboard only while it is open on screen.** iOS does not let
  apps read the clipboard in the background, and Copyo does not try. Each time you
  open or return to Copyo, it reads the clipboard if it has changed since last
  time. Turn off **Read Clipboard Automatically** in Copyo's Settings and it reads
  nothing on its own; you then save by tapping the system Paste button it shows.
  The first time you open Copyo, it does not read what is already on the
  clipboard.
- **iOS asks your permission** ("Allow Paste") each time Copyo reads the
  clipboard, unless you set Settings › Apps › Copyo › Paste from Other Apps to
  Allow.
- **Other ways content gets in, all started by you:** sharing to Copyo from the
  share sheet; Quick Save (the Action Button, a Control Center or Lock Screen
  control, or a Back Tap shortcut that runs "Save Clipboard"), which opens Copyo
  and reads the clipboard while it is on screen; and the Shortcuts action "Save
  Content", which saves whatever your shortcut passes to it.
- **No password filter.** iOS does not tell apps which app copied something or
  whether a password manager marked it as concealed, so the Mac's concealed-content
  filter and ignore list do not exist on iPhone and iPad. A password or code you
  copy can be saved the next time Copyo reads the clipboard; you can delete it
  from the history.
- **Clipboard history** is stored on your device, in a container shared only by
  Copyo, its share extension and its widgets. Widgets you add to your Home Screen
  show your most recent clips.
- **iCloud sync is on by default on iPhone and iPad.** You can turn it off in
  Copyo's Settings; with it off, or with no iCloud account signed in, nothing
  leaves your device.
- **System Search is off by default.** If you turn on "Show Clips in System
  Search", iOS indexes your clips on the device (Core Spotlight) so they appear in
  system search and Siri Suggestions. Turning it off deletes everything Copyo put
  in the index.
- **Photos:** Copyo never reads your photo library. It asks for add-only access
  only when you choose "Save Image" in the share sheet for an image clip.

### Deleting your data

Since we collect nothing, there is nothing for us to access, share, or delete.
On Mac, deleting the app and its data folder removes everything on your Mac. On
iPhone and iPad, deleting the app removes its data from that device, and "Clear
History" in Settings deletes every clip that is not pinned to a Pinboard. If you
use iCloud sync, deleting entries inside the app removes them from your iCloud
and your other devices too; deleting the app alone does not remove the iCloud
copy.

Questions: open an issue at https://github.com/VibeMage/copyo/issues

## 中文

本政策适用于 Mac 版 Copyo 和 iPhone / iPad 版 Copyo。

Copyo 不收集、不传输、不出售任何数据。我们不运营任何服务器，也读不到你的剪贴板和历史。

### 所有设备

- **无统计分析、无遥测、无崩溃上报、无广告、无追踪、无账号，也不含任何第三方 SDK。**
  应用自身的代码里没有任何联网逻辑。
- **iCloud 同步**开启时，历史会通过 Apple 的 CloudKit 镜像到**你自己 Apple 账户下的私有
  数据库**。登录同一个 Apple 账户、且开启了 iCloud 同步的 Mac、iPhone 和 iPad 共用这一个
  数据库。Copyo 同时会注册 Apple 推送服务，仅用于让 CloudKit 通知它「你的另一台设备改了
  东西」；这类推送是静默的，Copyo 从不弹出任何通知。私有数据库只有你能读，我们读不到。
- **更改同步方式需要退出并重新打开 Copyo 才会生效。** 设置页里有这个提示；在重启之前，
  生效的仍是启动时选定的那种方式。

### Mac

- **剪贴板历史**保存在你的 Mac 上。**同步默认关闭**，关闭时不会有任何数据离开本机。
- 密码管理器一类应用标记为隐藏、临时或自动生成的内容**从不记录**；你还可以按
  Bundle ID 指定要忽略的应用。
- **复制的文件**只记录路径，文件内容不会进入 Copyo 的数据库，也不会被同步。
- **录制全局快捷键**：只有在设置里录制新快捷键、并且 Copyo 在最前面时，Copyo 才会
  约每 20 毫秒查看一次哪些键正被按着，用来提醒你刚按的组合已被 macOS 或别的 App 占用。
  每次查看的是每个键是否按下，但只有在按着 ⌘、⌥ 或 ⌃ 时按下的键才会被拿来判断，其余的
  一概不理。它不保存任何内容，录制一结束就停止（录制中途切到别处时，会在切走的那一刻再
  查看一次，随即停止）。Copyo 不申请「输入监控」或「辅助功能」权限；其他任何时候，它和
  任何 App 一样，只接收你在它自己窗口里按的键，以及它自己的全局快捷键被按下。
- **可选的同步——两种任选其一，也可以都不开：**
  - *共享文件夹*：Copyo 只读写你亲自选定的那个文件夹。Mac App Store 版的访问权限
    来自系统标准的「打开」面板，且仅限于那一个文件夹。这种模式下 Copyo 不发起任何
    网络请求；如果你选的文件夹恰好在 iCloud Drive 或别的同步盘里，搬运文件的是那个
    服务商，和它对待任何文件夹一样。
  - *iCloud*：见上文。

### iPhone 和 iPad

- **Copyo 只在自己显示在屏幕上时读取剪贴板。** iOS 不允许应用在后台读取剪贴板，Copyo
  也不会尝试。每次打开或回到 Copyo，如果剪贴板和上次相比有变化，它会读取一次。在 Copyo
  的设置里关掉「自动读取剪贴板」后，它不会自行读取任何内容，你可以点它显示的系统「粘贴」
  按钮手动保存。第一次打开 Copyo 时，它不会读取剪贴板里已有的内容。
- **iOS 每次都会征求你的同意**（「允许粘贴」），除非你在「设置 › App › Copyo › 从其他
  App 粘贴」里选了「允许」。
- **内容进入 Copyo 的其他途径，全部由你发起：** 在分享面板里分享到 Copyo；一键保存
  （操作按钮、控制中心或锁屏上的控件，或运行「保存剪贴板」的轻点背面快捷指令），它会
  打开 Copyo，由屏幕上的 Copyo 读取剪贴板；以及快捷指令动作「保存内容」，它保存的是你的
  快捷指令传给它的内容。
- **没有密码过滤。** iOS 不会告诉应用内容是哪个应用复制的，也不会告诉它密码管理器是否把
  内容标记为隐藏，所以 Mac 上的隐藏内容过滤和忽略应用列表在 iPhone 和 iPad 上并不存在。
  你复制的密码或验证码可能会在 Copyo 下次读取剪贴板时被保存，你可以在历史里删除它。
- **剪贴板历史**保存在你的设备上，存放在只有 Copyo、它的分享扩展和小组件共用的容器里。
  你添加到主屏幕的小组件会显示最近的几条内容。
- **iPhone 和 iPad 上 iCloud 同步默认开启。** 你可以在 Copyo 的设置里关掉；关闭时，或
  设备未登录 iCloud 时，不会有任何数据离开本机。
- **系统搜索默认关闭。** 打开「在系统搜索中显示条目」后，iOS 会在设备上（Core Spotlight）
  为你的条目建立索引，使它们出现在系统搜索和 Siri 建议里。关掉后，Copyo 写进索引的内容会
  全部删除。
- **照片：** Copyo 从不读取你的照片图库。只有当你在分享面板里为图片条目选择「存储图像」时，
  它才会请求「仅添加」权限。

### 删除数据

由于我们不收集任何数据，我们无从访问、共享或删除你的数据。在 Mac 上，删除应用及其数据
目录即可清除本机上的一切。在 iPhone 和 iPad 上，删除应用即可清除它在该设备上的数据；设置
里的「清空历史」会删除所有没有固定到 Pinboard 的条目。若你使用 iCloud 同步，在应用里删除
条目同样会从你的 iCloud 和其他设备中删除；只删除应用不会删除 iCloud 中的副本。

如有疑问：https://github.com/VibeMage/copyo/issues
