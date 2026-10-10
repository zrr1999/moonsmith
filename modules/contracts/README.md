# MoonSmith Contracts

实现[共享契约](../../fps/FP-0001-workspace-modules.md#term-shared-contracts)，
包含语言无关的命令、进程结果、执行观察、异常指纹、判定、案例和执行记录。

`Case` 保存原始生成配置与参考结果，`Attempt` 保存一次实际执行的工具链、命令和输出。
记录通过标准库 JSON 编解码；`format_version = 1` 标识当前案例格式。

原始进程输出与可选故障注入输出分别保存。数据结构不包含语言 AST 或宿主资源句柄。
