# 验证 Corpus

按要支持的结论组织验证清单。每份 `corpus.toml` 引用共享的
[`cases/`](../cases/README.md)，不复制输入。目录和清单存在仅表示材料已组织，
实际结果以对应执行记录为准。分类名称和数量不属于测试契约。

## 分类与当前材料

| Corpus | 结论 | 当前 case 与接入范围 |
| --- | --- | --- |
| [differential](differential/corpus.toml) | 固定已知输入由我们的差分路径暴露真实分歧 | [#1326](../cases/moonbit/moonbit-docs-1326/case.toml) 的 UInt 可选值候选；需接入受影响工具链和适用的观察协议，尚未作为差分成功证据 |
| [discovery](discovery/corpus.toml) | 生成器在明确搜索条件下重新发现真实问题 | [UInt 可选值再发现](../cases/moonbit/rediscover-uint-option/case.toml)；已有种子范围、预算与目标，当前生成器尚缺 UInt、Option、模式匹配及移位规则 |
| [reduction](reduction/corpus.toml) | 大输入缩小并保持原失败条件 | [受控根调用](../cases/moonbit/reduce-root-call/case.toml)保存实际生成的 128 节点源码；[真实 UInt 问题](../cases/moonbit/reduce-real-uint-option/case.toml)引用历史候选，两份归约定义均待接入 |
| [generation](generation/corpus.toml) | 生成结果确定、结构合法并遵守预算 | [生成边界](../cases/moonbit/generation-boundaries/case.toml)已接入库行为检查；不作为发现真实问题的证据 |
| [oracles](oracles/corpus.toml) | 明确预期和正反观察能正确分类 | 三个历史参考案例、[缺失观察](../cases/engine/missing-observation/case.toml)及[非法输出](../cases/engine/invalid-output/case.toml)已接入 |
| [replay](replay/corpus.toml) | 保存材料重新执行且旧记录不变 | [生成案例重放](../cases/moonbit/replay-generated/case.toml)定义追加与不重生成要求，数据入口待接入 |
| [runtime](runtime/corpus.toml) | 执行失败正确结束并记录事实 | [执行超时](../cases/moonbit/execution-timeout/case.toml)含有界执行要求，数据入口待接入；不声明后代进程清理保证 |
| [campaigns](campaigns/corpus.toml) | 完成目标样本规模与矩阵，报告完整分母和成本 | [月度验收](../cases/moonbit/monthly-acceptance/case.toml)保存 10,000 样本及 1,000 样本五配置目标；不是已执行报告 |

历史参考案例检查明确输出；它们当前通过不等于检测到了真实配置分歧。
真实工具链、受控条件与模型观察分别标记，不能相互替代。同一 case 可被不同 corpus 引用，
但每项结论需要自己的执行条件和证据。

## 清单

`corpus.toml` 的 `id` 与目录名一致，`claim` 描述结论，`[[cases]]` 包含：

- `path`：相对于仓库根目录的 case 目录，必须位于 `cases/`；同一 corpus 内不重复。
- `runner`：这份数据所连接的测试入口；`pending` 明确表示尚未接入。
- `evidence`：该检查要求的证据种类，为 `real-toolchain`、`controlled` 或 `model`。
  对 `pending` 条目，这是所需证据，不是已取得证据。

当前已连接的入口：

| runner | 输入与检查 |
| --- | --- |
| `reference-output` | `main.mbt` 与明确预期，在真实三配置上执行并独立存证 |
| `generation-properties` | 生成参数与种子范围，检查当前生成器的确定性及预算约束 |
| `differential-observations` | 明确标为模型的观察数据，经过真实观察协议与 Engine 比较 |
| `pending` | 仅检查材料可读和引用存在，不运行任务，不计作产品验收通过 |

测试遍历当前清单，按 `runner` 选择案例；添加、合并或重命名分类不需要修改执行入口。
遍历顺序由 Host 的排序目录读取保持稳定，同一 case 与 runner 的跨清单引用只执行一次。
已接入的入口必须至少有一个 case，否则报错，避免缺失材料变成零项检查通过。

这些是仓库测试入口标识，不是封闭的算法清单或公共 CLI 参数。
已有模块行为测试与某份数据是否接入分别记录；`pending` 不表示该模块整体尚未实现。

## 发现判定与历史归因

随机发现比较同一程序在不同配置下的有效结果，不要求生成源码或输出与历史 case 一致。
分歧只支持异常候选；发现结果的原始观察必须独立保存。归约检查候选自己的有效结果是否
仍保持原配置对的分歧，具体数值可以变化。保持同一观察条件不证明根因相同，见
[失败判据](../fps/FP-0004-engine-execution-contract.md#term-failure-predicate)。

`target_case` 声明再发现要核对的历史目标，目前不包含自动匹配或根因归类实现。
仅有相同配置对、执行阶段或异常种类，不能据此把随机发现计为该历史问题的再发现。

## Case 形式

```text
corpora/<name>/corpus.toml
cases/<language-or-component>/<case-id>/
  case.toml
  main.mbt              # 仅源码输入需要
  observations.json     # 仅模型观察输入需要，通常与 main.mbt 二选一
```

case 定义只放必要材料。生成、再发现、重放场景和批次可以仅有 `case.toml`；
归约的源程序保存在 `main.mbt`，也可用 `source_case` 引用已有输入。
源码行数和节点数由验证目的决定，目录简单不要求输入必须很小。

新增输入字段、场景和目标在对应 case 中声明，并连接实际消费它的测试后再更改 `runner`。
目前不提供统一调度所有 corpus 的命令，不自动安装旧工具链，也不冻结跨仓库交换协议。

## 检查

从仓库根目录执行：

```shell
moon test modules/cli/src/app/corpus_wbtest.mbt modules/cli/src/app/regression_wbtest.mbt --target native
```

`just test` 同样包含这些检查。目录校验会遍历现有清单，检查引用和输入文件，
并拒绝越界路径、重复条目、未知入口及错误的证据标记。结构检查通过只支持材料完整性，
不能代替差分发现、真实缺陷归约或批量验收的执行结果。

日常产物仍保存在忽略的 `runs/`；原始输入和完成的旧记录保持不变。
