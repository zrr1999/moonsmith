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

## 使用

支持 macOS、Linux；需 MoonBit `0.10.14+7d59c7ec9`、Just 和 C 编译器。

```shell
just install   # 准备包索引并安装 Git hooks
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- --help
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- run
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- run --seed 42
moon run modules/cli/src/cmd/moonsmith --target native --deny-warn -- replay runs/case-<id>
```

可执行程序无参数时只显示帮助，`run` 启动一次测试；省略种子时自动选择并记录。
首版组合局部绑定与引用、条件分支、无环函数定义与调用，比较 native debug、native release、
wasm-gc debug 的正常输出，无需参考求值器。发现分歧后继续执行剩余配置。
原始证据保存成功后自动归约，保持同一对配置的输出分歧，并独立执行一次确认。
摘要显示缩减前后的节点数、整数常量量级与源码字节数、停止原因和确认状态，不保证全局最小。

摘要显示结果、种子、有效配置数和材料路径；异常时展开关键差异或失败原因。保存成功后，
一致返回 `0`、分歧返回 `2`、比较未完成返回 `3`；参数、生成或保存错误返回 `1`。
源码、构建文件和原始观察保存在 `runs/`；重放使用当前工具链并追加记录，已知版本变化会提示。
将重执行参数替换为摘要中的 `Replay material` 路径，可重放归约结果；传入案例目录则重放原例。
重放不再次启动归约。

设计见 [FP-0002](fps/FP-0002-moonbit-semantic-contract.md) 与
[FP-0003](fps/FP-0003-cli-workflows.md)，实现边界见
[执行契约](CONTRIBUTING.md#原型执行契约)。多配置一致不证明编译器正确，分歧仍需调查。

## 文档导航

| 文档 | 内容 |
| --- | --- |
| [项目申报书](docs/project-proposal.md) | 产品范围与预期验收目标 |
| [验证 Corpus](corpora/README.md)与[Case](cases/README.md) | 八类验收用途、共享输入、执行入口与待接入边界 |
| [提案入口](fps/README.md)与[术语索引](docs/glossary.md) | 当前提案阶段、设计决定、概念定义及引用规则 |
| [Engine 设计提案](fps/FP-0004-engine-execution-contract.md) | 职责、协作模型、策略扩展和验收条件 |
| [项目演进](EVOLUTION.md) | 过去的方向变化与原因 |
| [长期路线图](ROADMAP.md) | MoonSmith 向 SemaForge 渐进提取的目标、依赖与推进门槛 |
| [工程笔记](.agents/notes/README.md) | 来源证据、备选机制与实验规划 |
| [贡献指南](CONTRIBUTING.md) | 开发入口、原型执行契约与交付约定 |
| [Contracts](modules/contracts/README.md)、[Engine](modules/engine/README.md)、[MoonBit](modules/moonbit/README.md)、[CLI](modules/cli/README.md) | 各模块现有 API、使用方式与实现限制 |
