# Native release 构建异常分析

2026-10-22 对[项目验收记录](acceptance-validation.md#三例未完成比较)中的种子 1272、3745、6968 进行调查。
原始任务源码冻结于提交 `f87e8526f90d8e0f5ab71116cf42e00738c577a8`，调查源码为
`b077513396101e7f47c1ca02aca29cd6d8418635`。工具链为 Darwin 27.0.0 arm64、
Apple clang 21.0.0（`clang-2100.3.27.1`）、Moon / moonrun `0.1.20260920`（`914d7da`）和 moonc / core
`0.10.14+7d59c7ec9`。三例在 native release 下产生 C 编译器未声明 `_M…constrS…` 标识符诊断，
并分别缩减出 402、317、422 字节源码；另有 189 字节同模式复现。现有证据不能确定三例是否同一根因或具体优化 pass。

## 失败保持条件

本次调查仅在以下条件同时成立时接受候选：

1. `moon build --target native --release` 退出 255，至少存在一条 `error:`，且每条 `error:` 均包含
   `use of undeclared identifier '_M…constrS…'`，其中三个数字段均为十进制数字。
2. native debug 和 wasm-gc debug 均构建、执行成功；各自 stdout 等于该候选单独确定的参考结果。
3. 候选源码、预期、命令和原始观察对应同一份输入，独立确认逐字节使用该输入。

结构化候选的参考值由上述调查版本中的实验性求值器导出；该实现不包含在当前交付中。
手工源码按其内容确定预期，再核对成功配置的输出。只相同退出码、语法或类型拒绝、
其他 C 诊断、超时、Host 错误及缺少证据均不能替代目标失败；参考值允许随候选改变。诊断模式仅用于本次调查，
不是永久公共判据或根因标识。最终缩减结果另经独立确认；无效工程、非目标错误与证据不匹配的尝试不计入有效结果。

## 原例与结构化候选

三例原始输入均为 128 个语言模型节点、深度 6。native debug 与 wasm-gc debug 输出一致，native release 构建退出 255；
原始 C 中未声明的标识符依次为 `_M0L6constrS87`、`_M0L6constrS88`、`_M0L6constrS8`。诊断映射可能指向
core / abort 源文件，不能据此归因于 abort 库。

| 种子 | 原例两个成功配置的 stdout | 结构化节点数 | UTF-8 源码字节 | 尝试 / 接受 |
| --- | --- | --- | --- | --- |
| 1272 | `-7` + LF | 128 → 52 | 1273 → 522 | 236 / 13 |
| 3745 | `2147483646` + LF | 128 → 42 | 1311 → 429 | 297 / 15 |
| 6968 | `true` + LF | 128 → 51 | 1282 → 494 | 337 / 14 |

候选由既有 `CompleteProgram.candidates()` 生成，按节点数、整数常量绝对值之和、UTF-8 字节数
的字典序严格改善；每份候选重新编译并与其参考结果核对。每例最多提交 2,000 个候选。
三例分别接受 13、15、14 个候选后枚举耗尽，没有达到上限。枚举耗尽仅表示当前程序、候选集及顺序下
没有继续接受的候选，不证明全局最小。调查脚本未使用 `Reducer` 或 `ReductionSession`，
其预算和执行路径不同于产品默认归约，不能作为产品能力验收或算法性能比较。

## 从原例继续缩减

进一步的内容变换结果如下。每个最终候选均有目标 release 诊断、两组成功对照及独立确认；手工源码未重新导入结构化程序模型，
表中只报告 UTF-8 字节数。

| 种子 | 内容变换路径（字节） | 最终对照输出 | 独立确认 |
| --- | --- | --- | --- |
| 1272 | 522 → 432 → 428 → 402 | `0` + LF | 新建隔离工程再次保持目标；两组对照通过 |
| 3745 | 429 → 376 → 363 → 330 → 317 | `0` + LF | 新建隔离工程再次保持目标；两组对照通过 |
| 6968 | 494 → 452 → 426 → 422 | `0` + LF | 独立确认通过；源码哈希相同，目标及两组对照通过 |

1272 的变换包括确定构造器的 payload 分支、简化布尔条件和内层分支。522 字节输入的一个平行改写使 release 构建成功，
不属于失败保持路径。3745 的变换移除元组、未用形参及枚举分支，并同步更新调用和模式；将内层 match 整体替换为常量的
对照构建成功，不保持目标。6968 删除第二个 Bool 字段并同步构造与模式，移除结果 wrapper，最后将 `!false` 简化为 `true`；
wrapper 移除后输出从 `false` + LF 变为 `0` + LF，确认时按该候选的新预期核对。

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

三个代码块均保留末尾 LF。下一节的独立复现步骤也可用于这三份源码；固定工具链外的行为未验证。

## 189 字节的同模式小复现

以下 6 行源码为 189 个 UTF-8 字节，末尾一个 LF：

```moonbit
enum E { A; B(Int) }
fn f(b : Bool) -> Int {
 if (if b { false } else { let t = false; false }) { 0 } else { let e = E::B(0)
 match e { A => 0; B(x) => x } }
}
fn main { println(f(true)) }
```

它包含条件内部的局部绑定、枚举构造和字段读取 match。在固定环境下 release 构建失败，native debug / wasm-gc debug 均成功输出
`0` + LF。删除条件分支中的 `let t = false;`，或将 `B(x) => x` 改为 `B(x) => 0`，所得两份对照均 release 构建、
执行成功并输出 `0` + LF。这两次改动只说明对应变体消除了该小程序的触发表征，不证明相关结构在其他程序中都是必要条件；
三例各自的缩减路径没有汇合到这段文本。

### 独立复现步骤

使用上述固定版本的工具链，在新目录中将小程序逐字保存为 `main.mbt`，再写入以下三个描述符。独立 `moon.work` 用于隔离工作区：

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

最后一条命令退出 255，stderr 包含两处未声明 `_M0L6constrS84` 的诊断；具体编号和源位置只描述这次观察。生成的 C 位于
`_build/native/release/build/generated.c`。再分别验证 native debug 和 wasm-gc debug：

```shell
moon build --target native --debug
./_build/native/debug/build/generated.exe
moon build --target wasm-gc --debug
moonrun ./_build/wasm-gc/debug/build/generated.wasm
```

两次构建和两次执行的实测退出码均为 0，两次 stdout 都是十六进制 `30 0a`，即 `0` + LF。上述步骤也适用于前述三份缩减源码，
其成功配置输出同为 `0` + LF。

## 编译阶段对照

阶段实验仅对 189 字节小程序进行。release 生成 C 中，`_M0L6constrS84` 有两次引用而没有声明：

```c
moonbit_decref_cycle_free(_M0L6constrS84);
/* another branch */
struct _M0DTP29moonsmith9generated1E1B* _M0L4_2aBS83 =
  (struct _M0DTP29moonsmith9generated1E1B*)_M0L6constrS84;
```

这支持“到达 C 编译器的输入已经不合法”，不能单凭这些代码定位导致它的编译器变换。
对照以 `moon build --target native --release --dry-run` 给出的编译链为准：
固定 release 生成的 C 或 core，仅修改所列阶段的优化参数，并使用新的产物路径。
其他输入、编译器和链接参数保持一致；没有生成 C 的尝试不能用于判断 C 编译结果。

| 固定输入与单项改动 | 实测结果 | 证据范围 |
| --- | --- | --- |
| 原始 release 流水线 | `moon build` 退出 255，目标未声明变量诊断 | 小程序复现该表征 |
| 同一份 release C，C 编译命令仅改用 `cc -O0` | C 编译退出 1，仍有同样两处未声明变量诊断 | 降低 C 优化不能修复此输入 |
| 同一份 release core，`moonc link-core -O0` 后编译 C | link 退出 0，C 编译退出 1，保持目标诊断 | 仅关闭该阶段优化不能消除问题，未定位具体 pass |
| `build-package -O0` 与 `link-core -O0` 同时使用 | 生成 C，C 编译退出 1，报重复标签 `join_84` | 不同诊断，不能算原失败保持或同根因证据 |
| `build-package -O0` 后按默认参数链接 | link 退出 1，stdout / stderr 均为空，未生成 C | 输入存在但原因未明，不用于因果推断 |

没有“关闭 MoonBit 优化后通过”的结论；本次未检查上游源码、问题单或更新版本，未确定该问题是否已在上游修复。
三例诊断相同不证明同一根因。

## 相关实现

构建异常的当前 CLI 判据、归约、证据保存及退出码见[CLI 模块说明](../modules/cli/README.md#差分执行与存证)。
本调查的手工缩减与阶段对照不等同于产品执行结果。

## 证据范围

原始逐次执行数据未随源码发布；本记录的结论仅以列出的源码、复现命令、观察和阶段对照为范围。

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

诊断模式相同、源码更短及独立确认通过分别支持故障表征的可重现性、局部缩减及输入重执行；不证明唯一根因、全局最小或产品归约能力。
