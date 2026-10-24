# Native release 构建异常分析交接

更新时间：2026-10-22。此文件是内部交接材料，不是正式设计或验收记录。

> 交接已完成：402 / 317 字节结果已补独立确认，422 字节已有确认已核对。
> 当前结论见[正式分析](../../../docs/native-release-analysis.md)，后续选择与交付状态见
> [归约补齐方案](../research/native-release-reduction-plan.md)。用户随后已授权删除遗留
> `.cargo/` 和通过 PR 交付。本文件下文保留交接时的快照，旧待办、目录状态及授权边界
> 不代表当前状态；无需再次执行已完成的实验。

## 新会话先做什么

继续完成三例 native release 构建异常的分析交付。先核对下文两项尚缺的独立确认，
再整理正式分析记录和归约能力补齐顺序。不要重跑 10,000 个样本，也不要从头进行算法调研。

用户要求：分析三例是否属于同一问题、尽量缩成小复现、检查归约流程缺少的能力。
用户随后要求由小模型执行具体、有界任务，主会话负责规划和证据审查；最后要求写此 handoff，
将剩余工作交给新会话。当前工作不包含上游问题发布、工具链升级、合并或发布。

## 工作区与交付边界

- 工作区：`/Users/zhanrongrui/.codex/worktrees/4031/moonsmith`。
- 当前分支：`codex/monthly-validation-report`。
- 当前 HEAD：`b077513396101e7f47c1ca02aca29cd6d8418635`。
- 创建此交接前，Git 状态仅有无关的未跟踪 `.cargo/`；不要读取、暂存、删除或修改它。
- 本轮实验都在忽略的 `runs/native-release-investigation/`，没有修改产品代码、FP 或正式文档。
- 主检出 `/Users/zhanrongrui/workspace/zrr1999/moonsmith` 有其他工作，禁止切换过去修改。
- 当前 PR 是 #37；此前已有依赖 stack：#30 → #31 → #33 → #34 → #35 → #36 → #37，stack #32。
  先前已 Ready 且 CI 通过，尚未合并；这是历史核对结果，新会话没有重新查询远端前不要当作当前状态。
- 当前先完成分析和可审阅材料；如需继续远端交付，读取当前用户授权、Git 状态和现有 PR，
  按仓库规范处理，不能据此自行合并或发布。

遵守根目录 `AGENTS.md`。项目 skills 已存在于 `.agents/skills/`；按实际任务加载，
不必每次恢复重读所有文件。`evolution` 已确认可用，本轮没有方向变化，不需要演进条目。

## 已完成的规模实验

正式实验源码提交：`f87e8526f90d8e0f5ab71116cf42e00738c577a8`。
完整记录见 `docs/acceptance-validation.md`；这里只保留调查所需索引。

- 10,000 个计划样本全部通过内部检查和 native debug 基线编译。
- 种子 0–999 完成五配置；其余种子执行 native debug、native release、wasm-gc debug。
- 9,997 例完整比较且一致；以下三例为 `Incomplete`，native release build exit 255。
- 三例原始输入均为 128 节点、深度 6，并已在原案例下独立重放原始源码。
- 原例、样本与任务汇总保持不变。新实验不可替换或改写这些计数。

原始案例公共前缀：

```text
runs/acceptance-v2/basic/task-dc245225710075883372acc017712d63/cases/
```

| 种子 | 案例目录 | 原始尝试 | 两个成功配置的输出 |
| --- | --- | --- | --- |
| 1272 | `case-11d1541114ab38fdb20fc600cbc45401` | `run-e6fa67b50af06216b58f2d5147028f5e` | `-7` + LF |
| 3745 | `case-2c29a891ffe9046d552d798f4098b697` | `run-fbccbd55212f15fb11e7f31004558397` | `2147483646` + LF |
| 6968 | `case-ce5ac435b71e64da70c0ad59faa727b7` | `run-95272bea9b2958ebfe58a1649a154b7a` | `true` + LF |

原始生成 C 位于各 `attempts/<原始尝试>/_build/native/release/build/generated.c`。
未声明的变量依次为 `_M0L6constrS87`、`_M0L6constrS88`、`_M0L6constrS8`。
源位置映射可能指向 core/abort，不能据此把故障归因于 abort 库。

工具链：Darwin 27.0.0 arm64；Apple clang 21.0.0；Moon/moonrun `0.1.20260920`（`914d7da`）；
moonc/core `0.10.14+7d59c7ec9`。版本探测原始记录在 `runs/acceptance-v2/launcher.json`。
已安装实验 CLI 位于 `runs/acceptance-v2/bin/moonsmith`。

## 已完成的结构化候选实验

调查目录下 `helper/` 是一次性 MoonBit 包，调用现有生成器和 `CompleteProgram.candidates()`，
按保存的候选索引路径重建程序、导出源码、成本与每个候选自己的参考值。
`reduce.py` 在隔离工程中编译候选；它不是产品 CLI 的构建失败归约实现，也没有调用
`Reducer`/`ReductionSession`。因此不能将本轮结果写成产品自动归约已经支持构建失败。

| 种子 | 语言模型节点数 | 原始 → 缩减源码字节 | 已尝试 / 接受 |
| --- | --- | --- | --- |
| 1272 | 128 → 52 | 1273 → 522 | 236 / 13 |
| 3745 | 128 → 42 | 1311 → 429 | 297 / 15 |
| 6968 | 128 → 51 | 1282 → 494 | 337 / 14 |

每例保存于 `seed-<种子>/`：`original.json`、`accepted.jsonl`、`result.json`、
`reduced.mbt` 和逐候选 `trial-*/`。三例停止原因都是本次候选枚举耗尽；不是全局最小。
调查脚本的上限为每例 2,000 次提交，并非产品默认的 16 次或公开参数范围。

本次实验的目标判据为：release build exit 255，且全部 `error:` 行都匹配
`use of undeclared identifier '_M…constrS…'`；随后 native debug 和 wasm-gc debug 都必须
构建及执行成功，stdout 等于该候选自己的参考结果。不能仅凭 exit 255 接受候选。
主会话已经逐条审计 42 个接受候选的源码、release 诊断和两组对照，未发现缺项，结果位于
`accepted-audit-v1.json`。诊断模式持续相同仍不证明唯一根因。

## 小模型调查结果与可靠性核对

三项任务均已结束，恢复时不依赖旧会话的代理或终端 ID。所有路径以下述调查目录为前缀：

```text
/Users/zhanrongrui/.codex/worktrees/4031/moonsmith/runs/native-release-investigation/
```

### 1272

权威汇总：`agent-1272/result-v2.json`；旧 `result.json` 保留但其父子链有错误，不能引用为证据。

真实接受路径：

```text
seed-1272/reduced.mbt                                      522 bytes
  → derive-1272-03-enter-payload-arm/main.mbt               432 bytes
  → agent-1272/trial-31-derived-bool-literal/main.mbt        428 bytes
  → agent-1272/trial-32-derived-if-negation/main.mbt         402 bytes
```

每一步已有新的 release 目标诊断及 debug/wasm-gc 输出 `0` + LF 的证据。
**402 字节最终源码尚未额外独立复跑一次，新会话应补齐。**

`derive-1272-01`、`02`、`03` 是由 522 字节输入产生的平行变换。
其中 `02-drop-outer-condition` release 成功，是未保持目标的对照，不能串进接受链。

另有 208 字节手工概括复现，位于 `agent-1272/final-independent-confirmation/main.mbt`，
已独立确认并通过两组对照。它与上述原例缩减链分开报告，不能宣称原例已经逐步缩至该文本。
该代理先评估 30 个手工概括候选，后补 5 个原例窄变换；没有全局最小性保证。

### 3745

先读 `agent-3745-6968/result.json`，再读同目录 `result-v2.json` 中两项追加实验。

真实接受路径：429 字节结构化结果 → `derive-3745-01-drop-tuple`（376）→
`seed-3745/trial-02-drop-unused-parameter` → `trial-03-drop-unused-enum-case`（330）→
`trial-06-remove-last-unused-parameter`（317），最后三个目录均在 `agent-3745-6968/` 下。

317 字节候选已有 release 目标诊断及两组成功对照；**尚未额外独立复跑一次**。
330 字节版本的独立确认在 `confirm-3745/`，不能冒充 317 字节的确认。

补充对照 `trial-07-replace-inner-match-with-zero-corrected` 为合法的 255 字节源码，
release 成功，输出仍为 `0` + LF；说明这个替换失去目标。
早先 `trial-05` 有拼接笔误导致类型错误，只能算被拒的非目标错误。

### 6968

结果在 `agent-3745-6968/result.json`。
路径为 494 字节结构化结果 → `derive-6968-01-drop-second-bool`（452）→
`agent-3745-6968/seed-6968/trial-02-combine-bool-and-wrapper-correct-expected` →
`trial-04-simplify-true-condition`（422）。

422 字节源码已在 `agent-3745-6968/confirm-6968/` 独立确认，release 保持目标，
debug/wasm-gc 均输出 `0` + LF。
去掉结果包装后预期从 `false` + LF 变为 `0` + LF；代理初次用错预期，
随后在新目录纠正并重新执行。应读取修正后的 trial-02，不覆盖或采用错误预期记录。

所有手工源码都没有重新导入 `CompleteProgram`；字节数是 UTF-8 字节，不能编造 AST 节点数。
这里有界的人工缩减与额外确认不能计作产品功能或算法性能比较结果。

## 小复现与编译阶段对照

更早的独立小程序 `manual-002/main.mbt` 只有 189 个 UTF-8 字节，6 行；它比上述 208 字节
同模式复现更短，但同样不是三例都逐步归约到此文本的证明。完整源码：

```moonbit
enum E { A; B(Int) }
fn f(b : Bool) -> Int {
 if (if b { false } else { let t = false; false }) { 0 } else { let e = E::B(0)
 match e { A => 0; B(x) => x } }
}
fn main { println(f(true)) }
```

它在 release 构建产生未声明构造器变量错误，debug/wasm-gc 输出 `0` + LF。
两个成功对照：去掉条件中的局部绑定（`manual-001`）；将字段读取换成常量（`manual-003`）。
两者都在新的隔离工程中 release 编译、执行成功并输出 `0` + LF。

编译阶段的权威汇总是 `agent-stage/result-v2.json`，原始命令和输出在
`agent-stage/pass3/logs/`，相关 C 片段为 `agent-stage/release-c-snippet.txt`。

| 对照 | 实测结果 | 可以得出的结论 |
| --- | --- | --- |
| 原始 release 流水线 | `moon build` exit 255 | 小程序复现原诊断模式 |
| 同一份 release C 改用 `cc -O0` | exit 1，仍为原来的两个未声明变量错误 | 输入 C 已不合法，降低 C 优化不能消除此问题 |
| 同一份 release core 用 `moonc link-core -O0`，再编译 C | link 0；C 编译 1，仍为原诊断 | 仅关闭此阶段优化不能消除问题，不能据此定位具体 pass |
| `build-package -O0` 与 `link-core -O0` 同时使用 | 生成 C，但 C 编译报重复标签 `join_84` | 这是另一诊断，不能作为原失败保持证据 |
| `build-package -O0` 后按默认链接 | link exit 1，无诊断且未生成 C | 原因未明的无效/不确定对照，不用于因果推断 |

不得写成“关闭 MoonBit 优化后通过”，也不得将 `join_84` 当作原故障相同根因的证明。
目前支持的结论是三例具有同一类故障表征、存在相关小复现；是否同一唯一根因、具体编译器
pass、是否已被上游修复均未确定。调查没有联网查询上游源码、问题或新版本。

## 剩余步骤与完成标准

1. **补齐并审查证据。** 对 402 字节（1272）和 317 字节（3745）源码各复制到新目录，
   重新执行 release 和两组成功对照；可以让小模型分别做。对 422 字节已有确认只需核对原始
   JSON 和源码 SHA，不必无故重复。检查父子关系、实际源码、预期与退出码，不能只信代理汇总。
2. **形成正式分析记录。** 建议新建 `docs/native-release-analysis.md`，更新
   `docs/acceptance-validation.md` 中三例调查的链接与结论。明确结构化候选实验、手工缩减、
   同模式小复现、阶段对照各自的证据范围。正式文档不得引用本 handoff 或 `.agents/`。
   原始 `runs/` 材料可用文字路径和哈希索引，发布文档中保留能单独复制的源码与复现步骤。
3. **给出归约能力补齐方案。** 按下节职责和优先级形成可执行切片；未决公共语义继续明确标注，
   不在本轮分析中直接实现新 API 或修改退出码。现有设计已涵盖的实现不需要新增 FP。
4. **按改动完成检查并交付。** 若只有 Markdown，按贡献指南执行相应 Prek 检查，
   包含新增文件；不为文档制造产品测试。实现变更才需要相关行为测试、`just test/build/check`。
   仅本地文件已改不等于已提交、已推送或 PR 已更新，报告实际终点。

本交接创建时，以上正式分析文档尚未写入；现有 129 项测试及此前 PR 的绿色结果
来自前一轮实现，不能冒充本轮新改动的检查。不要声称产品已支持构建失败归约。

## 后续实施建议：范围已经调查，具体公共表达尚未决定

| 优先级 | 缺口 | 归属与验收重点 |
| --- | --- | --- |
| 1 | 构建失败没有进入产品归约 | `modules/cli/src/app/reduction.mbt` 只在 `Difference(first, second)` 时启动；保留原始 `Incomplete` 与构建证据，明确目标如何选择 |
| 1 | 相同退出码不足以辨认目标 | 工具链/预言机层提供明确诊断身份，冻结配置、阶段、目标特征和匹配版本；不同 C 错误、语法/类型拒绝、Host 错误、超时和缺证据不能替代目标 |
| 1 | 摘要只表达两配置输出分歧 | `modules/contracts/src/reduction.mbt` 的 `DifferentialReduction` 格式 3 固定 first/second configuration；需要核对目标表达、确认和旧源码重放的关系，不能静默改格式 |
| 2 | 缺少本例需要的协同候选 | 语言适配器负责删除未用形参与同步调用、删除枚举分支/字段与同步模式、保留作用域的替换/简化；每步完整检查，观察真实失败保持 |
| 2 | 调查材料不够直接 | Host/工具链记录实际子阶段命令、C 编译器版本及必要中间产物，关联候选和独立确认；当前生成 C 只是 `_build` 中的附带材料 |
| 3 | 源码重放不等于恢复结构化搜索 | 重建 AST 当前依赖种子、生成器和快照核对；不要在没有导入能力时把任意保存源码当作完整程序模型 |

`ReductionSession` 已有 caller-provided predicate、original/current/best、整体预算与过期响应约束，
可以继续复用；Engine 不应理解 MoonBit AST 或 Clang 文本。`Reducer::new` 的现有便利入口
用 `match_failure` 比较 Assessment 的 oracle/configuration/phase/kind；仅使用 `Exit(255)`
不够严格。选择如何表达诊断身份时要比较已有 Oracle/Assessment 扩展与调用方判据连接，
不能临时把具体构造器变量编号写成永久公共规则。

`fps/FP-0004-engine-execution-contract.md` 已要求新证据保持同一观察条件，明确不保证同根因。
若实现涉及任务退出码或公开持久化兼容语义，先按规划 skill 研究并询问未决关键选择，
在所属 FP 中修订；不因为跨包或接口新增就另建 Engine v2 FP。

本轮不安排 ddmin、缓存、并行搜索、通用诊断协议或完整计量协议。
算法孵化、比较与可视化归 Spore Lab 仓库；本仓库保留产品行为和真实工具链验收。

## 恢复工作的方式

用户明确要求主会话规划，小模型执行具体事情；代理 brief 应包含一个小目标、准确输入路径、
独占输出目录、验证条件和停止上限。新会话可选可用的小模型，不应继承整段冗长历史给每个代理。
主会话必须审查原始证据；本轮已纠正过父子路径、预期值和“不同诊断算同故障”等问题。

优先读各 `result-v2.json` 和选定原始日志，相关代码按需定位。不要每次重读全套 README、
skills 或整份生成 C，也不要反复重跑通过的实验。继续采用固定输入、明确预期、实际结果、
单个对照的描述方式，完整诊断保留文件，终端输出只呈现需要审查的片段。

旧会话曾出现平台 `cyber_policy` 终止，其中有两次尚未调用工具，与本地构建命令失败不同；
具体审核触发内容未知。这不是仓库代码安全问题的证据，也不是调整或绕过本地检查的理由。
若再遇平台终止，保留客户端记录并如实报告；不能推断为某个词或某条命令必然触发。

给新会话的起始指令：

> 请读取 `.agents/notes/handoffs/2026-10-22-native-release-analysis.md`，在文件指定的
> owning worktree 中继续“剩余步骤与完成标准”。由小模型执行有界的具体任务，你负责规划、
> 审查原始证据和汇总。先补两项独立确认，再完成正式分析与实施切片；不要重跑规模实验，
> 不改工具链，不把同类诊断说成已确定的唯一根因。
