# 贡献指南

## 开发准备

工具链要求见 [README](README.md#安装)。确认 `moon` 在 `PATH` 中后，在仓库根目录运行 `just install`，刷新包索引并安装 `pre-commit` 与 `commit-msg` hooks。第三方依赖使用正式发布版本；固定提交必须对应正式 release，不能用开发分支、私有补丁或旁路脚本替代缺失的上游能力。规范确需调整时，先说明原因和影响并取得维护者同意。

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `just install` | 准备依赖索引和 Git hooks |
| `just format` | 格式化 justfile 与 MoonBit 源码 |
| `just check` | 运行统一静态检查，通过独立的 prek 工具环境执行 |
| `just build` | 构建全部模块及 native 可执行入口 |
| `just test` | 运行单元测试与真实工具链集成测试 |
| `just coverage` | 运行相同测试和归约演示，生成 MoonBit 原生 Cobertura 覆盖率 |
| `just benchmark` | 对固定种子的生成与归约候选运行原生性能基准 |
| `just build-historical` | 用开发工具链构建历史编译器异常检查程序与 CLI |
| `just test-historical-guard` | 验证历史检查拒绝当前开发工具链 |
| `just test-historical` | 把 moon 安装目录传给预构建检查程序，核对该目录中的 moonc |
| `just test-compiler` | 用 `execution.toolchains` 指定 moon 安装目录，运行已经构建的 MoonSmith |

命令行使用与实际入口验证见 [README](README.md#使用)。检查工具、版本和适用范围统一维护在 [prek.toml](prek.toml)，本地和 CI 使用同一门禁；不得为交付跳过或降低检查。新增文件需纳入 Git 索引后才能被 `--all-files` 检查；未准备暂存时可使用 `git add --intent-to-add <文件>`，或运行 `uvx prek run --files <文件>`。

覆盖率和性能报告写入 `.artifacts/quality/`。PR 通过[测试工作流](.github/workflows/ci-tests.yml) 运行原生覆盖率并上传到 Codecov。[静态 CI](.github/workflows/ci-static-checks.yml) 在指向 `main` 的 PR 和 `main` 分支推送时运行 CodeQL。[持续评估工作流](.github/workflows/ce-quality.yml) 独立维护每周性能、外部链接、完整 Git 历史密钥扫描和在线审计，也可手动触发，具体低频检查命令保留在对应 job。本地 hooks 检查仓库内链接和锚点。严格在线 workflow 审计仅由受信任主分支的 CE 执行，查询失败或跳过视为失败。

jactionlint、Lychee 和 Vale 使用上游正式发布的 hooks；工作流离线检查统一通过 prek 执行。
Shell 脚本使用 jactionlint hook 环境提供的 ShellCheck。ast-grep 的固定版本尚未提供官方 hook；
它与 MoonBit 命令保留本地入口。

MoonBit 源码由官方格式器、类型检查器、测试、覆盖率和基准运行器检查。SonarQube Cloud 与 CodeQL 分析它们支持的 GitHub Actions 和 C 时钟适配层；这些结果不代表 MoonBit 源码分析。ast-grep 的时钟规则有正反例，模块依赖边界继续由 alint 检查。当前 Semgrep、OSV、jscpd、Lizard 和变异工具不支持本仓库的 MoonBit 源码或依赖格式；CodSpeed 尚无可用的正式 MoonBit 集成，因此性能采集保留原生报告，不将未执行的扫描记为通过。

## 变更与验证

日常检查、构建和测试使用 MoonBit 与 core `0.10.18+6c83a7f62`。历史构建异常单独验证：先用该版本执行
`just build-historical` 和 `just test-historical-guard`，再把 `0.10.14+7d59c7ec9` 的安装目录传给预构建检查程序。
检查程序核对被测编译器版本，验证种子 1272、3745、6968 的自动归约、独立确认和重放，并保存完整材料；
CLI 检查同时验证构建异常仍返回比较未完成的退出码 `3`。
覆盖率只来自开发工具链上的单元测试，不运行被测 moonc。MoonSmith 用 `0.10.18` 构建完成后，再分别调用 `0.10.14+7d59c7ec9` 和 `0.10.11+6ff76a5f9`。其中 `0.10.14` 仍核对三例构建异常的归约、确认和重放。
新编译器修复历史问题时，不需要维持旧异常来通过日常测试。

- 文档变更运行 `just check`；实现变更另运行 `just build`、`just test` 及相关行为测试。
- 命令行入口变更通过实际入口验证。测试应观察对外结果和真实失败边界，不能只检查内部调用。
- 模块、依赖或打包规则变更按 [FP-0001](fps/FP-0001-workspace-modules.md#验证)进行专项验收。
- 实现与所属文档同步更新，记录实际执行的检查、结果和未验证范围。区分设计目标、已有能力
  与实测证据；构建或 CI 通过不替代产品验收。

## 设计与文档

**`.agents/` 仅存放内部工作材料；该目录之外的文档都是正式文档。正式文档不得引用内部笔记，也不得把内部笔记作为设计前提、规范补充、使用说明或验收依据。** 需要采纳的结论先核实来源，再整理进所属正式文档并直接引用原始资料；内部笔记可以引用正式文档，不能反向成为其权威来源。不得仅把草稿改名或挪出内部目录就当作已经验证的结论。

正式验证报告应给出适用版本、输入、复现方法、判定标准、结果与限制；本机路径、临时任务 ID、
逐次试错和开发检查流水保留在 `.agents/`，不作为正式报告的正文或补充契约。

| 内容 | 维护位置 |
| --- | --- |
| 使用入口与文档导航 | [README](README.md) |
| 产品范围与验收目标 | [项目申报书](docs/project-proposal.md) |
| 设计、职责与约束 | 所属 [FP](fps/README.md)，术语由[索引](docs/glossary.md)定位 |
| 当前 API、执行行为与实现限制 | 各[模块 README](README.md#架构) |
| 固定输入与验证材料 | [案例说明](cases/README.md)及正式验收记录 |
| 未来安排与过去的方向变化 | [ROADMAP](ROADMAP.md) 与 [EVOLUTION](EVOLUTION.md) |

贡献指南只维护协作流程、检查入口和文档分工，不另存一份模块开发契约。文档使用 Markdown，架构图使用 Mermaid；修改原文，避免维护重复事实源。引用第三方源码或公开缺陷时保留原始来源与许可证。

文档直接陈述设计依据、执行方法、结果和具体限制。限制应对应实际功能或实验，集中写在所属文档中；不反复附加通用 AI 声明、免责或核验提醒。

只有已有设计未覆盖且有明确大影响面的决定才需要新 FP；普通修复和既定设计的实现直接推进。判断门槛与文档规则见 [FP-0000](fps/FP-0000-governance.md)，提案维护与索引生成按 [提案指南](fps/README.md#新建提案)执行，不手工维护生成索引。

## 发行

CD 负责版本核对、构建打包和包内容验收，并在推送版本标签后、公开发布前完成种子 0–99 的完整五配置验收，
再执行 Mooncakes 包发布与 GitHub Release，然后核对已发布二进制和 registry 安装。
测试和历史复现由 CI 负责。
执行入口及证据位置见[发行与验收](docs/releasing.md)。包验收使用 `moon package`、
`moon check`、`moon test` 和 `moon install`，发布直接使用 `moon publish` 和 `gh release`。

## 提交与 PR

提交及 PR 标题使用英文，遵循 ZenDev 的 emoji、type 和可选 scope 格式，例如：

```text
✨ feat(generator): generate bounded boolean expressions
🐛 fix(reducer): preserve the failure predicate
📝 docs(architecture): clarify component responsibilities
```

PR 正文使用[仓库模板](.github/pull_request_template.md)，必填“动机”和“解决方案”。围绕相对 base 的问题、最终改动及必要影响说明；“影响与边界”仅在需要说明兼容、迁移、限制或关键取舍时保留。不要罗列本地测试、命令、机器路径、CI 状态或操作流水，执行记录保留在 CI 或任务交付记录中。提交消息和 PR 格式分别由 hooks 与 CI 检查。

保护无关的未提交内容，按当前任务明确授权的终点交付；提交、推送或创建 PR 不自动授权合并、发布或扩大变更范围。
