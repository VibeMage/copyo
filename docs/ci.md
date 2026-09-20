# GitHub Actions 持续集成与自动发布

创建日期：2026-09-20 · 最后更新：2026-09-21

## 一、两个 workflow 各做什么

| workflow | 触发 | 需要 secret | 产出 |
| --- | --- | --- | --- |
| `ci.yml` | 每个 PR、推送 main（纯文档改动除外）、手动 | 否 | 绿灯而已，外加构建日志 artifact |
| `release.yml`：推 tag | 推送 `v*` tag | 是，缺了就**当场失败** | Release 上附 DMG / ZIP / SHA256SUMS.txt |
| `release.yml`：手动演练 | Actions 页面 Run workflow | 否，配了多少就走多远 | 只有 workflow artifact，**不创建 Release** |

这两条路径的区别是刻意的：**推 tag 是在要一次正式发布**，签名或公证凑不齐就红给你看，
而不是全绿地什么都不发（那样你会以为已经发了）；**手动触发是演练**，配了什么就跑到哪一步，
一个 secret 都没有时也能完整跑一遍。手动触发默认勾着 `dry_run`，在分支上跑时也一律按演练处理。

唯一的例外是「在一个已有的 tag 上手动触发、并且取消勾选 `dry_run`」——那等同于重推一次这个 tag，
会照常创建 Release。这是留给「发布作业挂在半路、想重来一次」的口子，不是误触能撞上的路径。

`ci.yml` 的 push 触发带 `paths-ignore`：只改 `art/`、`docs/`、`specs/` 或任何 `.md` 时不会跑。
这个过滤刻意只加在 push 上、没加在 `pull_request` 上——被路径过滤跳过的作业永远不会变成
success，将来若把 `ci.yml` 设成 required check，纯文档 PR 会永远卡在 pending 无法合并。

`ci.yml` 跑四件事：无签名编译 macOS Debug、无签名编译 macOS Release-AppStore、无签名编译 iOS 模拟器
（连带编两个扩展），以及 `swift test --package-path CopyoCore`。不碰任何证书，所以 fork 出去的 PR 也能跑绿。

为什么要单独编一遍 Release-AppStore：只有这份配置带 `APPSTORE` 编译条件，代码里那些 `#if APPSTORE`
分支别的配置根本编不到。不编它，沙盒版的编译错误要等到你本地打上架包时才暴露。

演练路径存在的理由：这个 workflow 在你配齐 secret 之前也能完整跑一遍，用来验证 checkout、Xcode、
编译链路，而不是一个要等六个 secret 都就位才第一次执行的黑盒。它刻意不往 Release 上挂东西——
README 向用户承诺「官方发布均已使用 Developer ID 签名并通过 Apple 公证」，挂未签名的包会当场让这句话变成假的。

`.github/dependabot.yml` 是配套的一小份配置：让 dependabot 每月检查一次这两个 workflow 里引用的
action 有没有新版本，有就自动提 PR。它不参与构建，删掉也不影响 CI 跑。

## 二、当前决定：签名留在本地，不配 secret（2026-09-21）

**结论**：`ci.yml` 保留；`release.yml` 只用手动演练；正式包继续用 `scripts/build-release.sh`
在本机签名公证，手动上传到 Releases。**第三节那六个 secret 不要配**，第五节的开发者后台准备、
第七节的第②③步演练也随之不必做。

决定性的理由只有一条：**在 CI 里签名，必须把 Developer ID 证书的私钥导成 `.p12` 放进
GitHub Secrets。** 那把私钥目前只存在于本机钥匙串里，进了 GitHub 就多出一个不受本人控制的
副本——仓库或账号一旦失守，对方能以本人身份签任何东西。这个风险本身不可接受，不与便利性权衡。
（供应链面也在扩大：2026-09-21 刚把四处 action 引用升到 v7，workflow 能读到 secret 就意味着
任何一个被投毒的 action 都够得着它。）

放弃掉的东西要说清楚，不假装没有代价：产物与 tag 的强绑定没有了（Releases 上的包来自谁的
工作区、对应哪个 commit，只能靠自觉）；换机器或多人发版会卡住；`release.yml` 里那条
tag 与 `MARKETING_VERSION` 的一致性断言也不会再执行。

为什么 `ci.yml` 仍然值得留：这个工程用 `PBXFileSystemSynchronizedRootGroup`（objectVersion 77），
target 的源文件按磁盘目录同步，不在 pbxproj 里逐个登记。于是一个文件可以存在于开发机上、
本地编译一切正常、却从没进过 git——**本地构建结构上发现不了这件事，只有干净 checkout 能**。
2026-09-21 核对 `CopyoWidgets/` 时正是因为这个结构，才必须专门确认磁盘与 git 是否一致。
加上 Release-AppStore 那条（见第一节末尾），`ci.yml` 覆盖的恰好是本地流程够不着的盲区，
而且它不碰任何证书，没有上面那个风险。

**直接后果：不要推 `v*` tag。** `release.yml` 的设计是「推 tag = 要一次正式发布，签名或公证
凑不齐就当场失败」（见第一节）。本地签名这条路下推 tag 只会得到一个红叉。手动 Run workflow
不受影响，随时可跑，用来验证 checkout / Xcode / 编译链路。

这里留了一个已知的坑：`release.yml` 的 `v*` 触发仍然挂着，哪天手滑 `git push --tags` 就会红一次。
没有摘掉它，是因为那个红叉是自解释的（日志第一行就写了缺哪个 secret），而摘掉触发器等于
把将来改回 CI 签名的路也一并拆了。知道它在那儿就行。

**什么情况下该改回来**：需要换机器或多人发版；或者愿意为此专门签发一张**只用于 CI、随时可吊销**
的证书，把风险限定在那张证书上。那时按第三节配 secret、第七节走三步演练即可，workflow 本身不用改。

## 三、需要配置的 secret（你来操作）

> ⚠️ **按第二节的决定，这一节当前不执行。** 下面的内容保留下来，是为了将来真要把签名搬进 CI
> 时不用重新查一遍；现在照着配等于把 Developer ID 私钥送进 GitHub，正是第二节拒绝的那件事。

仓库 → Settings → Secrets and variables → Actions → New repository secret。

| 名字 | 是什么 | 怎么拿 |
| --- | --- | --- |
| `DEVELOPER_ID_CERT_P12_BASE64` | Developer ID Application 证书 **连同私钥**导出的 .p12，再 base64 | 钥匙串访问 → 找到证书 → 右键「导出」→ 选 .p12 → 设一个导出密码 |
| `DEVELOPER_ID_CERT_PASSWORD` | 上面导出时设的那个密码 | —— |
| `PROFILE_APP_BASE64` | `dev.vibemage.Copyo` 的 Developer ID 描述文件（`.provisionprofile`）base64 | 开发者后台 → Profiles → ➕ → Developer ID Application → 选该 App ID → 下载 |
| `ASC_KEY_P8_BASE64` | App Store Connect API key 私钥 `.p8` 的 base64，用于非交互公证 | App Store Connect → 用户和访问 → 集成 → 密钥 → ➕，角色给 Developer 就够 |
| `ASC_KEY_ID` | 上面那把 key 的 Key ID（10 位字母数字） | 同一个页面上列着 |
| `ASC_ISSUER_ID` | Issuer ID（UUID 格式），整个团队共用一个 | 同一个页面顶部 |

只需要**一份**描述文件：macOS 的 Copyo.app 不内嵌任何扩展（CopyoShareExtension 和 CopyoWidgets
都只属于 iOS 版），所以不存在「一次归档要喂多份描述文件」的情况。

base64 编码在 macOS 上是 `base64 -i 输入 -o 输出`（Linux 上是 `base64 -w0`），workflow 里解码
统一用 `base64 --decode`——macOS 的 `-D` 和 GNU 的 `-d` 互不认。

```bash
base64 -i DeveloperID.p12 -o cert.txt              # 把 cert.txt 的内容整个粘进 secret
base64 -i Copyo.provisionprofile -o profile.txt
base64 -i AuthKey_XXXXXXXXXX.p8 -o key.txt
```

**.p8 只能下载一次**，下完立刻存好。

可选的加固：把这六个 secret 放进一个名为 `release` 的 GitHub Environment 并开 required reviewers，
然后在 `release.yml` 的 `release:` job 下加一行 `environment: release`。这样只有发布作业取得到它们，
误提交进来的 workflow 改动也偷不走。仓库级 secret 不加这行也能正常工作，所以默认没加。

## 四、明文即可、不要放 secret 的东西

仓库是公开的，下面这些标识符早就提交进库了，Team ID 更是嵌在每一个签名过的 app 里、本来就是公开设计。
放进 secret 只会让 YAML 难读，换不来任何安全收益：

- Team ID `9A94W79V84`
- Bundle ID `dev.vibemage.Copyo`
- App Group `group.dev.vibemage.Copyo`
- iCloud 容器 `iCloud.dev.vibemage.Copyo`

## 五、一次性准备（开发者后台侧）

1. **App ID 上的能力**：Identifiers → `dev.vibemage.Copyo` 必须已勾选 iCloud（CloudKit，容器
   `iCloud.dev.vibemage.Copyo`）与 Push Notifications。entitlements 里有这两项而 App ID 没开，
   描述文件根本申请不下来——和 `scripts/build-release.sh` 里 `print_signing_help()` 讲的是同一件事。
2. **证书**：Certificates → Developer ID Application → 下载并装进本机钥匙串 → 在钥匙串访问里导出
   为 .p12，**导出时必须带私钥**（展开证书条目选中那把钥匙一起导，只导证书是没用的）。
3. **描述文件**：Profiles → ➕ → Developer ID Application → 选上面那个 App ID → 下载。
   macOS 的扩展名是 `.provisionprofile`，不是 iOS 的 `.mobileprovision`。
   它大约一年过期，到期后 CI 会在签名步失败，日志里打印的「有效期至」是最快的排查线索。
4. **公证密钥**：App Store Connect → 用户和访问 → 集成 → 密钥。

## 六、本地与 CI 的差别

|  | 本地 `scripts/build-release.sh` | CI `scripts/ci-release.sh` |
| --- | --- | --- |
| 签名方式 | 自动签名 | 手动签名 |
| 描述文件 | `-allowProvisioningUpdates` 现场申请 | secret 里预装的那份 |
| 公证凭据 | 钥匙串里的 notarytool 配置 | App Store Connect API key |
| 日志 | `mktemp`，跑完就没了 | `build/logs/`，上传成 artifact |

为什么刻意不合并成一个脚本：无人值守的 runner 既没有 Xcode 里登录的 Apple ID 会话，也没有已注册的 Mac
（本地脚本归档时用的 "Apple Development" 身份需要一张按设备列表签发的 Mac App Development 描述文件，
而这类描述文件要求账号里至少注册过一台 Mac）。两条路在归档身份、描述文件来源、公证凭据、日志策略上
**每一步都不同**，硬合并买不到多少复用；而 `build-release.sh` 是你唯一验证过的发版路径，
改坏了不会在 CI 上红，会在下一次发版时红。

代价是两份脚本要一起维护：**产物命名和 DMG 布局是逐字对齐的，改一边记得改另一边。**

## 七、先演练再推 tag

> ⚠️ **按第二节的决定，目前只做第 1 步，并且不推 tag。** 第 2、3 步依赖第三节那些 secret。

仓库至今一个 tag 都没有，`on: push: tags` 这条路径在第一次真推之前完全没被执行过。按这个顺序趟一遍：

1. **什么都没配时**：Actions → Release → Run workflow。走未签名路径，验证 checkout、Xcode、编译链路。
2. **配齐证书和描述文件后**：Run workflow，`dry_run` 勾上、`skip_notarize` 也勾上。验证钥匙串导入、
   描述文件安装、手动签名归档导出这一整条链路，不花公证的等待时间。
3. **配齐 ASC 密钥后**：Run workflow，只勾 `dry_run`。这一步会真的走一遍公证，看看 notarytool 通不通。
4. 三步都绿了，再真发布。注意这一步和前三步不同：**推 tag 时若 secret 没配齐，作业会在头几秒就失败**，
   不会悄悄产出一个空的 Release。

```bash
# 先把 project.pbxproj 里的 MARKETING_VERSION 改成要发的版本号并提交，
# 否则 release.yml 第一步的版本一致性断言会把你拦下来
git tag v1.0.1
git push origin v1.0.1
```

版本号刻意以工程为单一事实来源、由 CI 断言 tag 与它一致，而不是反过来让 CI 用 tag 覆盖工程里的版本号：
否则应用「关于」里显示什么就完全取决于谁推了什么 tag，本地构建和 CI 构建还会给出不同的版本号。

## 八、常见失败与处置

| 症状 | 多半是 | 怎么办 |
| --- | --- | --- |
| 作业卡住不动直到 timeout | codesign 正在弹 GUI 授权框（无 TTY 下不报错，只是挂着） | 检查 `security set-key-partition-list` 那步是否执行、`-k` 传的密码对不对 |
| `No signing certificate ... found` | 临时钥匙串没进搜索列表，或把 login.keychain-db 挤掉了 | 看「导入签名证书」步里 `list-keychains -d user -s "$keychain" $old` 的 `$old` 是否为空 |
| 归档跑到一半 codesign 失败 | 新钥匙串 5 分钟无操作自锁了 | `security set-keychain-settings "$keychain"` 必须不带任何选项 |
| 公证状态 Invalid | entitlements、强化运行时或签名有问题 | 下载 artifact 里的 `notary-log.json`，真正的原因在 `issues[]` 里 |
| `tag 与 MARKETING_VERSION 不一致` | 工程里的版本号没跟着 bump | 改 `project.pbxproj` 提交，删掉旧 tag 重新打 |
| `找不到 Xcode 26.x*` | 锁了版本而镜像更新把它删了 | 照错误日志里列出的现有版本改 `release.yml` 的 `XCODE_VERSION`，或留空用镜像默认 |
| 推了 tag，作业几秒就红，报「没配置 ...」 | 这是设计如此：推 tag = 正式发布，secret 不齐时当场失败 | 按第三节配齐 secret，或先用 Run workflow 演练 |
| fork 里推 tag 也红 | fork 拿不到上游仓库的任何 secret | 正常现象。想在自己的 fork 里发布，就在 fork 上配一套自己的证书 secret |
| 想让 fork 的 PR 也能签名 | 做不到，也不该做 | fork PR 拿不到 secret、`GITHUB_TOKEN` 也只读，这正是签名/发布与 PR 门禁分成两个 workflow 的原因。**千万别改用 `pull_request_target` 去绕**，那等于在 fork 的代码上下文里交出写权限的 token |

## 九、CI 保证不了的事

免得看见全绿就以为万事大吉：

- **工程里没有任何测试 target**，两个共享 scheme 的 `<Testables>` 都是空的，`xcodebuild test` 会直接
  报 "Scheme Copyo is not currently configured for the test action."。真正跑到的测试只有 `CopyoCore`
  那个本地包里的那些，Mac 应用本体（面板、监听、同步）一行都没覆盖。
- **受限 entitlements 与描述文件对不上时，包在别人机器上才会被系统终止**，CI 这边照样全绿。
  发布前请在一台没有开发者证书的 Mac 上真装一次。
- **上架流程不在 CI 里**：`scripts/build-appstore.sh` 仍是本地手动跑，它需要 Apple Distribution +
  Mac Installer Distribution 两张证书，还需要人工确认提审。

## 十、后续可做（不在本次范围）

1. **给 DMG 本身也签名 + 公证 + staple**。现在只有 `.app` 被 staple，用户把它从 DMG 里拖出来离线也能过
   Gatekeeper，所以不阻塞；好处是磁盘映像本身也不再被标记为未识别。代价是多一轮公证往返，
   而且本地脚本和 CI 的产物从此不再等价。
2. **`CURRENT_PROJECT_VERSION` 自动递增**（ROADMAP 里已有独立条目）。顺带一提，现在 macOS 的
   Release-AppStore 配置是 4，其余 11 处都是 1，本来就不齐。
3. **两个 iOS 扩展的 Release 配置缺 `ENABLE_HARDENED_RUNTIME`**。macOS 的直分发包里没有 appex，
   所以不影响本流程，但 iOS 侧将来要走公证路径前必须补上。
4. **把 action 从版本 tag 改成 pin 到 commit SHA**。tag 是可以被重新指向的，pin 到 SHA 更稳妥：
   `gh api repos/actions/checkout/git/ref/tags/v5.0.0 --jq .object.sha`，然后写成
   `actions/checkout@<sha> # v5.0.0`。`.github/dependabot.yml` 对 SHA 和 tag 都能照常升级。
