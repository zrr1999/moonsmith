# MoonSmith

面向 MoonBit 编译器的类型引导程序生成、语义验证与失败用例归约工具。

目前已搭建由 `moon.work` 管理的多模块开发骨架，目标与范围见[项目申报书](docs/project-proposal.md)。

参与开发见[贡献指南](CONTRIBUTING.md)；影响重大的新设计决定使用 [FP 提案](fps/README.md)。

## Quick Start

安装 Git、MoonBit、uv 和 Just，确保 `moon`、`uvx`、`just` 在 `PATH` 中，然后在仓库根目录运行：

```shell
just install
just check
just build
just test
just run
```

`just run` 目前仅显示开发状态，生成、验证和归约功能尚未实现。
