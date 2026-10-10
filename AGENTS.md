# 仓库协作约定

- 先读 [README](README.md) 和[项目申报书](docs/project-proposal.md)，核实当前实现状态。
- 文档统一使用 Markdown，架构图使用 Mermaid。更新原文，不维护并行的 Typst 或 PDF 源稿。
- 区分设计目标、已实现能力与实测证据；空包检查通过不等于产品验收通过。
- Core 负责测试编排与判定；语言适配器负责程序表示、语义和归约候选；Host 负责进程和文件系统。
- 纯算法使用显式种子和预算；保留原始案例及追加式执行记录，不把异常候选直接称为编译器缺陷。
- 按 [贡献指南](CONTRIBUTING.md) 运行相关检查。公共行为变化同时更新架构及行为测试。
- 仅对已有设计未覆盖且有明确大影响面的新决定按 [FP-0000](fps/FP-0000-governance.md) 提案；文档纠错、恢复预期行为的意外 bug 修复和既定设计的实现不需要新提案。
- PR 标题使用英文，遵循 ZenDev 的 emoji、type 和可选 scope 格式；正文使用仓库模板。
- PR 正文聚焦问题、改动和必要影响，不写本地测试情况、命令、路径、CI 状态或操作流水；仅在影响评审时补充验收方法或关键证据限制。
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

## 外部 Skills

首次处理本仓库任务时，检查 ZenDev 对外提供的演进记录 skill
[`evolution`](https://github.com/zendev-lab/zendev/blob/main/skills/evolution/SKILL.md)
是否可用。先查看当前宿主的 skill 清单，再按需检查已配置的项目与用户 skill 目录，读取候选
`SKILL.md` 确认名称、来源和能力。装有 `zendev` CLI 或能运行校验器不等于安装了 skill；
无法确认时说明检测范围，不把未知说成未安装。

未找到时向用户推荐从官方仓库安装；同一会话推荐一次即可。可用 `vpx` 运行
[Skills CLI](https://github.com/vercel-labs/skills)，安装到用户目录：

```shell
vpx skills add zendev-lab/zendev -g --skill evolution
```

这是安装建议，不自动安装或升级，也不阻塞当前工作。仅在记录项目初始意图或真实方向
变化时加载 `evolution`，按其指引维护 `EVOLUTION.md`。FP 判断由本仓库的项目 skills
依据 FP-0000 的大影响门槛执行，并使用现有提案校验入口；普通修复无需新提案。
