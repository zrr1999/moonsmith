# 仓库协作约定

- 先读 [README](README.md) 和[项目申报书](docs/project-proposal.md)，核实当前实现状态。
- 文档统一使用 Markdown，架构图使用 Mermaid。更新原文，不维护并行的 Typst 或 PDF 源稿。
- 区分设计目标、已实现能力与实测证据；空包检查通过不等于产品验收通过。
- Core 负责测试编排与判定；语言适配器负责程序表示、语义和归约候选；Host 负责进程和文件系统。
- 纯算法使用显式种子和预算；保留原始案例及追加式执行记录，不把异常候选直接称为编译器缺陷。
- 按 [贡献指南](CONTRIBUTING.md) 运行相关检查。公共行为变化同时更新架构及行为测试。
- 仅对已有设计未覆盖且有明确大影响面的新决定按 [FP-0000](fps/FP-0000-governance.md) 提案；文档纠错、恢复预期行为的意外 bug 修复和既定设计的实现不需要新提案。
- PR 标题使用英文，遵循 ZenDev 的 emoji、type 和可选 scope 格式；正文使用仓库模板。
- 交付到用户指定的终点。远端创建、推送、PR 和发布以当前任务明确授权的范围为准。

## 仓库 Skills

按任务加载对应 skill；只有任务跨越职责边界时才组合使用，不要求每次执行全部流程。

| 任务 | Skill |
| --- | --- |
| 功能设计、跨包修改或重构规划 | [moonsmith-change-planning](.agents/skills/moonsmith-change-planning/SKILL.md) |
| 评审工作区改动、提交或 PR | [moonsmith-code-review](.agents/skills/moonsmith-code-review/SKILL.md) |
| 新增或修复行为测试、回归测试 | [moonsmith-test-behavior](.agents/skills/moonsmith-test-behavior/SKILL.md) |
| 本地交付或已授权提交前检查 | [moonsmith-pre-submit-checks](.agents/skills/moonsmith-pre-submit-checks/SKILL.md) |

上述项目 skills 随仓库维护，无需个人安装。项目契约和检查命令保留在现有文档中，skills 按需引用。
