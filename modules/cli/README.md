# MoonSmith CLI

通过[应用装配层](../../fps/FP-0001-workspace-modules.md#term-application-layer)连接 Engine、
MoonBit 适配器、宿主执行、案例存储和报告，提供单案例差分测试与保存材料重执行。

在仓库根目录使用 `just run` 启动一次测试，`just run run --seed 42` 指定种子，
`just run replay <案例目录>` 追加一次重执行。帮助见 `just run --help`；可执行程序无参数时
只显示帮助。命令行只接受当前差分工作流，不保留旧参数、`demo` 或旧案例格式兼容路径。

`cmd/moonsmith` 拥有参数解析、帮助、终端输出与退出码，只依赖 app 与 Host。
`app` 装配生成、执行、比较与保存；`toolchains/moon` 定义执行矩阵；`host` 封装进程和文件系统；
`artifacts` 维护原案例与追加记录；`report` 只渲染传入数据。支持 macOS 与 Linux native 宿主。

`app.run_differential(seed?, ...)` 接通模板生成、多配置执行、Engine 比较和版本 2 存证。
省略种子时从系统熵选择 Int 值；显式种子优先，熵不可用时报告错误，不回退到固定种子。
生成器取得显式值，案例与失败报告保留该值。库调用可指定生成预算与执行超时。
固定三配置全部尝试，分歧不会提前终止执行，失败成员保留在计划及观察中。

`app.replay_differential` 读取保存的源码、`moon.mod`、`moon.pkg`、配置及观察协议，复制到
新的尝试目录执行，不重生成程序。不支持的格式、协议或配置在执行前拒绝。
原案例与已完成尝试不覆盖；新的 `attempt.json` 最后独占写入，标志本次证据保存完成。
重放使用当前工具链；原执行的版本已知且发生变化时，终端摘要提示变化。
工具链探测失败保留原始状态与输出，摘要标明版本未知。

两种入口返回 `DifferentialRun`，包含案例与尝试记录、各自目录、原工具链探测及保存错误。
`save_error` 非空时仍保留已经取得的观察与比较结论，调用者不能将它视为保存成功。
`app.describe_differential` 为 CLI 提供摘要：正常结果简短，异常展开结果与失败原因。
可选的 `on_plan` 回调在执行前给出实际计划配置，便于展示进度，不参与结果判定。
退出码及保存条件以 [FP-0003](../../fps/FP-0003-cli-workflows.md#结果与产物)为准。

`toolchains/moon.observe` 的 `build_timeout_ms` 与 `run_timeout_ms` 分别控制每次编译及运行，
默认 30000 与 2000 毫秒，允许范围均为 `1..600000`。无效值在执行前拒绝，实际值写入观察。
当前 CLI 使用默认预算；配置入口与公开范围另行设计。记录包含命令、输出上限、状态、原始输出，
以及 `moon version --all` 和 `uname -srm` 探测。Host 不快照整个环境或提供任意源码沙箱。

行为测试覆盖真实工具链、差分与不完整证据、保存失败、保存材料重执行、版本变化提示及 CLI
结果。内部故障注入与真实编译器异常分别标识，执行边界见根目录[贡献指南](../../CONTRIBUTING.md)。
