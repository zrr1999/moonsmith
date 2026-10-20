# 固定验证案例

此目录保存需要长期复用的具体输入及必要预期。每个案例通常只有 `case.toml` 和
`main.mbt`，由 CLI app 的行为测试直接发现和消费。普通生成性质、判定反例、重放和
超时场景就近放在所属模块的测试中，不再维护外层 corpus 清单。

```text
cases/
  README.md
  moonbit/
    <case-id>/
      case.toml
      main.mbt
```

案例按语言组织，ID 保持稳定，同一输入可供多个测试使用。源码是被测输入，不加入
`moon.work`，不随发布库打包；执行时在忽略的 `runs/` 中准备工程并追加记录。
历史回归尽量只保留触发所需的代码，归约演示保留较大的原例；不为每例创建空构建文件、
独立 README 或执行脚本。

## 元数据与执行

`main.mbt` 是固定的源码文件名。`case.toml` 的 `kind` 标明当前消费方式，其他字段只保存
该输入实际需要的条件。复杂判定由测试代码调用已有 Engine 和语言适配器实现。

| kind | 必要条件与实际入口 |
| --- | --- |
| `reference-output` | `source` 保留上游来源，`reported_compiler` 可选；`configurations` 和完整 `expected_stdout` 由[历史参考测试](../modules/cli/src/app/regression_wbtest.mbt)执行和判定，空输出写空字符串 |
| `reduction` | 保存生成器来源、种子和生成预算；[归约测试](../modules/cli/src/app/reduction_wbtest.mbt)先核对生成源码与快照，再运行已有受控故障注入、成本检查、独立确认和重放 |
| `differential` | 保存源码、报告版本、配置对及预期现象；目前仅保存候选材料，尚未接入对应受影响工具链与观察协议，不能计作真实差分验收成功 |

测试直接读取 `cases/moonbit/` 下的案例目录，按 Host 的确定排序遍历，忽略隐藏条目。
新增或重命名案例无需维护路径清单。未知种类、缺失元数据、缺失或空源码明确报错；
必需的参考或归约案例集为空时失败。参考预期中的未知字段、未知配置和重复配置在该例编译前拒绝。
种类描述实际消费方式，目录数量和案例数量不属于测试契约；新增消费方式应同时接入实际测试。

归约输入是生成器导出的完整源码快照，测试只统一末尾换行为一个 LF 后逐字核对。
测试使用记录的生成参数取得 `CompleteProgram`，核对发射源码与快照一致后才进入归约，
不把任意外部源码伪装为生成记录或已解析的 AST。
生成器修订字段保留原导出来源，实际重跑还需通过快照核对。归约与重放沿用已有运行材料格式，
原例和已完成执行记录不覆盖；候选预算仍使用现有默认值。

## 当前材料与验证范围

| 材料 | 当前结论与边界 |
| --- | --- |
| [#1006](moonbit/moonbit-docs-1006/case.toml) | 字符串尾部模式输出 `n`；上游讨论指向 core 修复 |
| [#1070](moonbit/moonbit-docs-1070/case.toml) | 正零的 Int64 位表示为 `0` |
| [#1266](moonbit/moonbit-docs-1266/case.toml) | 管道向 tuple struct 传参正常编译且无输出；旧版真实复现与当前回归分别记录 |
| [#1326](moonbit/moonbit-docs-1326/case.toml) | UInt 可选值与移位的历史差分候选；材料存在不代表由 MoonSmith 检测或重新生成了该问题 |
| [生成快照](moonbit/reduce-root-call/case.toml) | 实际导出的 128 节点输入，通过现有受控注入验证缩减、确认和重放；不作为真实编译器缺陷归约证据 |

历史参考入口按每例的配置执行，复用 `toolchains/moon` 与 Engine 的明确预期判定，
保存工具链、平台、命令、原始观察及报告。某例预期不满足时继续其余案例并汇总失败。
来源及旧版真实复现见[历史验收记录](../docs/historical-regressions.md)。

验证目标与文件目录分别维护：

| 验证目标 | 预言机与证据 |
| --- | --- |
| 已知输入暴露问题 | 固定输入在指定工具链下满足明确预期或出现目标异常；当前正常参考检查与旧版真实复现分别报告 |
| 生成机制发现问题 | 同一个生成程序在不同配置下的有效结果存在分歧，无需与历史源码逐字一致；历史归因还需独立证据，当前没有自动归因实现 |
| 归约保留失败 | 每个候选提供新证据，满足会话冻结的[失败判据](../fps/FP-0004-engine-execution-contract.md#term-failure-predicate)，并改善同一成本顺序；保持配置对分歧不证明根因相同，也不保证全局最小 |
| 基础行为与批量验收 | 生成合法性、预算、判定、重放和执行失败由模块行为测试覆盖；样本规模及完整矩阵以[申报书](../docs/project-proposal.md#预期验收产物)和实际批跑报告验收 |

纯算法使用显式种子和预算。批量验收目标见[申报书](../docs/project-proposal.md#预期验收产物)，
参数使用根目录的
[任务配置](../acceptance.toml)，执行与材料说明见 [CLI 模块](../modules/cli/README.md#任务配置)，
不为每个随机样本在此建立固定案例。
算法孵化、对比与可视化归 Spore Lab 仓库，本仓库保留产品回归和真实工具链验收。

## 检查与来源

`just test` 包含直接发现、元数据反例、历史参考与归约重放检查。聚焦运行：

```shell
moon test modules/cli/src/app/cases_wbtest.mbt modules/cli/src/app/regression_wbtest.mbt --target native
moon test modules/cli/src/app/reduction_wbtest.mbt --target native
```

结构检查只证明材料可读；尚未执行的受影响工具链、随机再发现和真实缺陷归约仍待取得证据。
当前配置为 native debug、native release、wasm-gc debug，不等同于完整五配置验收。

历史程序依据公开问题独立编写，生成快照记录实际生成条件，均使用本仓库的 GPL-3.0-only
许可证。引入第三方原始源码时保留来源与许可。真实工具链、受控注入和模型观察分别报告，
执行记录与既有生成案例格式继续独立维护。
