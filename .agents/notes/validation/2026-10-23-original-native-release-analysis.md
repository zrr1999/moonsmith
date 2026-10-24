# 正式报告整理前的执行与调查记录

此文件归档整理前原文中的执行索引、审计流水和阶段计划，不作为产品补充契约。

````markdown
# Native release 构建异常分析

2026-10-22 对[项目验收记录](acceptance-validation.md#三例未完成比较)中的种子 1272、3745、6968
继续调查。三例可重复触发同类诊断：native release 生成的 C 引用了未声明的
`_M…constrS…` 标识符。分别保留原例的结构化缩减结果和进一步人工缩减结果，并找到一个
189 字节的同模式小复现。现有证据不能确定三例是否来自同一根因或具体优化 pass。

本次没有重跑规模任务、升级工具链或修改产品判定。原任务仍为 10,000 个计划样本、
9,997 例完整比较且一致、3 例 `Incomplete`。以下调查执行均另存材料，不计入或替换原任务计数。

## 条件与目标

原始生成与执行使用提交 `f87e8526f90d8e0f5ab71116cf42e00738c577a8`；调查时仓库 HEAD 为
`b077513396101e7f47c1ca02aca29cd6d8418635`。环境沿用 Darwin 27.0.0 arm64、
Apple clang 21.0.0（`clang-2100.3.27.1`）、Moon / moonrun `0.1.20260920`（`914d7da`）和
moonc / core `0.10.14+7d59c7ec9`。原始版本探测在 `runs/acceptance-v2/launcher.json`；
本轮另将当前版本核对保存为 `runs/native-release-investigation/review-2026-10-22/toolchain-probes.json`，
探测结果与上述版本一致。各确认命令自身未分别保存工具版本。

本次实验中的失败保持条件是以下条件同时成立：

1. `moon build --target native --release` 退出 255，至少存在一条 `error:`，
   且每条 `error:` 都包含 `use of undeclared identifier '_M…constrS…'`，其中三个数字段均为十进制数字。
2. native debug 和 wasm-gc debug 均构建、执行成功；每组 stdout 都等于当前候选自己的参考结果。
3. 候选源码、预期、命令和原始观察对应同一份输入；新的独立确认逐字节复制该输入。

结构化候选的参考值由现有求值器导出；手工源码按其内容单独确定预期，再核对成功配置的实际输出。
只相同退出码不满足条件。语法或类型拒绝、其他 C 诊断、超时、Host 错误及缺少证据均不能
替代目标。这里的诊断模式仅供本次调查使用，尚未成为永久公共判据或根因标识。
归约允许参考值改变；不能把原例的 `-7`、`2147483646` 或 `true` 强加给所有候选。

## 原例与结构化候选

三例原始输入均为 128 个语言模型节点、深度 6。native debug 与 wasm-gc debug 输出一致，
native release build exit 255；原始 C 中未声明的标识符依次为 `_M0L6constrS87`、
`_M0L6constrS88`、`_M0L6constrS8`。诊断映射可能指向 core/abort 源文件，不能据此归因于 abort 库。

| 种子 | 原例两个成功配置的 stdout | 结构化节点数 | UTF-8 源码字节 | 尝试 / 接受 |
| --- | --- | --- | --- | --- |
| 1272 | `-7` + LF | 128 → 52 | 1273 → 522 | 236 / 13 |
| 3745 | `2147483646` + LF | 128 → 42 | 1311 → 429 | 297 / 15 |
| 6968 | `true` + LF | 128 → 51 | 1282 → 494 | 337 / 14 |

一次性辅助包调用现有生成器与 `CompleteProgram.candidates()`，按保存的候选索引路径重建
结构化输入，导出源码、成本和候选自己的参考值。调查脚本在隔离工程中逐个验证，
每例提交上限为 2,000；三例都以本次候选枚举耗尽结束，没有达到上限。
共接受 42 个候选，逐条核对源码哈希、父索引路径、release 诊断及两组成功对照后，未发现缺项。

这次脚本没有调用 `Reducer` 或 `ReductionSession`，不构成产品自动归约构建失败的验收，
也不能与默认 16 个候选、公开上限 64 的产品预算作性能比较。枚举耗尽仅说明当前程序、
候选集和顺序下没有继续接受的候选，不证明全局最小。

## 从各原例继续缩减

按保存源码逐步比对，进一步得到下列内容变换路径。每个保留结果都有新的 release 目标诊断
和两组成功对照；这里的手工源码未重新导入 `CompleteProgram`，只报告 UTF-8 字节数。

| 种子 | 内容变换路径（字节） | 最终对照输出 | 独立确认 |
| --- | --- | --- | --- |
| 1272 | 522 → 432 → 428 → 402 | `0` + LF | 新建隔离工程再次保持目标；两组对照通过 |
| 3745 | 429 → 376 → 363 → 330 → 317 | `0` + LF | 新建隔离工程再次保持目标；两组对照通过 |
| 6968 | 494 → 452 → 426 → 422 | `0` + LF | 核对已有独立确认；源码哈希相同，目标及两组对照通过 |

1272 先进入确定构造器的 payload 分支，再将 `!false` 改为 `true`，将内层布尔分支改为否定。
其 522 字节输入的三种早期改写是平行实验，其中删除外层条件的变体 release 成功，不属于
失败保持路径。428 → 402 的源码差异已核对，但 402 字节候选的 `parent_path` 仍标为
432 字节输入；不能仅凭该字段还原顺序，内容及逐候选观察才是这里采用的证据。

3745 依次移除元组、删除未用形参并同步调用、删除未用枚举分支并同步模式，最后删除剩余
未用形参但保留函数调用。把内层 match 整体替换为常量的合法 255 字节对照 release 成功，
说明该次替换失去目标。早先一份拼接笔误造成类型错误的候选不属于目标观察。

6968 删除第二个 Bool 字段并同步构造与模式，再移除结果 wrapper，最后将 `!false` 简化为
`true`。wrapper 移除后输出从 `false` + LF 变为 `0` + LF；初次实验用了错误预期，未被接受。
修正预期的 trial-02 与该次输入逐字节相同，重新验证通过。其父记录指向错误预期的 trial-01，
而非直接命名 452 字节输入；源码差异支持上述内容变换，元数据的不一致仍保留在原材料中。

本轮 3745 的第一份新增确认因工程描述符写成字面量 `\n` 而解析失败，未作为目标证据。
正确描述符在新目录建立后才完成有效确认，旧失败记录没有覆盖。已有 330 字节版本的确认
也没有冒充最终 317 字节版本的确认。

### 种子 1272 的 402 字节结果

```moonbit
enum E0 {
  C0
  C1
  C2(Bool, Bool)
}

fn main {
  println({ let v0 : E0 = E0::C2(false, false); (match v0 {
E0::C0 => (0)
E0::C1 => (0)
E0::C2(v1, v2) => ((if (if (!v1) { false } else { { let v3 : (Int, Int, Bool) = (0, 0, false); false } }) { 0 } else { { let v3 : E0 = (if v2 { E0::C2(false, false) } else { E0::C1 }); (match v3 {
E0::C0 => (0)
E0::C1 => (0)
E0::C2(v4, v5) => (0)
}) } }))
}) })
}
```

### 种子 3745 的 317 字节结果

```moonbit
enum E0 {
  C0
  C2(Int)
}

fn f0() -> Bool {
  false
}

fn main {
  println({ let v0 : E0 = (if (if f0() { false } else { { let v1 : Bool = true; false } }) { E0::C0 } else { E0::C2({ let v0 : E0 = E0::C2(0); (match v0 {
E0::C0 => (0)
E0::C2(v1) => (v1)
}) }) }); (match v0 {
E0::C0 => (0)
E0::C2(v1) => (0)
}) })
}
```

### 种子 6968 的 422 字节结果

```moonbit
enum E0 {
  C0
  C1(Int)
}

fn f0() -> Int {
  { let v0 : E0 = (if (if { let v0 : E0 = E0::C1(0); (match v0 {
E0::C0 => (false)
E0::C1(v1) => ((v1 < 0))
}) } { (match E0::C0 {
E0::C0 => (true)
E0::C1(v1) => (false)
}) } else { true }) { E0::C1({ let v0 : E0 = E0::C1(0); (match v0 {
E0::C0 => (0)
E0::C1(v1) => (v1)
}) }) } else { E0::C0 }); (match v0 {
E0::C0 => (0)
E0::C1(v1) => (0)
}) }
}

fn main {
  println(f0())
}
```

上述代码块保留实验源码及末尾 LF；精确哈希见后文。它们可用下一节相同的隔离工程描述符
和命令分别复现。没有承诺更换格式、工具链或构建配置后仍出现相同诊断。

## 189 字节的同模式小复现

以下 6 行源码为 `manual-002/main.mbt`，189 个 UTF-8 字节，末尾一个 LF：

```moonbit
enum E { A; B(Int) }
fn f(b : Bool) -> Int {
 if (if b { false } else { let t = false; false }) { 0 } else { let e = E::B(0)
 match e { A => 0; B(x) => x } }
}
fn main { println(f(true)) }
```

它具有条件内部的局部绑定、枚举构造和字段读取 match，在固定环境下 release 构建失败，
native debug / wasm-gc debug 均成功输出 `0` + LF。删除条件分支中的 `let t = false;`
（`manual-001`），或将 `B(x) => x` 改为 `B(x) => 0`（`manual-003`），所得两份对照
在新的隔离工程中均 release 构建、执行成功，stdout 为 `0` + LF。

这说明这两次特定改动消除了小程序的触发表征，不证明这些结构在所有程序中都是必要条件。
三例的已验证缩减路径没有汇合到这段文本。另有独立确认的 208 字节手工概括程序，
同样只能作为同模式复现，不能声称三例已经全部逐步缩至 189 或 208 字节。

### 独立复现步骤

使用上述固定版本的工具链，创建新的 `native-release-repro` 目录，将小程序逐字保存为
其中的 `main.mbt`。在该目录写入以下三个描述符；独立 `moon.work` 用来隔离外层工作区：

```shell
cat > moon.mod <<'TOML'
name = "moonsmith/generated"
version = "0.0.0"
TOML
cat > moon.pkg <<'PKG'
pkgtype(kind: "executable")
PKG
cat > moon.work <<'TOML'
members = ["."]
TOML

moon version --all
cc --version
moon build --target native --release
```

实测最后一条命令退出 255，stderr 包含两处未声明 `_M0L6constrS84` 的诊断；
具体编号和源位置只描述这次观察。生成 C 在 `_build/native/release/build/generated.c`。
继续分别验证两组对照：

```shell
moon build --target native --debug
./_build/native/debug/build/generated.exe
moon build --target wasm-gc --debug
moonrun ./_build/wasm-gc/debug/build/generated.wasm
```

两次构建和两次执行的实测退出码均为 0，两次程序 stdout 都为十六进制 `30 0a`，即 `0` + LF。
上述步骤也适用于前述三份独立缩减源码，其成功配置输出同为 `0` + LF。

## 编译阶段对照

阶段实验只对 189 字节小程序进行。release 生成 C 中，`_M0L6constrS84` 有两次引用且
没有声明，其中一次在 `moonbit_decref_cycle_free`，另一次被转换为枚举结构体指针：

```c
moonbit_decref_cycle_free(_M0L6constrS84);
/* another branch */
struct _M0DTP29moonsmith9generated1E1B* _M0L4_2aBS83 =
  (struct _M0DTP29moonsmith9generated1E1B*)_M0L6constrS84;
```

这支持“到达 C 编译器的输入已经不合法”，不能单凭这几行定位导致它的编译器变换。
每个对照都保留实际参数、输入输出哈希和完整诊断：

| 固定输入与单项改动 | 实测结果 | 证据范围 |
| --- | --- | --- |
| 原始 release 流水线 | `moon build` 退出 255，目标未声明变量诊断 | 小程序复现该表征 |
| 同一份 release C，C 编译命令仅改用 `cc -O0` | C 编译退出 1，仍有同样两处未声明变量诊断 | 降低 C 优化不能修复此输入 |
| 同一份 release core，`moonc link-core -O0` 后编译 C | link 退出 0，C 编译退出 1，保持目标诊断 | 仅关闭该阶段优化不能消除问题，未定位具体 pass |
| `build-package -O0` 与 `link-core -O0` 同时使用 | 生成 C，C 编译退出 1，报重复标签 `join_84` | 不同诊断，不能算原失败保持或同根因证据 |
| `build-package -O0` 后按默认参数链接 | link 退出 1，stdout / stderr 均为空，未生成 C | 输入存在但原因未明，属于不确定对照，不用于因果推断 |

因此没有“关闭 MoonBit 优化后通过”的结论；没有检查上游源码、问题单或更新版本，
也没有确定该问题是否已在上游修复。

## 产品归约缺口与补齐顺序

[Engine 既有设计](../fps/FP-0004-engine-execution-contract.md#term-failure-predicate)将失败判据
与展示用指纹分开，要求保持观察条件，不保证同根因。以下是按当前源码核对的实现缺口及
建议切片，尚未实现新 API、修改公共格式或任务退出码。

| 顺序 | 当前缺口与责任归属 | 后续切片的可观察验收 |
| --- | --- | --- |
| 1 | [CLI 归约入口](../modules/cli/src/app/reduction.mbt)只接收 `Difference(first, second)`；构建失败不会启动搜索 | 对有目标诊断的已保存原例启动有界搜索；原始 `Incomplete`、观察和任务分母保持可追溯；非目标失败不替代目标 |
| 1 | [现有匹配](../modules/engine/src/oracle.mbt)只比较 Oracle、配置、阶段和失败种类；`Exit(255)` 无法区分不同诊断 | 由工具链适配器 / Oracle 识别版本化诊断条件，区分其他错误、缺证据和目标消失；Engine 不解释 Clang 文本或 MoonBit AST |
| 1 | [归约记录格式 3](../modules/contracts/src/reduction.mbt)固定表达一对输出分歧配置 | 明确保存目标及匹配版本、候选与独立确认关联；旧案例与尝试仍可源码重放；不得静默改写既有格式含义 |
| 2 | [语言候选](../modules/moonbit/src/structural_reduce.mbt)尚缺这里需要的声明与引用协同改写 | 删除未用形参与同步调用、枚举分支 / 字段与同步构造和模式；保持作用域的简化均完整检查并验证真实目标 |
| 2 | [工具链观察](../modules/cli/src/toolchains/moon/matrix.mbt)记录顶层 `moon build`；C 与 core 仅是构建目录的附带产物 | 保存实际子阶段参数、C 编译器版本及必要中间产物，按候选和确认关联；没有产物时明确缺失 |
| 3 | [源码重放](../modules/cli/src/app/differential.mbt)执行已保存源码，不恢复结构化搜索 | 若恢复搜索，先重建生成器 / 种子 / 预算对应模型并核对源码快照；没有导入能力时不把任意源码当作 `CompleteProgram` |

可复用 [ReductionSession](../modules/engine/src/session.mbt) 已有的调用方判据、original / current /
best、整体预算和过期响应约束，无需为这三例另建 Engine v2。后续实现方向为保留
`Incomplete` / 退出码 3 并附归约结果，由 MoonBit 工具链专用 Oracle 定义版本化诊断规则，
接入现有会话。具体身份编码及新目标记录与旧格式的关系仍待明确；上述方向尚未实现。
后续若涉及正式 CLI 判定或持久化语义，先按所属提案及
[FP-0000](../fps/FP-0000-governance.md#何时需要-fp)评估与评审；已有设计覆盖的实现不重复提案。
本阶段不安排 ddmin、缓存、并行搜索、通用诊断协议或算法性能比较。

## 本地证据索引与限制

本次原始材料位于工作区 `runs/native-release-investigation/`，不随源码提交；本文代码块和
复现步骤可以独立使用。以下相对目录均以该路径为前缀：

| 材料 | 保存位置 |
| --- | --- |
| 三例结构化输入、接受路径和逐候选命令 | `seed-1272/`、`seed-3745/`、`seed-6968/` 的 `original.json`、`accepted.jsonl`、`result.json` 与 `trial-*/` |
| 1272 手工结果 | `agent-1272/result-v2.json`、`derived-probes.json`；早期 `result.json` 的错误链不作为依据 |
| 3745 / 6968 手工结果 | `agent-3745-6968/result.json` 与追加的 `result-v2.json`，以及各 `seed-*/trial-*/` |
| 402 / 317 字节新增独立确认 | `confirmation-2026-10-22/seed-1272/` 与 `confirmation-2026-10-22/seed-3745-v2/`，各有五条命令 JSON、源码及生成 C |
| 422 字节已有独立确认 | `agent-3745-6968/confirm-6968/` 的 `confirmation.json` 和五条原始命令 JSON；本轮只核对，无重复编译 |
| 小复现与成功变体 | `manual-001/`、`manual-002/`、`manual-003/`；成功变体的独立 release 执行另存 `agent-stage/pass3/` |
| 阶段对照 | `agent-stage/result-v2.json`、`agent-stage/pass3/logs/` 和 `agent-stage/release-c-snippet.txt` |
| 本轮主审计 | `review-2026-10-22/evidence-audit.json`：42 个结构化接受候选、10 个手工内容步骤、3 份独立确认及 13 条阶段命令；含 460 份输入 / 记录 / 产物的哈希索引 |

精确源码 SHA-256（代码块不含 Markdown 围栏，保留末尾 LF）：

| 输入 | UTF-8 字节 | SHA-256 |
| --- | --- | --- |
| 1272 结构化结果 | 522 | `8bcd39d570bf46bbeab15dc88bf2451dc093395a9b7ae48d7212c6a43bf16e87` |
| 3745 结构化结果 | 429 | `4a990c34e89721bb50ab531b2c75196b6bfe9a2ca621d50691111e406ddb1dc4` |
| 6968 结构化结果 | 494 | `b67393cb8f4702f31bfbeedea5f4bad9a88badcde5f705c1a70cd47c43a264f3` |
| 1272 最终输入及独立副本 | 402 | `1bbec9a8701d9b75863ea0301aa0eba57afdbf257e49d6254a34acaab0a2dbca` |
| 3745 最终输入及独立副本 | 317 | `cb1055e5a5128999dfba9b10e7fe239042401cc8c0d75199bac2e03a03513afb` |
| 6968 最终输入及独立副本 | 422 | `641f0d5d23a63db15454502c6023847ebf8eb1fd2afcc9cd98c16042d0cc091c` |
| 189 字节小复现 | 189 | `9813d37c459a9e40eeeb86d464921d3fcba36bd35afebc5ff527b6a4bcf78612` |
| 另一个手工同模式复现 | 208 | `c5232929ea0cfe5b0bc40f9ad3dfe624134450ba0c20ebb21b583b887a688698` |

本轮没有将这些源码纳入产品固定回归集，也没有发布上游问题。行为证据限于上述环境、输入和
对照；原始日志中的缺失字段或错误父标注没有被补造。诊断模式相同、源码更短、独立确认通过
分别支持故障表征的可重现性、局部缩减和输入重执行，不证明唯一根因、全局最小或产品归约能力已补齐。
````
