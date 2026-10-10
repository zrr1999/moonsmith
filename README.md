# MoonSmith

面向 MoonBit 编译器的类型引导程序生成、语义验证与失败用例归约工具。

原型已支持确定性程序生成、参考求值、三种编译配置比较、归约和案例重放。
完整目标与范围见[项目申报书](docs/project-proposal.md)，架构和开发约定见[贡献指南](CONTRIBUTING.md)。

## Quick Start

安装 Git、MoonBit、uv 和 Just，确保 `moon`、`moonrun`、`uvx`、`just` 和 C 编译器在 `PATH` 中。
原型宿主支持 macOS、Linux；当前验证工具链为 MoonBit `0.10.14+7d59c7ec9`。

```shell
just install
just check
just build
just test
just run
```

`just run` 用种子 7 生成程序，比较 native debug、native release、wasm-gc 与参考结果，
并打印 `runs/` 下的案例目录。更多操作：

```shell
just run run --seed 42 --depth 4
just run demo
just run replay runs/case-<打印的案例标识>
```

`demo` 注入输出差异并演示归约，预期退出码为 `2`；它不代表发现编译器缺陷。
每次执行的命令、输出、判定和 Markdown 报告保存在案例的 `attempts/` 子目录。
