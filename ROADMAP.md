# Roadmap

## 计划中

- [ ] Mac App Store 上架（1.0 已提交审核，材料见 docs/appstore-submission.md）
- [ ] CloudKit iCloud 同步（Mac 1.1 已实现，待发布；与文件夹快照同步并存、二选一，模型无需改动）
- [ ] iOS / iPadOS 版（详见 docs/ios-plan.md）
  - 定位：Mac 剪贴板历史的口袋入口 + 手机侧收集器，同一应用记录组成 Universal Purchase
  - Phase 0：抽出共享 `PasterCore` 包，Mac 先接入 CloudKit（已完成）
  - Phase 1：历史 / 搜索 / Pinboard / 复制，三条保存通道（前台自动读取、分享扩展、一键保存：操作按钮 / 敲击背面 / 控制中心），iPad 侧栏与拖放（2026-09-05 代码完成，待开发者后台配置、真机验证与提审，见 docs/ios-plan.md 3.2）
  - Phase 2：键盘扩展、小组件、Spotlight 索引
- [ ] 法语本地化（英文/中文已完成，String Catalog 就绪，添加语言即可）
- [ ] 应用内更新检查：比对 GitHub Releases，有新版时提示下载
- [ ] GitHub Actions CI：推送 tag 自动构建并附加 DMG 到 Release
- [ ] 单元测试：剪贴板内容分类、去重、同步合并逻辑
- [ ] 英文版 README
- [ ] 构建号随版本递增（`CURRENT_PROJECT_VERSION`）

## 已完成（v0.1.0）

- Developer ID 签名 + Apple 公证的发布流程（Release 中的 DMG 双击即装）
- 界面中英双语（String Catalog，英文基准 + 简体中文，跟随系统语言）
- 剪贴板历史：文本 / 富文本 / 链接 / 颜色 / 图片 / 文件，自动去重
- `⇧⌘V` 底部滑出卡片面板，即输即搜，全键盘操作，空格预览
- 自动粘贴回之前的前台应用（辅助功能权限，未授权时优雅降级）
- Pinboard 固定分组、历史上限自动清理、忽略指定应用
- 隐私：跳过密码管理器的 Concealed/Transient 内容，数据仅存本地
- iCloud Drive 同步（可选，支持自定义同步文件夹）
- 自定义全局快捷键（录制任意组合键）
- 首次启动引导、DMG 打包脚本、图标生成管线

欢迎通过 Issue 提出建议，或直接认领上面的条目提 PR。
