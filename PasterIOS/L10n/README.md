# 界面文案的中文翻译

各界面代理**不要直接改** `PasterIOS/Localizable.xcstrings`（并行改同一个 JSON 必冲突）。

做法：
1. 代码里照常写 `String(localized: "English source string")`，英文源串就是 key。
2. 把这一屏用到的中文翻译写成 `PasterIOS/L10n/<screen>.zh-Hans.json`，形如：

```json
{
  "No clips yet": "还没有内容",
  "Search history": "搜索历史"
}
```

`<screen>` 用界面名小写：`history` / `detail` / `pinboard` / `settings` / `onboarding` / `ipad` / `share`。

3. 集成代理把这些 JSON 合并进 `Localizable.xcstrings`（en 用 key 原文，zh-Hans 用这里的值，
   `extractionState` 一律 `manual`）。已经在 catalog 里的 key 不必重复提交。
