# Native release 调查后的归约补齐方案

日期：2026-10-22。本轮完成正式分析和可审阅方案；用户随后授权将本轮文档提交、推送至现有 PR #37。
产品实现、合并及发布不在本轮范围。
实测结论见[正式分析](../../../docs/native-release-analysis.md)，这里记录源码观察、备选方案及决定来源。

## 范围与决定来源

任务明确要求在现有 owning worktree 调查三例、补齐两份独立确认、核对已有确认并交付方案。
小模型只执行准确输入、有独占输出目录和停止上限的任务；主会话核对原始记录。
不重跑规模实验、不升级工具链、不以同诊断证明同根因、不把手工源码冒充完整语言模型。

已经确定的责任边界来自 [FP-0004](../../../fps/FP-0004-engine-execution-contract.md)：
Engine 编排和搜索，语言适配器提供程序模型与合法候选，Host 执行和存储。
复用既有会话、保留原例和追加尝试属于已覆盖的设计，不需要 Engine v2 FP。

2026-10-22 用户已通过本轮问答明确选择：

- 保留 `Incomplete` / 退出码 3，另附构建异常归约与确认结果。
- 由 MoonBit 工具链的专用 Oracle 定义版本化诊断规则，接入现有会话；本切片不先扩展共享
  Assessment / FailurePredicate 契约。
- 本轮检查范围采用明确例外：执行定向文档检查，完整 `just check` 标为未运行，继续保留
  `.cargo/` 内容的禁读约束；后续经用户授权清理目录，已补跑完整门禁，见下文。

本轮只记录选择，不实施产品公共 API、判据编码或 CLI 变化。具体身份编码及新目标记录与
旧格式的关系仍需在实施切片中明确。正式文档直接表述所选方向，不记入用户确认过程。

## 当前调用路径与缺口

1. [run_differential](../../../modules/cli/src/app/differential.mbt)生成 `CompleteProgram`，
   先存原例并执行选定配置，再调用 `reduce_differential`。
2. [reduce_differential](../../../modules/cli/src/app/reduction.mbt)的 guard 只允许已保存的
   `Difference(first, second)`，创建对应配置对的差分判据；三例 `Incomplete` 从此返回。
3. [differential_assessment](../../../modules/engine/src/differential_assessment.mbt)只为配置对
   建立正常输出比较；缺少任一输出为 `Insufficient(MissingObservation)`。
4. [reference_assessment 与 match_failure](../../../modules/engine/src/oracle.mbt)能够保留构建
   `Exit(code)`，但只比较 Oracle、配置、阶段、失败种类；不同诊断的 exit 255 会混同。
   将原例参考值冻结到所有候选还会错误拒绝合法改变输出的缩减。
5. [ReductionSession](../../../modules/engine/src/session.mbt)已经接收调用方判据，保留
   original/current/best、预算和候选 ID。[Reducer](../../../modules/engine/src/reducer.mbt)
   是基于 `FailurePredicate` / `match_failure` 的调度便利入口；不能假定它已接收任意谓词。
6. [DifferentialReduction 格式 3](../../../modules/contracts/src/reduction.mbt)固定 first/second
   configuration；[保存入口](../../../modules/cli/src/artifacts/differential.mbt)只写新文件。
   [replay](../../../modules/cli/src/app/differential.mbt)校验保存源码、构建文件和案例关系后
   执行源码，不读取归约摘要来恢复搜索，也不验证摘要目标。
7. [结构化候选](../../../modules/moonbit/src/structural_reduce.mbt)已有表达式替换、整函数删除、
   枚举定义列表截短和完整合法性过滤，缺少未用形参 / 枚举分支 / payload 与引用的协同删除。
   当前函数删除会以返回类型的零值替换调用，可能丢失本例需要保留的调用结构。
8. [工具链](../../../modules/cli/src/toolchains/moon/matrix.mbt)记录顶层 `moon build` 与运行命令，
   尚未将实际 build-package/link-core/cc 参数、C 编译器身份和必要中间文件纳入正式证据。

## 关键备选方案

### 构建异常与 CLI 结论

| 方案 | 代价与收益 | 当前建议 |
| --- | --- | --- |
| 保留 `Incomplete` / 3，另附构建异常目标、归约及确认状态 | 保留现有比较与分母含义；用户可获得复现材料，但自动化仍需理解比较未完成 | 本轮已选择；不把找到构建异常等同于得到两份可比较输出 |
| 将已确认构建异常作为独立发现，并重新设计结论及退出码 | 能直接表达工具链异常；影响脚本、任务汇总、报告与既有案例的解释，需要先明确兼容保证 | 可行，但本轮不预定新值或改变 `Incomplete` 含义 |
| 维持当前仅归约输出分歧 | 无公共行为变化；三例仍依赖人工调查，无法闭合用户报告流程 | 当前事实，不满足后续自动归约目标 |

### 诊断身份与判据连接

| 方案 | 代价与收益 | 当前建议 |
| --- | --- | --- |
| MoonBit 工具链专用 Oracle 解释原始证据，输出明确目标结果，复用现有会话判据 | 文本匹配留在适配器；Engine 保持通用。仍需明确规则版本、稳定身份、控制组条件和目标的持久表达，不能只把 `Exit(255)` 塞回现有判据 | 本轮已选择；不预定如何把身份编码进现有字符串字段 |
| 扩展共享 Assessment / FailurePredicate 契约以承载诊断身份 | 目标数据更显式，多个调用方可直接复用；扩大公共类型及序列化、报告、去重与兼容评审范围 | 若实际消费者需要统一身份再选择；不得先造无调用者的通用诊断协议 |
| 直接在 CLI / Engine 中匹配具体构造器编号或 exit 255 | 实现表面短，但复制判定规则且会接受类型错误、不同 C 错误或丢失目标 | 不可作为满足验收的方案 |

两种可行身份方案都必须让 Oracle 在证据完整且目标条件成立时才报告保持。
目标消失是 NotPreserved；缺证据、截断、超时或 Host 错误不能算 Preserved。
具体状态组合须跟现有 `PredicateStatus` 与 Oracle 适用条件核对，不能临时创造新语义。

### 持久化与重放

可行方向包括：给新目标另存明确带版本的归约记录，保留旧格式 3 读取；或建立能表达两种目标的
下一版记录并提供显式兼容读取。两者都必须保留 case / attempt 的源码重放和原始比较结论，
不能用 first/second configuration 伪装构建目标，也不能把“源码可运行”称作“原目标确认通过”。
此选择依赖前两项公共语义；本轮只记录需求与验收，不预定新类型、字段或格式版本号。

## 最小可执行切片

### 切片 1：建立目标判断与拒绝边界

- 所属：`modules/cli/src/toolchains/moon` 中的工具链证据解释及其实际 Oracle 装配；
  如选择共享契约方案，再改 `modules/contracts`。Engine 不接触 Clang 或 AST。
- 前置：确认诊断身份的责任与表达；固定目标配置、阶段、规则版本、工具链条件与控制组条件。
- 输入：原始 release 诊断、两个成功控制组和当前候选的语义 / 规范输出。
- 测试：目标错误通过；同为 255 的类型拒绝、重复标签、空诊断和混合错误不通过；
  超时、Host 错误、截断和缺观察为不确定；目标消失明确拒绝。
- 真实验收：三份固定输入各得到目标保持；`manual-001`、`manual-003` 及已保存的合法
  3745 常量替换对照失去目标。用错误预期的 6968 记录证明控制组失败不能被接受。
- 文档：工具链 / CLI 的现有 README；只有公共契约含义发生变化才修订其权威定义。

### 切片 2：接通保存、搜索、独立确认与报告

- 所属：CLI app / artifacts / report 和必要 Contracts 记录；复用 Engine 会话及调度，
  避免另写一套候选接受循环。若便利 Reducer 需要兼容入口，按实际调用方最小扩展。
- 前置：确定任务结论和目标记录方案，查清既有支持的案例 / 尝试格式和报告消费者。
- 验收：保存原例后才开始；每个候选和确认都有独立尝试 ID、精确源码哈希、命令与原始结果；
  原例和样本分母不变。保存失败保持操作错误，不以旧证据代替本次确认。
- 预算：沿用显式候选预算和稳定顺序；0、边界值、预算耗尽、枚举完成与取消分别可观察，
  不将调查脚本的 2,000 上限变成默认或悄悄扩大公开范围。
- 入口测试：真实 `run` 触发目标搜索，best 的确认重新执行而非复用缓存；源码重放追加记录、
  不再次自动归约；旧案例和尝试仍可加载。缺少原目标说明不能显示“目标已确认”。
- 文档：正式行为与兼容要求写所属 FP / 模块 README，不为这次实现另建 Engine v2。

### 切片 3：补充协同语言候选

- 所属：`modules/moonbit`；Engine 仅处理候选，不拥有语言声明或引用的更新规则。
- 先补未用形参及所有调用点同步删除，保留调用；再补枚举分支 / payload 的声明、构造器和
  模式参数同步改写；最后处理作用域保持的分支和布尔简化。
- 验收：候选 finish 成功、结果协议满足选定目标约束、成本严格降低、稳定顺序与去重；
  观察实际求值 / 工具链行为，不写只镜像实现的断言。每个新操作均包含会失去目标的对照。
- 三例手工结果是缺口证据，不是未来必须重现同一搜索路径或字节数的保证。
  若允许改变结果类型以去除 6968 wrapper，先明确结果协议与控制组重算规则，不能直接放宽
  当前 `result_type == original.result_type` 约束。
- 实现变更按贡献指南完成行为测试、`just build`、`just test` 与 `just check`；
  真实工具链验收限定少量固定输入，不重跑 10,000 样本。

### 切片 4：强化可诊断证据，按需恢复结构化搜索

- 所属：Host 执行与文件保存，Moon 工具链解释实际子阶段；记录实际 argv、cwd、退出状态、
  C 编译器版本及选定 core / C 的哈希。dry-run 计划不能冒充实际执行记录。
- 验收：缺产物和无诊断退出能直接辨识；中间产物关联准确候选和确认，路径映射不被当作归因。
- 当前保存源码可重放。若后续支持恢复生成模型，必须按生成器版本、种子和预算重建，
  核对源码快照后才能开始；手工输入没有解析导入能力时明确拒绝恢复结构化搜索。
- 本轮不建立任意源码导入、通用诊断协议、缓存或并行搜索；算法孵化与比较仍归 Spore Lab。

## 本轮复核与限制

追加原始材料位于 `runs/native-release-investigation/confirmation-2026-10-22/`。
主会话审计脚本及 460 份哈希索引位于 `review-2026-10-22/`，复核 42 个结构化接受候选、
10 个手工内容步骤、3 份独立确认与 13 条阶段命令，未重跑已通过实验。
原始父标注、错误预期、旧错误汇总、无效工程搭建与不同诊断均保留并排除，不覆盖历史材料。

一名代理在只读核对时误用默认主检出作 workdir，命令因文件不存在失败，没有写入；
此操作违反任务的每次终端显式 owning worktree 要求，已在交付记录中披露。
编译异常调查阶段没有读取、暂存或修改 `.cargo/` 的内容。

全仓门禁的 Gitleaks hook 固定执行 `gitleaks dir .`，而任务禁止读取无关未跟踪 `.cargo/`。
现有 `.gitleaks.toml` 未排除该路径；不能在没有明确例外的情况下运行会读取它的扫描，
也不能临时改配置或悄悄跳过该门禁。用户已明确批准本轮定向文档检查的范围例外，
因此当时完整门禁记为未运行，不写成通过；后续补跑结果见下文。

已独立执行本次四个变更文件的定向 Prek 检查：Markdown、链接、拼写、适用的内置文件检查、
alint 和提案检查通过；无适用文件的 hook 显示 Skipped，不计作执行通过。
`git diff --check` 通过；四个 MoonBit 代码块逐字节匹配原始输入，当前工具链版本探测与
原实验一致。最后文档改动后再检查相应文件，记录保存为
`runs/native-release-investigation/review-2026-10-22/document-checks.json`。
范围例外不授权 Gitleaks 扫描 `.cargo/`，也不成为后续实现或提交的永久检查规则。

### 后续目录来源核对

用户随后指出 MoonSmith 不是 Rust 项目，并要求核对 `.cargo/` 的来源。只列目录项与元数据，
观察到其中只有 `bin/lychee-0.24.2`，没有项目 Cargo 配置。目录创建于 2026-10-18 UTC 03:17，
历史会话在同一时间执行 Git 提交检查，随后首次出现未跟踪 `.cargo/`，并记录了该文件路径。
这支持其为链接检查工具的安装产物，不是 MoonSmith 的产品依赖。

仓库当前 lychee hook 使用正式 `lychee-v0.24.2`，其
[安装脚本](https://github.com/lycheeverse/lychee/blob/lychee-v0.24.2/scripts/lychee_pre_commit.sh)
原本把二进制放在 hook 仓库的 `.cargo/bin` 下。上游
[问题 2292](https://github.com/lycheeverse/lychee/issues/2292)及
[修复 2293](https://github.com/lycheeverse/lychee/pull/2293)确认 worktree 的 Git 环境变量会干扰
脚本定位；本机缓存的两份脚本均尚无该环境清理。该机制与当前产物及时间线吻合，但本轮未重新
触发提交 hook 来动态复现安装路径。未读取可执行文件内容、未删除文件、未升级或修改 hook。

之前为防止误提交加入了仓库本地 `info/exclude` 的 `/.cargo/`；它不上传，也不修复工具安装
位置。不能把“未跟踪”直接当作共享配置不应提交的证据，或把这条本地规则当作 MoonSmith
正式依赖 / 检查策略。

### 用户授权清理后的状态

用户明确要求升级 lychee 并删除遗留 `.cargo/`。重新查询上游
[正式 release](https://github.com/lycheeverse/lychee/releases/tag/lychee-v0.24.2)与 release API，
最新正式版本仍为当前的 `lychee-v0.24.2`；修复 2293 目前只包含在 nightly 中。
因此按正式版本约定保留现有 hook 配置，升级等待包含修复的正式 release。

已删除仅含 `bin/lychee-0.24.2` 的工作树 `.cargo/`，并撤回此前加入本地 `info/exclude` 的
`/.cargo/` 规则；删除前只核对目录项与元数据，没有读取可执行文件内容。
删除后完整 `just check` 通过，含 Gitleaks、lychee 与 MoonBit 格式和类型检查，检查后目录未重建。
这次直接运行检查未模拟 Git 提交环境，旧版 hook 在后续 worktree 提交中仍可能重建该目录。
此前批准的定向检查例外及其历史结果保留，但当前完整门禁已补跑通过。
清理与完整检查记录分别保存为
`runs/native-release-investigation/review-2026-10-22/lychee-cleanup.json` 和
`runs/native-release-investigation/review-2026-10-22/post-cargo-cleanup-checks.json`。
