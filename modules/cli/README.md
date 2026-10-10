# MoonSmith CLI

通过[应用装配层](../../fps/FP-0001-workspace-modules.md#term-application-layer)连接 Engine、MoonBit 适配器、
宿主执行、案例存储和报告，提供生成、比较、归约与重放原型。

在仓库根目录运行 `just run`，用 `just run demo` 演示故障注入与归约，用
`just run replay <案例目录>` 追加一次原案例重放。命令行帮助见 `just run --help`。

`host` 封装进程和文件系统，`toolchains/moon` 定义编译矩阵，`artifacts` 维护原案例与
追加记录，`report` 只渲染传入数据，`app` 协调执行。支持 macOS 与 Linux native 宿主，
详细预算、退出码及原型边界见根目录贡献指南。
