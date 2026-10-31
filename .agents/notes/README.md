# 工程笔记

此目录保存内部调研、方案比较和工程决策的依据，供后续设计与实现查阅。
笔记区分源码观察、备选方案和实测结果；记录日期和来源，不把候选方案写成已实现契约。

- [Engine 架构调研](research/engine-research.md)：编排、判定、归约与重放的参考机制和实现候选。
- [对比项目与基准规划](research/comparison-projects.md)：外部项目清单、比较边界和实验方法。
- [差分归约接入](research/differential-reduction.md)：自动接入的用户选择、失败保持与存证边界。
- [构建异常归约补齐](research/native-release-reduction-plan.md)：三例调查后的源码缺口、未决公共语义及有界实施切片。
- [本月剩余能力实施](research/monthly-completion.md)：stack 后续层、公共语义选择及 Host 依赖核对。
- [Engine 抽象骨架](research/engine-abstraction.md)：职责与组合约束、最小 Int 简化及成本记录。
- [历史回归验收](../../docs/historical-regressions.md)：首批案例来源、当前工具链检查与旧版真实复现。
- [验证材料目录](research/corpus-layout.md)：上游组织方式调研、固定案例与模块测试的边界、待取得的证据。
- [CI 与发布职责](research/ci-release-boundary.md)：官方项目的发布入口、用户确定的职责边界与验收安排。

公开的产品目标和使用说明保留在 [README](../../README.md)、[项目申报书](../../docs/project-proposal.md)
和[贡献指南](../../CONTRIBUTING.md)；跨文档设计决定由 [FP](../../fps/README.md) 维护。
需要形成项目约定时核实来源并更新所属正式文档，再从笔记引用，避免维护两份事实源。
目录之外的正式文档不得引用内部笔记；验收结论按原始记录核实后整理进正式验收文档。

未来目标见 [ROADMAP.md](../../ROADMAP.md)，方向变化见 [EVOLUTION.md](../../EVOLUTION.md)；
提案当前阶段在 FP 的 `status` 中维护，笔记不另存一份状态或排期。
