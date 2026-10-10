# Feature Proposals

FP 保存 MoonSmith 影响重大的功能与治理设计。先读 [FP-0000](FP-0000-governance.md)，
只有现有设计未覆盖的新决定且有明确大影响面时才需要新 FP。文档纠错、恢复预期行为的
意外 bug 修复、普通兼容增强和既定设计的实现直接推进。

提案围绕问题、约束、方案、取舍和验证条件展开，详细到足以指导实现。保留支撑设计判断
的事实，省略重复背景、实施进度和操作过程。

## 新建提案

1. 复制[模板](../templates/fp.md)到 `fps/FP-NNNN-short-title.md`。编号从 `0001`
   递增，取现有最大编号加一；slug 使用小写英文与连字符。合入前检查是否与其他提案重号。
2. 同步填写文件名、整数 `fp`、不带编号的 `title` 和 `# FP-NNNN: 标题`。
   `type` 为 `Feature` 或 `Governance`；`authors` 为实际作者的小写 GitHub 用户名；
   `created` 为创建日期。替代旧提案时填写 `supersedes: ["FP-NNNN"]`，否则保留空数组。
3. 写清摘要、动机、设计、兼容性和验证；更新索引并检查改动：

   ```shell
   uvx --from zendev==0.4.0 zendev proposal check --fix
   uvx --from zendev==0.4.0 zendev proposal check
   ```

4. 按[贡献指南](../CONTRIBUTING.md)检查所有改动。提案 PR 复用仓库模板，标题使用英文：

   ```text
   📝 docs(fp): propose deterministic case replay
   📝 docs(fp): revise deterministic case replay
   📝 docs(fp): supersede FP-0001 with versioned replay records
   ```

编号以文档为准，新提案和修订的 PR 标题不写新编号。需要 FP 的实现 PR 关联对应提案，并分别报告
实现和验证结果。PR、推送和发布仍遵守当前任务的授权范围。

## 文档与索引

提案直接放在 `fps/`，不设草稿目录或采纳、实现状态字段。合并提案只保存设计文本，
不表示已经采纳、排期或实现；讨论和决策由 Git 与关联 PR 保留。

[fps-index.json](../fps-index.json)由 frontmatter 确定性生成，不手工维护。
`just check` 和 CI 通过同一个 ZenDev hook 检查元数据、文件名、章节、关系与索引。
架构说明维护当前整体设计，`EVOLUTION.md` 记录方向变化，测试和原始记录提供实现证据。
