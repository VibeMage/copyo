# Privacy Policy / 隐私政策

**Effective date / 生效日期: 2026-09-20**

## English

Copyo does not collect, transmit, or sell any data. We operate no server of our
own and cannot read your clipboard.

- **Clipboard history** is stored on your Mac. **Syncing is off by default**, and
  with it off nothing leaves your Mac.
- **No analytics, no telemetry, no crash reporting, no advertising, and no
  third-party SDKs of any kind.** The app's own code contains no networking.
- **Concealed content** — what password managers and similar apps mark as
  concealed, transient or auto-generated — is never recorded. You can also list
  apps to ignore by bundle ID.
- **Copied files** are recorded as file paths only. Their contents are never
  copied into Copyo's database and are never synced.
- **Optional sync — you pick one of two, or neither:**
  - *Shared Folder*: Copyo reads and writes files only inside a folder you choose
    yourself. In the Mac App Store build that access comes from the standard
    macOS open panel and is limited to that folder. Copyo makes no network
    request in this mode; if the folder you picked happens to live in iCloud
    Drive or another synced folder, that provider moves the files, as it would
    for any folder.
  - *iCloud*: your history is mirrored into **your own private CloudKit database**
    under your Apple Account, using Apple's CloudKit framework. Copyo also
    registers for Apple Push Notification service, purely so CloudKit can signal
    that another of your Macs made a change; those pushes are silent and Copyo
    never displays a notification. A private database is readable only by you —
    not by us.
- **Changing the sync setting takes effect after you quit and reopen Copyo.** The
  app tells you this in Settings; until you restart it, the mode chosen at launch
  is still the one in effect.

Since we collect nothing, there is nothing for us to access, share, or delete.
Deleting the app and its data folder removes everything on your Mac; if you used
iCloud sync, deleting entries inside the app removes them from your iCloud too.

Questions: open an issue at https://github.com/VibeMage/copyo/issues

## 中文

Copyo 不收集、不传输、不出售任何数据。我们不运营任何服务器，也读不到你的剪贴板。

- **剪贴板历史**保存在你的 Mac 上。**同步默认关闭**，关闭时不会有任何数据离开本机。
- **无统计分析、无遥测、无崩溃上报、无广告，也不含任何第三方 SDK。** 应用自身的代码
  里没有任何联网逻辑。
- 密码管理器一类应用标记为隐藏、临时或自动生成的内容**从不记录**；你还可以按
  Bundle ID 指定要忽略的应用。
- **复制的文件**只记录路径，文件内容不会进入 Copyo 的数据库，也不会被同步。
- **可选的同步——两种任选其一，也可以都不开：**
  - *共享文件夹*：Copyo 只读写你亲自选定的那个文件夹。Mac App Store 版的访问权限
    来自系统标准的「打开」面板，且仅限于那一个文件夹。这种模式下 Copyo 不发起任何
    网络请求；如果你选的文件夹恰好在 iCloud Drive 或别的同步盘里，搬运文件的是那个
    服务商，和它对待任何文件夹一样。
  - *iCloud*：历史会通过 Apple 的 CloudKit 镜像到**你自己 Apple 账户下的私有数据库**。
    Copyo 同时会注册 Apple 推送服务，仅用于让 CloudKit 通知它「你的另一台 Mac 改了
    东西」；这类推送是静默的，Copyo 从不弹出任何通知。私有数据库只有你能读，我们读不到。
- **更改同步方式需要退出并重新打开 Copyo 才会生效。** 设置页里有这个提示；在重启之前，
  生效的仍是启动时选定的那种方式。

由于我们不收集任何数据，我们无从访问、共享或删除你的数据。删除应用及其数据目录即可
清除本机上的一切；若你用过 iCloud 同步，在应用里删除条目同样会从 iCloud 中删除。

如有疑问：https://github.com/VibeMage/copyo/issues
