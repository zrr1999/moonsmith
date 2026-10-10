# MoonSmith Contracts

定义语言无关的命令、进程结果、执行观察、异常 fingerprint、判定、案例和执行记录。

`OracleResult` 以 Oracle、配置和阶段标识一项判断，结果区分满足、违反、不适用和证据不足。
`Assessment` 保存这些结果的不可变快照；完整性要求所提交的结果非空、无重复标识且无证据不足，
不会推断调用方未声明的检查。`FailurePredicate` 为原型的异常类别加上 Oracle 身份，
`PredicateStatus` 区分保持、不保持、不可判定和不适用。更复杂的关系判据由后续 Oracle 扩展。

`Case` 保存原始生成配置与参考结果，`Attempt` 保存一次实际执行的工具链、命令和输出。
记录通过标准库 JSON 编解码；`format_version = 1` 标识当前案例格式。
新增判断契约用于库内交互，尚未加入持久化格式；现有 `Attempt` 继续保存原型主结论与原始观察。

原始进程输出与可选故障注入输出分别保存。数据结构不包含语言 AST 或宿主资源句柄。
