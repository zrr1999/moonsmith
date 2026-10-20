# 贡献指南

## 开发准备

工具链要求见 [README](README.md#使用)。确认 `moon` 在 `PATH` 中后，在仓库根目录运行
`just install`，刷新包索引并安装 `pre-commit` 与 `commit-msg` hooks。
第三方依赖使用正式发布版本；固定提交必须对应正式 release，不能用开发分支、私有补丁或
旁路脚本替代缺失的上游能力。规范确需调整时，先说明原因和影响并取得维护者同意。

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `just install` | 准备依赖索引和 Git hooks |
| `just format` | 格式化 justfile 与 MoonBit 源码 |
| `just check` | 运行统一静态检查，与 `uvx prek run --all-files` 相同 |
| `just build` | 构建全部模块及 native 可执行入口 |
| `just test` | 运行单元测试与真实工具链集成测试 |

命令行使用与实际入口验证见 [README](README.md#使用)。检查工具、版本和适用范围统一维护在
[prek.toml](prek.toml)，本地和 CI 使用同一门禁；不得为交付跳过或降低检查。
新增文件需纳入 Git 索引后才能被 `--all-files` 检查；未准备暂存时可使用
`git add --intent-to-add <文件>`，或运行 `uvx prek run --files <文件>`。

## 变更与验证

- 文档变更运行 `just check`；实现变更另运行 `just build`、`just test` 及相关行为测试。
- 命令行入口变更通过实际入口验证。测试应观察对外结果和真实失败边界，不能只检查内部调用。
- 模块、依赖或打包规则变更按 [FP-0001](fps/FP-0001-workspace-modules.md#验证)进行专项验收。
- 实现与所属文档同步更新，记录实际执行的检查、结果和未验证范围。区分设计目标、已有能力
  与实测证据；构建或 CI 通过不替代产品验收。

## 设计与文档

**`.agents/` 仅存放内部工作材料；该目录之外的文档都是正式文档。正式文档不得引用内部笔记，
也不得把内部笔记作为设计前提、规范补充、使用说明或验收依据。**
需要采纳的结论先核实来源，再整理进所属正式文档并直接引用原始资料；内部笔记可以引用
正式文档，不能反向成为其权威来源。不得仅把草稿改名或挪出内部目录就当作已经验证的结论。

| 内容 | 维护位置 |
| --- | --- |
| 使用入口与文档导航 | [README](README.md) |
| 产品范围与验收目标 | [项目申报书](docs/project-proposal.md) |
| 设计、职责与约束 | 所属 [FP](fps/README.md)，术语由[索引](docs/glossary.md)定位 |
| 当前 API、执行行为与实现限制 | 各[模块 README](README.md#架构) |
| 固定输入与验证材料 | [案例说明](cases/README.md)及正式验收记录 |
| 未来安排与过去的方向变化 | [ROADMAP](ROADMAP.md) 与 [EVOLUTION](EVOLUTION.md) |

贡献指南只维护协作流程、检查入口和文档分工，不另存一份模块开发契约。
文档使用 Markdown，架构图使用 Mermaid；修改原文，避免维护重复事实源。
引用第三方源码或公开缺陷时保留原始来源与许可证，记录 AI 辅助范围并人工核验关键结论。

只有已有设计未覆盖且有明确大影响面的决定才需要新 FP；普通修复和既定设计的实现直接推进。
判断门槛与文档规则见 [FP-0000](fps/FP-0000-governance.md)，提案维护与索引生成按
[提案指南](fps/README.md#新建提案)执行，不手工维护生成索引。

## 提交与 PR

提交及 PR 标题使用英文，遵循 ZenDev 的 emoji、type 和可选 scope 格式，例如：

```text
✨ feat(generator): generate bounded boolean expressions
🐛 fix(reducer): preserve the failure predicate
📝 docs(architecture): clarify component responsibilities
```

PR 正文使用[仓库模板](.github/pull_request_template.md)，必填“动机”和“解决方案”。
围绕相对 base 的问题、最终改动及必要影响说明；“影响与边界”仅在需要说明兼容、迁移、限制
或关键取舍时保留。不要罗列本地测试、命令、机器路径、CI 状态或操作流水，执行记录保留在
CI 或任务交付记录中。提交消息和 PR 格式分别由 hooks 与 CI 检查。

保护无关的未提交内容，按当前任务明确授权的终点交付；提交、推送或创建 PR 不自动授权
合并、发布或扩大变更范围。
