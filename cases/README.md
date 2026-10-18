# 验证 Case

此目录保存唯一的输入与必要预期，由八类 [corpus](../corpora/README.md) 引用。
程序按语言、模型数据按组件组织；case ID 保持稳定，执行状态和验证用途不放进路径名。
同一输入可以支持多项检查，分别取得证据。

## 最小文件结构

| 输入形式 | 文件 | 示例 |
| --- | --- | --- |
| 固定程序 | `case.toml`、`main.mbt` | [已知差分候选](moonbit/moonbit-docs-1326/case.toml) |
| 生成或搜索条件 | `case.toml` | [生成边界](moonbit/generation-boundaries/case.toml)、[再发现](moonbit/rediscover-uint-option/case.toml) |
| 较大归约原例 | `case.toml`、`main.mbt` | [128 节点根调用](moonbit/reduce-root-call/case.toml) |
| 模型观察 | `case.toml`、`observations.json` | [非法输出](engine/invalid-output/case.toml) |
| 引用已有输入的场景 | `case.toml` | [重放](moonbit/replay-generated/case.toml) |
| 批次条件 | `case.toml` | [月度验收目标](moonbit/monthly-acceptance/case.toml) |

不创建空源码或无作用的构建文件。源码是被测输入，不加入 `moon.work`，不随发布库打包。
执行时在 `runs/` 的新目录准备所需工程；多文件和特殊依赖在出现具体需求时再扩展。

## 字段与归属

`case.toml` 保存该种输入实际需要的条件。新类型用 `kind` 标明用途；
`input` 或 `observations` 指向本 case 的文件，`source_case` 和 `target_case`
指向仓库内已有 case。公开问题使用 `source` 保留 URL，
`reported_compiler` 只表示上游报告版本，不代表已在该版本实测。

各类预期由对应测试入口解释：源码可以声明完整 stdout，模型数据声明结果分类，
生成定义声明种子范围与构造预算，归约定义声明失败条件、目标成本和候选预算。
不向不适用的输入添加生成种子、分组参数或虚假的节点数。
未接入的定义不会被通用参考测试当作已执行案例。

## 已接入的历史参考案例

| 案例 | 预期行为 | 公开来源 |
| --- | --- | --- |
| [moonbit-docs-1006](moonbit/moonbit-docs-1006/main.mbt) | 字符串尾部模式输出 `n` | [#1006](https://github.com/moonbitlang/moonbit-docs/issues/1006)，讨论指向 core 修复 |
| [moonbit-docs-1070](moonbit/moonbit-docs-1070/main.mbt) | 正零的 Int64 位表示为 `0` | [#1070](https://github.com/moonbitlang/moonbit-docs/issues/1070) |
| [moonbit-docs-1266](moonbit/moonbit-docs-1266/main.mbt) | 管道向 tuple struct 传参正常编译并无输出 | [#1266](https://github.com/moonbitlang/moonbit-docs/issues/1266) |

这三个案例的参考入口继续使用 `source`、可选的 `reported_compiler`、
`configurations` 和 `expected_stdout`，其中完整 stdout 包含换行，无输出写空字符串。
字段缺失、重复配置及未知字段在该例编译前报错。
它们由 [oracles](../corpora/oracles/corpus.toml) 的 `reference-output` 条目明确选入，
不再遍历全部 MoonBit case 后一律按参考输出执行。

当前配置为 native debug、native release、wasm-gc debug 中至少两个。工具链使用当前
`PATH`；每次执行新建 `runs/historical-<随机后缀>/cases/moonbit/<case-id>/`，
保留复制的输入、实际工具链、平台、
命令、原始输出、`attempt.json` 和 `report.md`。某例预期不满足时继续其余案例并汇总失败。
旧版复现见[验收记录](../.agents/notes/research/historical-regressions.md)，与当前检查分别报告。

这些记录与现有生成案例的 `case.json` 分别维护；CLI 的 `run`、`replay` 沿用原格式。
执行入口和未接入边界统一见 [corpus 说明](../corpora/README.md#检查)。

## 来源

历史程序依据公开问题独立编写，生成快照记录实际生成条件，均使用本仓库的 GPL-3.0-only
许可证。模型观察显式标为 `model`，其命令字段是不可执行的模型描述，不是真实编译器记录。
引入第三方原始源码时保留其来源与许可说明。公开问题状态、模型输入和故障注入均不能
代替真实问题的复现证据。
