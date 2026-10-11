# MoonSmith CLI

通过[应用装配层](../../fps/FP-0001-workspace-modules.md#term-application-layer)连接 Engine、MoonBit 适配器、
宿主执行、案例存储和报告，提供生成、比较、归约与重放原型。

在仓库根目录运行 `just run`，用 `just run demo` 演示故障注入与归约，用
`just run replay <案例目录>` 追加一次原案例重放。命令行帮助见 `just run --help`。

`host` 封装进程和文件系统，`toolchains/moon` 定义编译矩阵，`artifacts` 维护原案例与
追加记录，`report` 只渲染传入数据，`app` 协调执行。支持 macOS 与 Linux native 宿主，
详细预算、退出码及原型边界见根目录贡献指南。

`cmd/moonsmith` 拥有参数解析、帮助信息、终端输出及退出码；`app.run` 与 `app.replay`
提供不依赖命令行参数的应用入口。CLI 只调用 app 和 Host，具体语言与工具链在 app 装配。

`toolchains/moon.observe` 可通过 `build_timeout_ms` 与 `run_timeout_ms` 分别覆盖每次编译和
执行的超时，默认值为 30000 与 2000 毫秒，允许范围均为 `1..600000`。无效值在执行前拒绝，
实际值写入各观察的 `Command`；超时保留为 `TimedOut`，不作为差分结果值。
当前命令行仍使用默认超时，这两个参数的 CLI 接入尚待完成。
