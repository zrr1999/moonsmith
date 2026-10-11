# MoonSmith Contracts

实现[共享契约](../../fps/FP-0001-workspace-modules.md#term-shared-contracts)，
包含语言无关的命令、进程结果、执行观察、异常指纹、判定、案例和执行记录。

`Comparison` 表达无参考值的差分结果：全部配置一致、两个有效配置结果不同，或比较未完成。
它与已有参考判定 `Verdict` 分开表示，避免改变旧案例结论的含义。

`Case` 保存原始生成配置与参考结果，`Attempt` 保存一次实际执行的工具链、命令和输出。
记录通过标准库 JSON 编解码；`format_version = 1` 标识旧参考案例格式。

`DifferentialCase` 与 `DifferentialAttempt` 使用 `format_version = 2`，不要求参考值。
案例包含 `GenerationRecord`（种子、生成器版本、有效预算和实际规模）、生成源码与构建文件、
观察协议、计划配置和执行超时；输入嵌入源码，程序无参数且 stdin 为空。
执行记录保存当前工具链和平台探测的 `ProcessEvidence`、各配置的原始观察及 `Comparison`。
版本 2 的重执行使用保存材料，不要求仍能运行当时的生成器，也不转换旧参考结论。

原始进程输出与可选故障注入输出分别保存。数据结构不包含语言 AST 或宿主资源句柄。
