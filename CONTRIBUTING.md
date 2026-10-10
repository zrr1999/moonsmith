# 贡献指南

## 开发准备

先保证本机 `moon` 已在 `PATH` 中，官方安装目录为 `~/.moon/bin`。然后在仓库根目录运行
`just install`，把 `prek` 的 `pre-commit` 和 `commit-msg` hooks 装进本仓库 `.git/hooks/`。
检查工具配置见 [prek.toml](prek.toml) 和 [CI 工作流](.github/workflows/ci-static-checks.yml)。

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `just` | 列出开发命令 |
| `just install` | 安装 Git hooks |
| `just format` | 格式化 justfile 和 MoonBit 包 |
| `just check` | 仓库只读门禁，运行 `prek --all-files` |
| `just build` | 构建 workspace 全部模块及 native 可执行入口 |
| `just test` | 运行全部模块的 native 测试；当前骨架没有产品测试 |
| `just run` | 运行开发入口，当前仅显示开发状态 |

新增文件需纳入 Git 索引后才能被 `--all-files` 检查。尚不准备暂存内容时可使用
`git add --intent-to-add <文件>`；单独检查未跟踪文件也可运行
`uvx --from prek==0.3.10 prek run --files <文件>`。

文档变更运行 `just check` 和 `git diff --check`。实现变更运行 `just check`、`just build` 与
`just test`，并增加或运行相关行为测试。入口变更还需运行 `just run`。进程生命周期、判定和
归约必须覆盖其实际失败边界，不能只断言内部调用。
未来的编译器测试矩阵与 MoonSmith 自身的构建检查分别记录；当前 CI 的 native 检查不代表
四后端、五配置验证已经完成。

## 质量检查

第三方 hooks 的版本固定在 `prek.toml`，本地 `just check` 与 CI 使用同一入口。

| 工具 | 检查范围 |
| --- | --- |
| MoonBit、Just | 源码格式、类型、编译器警告及任务文件格式 |
| alint | 包结构、依赖方向与纯计算边界 |
| Tombi、yamllint | TOML 格式与 lint，YAML 缩进、重复键及布尔值 |
| rumdl、typos、lychee | Markdown 结构、拼写及本地链接 |
| check-jsonschema | Renovate 配置与 `schemas/` 下的 JSON Schema 定义 |
| actionlint、zizmor | GitHub Actions 语法、表达式及工作流安全问题 |
| Gitleaks | 工作区中的凭据和令牌，包括未跟踪文件；日志隐藏匹配值 |
| prek 文件检查 | 大文件、跨平台文件名、符号链接、脚本权限、意外子模块及文本卫生 |
| ZenDev | 提案结构与索引，提交及 PR 消息规范 |

新增的格式检查不自动改写文件。Markdown 使用 [.rumdl.toml](.rumdl.toml)，允许中文长段落、
GitHub 裸链接及 FP 的元数据标题；YAML 规则见 [.yamllint.yml](.yamllint.yml)。Tombi 和
zizmor 使用离线模式，JSON Schema 检查使用工具内置的 schema。Gitleaks 检查当前工作区，
通过 [.gitleaks.toml](.gitleaks.toml) 排除构建缓存、依赖下载、托管 worktree 和实验产物。

## 模块与包边界

根目录的 [moon.work](moon.work) 组织四个独立 module；每个 module 有自己的 `moon.mod`、
版本、依赖、README 和 LICENSE。module 是发布单位，内部 package 由 `moon.pkg` 定义，是编译与
命名空间单位。采用 [Moon workspace](https://docs.moonbitlang.com/en/stable/toolchain/moon/workspace.html)
的本地成员解析，不使用旧格式的路径依赖。

| 目录 | Module 名称 | 仓库内模块依赖 |
| --- | --- | --- |
| `modules/contracts` | `zrr1999/moonsmith-contracts` | 无 |
| `modules/core` | `zrr1999/moonsmith-core` | contracts |
| `modules/moonbit` | `zrr1999/moonsmith-moonbit` | contracts |
| `modules/cli` | `zrr1999/moonsmith` | contracts、core、moonbit |

四个模块的 `0.0.0` 都是初始占位版本，尚未发布；后续分别管理版本，无需同步升级。
`moon.mod` 使用带版本的依赖声明，workspace 内按成员名解析到本地源码。成员版本变化后
运行 `moon work sync` 更新依赖方声明。当前声明的是模块依赖图；`moon.pkg` 的 import
只在出现真实调用时添加。

下表列出全部九个 package。contracts、core 和 moonbit 各自的 `src/moon.pkg` 定义根包，
包名等于模块名。其余六个包位于 CLI 模块内，完整包名为
`zrr1999/moonsmith/<相对 src 的路径>`。

| 包 | 所属模块 | 职责 | 允许的仓库内依赖 |
| --- | --- | --- | --- |
| `contracts` | `zrr1999/moonsmith-contracts` | 语言无关的配置、观察值、预算和案例记录 | 无 |
| `core` | `zrr1999/moonsmith-core` | 纯测试编排、判定和归约搜索 | `contracts` |
| `moonbit` | `zrr1999/moonsmith-moonbit` | MoonBit 程序表示、生成、解释、源码输出和归约候选 | `contracts` |
| `host` | `zrr1999/moonsmith` | 进程生命周期、文件系统及平台访问 | `contracts` |
| `toolchains/moon` | `zrr1999/moonsmith` | Moon 工具链探测、命令计划及诊断分类 | `contracts`、`host` |
| `artifacts` | `zrr1999/moonsmith` | 案例持久化和追加式执行记录 | `contracts`、`host` |
| `report` | `zrr1999/moonsmith` | 从传入的记录生成报告 | `contracts` |
| `app` | `zrr1999/moonsmith` | 装配具体适配器，协调执行、存储及报告 | 上述各包 |
| `cmd/moonsmith` | `zrr1999/moonsmith` | CLI 参数、终端交互和退出码 | `app`、`host` |

Core 和语言包保持纯计算，通过参数与返回值交互。Core 不导入 MoonBit AST、Host 或存储包；
报告包不自行读写文件。`app`、CLI、Host、工具链及存储包目前限定为 native，纯计算包保留
其他后端的使用空间。后续 Rust、Swift 适配器与 `moonbit` 并列，由 `app` 选择和装配。

当前库包只声明边界，尚未定义公共 API。先在 Core、MoonBit 模块内按文件组织算法，实际规模
需要时再拆成子包。各包的行为测试放在相应包内，优先通过公共接口测试。模块拆分的理由和
兼容性见 [FP-0001](fps/FP-0001-workspace-modules.md)。

[.alint.yml](.alint.yml) 检查 workspace 布局、模块与包清单、当前组件之间的依赖方向，并阻止
纯计算组件直接导入已列出的环境与 I/O 依赖。import 检查覆盖 `moon.mod` 与 `moon.pkg`，
依赖 `moon fmt` 规范化的格式；新增模块、包或依赖时同步核对规则。
`just check` 和 CI 都通过 prek 执行 alint，单独运行可用
`uvx prek run alint --all-files`。

## 提交与 PR

提交及 PR 标题使用英文，保留 ZenDev 的 emoji 和类型配对，例如：

```text
🎉 init: bootstrap MoonSmith repository
📝 docs(architecture): define the compiler validation pipeline
✨ feat(generator): generate bounded boolean expressions
🐛 fix(reducer): preserve the failure predicate
```

本地检查示例：

```shell
uvx --from zendev==0.4.0 zendev message check --title --profile zendev --text "📝 docs: clarify the execution matrix"
```

PR 正文使用[模板](.github/pull_request_template.md)，说明动机、解决方案和实际验证。
正文面向不了解会话背景的评审者，聚焦本 PR 相对 base 的改动：解决的问题、最终设计或
行为、影响及直接相关的验证。依赖、兼容性和迁移信息仅在影响评审或使用时补充；省略
操作流水、协作过程、其他 PR 的工作总结和与本次改动无关的能力说明。
所有 PR 都检查标题；依赖更新机器人仅豁免正文模板。机器校验格式，英文表述由提交者及
评审者核对。提交、推送和 PR 的交付范围以当前任务的明确授权为准。

## 设计与证据

只有已有设计未覆盖、且有明确大影响面的新决定才使用 [FP](fps/README.md)，门槛见
[FP-0000](fps/FP-0000-governance.md#何时需要-fp)。文档纠错、恢复预期行为的意外 bug 修复、
普通兼容增强和既定设计的实现无需新提案；原 bug 严重或改动量大本身不是提案理由。
提案记录取舍，架构维护整体设计，实现 PR 关联对应文档并附实际验证。

提案变更运行 `uvx --from zendev==0.4.0 zendev proposal check --fix` 更新
`fps-index.json`，再运行 `just check`。索引不手工维护；`just check` 和 CI 都检查 FP。

架构和实现按同一个小切片更新。产品方向改变时，在 [EVOLUTION.md](EVOLUTION.md)
记录日期、触发、变化和理由。比赛范围与验收目标维护在[申报书](docs/project-proposal.md)中，
实测结果另附工具链、环境与原始记录。

固定回归案例纳入版本控制；批次实验产物放在忽略的 `runs/`。引用公开缺陷、历史项目或
第三方代码时保留来源及许可证说明。记录 AI 辅助的范围，人工核验涉及语义和实验的结论。
