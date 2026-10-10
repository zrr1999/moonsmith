# Engine 架构调研

调研日期：2026 年 10 月 10 日。目标是研究 MoonSmith Engine 的编排、判定、归约与重放边界。
本轮读取了当前 workspace、已有设计、官方文档、作者论文和下列固定提交的关键源码。
**没有运行第三方 benchmark、历史编译器复现或 MoonSmith 产品实验。** 源码观察与本项目建议分别列出。

完整生态清单继续维护在[对比项目与基准规划](comparison-projects.md)；本文深入其中与 Engine 直接相关的
机制，并补充 LibAFL、Hypothesis、本机 MoonBit QuickCheck 及归约算法研究。
本文保存来源观察、备选方案与实现候选，为 Engine 的职责和策略边界提供依据。具体算法和参数不构成提案要求，
也不因来源项目采用过某种做法就成为 MoonSmith 的默认实现。

## 1 仓库事实与问题

交付时按 `main` 的 `a6fa34549021ae71c3eb659f0595632aa3ed1865` 重新核查源码。
后续 Core 更名为 Engine，本文同步使用新名称和路径；以下实现观察仍以该原型基线为准。
原型已经包含[判定器](../../../modules/engine/src/oracle.mbt)、[泛型归约器](../../../modules/engine/src/reducer.mbt)
和[应用编排](../../../modules/cli/src/app/campaign.mbt)，并有行为及工具链集成测试；本轮未重新执行产品实验。
早期调研基于 `33f3c8f7f40ca43e9c49ed7a200b0a2bbc5efc4d` 加未提交设计的骨架现场，
该现场已不能代表当前实现。

[FP-0001](../../../fps/FP-0001-workspace-modules.md)与[贡献指南](../../../CONTRIBUTING.md#原型执行契约)
规定 Engine 纯计算、语言适配器拥有程序与语义、Host 拥有进程和文件系统，app 装配。
现有 `judge` 返回遇到的首个明确异常；`Reducer[P]` 以候选列表、严格下降和 fingerprint 相等推进；
完整执行与确认流程位于 app。这些是现有实现事实，不是对未来所有 Oracle 和搜索方法的约束。

后续设计沿用原定模块边界，按各语言具有类似 MoonBit 的能力开展。算法、参数和工程机制
作为可替换的实现选择，具体实现须说明取舍和验证范围。

本轮需要补齐的内容是：

- app 与 Engine 谁决定下一步，跨边界结果怎样关联到正确案例与任务。
- 多种 Oracle 同时工作时，部分失败、缺配置和参考求值失败怎样汇总。
- 原失败判据如何被冻结，参考与变形关系在归约过程中怎样重新计算。
- 种子、逻辑预算、时间预算、取消和重复确认的统计语义。
- 原始案例、执行证据、派生结论及缓存分别由谁拥有，何时可以报告完成。

## 2 参考机制与取舍

| 来源 | 核查到的机制 | 对 MoonSmith 的借鉴建议，待讨论 |
| --- | --- | --- |
| [LibAFL Feedback](https://github.com/AFLplusplus/LibAFL/blob/70259b66bcbdc322b81ee59e71d83f27e0187c35/docs/src/core_concepts/feedback.md)、[StdFuzzer](https://github.com/AFLplusplus/LibAFL/blob/70259b66bcbdc322b81ee59e71d83f27e0187c35/crates/libafl/src/fuzzer/mod.rs) | Observer 提供观察；Feedback 决定样本是否有探索价值；Objective 表达目标命中。`StdFuzzer` 分别持有 scheduler、feedback、objective | 执行证据、异常判定和探索反馈分开。首版只需要前两者，特征共现不能自动成为编译器覆盖率 |
| [Csmith 作者论文](https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf) | 通过约束生成空间排除破坏差分比较的未定义和未指定行为 | 可比较资格是语言 profile 的责任；Engine 只消费检查结果，不补写一份类型系统或整数语义 |
| [YARPGen](https://github.com/intel/yarpgen/blob/1adb290f453505838f3aa33dc571f292b0c1810f/README.md)、[执行脚本](https://github.com/intel/yarpgen/blob/1adb290f453505838f3aa33dc571f292b0c1810f/scripts/run_gen.py) | 生成时控制数值范围；独立脚本驱动编译器和配置、收集输出分组与超时 | 显式执行矩阵和阶段记录有价值。项目选择保留完整规范值；上游 checksum 和多数结果分组不作为本项目正确性证明 |
| [Fuzzilli MinimizationHelper](https://github.com/googleprojectzero/fuzzilli/blob/a9d7aff02d8b8d97c8fd8089aea894d24bc11f1e/Sources/Fuzzilli/Minimization/MinimizationHelper.swift)、[Minimizer](https://github.com/googleprojectzero/fuzzilli/blob/a9d7aff02d8b8d97c8fd8089aea894d24bc11f1e/Sources/Fuzzilli/Minimization/Minimizer.swift) | 先检查候选静态有效性，再执行并检查原 `ProgramAspects`；不同 reducer 按明确顺序运行；生成新的归约副本 | 把合法性、目标行为和候选提交分成三个关口。保留原件，Engine 拥有接受决定，语言层拥有变换 |
| [C-Reduce 驱动](https://github.com/csmith-project/creduce/blob/31e855e290970cba0286e5032971509c0e7c0a80/creduce/creduce.in)、[作者论文](https://users.cs.utah.edu/~regehr/papers/pldi12-preprint.pdf) | 通用搜索调用领域变换与外部 interestingness test；测试需要确定性、独立目录及超时边界；论文专门讨论归约引入无效程序的问题 | 借鉴有序变换与保持判据的搜索，但不用任意非零退出或字符串匹配充当编译器异常契约 |
| [Perses](https://github.com/uw-pluverse/perses/blob/bb7bc6521bebff54729d54eaac22b5b046bede96/README.md) | 根据语法约束候选空间，由测试脚本判定是否保留；支持候选缓存与不同列表归约算法 | 语法有效性和失败保持应分开；MoonBit 首版还需要类型、绑定及 profile 检查。暂不引入语法框架或算法插件体系 |
| [wasm-shrink 实现](https://github.com/bytecodealliance/wasm-tools/blob/3505209492e7ded0b4fc1580beb35cf655868bfc/crates/wasm-shrink/src/lib.rs) | 先验证原输入和判据，使用显式 seed、尝试限额和去重集合；搜索点 `current` 与最小已知结果 `best` 分开，允许部分非缩小移动 | 搜索方法、接受规则和最佳结果可以分离。严格下降与非单调探索是不同实现取舍，需要分别声明预算和停止保证 |
| [MoonGrammata Oracle](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/oracle.mbt)、[归约](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/reduce.mbt)、[重放](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/replay.mbt) | target 回调产生 disposition、特征及可选 digest；归约比较 FailureFingerprint；版本化 ReplayRecord 保存原字节 | 提供这些抽象的 MoonBit 源码实例。MoonSmith 需要更细的配置分区、阶段及关系判据，不能把 fingerprint 相等直接当作接受条件 |
| [Hypothesis flaky 指南](https://hypothesis.readthedocs.io/en/latest/tutorial/flaky.html)、[重放指南](https://hypothesis.readthedocs.io/en/latest/tutorial/replaying-failures.html) | 区分结果不稳定和生成过程不稳定；内部失败数据库及 replay blob 可能随版本失效 | 明确输入可重建、判据可重现与固定回归三种不同承诺。确认运行不能靠缓存，长期案例保存实际输入与环境 |
| [EMI 项目及原论文入口](https://web.cs.ucdavis.edu/~su/emi-project/) | 等价关系相对于指定输入成立，并非所有输入上的完全等价 | 变形 Oracle 必须携带关系与适用前提；具体变换需要单独验证，不因引用 EMI 就引入动态覆盖机制 |

这些是职责与算法机制的比较，不是效果排名。源码层、FuzzIL、Wasm 和通用结构输入的合法性条件不同；
上游的检测数、缩减率与吞吐量没有迁移成 MoonSmith 的验收数字。

## 3 源码核查带来的具体修正

### 失败类别仍然不够精确

本机标准库的 QuickCheck `driver.mbt` 在收缩时区分 `Falsified` 与 `Raised`，但所有 `Raised` 彼此匹配。
它适合通用性质测试，不能据此保持某个编译阶段、特定配置集合或观察分区。
MoonSmith 应复用其性质测试能力，而把 `FailurePredicate` 的冻结与匹配留在 Engine。

MoonGrammata 的归约入口直接调用 `Target` 并比较 fingerprint；这与其通用字节目标一致。
MoonSmith 的进程、解释器和多配置观察有独立所有者，因此可比较显式任务往返与注入回调的成本，
不能仅因参考项目存在类似入口，就直接决定采用它或排除它。

### 预算的计数单位必须写出来

本机 QuickCheck 对每个检查过的收缩候选计数，包括过滤掉的候选。wasm-shrink 的尝试额度则与其搜索轮次、
变异枚举及最佳结果更新相关。两个名为 attempts 的数字不能直接比较。
候选方案建议分别记录生成尝试、候选检查、实际进程启动、配置执行和确认轮次，并使用不重置的会话总限额。

### 归约零进展是有效结果

MoonGrammata 在没有接受任何归约步骤时返回 `NoReductionPossible`。候选方案建议返回原案例作为
`best_reproducer`，同时记录当前策略已穷尽或预算耗尽。原案例已经很小时，这仍是可交付的诊断证据。

### 参考项目不是直接依赖

wasm-shrink 固定提交的 README 库示例仍把通知回调写成 `run` 参数，而同提交源码采用
`on_new_smallest` 配置及单一 predicate 参数。本轮以源码核对机制，不把示例签名复制为 API。
Engine 无需引入 LibAFL、Fuzzilli、Perses 或其他运行时；本轮也没有修改依赖。

## 4 三种 Engine 组织方式

| 方案 | 收益 | 需要评估的代价 | 与当前设计方向的关系 |
| --- | --- | --- | --- |
| Engine 通过注入的 Language、Runner、Store 能力推进流程 | 调用链直接；实现可替换；编排仍集中在库内 | 需要明确异步、取消和保存失败的传播，以及副作用与纯计算边界 | 具体能力调用可由装配层承担，Engine 不直接依赖 Host 或 Store |
| Engine 提供纯算法函数，流程写在 app | Engine 简单；可单独组合算法；应用可选择不同流程 | 确认、预算和归约状态可能分散，需明确哪些流程是库契约 | 独立算法可以复用，但不把 Engine 拥有的流程决定转移给 app |
| Engine 用显式状态推进并返回任务，app 执行与回传 | 决策集中；可用脚本化证据驱动；执行方式可以替换 | 增加任务/结果协议、关联校验和跨边界数据传递 | 符合编排与执行分离；具体协议与任务粒度仍属于实现选择 |

三种组织方式需要围绕 Engine 拥有编排、app 执行与回传的责任划分评估；任务枚举、会话编码、
在途数量或持久化顺序属于实现选择。源码比较不能单独证明某种接口最优。

## 5 版本与证据边界

GitHub 源码链接固定到本轮读取的提交，已读取关键文件内容；Csmith、EMI 使用作者论文或
项目页；Hypothesis 使用当日在线文档。未执行其测试，不能据此确认它们在当前本机可安装或具有某种性能。

本地 MoonBit 核查环境为 macOS arm64，`moon 0.1.20260920 (914d7da)`；安装目录的标准库 manifest
声明 `0.10.14+7d59c7ec9`。为避免把版本字符串当作源码一致性证明，记录实际读取文件的 SHA-256：

| 本机标准库文件（相对 `~/.moon/lib/core/`） | SHA-256 |
| --- | --- |
| `quickcheck/driver.mbt` | `106ab999cc30fdd0146f718db1c9ef875ff84ce4746a6009051854531551181b` |
| `quickcheck/splitmix/random.mbt` | `d64b24188092812aac9dbbd5d2659b99e8e20691642eb7c6c0de9bc0ef71b026` |

`splitmix` 的当前公开接口提供显式 seed 的构造、`next_uint64`、`clone` 和 `split`；调用不带 limit 的
`next_uint64` 避免将有界采样的拒绝次数混入案例编号分配。这是调度实现的候选依据，
固定版本下的向量及不同构建后端的一致性仍需验证。现有[生成器](../../../modules/moonbit/src/generate.mbt)
使用 ChaCha8；这里的可行性核查不要求替换它，也不是种子派生协议或跨版本生成相同程序的承诺。

本轮设计由 AI 辅助调研与起草。文档门禁只能验证结构、链接和仓库约束；编排、缓存隔离、
进程清理及判据保持的行为证据，须通过相应行为测试和真实工具链实验取得。

## 6 实现候选与评估方法

### 归约策略的补充调研

后续讨论将重点从选择某个归约算法转为设计可替换的策略边界。以下结论来自论文与关键源码，
不是 MoonSmith 上的效果排名。

| 路线与来源 | 机制及限制 | 对抽象边界的启示 |
| --- | --- | --- |
| [HDD](https://www.cs.ucdavis.edu/~su/publications/icse06-hdd.pdf) | 按结构层次应用集合缩减，借助输入相关的构造逻辑产生候选 | 搜索需要操作范围与可选择元素，合法性由领域层负责 |
| [Perses 列表接口](https://github.com/uw-pluverse/perses/blob/bb7bc6521bebff54729d54eaac22b5b046bede96/src/org/perses/listminimizer/ListMinimizerArguments.kt) | 列表算法获得元素、性质检查、进展回调及权重等信息 | 局部搜索可以独立于外层程序归约；具体 API 不必照搬 |
| [ProbDD](https://xiongyingfei.github.io/papers/FSE21a.pdf)、[CDD](https://cs.uwaterloo.ca/~cnsun/public/publication/icse25_cdd/icse25_cdd.pdf) | 利用历史反馈安排删除尝试；CDD 简化概率机制，减少重访也可能失去 1-minimality 保证 | 策略需要自身状态与反馈，停止保证要独立表达，不能由接口统一许诺最小性 |
| [WDD](https://arxiv.org/html/2411.19410v1)、[实现](https://github.com/uw-pluverse/perses/blob/bb7bc6521bebff54729d54eaac22b5b046bede96/src/org/perses/listminimizer/WeightedDeltaDebugger.kt) | 按元素权重而非仅按数量组织分组 | 度量信息可以按策略需求提供，不应被某一种分组算法固定 |
| [Fuzzilli 调度](https://github.com/googleprojectzero/fuzzilli/blob/a9d7aff02d8b8d97c8fd8089aea894d24bc11f1e/Sources/Fuzzilli/Minimization/Minimizer.swift)、[Hypothesis 内部说明](https://github.com/HypothesisWorks/hypothesis/blob/1484f6dd4c0a220f68e2698afed29e2a16a3f654/guides/internals.rst) | 多个 pass 组合运行；前一改写会改变后一操作的机会，调度还可区分成本 | 操作调度与局部搜索是两个独立替换点，候选上下文和反馈不能丢失 |
| [GReduce](https://arxiv.org/html/2402.04623v1) | 缩减生成器执行轨迹，再通过对齐执行构造输入 | 候选表示并不只有 AST；参考机制不意味着本项目需要实现轨迹归约 |
| [C-Reduce](https://users.cs.utah.edu/~regehr/papers/pldi12-preprint.pdf)、[Vulcan](https://researchmgt.monash.edu/ws/portalfiles/portal/716513714/716367322-oa.pdf) | 一些改写不立即减小程序，却可能开启后续缩减机会 | 搜索状态与最佳结果、搜索方法与接受规则需要区分；非单调探索须有单独的约束 |

这些方法共同支持语言操作、操作调度、局部搜索和公共引擎的责任划分。某个算法需要的权重、
游标或概率状态不应成为所有策略都必须携带的字段。实现抽象是否有效，应通过替换真实策略验证。

### 前期讨论过的实现起点

以下保留前期讨论的实现候选，便于后续实验承接。用户随后要求提案只约定大方向，
因此这些内容不构成 FP、架构的强制要求或必须交付的算法清单，也不能替代后续实现范围讨论。

| 主题 | 已讨论的候选 | 后续评估重点 |
| --- | --- | --- |
| 搜索算法 | 逐项枚举基线与 ddmin，后续评估 CDD、WDD | 接口能否替换、有效候选比例、验证成本与最终规模 |
| 操作调度 | 从粗到细运行各 pass，有进展后再循环 | 重访成本、不同操作之间的机会变化 |
| 接受规则 | 首个实现使用严格下降 | 终止容易验证；是否需要额外探索另行评估 |
| 确认策略 | 原案例与最终结果各额外执行 3 次，次数可配置 | 不同失败类型的稳定性证据与执行成本 |
| 执行与恢复 | 先顺序执行，保存案例后支持重放和重新归约 | 吞吐及恢复需求，不预先承担内部搜索状态兼容 |
| 随机与重放 | 固定版本内保证 seed 复现，长期重放保留源码 | 版本和输入证据是否足以复现，不承诺跨版本生成相同程序 |

同条件评估固定案例、失败判据、语言操作、环境和预算；分别报告候选合法率、保持判据的比例、
实际工具链执行数、耗时、结果规模及停止原因。改变一个搜索因素时，保持其余条件可比较。
合成案例用于验证契约与算法行为，真实 MoonBit 案例用于证明产品效果，两类结果分开呈现。
