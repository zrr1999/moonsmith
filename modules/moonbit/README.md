# MoonSmith MoonBit Adapter

作为 MoonBit 的[语言适配器](../../fps/FP-0001-workspace-modules.md#term-language-adapter)，
提供类型化程序、确定性生成、参考求值、源码输出及归约候选。

`int-bool-v1` 使用分开的整数和布尔表达式树、顺序局部绑定及有界深度。
`generate` 接收显式种子；`Program` 提供 `evaluate`、`valid`、`emit`、`size` 和 `candidates`。
删除绑定时修正引用，候选再次校验作用域与 Int 运算范围。

FP-0002 的结构路径使用 `Template`、`Expr`、`Function` 和 `Binder` 表达带类型空洞、词法绑定、
分支与函数调用。`Template` 包含 `enums`、`functions` 和 `result`；`enums` 为空时沿用标量模型。
函数以定义数组中的索引标识；同一作用域内绑定标识唯一，不同函数或分支的
独立作用域可以复用标识。函数可引用后面的定义，但整个调用关系必须无环，包括未调用函数
及未执行分支中的调用。

`Template.check` 检查部分程序的约束，允许类型正确的空洞；`Template.finish` 拒绝剩余空洞，
返回拥有独立快照的 `CompleteProgram`。检查只处理结构和类型，不求值。
错误通过 `StructureError` 区分空洞、非法引用、类型、参数和调用依赖。
完整执行入口要求结果适用现有观察协议，复合结果抛出 `UnsupportedResultType`；
`check` 仍可检查具有复合结果的模板。

`Ty.Tuple` 表示至少两个有序字段，`Expr.Tuple` 构造值，`Project` 检查投影范围。
`Ty.Enum` 以 `Template.enums` 的索引标识名义类型；`EnumDefinition.variants` 保存各构造子的
字段类型，`Variant` 指定定义、构造子索引和实参，`Match` 为每个构造子提供一项 `MatchArm`。
模式参数在各自分支中独立可见，数量、类型和分支结果都检查。枚举类型依赖无环，
允许前向引用，拒绝经元组间接递归；未使用定义、未调用函数和未执行分支均检查。
复合值可作为局部绑定、参数、返回值及分支结果，源码输出使用独立枚举声明和穷尽匹配。

`CompleteProgram.emit` 输出包含函数定义和单值输出入口的 MoonBit 源码，`result_type` 给出
输出表达式类型。`size` 为表达式、函数、函数与模式参数、枚举定义及构造子字段参数的节点总数；
每个枚举定义和构造子各计一个节点。`depth` 为表达式最大嵌套层数，
叶子深度为零，不代表运行时调用栈深度。完整程序不会因原模板中的可变数组被修改而改变。
快照包含嵌套元组类型、枚举字段、模式参数和表达式数组。

`CompleteProgram.structural_candidates` 按固定顺序删除函数、简化结果及函数体，递归简化嵌套表达式。
删除绑定时用其类型的常量修复引用；删除函数时修复调用和后续函数编号。每个候选重新经过
完整类型、作用域与无环检查，保持结果类型并按源码去重。
`integer_candidates` 将结果表达式及函数体中每个非零 Int 常量分别替换为 `0`，保留原节点数；
零常量不再产生同一改写。`candidates` 合并上述两项操作并按源码去重，便于库调用。
复合表达式的字段和匹配分支也进入遍历；移除模式绑定时按类型修复引用。
还尝试截去未使用的尾部枚举定义，保留通过完整检查的候选，不承诺穷尽所有定义删除方式。

`cost` 返回节点数、全部整数常量绝对值之和与源码 UTF-8 字节数；计算绝对值前先将 Int
提升为 Int64，包含 `-2147483648`。`is_smaller_than` 按这三个分量的字典序比较，候选筛选
与 Engine 装配使用同一顺序。成本标识为 `moonbit-nodes-int-magnitude-utf8-v1`。
整数常量简化说明同节点数的程序仍可更简单，不提供完整的常量缩减算法。
不要求保持计算值：
是否仍触发原分歧由 Engine 根据候选的实际执行证据判定。本 API 不承诺穷尽所有合法缩减。

结构路径采用单值行观察协议。`Ty.normalize_output` 按输出类型检查完整 stdout：整数必须
是有符号 32 位范围内的规范十进制表示，布尔必须是 `true` 或 `false`，并且恰好以一个 LF
结束。额外文本、空白、其他类型及越界数字均不构成可比较值；合法输出原样返回，原始观察
不被改写。该检查只解释输出编码，不计算程序的正确答案。`result_protocol` 提供版本化
标识 `moonbit-int32-line-v1` 或 `moonbit-bool-line-v1`，便于保存后选用相同协议。
`result_protocol` 返回可选标识，元组和枚举返回 `None`，其默认文本也不构成可比较结果。

`equivalent_variants` 返回经完整检查的输出等价程序：Int 加零或 Bool 双重否定，以及常量
条件包装。它们保持正常输出值和类型，可以增加节点和执行成本，不用于归约候选，也不受
原生成预算约束。真实五配置测试比较原程序和变换程序的有效输出；完整程序参考解释器
留待后续实现。`run` 可通过 `execution.equivalent_variants` 开启原程序与变换程序的统一差分，
配置、计数和存证见 [CLI 说明](../cli/README.md#差分执行与存证)。

`CompleteProgram.equivalent_group` 将原程序及这些变换组成不可直接修改的
[等价程序组](../../fps/FP-0002-moonbit-semantic-contract.md#term-equivalent-program-group)。
`EquivalentGroup.members` 返回稳定身份、变换版本与完整程序，`relations` 返回相同顺序的关系：
`original` 使用 `identity/v1`，`equivalent-1` 使用 `int-add-zero/v1` 或 `bool-double-not/v1`，
`equivalent-2` 使用 `true-branch/v1`。原有 `equivalent_variants` API 保留。
组的 `structural_candidates` 和 `integer_candidates` 仅缩减原程序，再重新应用既定变换并完整检查；
不会各自缩减成员。`cost` 对各成员的三个成本分量分别求和，`is_smaller_than` 沿用字典序，
成本标识为 `moonbit-group-sum-nodes-int-magnitude-utf8-v1`。组自身不执行搜索或编译器。

`synthesize(seed, limits?, generator?)` 先随机组合带空洞的结构模板，再用同一套
规则补全。模板组合与补全共享一个 ChaCha8 随机流和预算；函数只能调用此前的函数定义，
引用从当前位置的可见绑定中选择。模板不来自固定示例列表，也不需要求值后筛除程序。
整数加减使用 MoonBit 的有符号 32 位环绕语义，常量包括整数边界值；不生成除法、浮点、
循环、递归或外部状态读取。

| 生成器选择 | 标识与范围 |
| --- | --- |
| `Generator.ScalarV1` | `template-rules-v1`，原有标量模板规则，保留固定案例的原始生成条件 |
| `Generator.CompositeV2`（默认） | `template-rules-v2`，增加元组构造、局部绑定与投影，以及条件选择枚举值后的穷尽匹配 |

`generator_identifiers` 列出支持的标识，`parse_generator` 精确解析，未知值返回 `None`。
新版生成二或三字段元组，至多一个共享枚举定义，其二或三个构造子各含零至两个 Int/Bool
字段；空洞、函数签名及最终结果保持 Int/Bool。已有函数调用、分支和绑定可嵌入这些规则，
语言模型更广的复合参数、返回值与嵌套类型另由手工结构及工具链测试覆盖。

规则按实际表达式和新增枚举定义的节点数及深度检查剩余预算，选中后才提交结构和定义。
候选准备也消耗同一随机流，节点和构造计数不包含未选中的结构；构造次数统计规则展开及
函数、枚举、构造子头。组合和补全持续共用预算，接受一个新规则不会重置计数。

| 生成预算 | 默认值 | 允许范围 | 含义 |
| --- | --- | --- | --- |
| `max_nodes` | 128 | `1..2048` | 完整程序节点数，包括函数、枚举定义、构造子和参数；当前标量空洞预留一个节点 |
| `max_depth` | 6 | `0..16` | 表达式嵌套深度，叶子为零 |
| `max_attempts` | 256 | `1..8192` | 模板和补全合计的规则构造次数，包括函数、枚举、构造子头与终结节点 |

规模或深度不足以继续展开时选择终结节点；构造次数耗尽则抛出 `AttemptsExhausted`，不会
无界重试。非法预算抛出 `InvalidLimits`。`GeneratedProgram` 返回完整程序、实际生成器选择和构造次数；
相同版本、种子和预算产生相同源码，不承诺跨版本只凭种子重生成。

结构检查、自动组合、规则补全和共享预算均有行为测试；应用层以真实多配置执行生成案例，
并验证保存材料重执行。当前 CLI 使用此差分路径；旧 `generate` 与 `Program.evaluate` 保留为原型库能力。

结构归约还会同步删除函数形参与全部调用实参、未构造的枚举分支与相应模式，以及枚举字段与
全部构造和模式参数；仍被使用的参数由完整检查拒绝删除。已知构造器的 match 可替换成保留
实参绑定的分支，布尔字面量否定与布尔分支可简化。所有候选继续保持结果类型、严格降低成本，
按稳定顺序去重；是否保持编译器异常必须由调用方取得新观察后判断。

本模块不调用编译器，不负责搜索或保存结果。语言范围见 [FP-0002](../../fps/FP-0002-moonbit-semantic-contract.md)，
执行与存证入口见 [CLI 模块](../cli/README.md#差分执行与存证)。
