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
| `just test` | 运行 native 测试；当前空包没有产品测试 |

新增文件需纳入 Git 索引后才能被 `--all-files` 检查。尚不准备暂存内容时可使用
`git add --intent-to-add <文件>`；单独检查未跟踪文件也可运行
`uvx --from prek==0.3.10 prek run --files <文件>`。

文档变更运行 `just check` 和 `git diff --check`。实现变更运行 `just check` 与 `just test`，并增加或
运行相关行为测试。进程生命周期、判定和归约必须覆盖其实际失败边界，不能只断言内部调用。
未来的编译器测试矩阵与 MoonSmith 自身的构建检查分别记录；当前 CI 的 native 检查不代表
比赛要求的四后端、五配置验证已经完成。

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
