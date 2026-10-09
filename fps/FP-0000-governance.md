---
fp: 0
title: "MoonSmith 提案约定"
type: Governance
authors:
  - "zrr1999"
created: 2026-10-09
supersedes: []
---

# FP-0000: MoonSmith 提案约定

## 摘要

MoonSmith 使用 Feature Proposal（FP）保存值得长期保留的功能与治理设计。
一项新决定对应一份带编号的 Markdown，复用 Git、PR 和现有 ZenDev 检查。
提案不编码采纳或实现状态。

## 动机

语言子集、判定方法、失败判据和案例格式会共同影响测试结论。短提案记录这些决定的
理由和验证方式，便于后续实现与审查，也避免为每次修复或实现步骤重复编写设计。

## 设计

### 何时需要 FP

先判断是否有新的契约或治理决定，再检查已有 FP 和架构是否已经覆盖它。以下变更需要 FP：

- 新增或改变 CLI、配置、公开 API、案例与报告格式、重放和兼容性承诺。
- 新增或改变语言子集、可观察语义、判定或归约保持条件，以及实验统计口径。
- 改变 Core、语言适配器、Host 等模块的责任、状态或资源所有权。
- 改变提案、协作或发布规则。

实现已有设计、恢复既定行为的修复、测试补充、文字修正，以及保持契约的内部重构和
依赖维护可以直接提交实现 PR，关联已有设计即可。判断依据是行为和责任变化，
不是代码量或 `feat`、`fix` 标签。边界不清时先说明问题和现有依据，再由评审者判断。

### 编写与评审

提案放在 `fps/FP-NNNN-short-title.md`；`0000` 用于本约定，后续编号递增，
已合入的编号不删除或复用。正文使用[模板](../templates/fp.md)，默认中文，保留英文
技术标识。`Feature` 描述功能设计，`Governance` 描述协作规则。

frontmatter 只包含 `fp`、`title`、`type`、`authors`、`created`、`supersedes`。
作者填写对内容负责的人的小写 GitHub 用户名，不带 `@`；schema 只检查离线格式。
编号、标题与 H1 必须一致。具体操作见[提案入口](README.md)。

候选直接作为带编号文档评审，不维护单独的草稿目录。提案 PR 复用仓库模板；标题用英文，
采用 `📝 docs(fp): propose/revise/supersede ...` 的约定。产品实现 PR 关联对应 FP，
独立说明实现范围与验证。新决定应在依赖它的实现合入前完成设计评审。

提案合并只表示文本进入版本库，不等于采纳、排期或实现。讨论与决策保留在关联 PR 中；
未合入的候选保留在关闭的 PR 中。提案不维护 `status`、审批人或实现进度字段。

### 修订与替代

不改变含义的修正直接更新原文；改变原决定时创建新 FP，在新文档的 `supersedes` 中
引用被替代的 `FP-NNNN`。保留旧提案，反向关系 `superseded_by` 由索引生成。
提案合入前发生编号冲突时，同步调整文件名、frontmatter、H1、引用和索引。

[设计文档](../docs/project-proposal.md)说明项目范围与架构边界；FP 保存具体决定和取舍；
[EVOLUTION.md](../EVOLUTION.md)记录方向变化并链接相关 FP。实现时同步更新架构与
行为测试，实测结论仍须有环境、工具链和原始记录支撑。

## 兼容性

本约定从引入之日起用于新决定。现有架构、申报书及其他设计文档保留原位，无需追溯
改写成 FP；文档中的计划也不因此成为已实现能力。已有设计范围内的实现可直接关联原文，
新的契约或取舍才需要补充 FP。

## 验证

`proposal.toml` 配置固定版本 ZenDev 的元数据、文件名、模板章节、替代关系和
确定性索引检查。`just check` 与 CI 共用 `zendev-proposal-check`；更新提案后用
`zendev proposal check --fix` 生成 `fps-index.json`。

检查通过说明文档结构与索引一致，不能证明设计已被采纳、实现正确或实验完成。
是否需要新提案及证据是否充分，由作者与评审者依据具体契约判断。

参考 [Cue FP-0000](https://github.com/zendev-lab/cue/blob/1a7d822266333fbc7bf509f2a4227c188b2cf928/fps/FP-0000-governance.md)
与 [ZenDev ZFP-0000](https://github.com/zendev-lab/zendev/blob/6d2c1ca43d2a794e08c9e22459ff7fe81ccf6600/zfps/ZFP-0000-governance.md)
的轻量、无状态提案方式。
