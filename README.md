# MoonSmith

面向 MoonBit 编译器的类型引导程序生成、语义验证与失败用例归约工具。

## 架构

四个独立模块通过 `moon.work` 组成工作区：

| 模块目录 | 职责 |
| --- | --- |
| `modules/contracts` | 共享数据契约 |
| `modules/core` | 结果判定与通用归约，不依赖具体语言 |
| `modules/moonbit` | MoonBit 程序生成、参考求值、源码输出与归约候选 |
| `modules/cli` | 命令行、编译执行、案例存储与重放 |

流程：生成程序 → 参考求值与多配置执行 → 比较结果 → 归约异常案例 → 保存与重放。

## 使用

支持 macOS、Linux；需 MoonBit `0.10.14+7d59c7ec9`、Just 和 C 编译器。

```shell
just deps                       # 准备包索引
just run                        # 生成并验证一个案例
just run demo                   # 注入差异，演示归约；退出码为 2
just run replay runs/case-<id>   # 重放打印出的案例目录
```

原型覆盖确定性的整数、布尔和分支子集，比较 native debug、native release、wasm-gc。
源码、执行记录和报告保存在 `runs/`；`demo` 不代表发现编译器缺陷。

完整设计见[项目申报书](docs/project-proposal.md)，开发与测试见[贡献指南](CONTRIBUTING.md)。
Core 的后续职责与策略边界见[架构设计](docs/core-architecture.md)和
[FP-0002](fps/FP-0002-core-execution-contract.md)，依据见[调研记录](docs/core-research.md)。
