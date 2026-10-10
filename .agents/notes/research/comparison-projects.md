# 对比项目与基准规划

整理日期：2026 年 10 月 9 日。将编译器测试、程序生成、归约及相关基础设施项目纳入对比清单，
为[项目申报书](../../../docs/project-proposal.md)中的生成、判定与归约目标提供参考。

2026 年 10 月 10 日补充的[Core 专题调研](core-research.md)对关键执行、判定、归约与重放路径
核查了固定提交源码，进一步比较 Core 的职责与策略边界。
具体算法和参数作为研究及实现候选保留，不由提案固定；仍未运行跨工具 benchmark。

对比范围仅包含外部项目。`Yingqingxue/moonsmith` 属于本项目范围，
不列为竞品或外部基准；后续检索也应排除此项。

**当前证据为维护者文档、项目元数据和论文核查，尚未在本机运行这些项目的 benchmark。**
表中能力是来源描述，借鉴点和实验安排是 MoonSmith 的建议。研究原型、归档项目及不同
测试层次分别记录，不以星数、更新时间或上游缺陷总数作统一排名。

## 1 MoonBit 同生态项目

| 项目 | 来源描述与定位 | 比较和借鉴重点 |
| --- | --- | --- |
| [MoonGrammata](https://github.com/erzhuzi259/MoonGrammata) | 结构化输入生成、树变异、反馈驱动样本库、失败指纹和重放 | 确定性契约、预算、失败判据和证据；适配同一任务后才比较检测效果 |
| [moonfuzz](https://github.com/yesuifengliu01/moonfuzz) | 项目自述为纯 MoonBit 覆盖引导 fuzzing 框架；README 当前只有标题 | 保留为字节变异与通用 fuzzing 的对比候选；具体能力继续核查源码和运行结果 |

## 2 语言专用的程序生成与语义测试

| 项目 | 测试对象与方法 | 借鉴或比较重点 |
| --- | --- | --- |
| [Csmith](https://github.com/csmith-project/csmith) | 随机 C 程序与编译器差分 | 有效完整程序、语言约束、可观察结果和跨编译器比较 |
| [YARPGen](https://github.com/intel/yarpgen) | 面向优化器的 C/C++ 程序生成 | 定向生成策略、配置矩阵与优化相关特征组合 |
| [RustSmith](https://github.com/rustsmith/rustsmith) | Rust 源程序随机生成与编译器测试 | Rust 阶段的源码生成有效性、语言特征和所有权相关约束 |
| [Rustlantis](https://github.com/cbeuw/rustlantis) | 确定性、避免未定义行为的 Rust MIR 生成与差分 | 内存模型约束、后端比较、种子重放和复现案例；明确标注 MIR 层次 |
| [CLsmith](https://github.com/ChrisLidbury/CLSmith) | Csmith 衍生的 OpenCL C 程序生成 | 适配专门语言及执行模型时需要增加哪些约束 |
| [Solsmith](https://arxiv.org/abs/2506.03909) | Solidity 程序生成与编译器测试，本轮以原论文核查 | 语言专用语义约束、配置差分和有效程序构造 |
| [jubnzv/moonsmith](https://github.com/jubnzv/moonsmith) | Lua 随机程序生成，README 声明支持 Lua 5.1 与 5.3 | 终止约束、全程序输出；引用时注明 Lua，避免同名混淆 |

RustSmith 与 Rustlantis 分别承担源码层和 MIR/后端层的参照作用。Rustlantis 的输入
不能直接证明 Rust 源码类型检查或借用检查的覆盖。不同语义子集下的生成速度与通过率
也不能直接比较高低。

## 3 跨语言生成与类型检查

| 项目 | 方法 | 对架构的参考意义 |
| --- | --- | --- |
| [Xsmith](https://docs.racket-lang.org/xsmith/index.html) | 用 DSL 描述语法、类型规则和生成策略 | 比较语言规则的表达成本、生成决策及约束组织 |
| [Hephaestus](https://github.com/hephaestus-compiler-project/hephaestus) | 高层 IR、语言翻译器、程序生成和类型相关变换 | 对比共享 IR 与各语言自有表示；记录共同及语言专有特征 |
| [Thalia](https://github.com/hephaestus-compiler-project/thalia) | 从真实库 API 合成类型密集程序 | API 图、类型实例构造和 API 组合测试；独立仓库已归档，保留方法与复现实验价值 |
| [Eris](https://github.com/hephaestus-compiler-project/eris) | 从合法种子枚举注入单一类型错误的程序 | 后续类型负例测试：预期拒绝与运行时语义比较使用不同判据 |

Thalia 和 Eris 均说明了与 Hephaestus 的衍生关系，不能当作三个完全独立的实现重复
计算方法数量。Eris 的重点是错误程序是否被错误接受；其思路留作后续独立 profile，
当前原型仍以受限子集的合法程序为输入。

## 4 中间表示、多后端与专项测试

| 项目 | 方法 | 借鉴或比较重点 |
| --- | --- | --- |
| [Fuzzilli](https://github.com/googleprojectzero/fuzzilli) | 基于 FuzzIL 的生成、变异及 JavaScript 输出 | IR 如何服务于有效变换，输出器与执行引擎如何分离 |
| [wasm-tools](https://github.com/bytecodealliance/wasm-tools) | `wasm-smith` 生成、`wasm-mutate` 变异、`wasm-shrink` 归约、`wasmparser` 验证 | 各能力的组合接口，以及源程序比较与生成产物验证的分离 |
| [NNSmith](https://github.com/ise-uiuc/nnsmith) | DNN 图生成及框架/编译器测试 | 语义对象、后端适配及数值比较规则；不直接迁移数值容差到整数程序 |
| [MLIRSmith](https://github.com/Colloportus0/MLIRSmith) | 随机 MLIR 程序生成 | IR 合法性、dialect 和编译管线覆盖，与前端测试分别评估 |
| [Go signature-fuzzer](https://github.com/golang/tools/tree/master/cmd/signature-fuzzer) | 生成 Caller/Checker 函数对，检查参数与返回值传递 | ABI、函数签名等专项生成器对特定行为的验证 |
| [jsfunfuzz / funfuzz](https://github.com/MozillaSecurity/funfuzz) | JavaScript 引擎测试，含 SpiderMonkey 不同 JIT 配置的输出比较 | 配置差分、进程管理及失败案例处理 |
| [lafleur](https://github.com/devdanzin/lafleur) | 利用 CPython JIT 反馈的演化式 fuzzing | 专项变异、运行反馈与样本选择；JIT 覆盖与语言语义特征覆盖分开统计 |

MLIRSmith 此处固定指向 `Colloportus0/MLIRSmith`，避免与相近名称研究混淆。wasm-tools
的四个组件分别保留比较位置，Wasm 校验通过不等于 MoonBit 源程序被正确编译。

## 5 语法、约束与结构化变异

| 项目 | 方法 | 借鉴或比较重点 |
| --- | --- | --- |
| [Grammarinator](https://github.com/renatahodovan/grammarinator) | ANTLR 语法驱动的输入生成 | 语法生成、复合结构和扩展规则；另行衡量语义合法性 |
| [Nautilus](https://github.com/nautilus-fuzz/nautilus) | 语法结构与覆盖反馈结合 | 结构化变异、样本利用和生成预算 |
| [ISLa](https://github.com/rindPHI/isla) | 上下文无关语法与声明式约束求解 | 声明式约束与手写检查器的表达成本及求解成本 |
| [Superion](https://github.com/zhunki/Superion) | 在 AFL 上增加 AST 子树变异 | 子树变换、语法保持，以及仍需检查的类型和绑定条件 |

适配同一目标后，这些项目可以作为生成策略基线。能生成合法语法、能表达某类约束和
覆盖完整语言语义是不同能力，分别列出证据。

## 6 归约、变形测试与公共基础设施

| 项目或方法 | 角色 | 比较方式 |
| --- | --- | --- |
| [C-Reduce](https://github.com/csmith-project/creduce) | 外部判据指导的归约，主要面向 C/C++ | 搜索策略、判据调用和停止条件；迁移到 MoonBit 前验证变换支持 |
| [Perses](https://github.com/uw-pluverse/perses) | 语法引导、语言无关的归约 | 接入对应语法和同一判据后比较成本与结果；不能假定已经支持 MoonBit |
| [QuickCheck](https://hackage.haskell.org/package/QuickCheck) | 性质测试中的随机生成与收缩 | 生成器/收缩器接口；编译器用例还需保持自己的失败判据 |
| [Hypothesis](https://hypothesis.readthedocs.io/en/latest/tutorial/flaky.html) | 性质测试、收缩、失败重放及不稳定性诊断 | 明确生成和结果的不稳定性；内部 replay blob 不作为长期源码归档格式 |
| [LibAFL](https://aflplus.plus/libafl-book/core_concepts/feedback.html) | 可组合的 executor、observer、feedback、objective 与调度 | 执行证据、探索价值和异常目标分开；不提前迁移整个通用 fuzzing 框架 |
| [EMI / Orion / Athena / Hermes](https://web.cs.ucdavis.edu/~su/emi-project/) | 在给定输入下保持行为的变换式编译器测试 | 变形关系、变换前提和观察协议；输入限定下的等价不是全输入等价 |
| [AFL](https://github.com/google/AFL) | 覆盖引导 fuzzing；本轮核查的原仓库已归档 | 样本调度、反馈与低层变异的方法参照，实施前再选具体版本 |
| [libFuzzer](https://llvm.org/docs/LibFuzzer.html) | 进程内覆盖引导 fuzzing 引擎 | 目标接入、执行预算和崩溃样本管理 |
| [OSS-Fuzz](https://github.com/google/oss-fuzz) | 持续 fuzzing 基础设施 | 长期回归、运行环境与报告流程，不作为生成算法的直接基线 |

EMI 家族中的 Hermes 另见[作者论文](https://www.vuminhle.com/pdf/oopsla16.pdf)。保留各
实现名称，实际实验时按能够复现的具体 artifact 和版本登记。

## 7 实验分组与共同记录

所有项目都进入参考范围，只有满足相同任务和输入条件的工具才进行量化排名：

| 实验组 | 进入条件 | 主要指标 |
| --- | --- | --- |
| MoonBit 工具闭环 | 同一工具链和矩阵，明确支持子集及适配工作 | 合法生成率、矩阵完成率、历史案例检测、重复复现率 |
| 生成策略 | 相同语言、相近规模与约束，固定预算及独立种子集 | 有效程序/秒、语义特征组合、失败类别与去重后案例 |
| 归约策略 | 相同原始程序、失败判据和预算；双方能处理该表示 | 最终规模、判据调用次数、耗时、失败保持及停止原因 |
| 类型分析 | 明确预期接受/拒绝及错误注入规则 | 错误接受、错误拒绝、诊断与崩溃，不混入运行差分 |
| 跨语言架构 | 第二语言适配器的实际实现 | 新增语言代码、Core 修改范围、接口变化及环境需求 |

每次实验归档工具提交或版本、实际依赖、目标编译器与标准库、操作系统和硬件、输入
表示、profile、种子集合、预算、失败判据及去重规则。不可用配置和失败尝试也保留，
不通过过滤改变统计分母。

源程序、MIR、Wasm、MLIR 和 DNN 图的覆盖层次不同，跨层次主要比较方法和架构。
AST 节点数只在同一表示内比较；跨工具可采用统一格式化后的源码字节或 token 数。
论文报告的缺陷数不当作本机复现实验结果。

当前 MoonSmith 已有受限原型，但本轮没有跨工具性能或效果比较。未安装和运行的项目保持
“待实测”，不能将文档描述提升为本地验收通过。

## 8 对当前设计的影响

| 设计问题 | 优先对照项目 | 当前决定 |
| --- | --- | --- |
| 表示与生成 | Fuzzilli、Csmith、RustSmith、Rustlantis、Xsmith | MoonBit 适配器维护受限带类型 IR、绑定和数值约束 |
| 跨语言边界 | Hephaestus、Thalia、Eris、NNSmith | Core 共享执行与判定协议，各语言保留表示；第二语言出现后再稳定接口 |
| 归约与重放 | Perses、C-Reduce、wasm-shrink、MoonGrammata | 适配器产生候选，Core 验证原判据；保留原始案例和证据 |
| 价值依据 | MoonBit 同生态项目、历史案例、可控故障 | 用实际子集、判据保持和复现质量说明价值，避免将已有方法表述为独有能力 |

当前阶段仍只交付 MoonBit。RustSmith 与 Rustlantis 为后续 Rust 阶段保留基线；Swift
为未来适配方向，本轮未据“未找到工具”推断其生态不存在同类项目。

原讨论中的 OpenSmith 品牌示例和拟议平台名称属于命名资料，语言与编译器本身属于
适配或被测对象。它们保留各自角色，不参与测试工具效果排名；此次不更名。

本清单中的仓库链接用于定位项目；[Core 专题调研](core-research.md)另外记录关键源码的固定提交。
正式 benchmark 仍需固定工具源码、依赖和执行环境；项目介绍及 README 本身不足以复现执行。
