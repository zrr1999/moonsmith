# MoonSmith

面向 MoonBit 编译器的程序生成与差分测试工具，保存可再次执行的异常证据。

## 架构

四个独立模块通过 `moon.work` 组成工作区：

| 模块目录 | 职责 |
| --- | --- |
| `modules/contracts` | 共享数据契约 |
| `modules/engine` | 结果判定与通用归约，不依赖具体语言 |
| `modules/moonbit` | MoonBit 程序模型、模板生成、合法性检查与观察协议 |
| `modules/cli` | 命令行、编译执行、案例存储与重放 |

流程：自动组合模板 → 按类型与作用域补全 → 多配置执行 → 差分比较 → 保存与重放。

## 使用

支持 macOS、Linux；需 MoonBit `0.10.14+7d59c7ec9`、Just 和 C 编译器。

```shell
just deps                       # 准备包索引
just run --help                  # 查看帮助
just run                        # 生成并测试一个案例，自动选择种子
just run run --seed 42           # 指定种子
just run replay runs/case-<id>   # 使用保存材料再次执行
```

可执行程序无参数时只显示帮助；开发命令 `just run` 默认传入 `run`。
首版组合局部绑定与引用、条件分支、无环函数定义与调用，比较 native debug、native release、
wasm-gc debug 的正常输出，无需参考求值器。发现分歧后继续执行剩余配置。

摘要显示结果、种子、有效配置数和材料路径；异常时展开关键差异或失败原因。保存成功后，
一致返回 `0`、分歧返回 `2`、比较未完成返回 `3`；参数、生成或保存错误返回 `1`。
源码、构建文件和原始观察保存在 `runs/`；重放使用当前工具链并追加记录，已知版本变化会提示。
不支持旧命令、参数或案例格式，不提供自动迁移；旧案例文件不会被删除或改写。

设计见 [FP-0002](fps/FP-0002-moonbit-semantic-contract.md) 与
[FP-0003](fps/FP-0003-cli-workflows.md)，实现边界见
[执行契约](CONTRIBUTING.md#原型执行契约)。多配置一致不证明编译器正确，分歧仍需调查。

## 文档导航

| 文档 | 内容 |
| --- | --- |
| [项目申报书](docs/project-proposal.md) | 产品范围与预期验收目标 |
| [提案入口](fps/README.md)与[术语索引](docs/glossary.md) | 当前提案阶段、设计决定、概念定义及引用规则 |
| [项目演进](EVOLUTION.md) | 过去的方向变化与原因 |
| [长期路线图](ROADMAP.md) | MoonSmith 向 SemaForge 渐进提取的目标、依赖与推进门槛 |
| [工程笔记](.agents/notes/README.md) | 来源证据、备选机制与实验规划 |
| [贡献指南](CONTRIBUTING.md) | 开发入口、原型执行契约与交付约定 |
| [Contracts](modules/contracts/README.md)、[Engine](modules/engine/README.md)、[MoonBit](modules/moonbit/README.md)、[CLI](modules/cli/README.md) | 各模块现有 API、使用方式与实现限制 |
