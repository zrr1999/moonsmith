# MoonSmith

面向 MoonBit 编译器的程序生成与差分测试工具，保存可再次执行的异常证据。

## 架构

四个独立模块通过 `moon.work` 组成工作区：

| 模块目录 | 职责 |
| --- | --- |
| `modules/contracts` | 共享数据契约 |
| `modules/engine` | 结果判定与通用归约，不依赖具体语言 |
| `modules/moonbit` | MoonBit 程序模型、模板生成、合法性检查、归约候选与观察协议 |
| `modules/cli` | 命令行、编译执行、案例存储与重放 |

流程：自动组合模板 → 按类型与作用域补全 → 多配置执行 → 差分比较 → 保存原例 → 归约分歧 → 确认与重放。

## 安装

支持 macOS、Linux；需 MoonBit `0.10.14+7d59c7ec9` 和 C 编译器。
选择 JS 配置时还需 Node.js；Wasm 与 Wasm GC 由 MoonBit 工具链中的 `moonrun` 执行。
Just 用于仓库开发检查。

从完整仓库检出安装 native 命令：

```shell
git clone https://github.com/zrr1999/moonsmith.git
cd moonsmith
moon install ./modules/cli/src/cmd/moonsmith
moonsmith --help
```

`moon install` 默认将可执行文件放入 `~/.moon/bin`，需将该目录加入 `PATH`；
可用 `--bin /absolute/bin` 选择安装位置。安装从仓库根目录执行，以 `moon.work` 解析本仓库的库，
外部依赖使用声明的正式版本。当前内部库尚未发布到 registry，使用完整源码安装。
安装后的命令可从其他工作目录启动，使用宿主已安装的 MoonBit 与运行时。

## 使用

安装后使用 `moonsmith run`、`moonsmith run --set seed_start=42` 和
`moonsmith replay <保存材料目录>`。仓库开发可以直接运行源码：

```shell
just install   # 准备包索引并安装 Git hooks
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- --help
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- run
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- run --set seed_start=42
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- replay runs/task-<id>/cases/case-<id>
```

可执行程序无参数时只显示帮助，`run` 执行有限测试任务，默认一个样本。 `run --config acceptance.toml --set sample_count=10` 可读取任务文件并覆盖字段；键名与 TOML 一致，默认值、文件和命令行依次覆盖。省略起始种子时自动选择并记录完整范围。首版组合局部绑定与引用、条件分支、无环函数定义与调用，比较 native debug、native release、 wasm-gc debug 的正常输出，无需参考求值器。任务配置还可选择 wasm debug 与 js debug；[acceptance.toml](acceptance.toml) 显式使用全部五配置。发现分歧后继续执行剩余配置。原始证据保存成功后自动归约，保持同一对配置的输出分歧，并独立执行一次确认。摘要显示缩减前后的节点数、整数常量量级与源码字节数、停止原因和确认状态，不保证全局最小。任务汇总分别记录内部生成检查、基线编译接受、完整比较与操作错误，并保留计划样本数作为分母。

摘要显示结果、种子、有效配置数和材料路径；异常时展开关键差异或失败原因。保存成功后，一致返回 `0`、分歧返回 `2`、比较未完成返回 `3`；参数、生成或保存错误返回 `1`。源码、构建文件和原始观察保存在 `runs/`；重放使用当前工具链和运行时并追加记录，已知版本变化会提示。将重执行参数替换为摘要中的 `Replay material` 路径，可重放归约结果；传入案例目录则重放原例。重放不再次启动归约。

设计见 [FP-0002](fps/FP-0002-moonbit-semantic-contract.md) 与 [FP-0003](fps/FP-0003-cli-workflows.md)，实现边界见 [CLI 实现说明](modules/cli/README.md#差分执行与存证)。多配置一致不证明编译器正确，分歧仍需调查。

## 文档导航

| 文档 | 内容 |
| --- | --- |
| [项目申报书](docs/project-proposal.md) | 产品范围与预期验收目标 |
| [固定验证案例](cases/README.md) | 可复用输入、预言机、执行入口与待验收边界 |
| [五配置矩阵验证](docs/five-configuration-pilot.md) | 固定输入、判定标准、复现方法与 100 例验证结果 |
| [归约演示](docs/reduction-demonstration.md) | 受控注入的缩减率、耗时、独立确认与源码重放 |
| [CLI 安装验收](docs/cli-installation-validation.md) | 完整源码安装、仓库外执行和工具链依赖边界 |
| [任务配置示例](acceptance.toml)与[命令行配置](modules/cli/README.md#任务配置) | 有限种子任务、统一覆盖、逐样本存证和汇总 |
| [提案入口](fps/README.md)与[术语索引](docs/glossary.md) | 当前提案阶段、设计决定、概念定义及引用规则 |
| [Engine 设计提案](fps/FP-0004-engine-execution-contract.md) | 职责、协作模型、策略扩展和验收条件 |
| [项目演进](EVOLUTION.md) | 过去的方向变化与原因 |
| [长期路线图](ROADMAP.md) | MoonSmith 向 SemaForge 渐进提取的目标、依赖与推进门槛 |
| [贡献指南](CONTRIBUTING.md) | 开发流程、检查入口、文档分工与交付约定 |
| [Contracts](modules/contracts/README.md)、[Engine](modules/engine/README.md)、[MoonBit](modules/moonbit/README.md)、[CLI](modules/cli/README.md) | 各模块现有 API、使用方式与实现限制 |
