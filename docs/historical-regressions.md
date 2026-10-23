# 历史回归验收记录

本报告记录 2026-10-18 的三个固定输入参考检查，以及一个旧版编译器故障复现。
2026-10-20 完成输入、单一改写对照、退出码与归档 SHA-256 复核，归档与官方发行资产的 digest 一致。
报告将上游来源、固定版本验证和旧版复现分别列证；固定输入与消费方式见
[案例说明](../cases/README.md)。

## 来源与检查范围

| 案例 | 来源事实 | 记录结果 |
| --- | --- | --- |
| [#1006](https://github.com/moonbitlang/moonbit-docs/issues/1006) | 上游报告 `v0.6.28+d96d14d39` 在 Windows 上将字符串尾部字符错误绑定为首字符；讨论指向 [core 修复 #2822](https://github.com/moonbitlang/core/pull/2822) | 独立改写为 `"moon"` 的尾部匹配，期望 `n`；验证版本三配置通过；未执行原始版本 |
| [#1070](https://github.com/moonbitlang/moonbit-docs/issues/1070) | 上游报告正零分支产生负零位模式，未注明编译器版本 | 独立编写正零分支案例，期望 Int64 位表示 `0`；验证版本三配置通过；不猜测受影响版本范围 |
| [#1266](https://github.com/moonbitlang/moonbit-docs/issues/1266) | 上游报告 `v0.10.0+e66899a54` 编译管道向 tuple struct 构造器传参时内部断言失败 | 独立改写为 `7 |> Pair(9)`；验证版本三配置通过；同版本正式 Wasm 编译器真实复现，直接构造对照编译成功 |

这是三个公开问题候选、一个旧版真实复现，以及三个固定版本回归检查。
其中 #1006 涉及标准库修复，不把它单独归因为编译器缺陷；这些检查未发现新的编译器缺陷。
案例未导入生成器的 AST，也没有进行结构化归约。

## 固定版本验证结果

环境为 macOS 27.0.1 arm64，`uname -srm` 为 `Darwin 27.0.0 arm64`。

```text
moon 0.1.20260920 (914d7da 2026-09-20)
moonc v0.10.14+7d59c7ec9 (2026-09-18)
moonrun 0.1.20260920 (914d7da 2026-09-20)
```

复现入口为 `moon test modules/cli/src/app/regression_wbtest.mbt --target native`。
每例完成 native debug、native release、wasm-gc debug 的构建和执行，共 9 次构建、9 次执行。
三个判定均为 `Match`，分别匹配完整输出
`"n\n"`、`"0\n"` 与空字符串，保留原始案例。

原始 JSON 保存在本地忽略的运行目录，未随仓库发布。各例记录包含工具链、平台、
全部命令和 stdout/stderr；本页保留环境、步骤、关键输出与范围限制，读者可用仓库中的
[固定输入](../cases/README.md)及以下正式发行版重新执行。

## #1266 旧版复现与对照

受影响编译器来自官方正式发布
[v0.10.0+e66899a54](https://github.com/moonbitlang/moonbit-compiler/releases/tag/v0.10.0%2Be66899a54)，
使用该 release 的 `moonbit-wasm.tar.gz`。实测 SHA-256 与 GitHub asset 的 digest 相同：

```text
35499cef777568f6d18ad65b777c67f688f4d857b8fa9efbed40d978cab32bdf
```

执行环境为上述 macOS arm64、Node `v26.3.1`。归档内编译器自报
`v0.10.0+e66899a54 (2026-06-09)`；直接调用该编译器，目标显式设为 `wasm-gc`。
这个无标准库调用的案例无需安装配套 Moon 和 core。复现方法使用隔离的旧版编译器，不要求替换宿主工具链。

可在仓库根目录重现：

```shell
mkdir -p .tools runs
HIST_TOOLCHAIN=$(mktemp -d "$PWD/.tools/moonbit-0.10.0-XXXXXX")
HIST_RUN=$(mktemp -d "$PWD/runs/historical-old-XXXXXX")
gh release download 'v0.10.0+e66899a54' \
  --repo moonbitlang/moonbit-compiler --pattern moonbit-wasm.tar.gz \
  --dir "$HIST_TOOLCHAIN"
shasum -a 256 "$HIST_TOOLCHAIN/moonbit-wasm.tar.gz"
tar -xzf "$HIST_TOOLCHAIN/moonbit-wasm.tar.gz" -C "$HIST_TOOLCHAIN"
node --stack-size=4096 "$HIST_TOOLCHAIN/moonc.js" -v
cp cases/moonbit/moonbit-docs-1266/main.mbt "$HIST_RUN/main.mbt"
node --stack-size=4096 "$HIST_TOOLCHAIN/moonc.js" compile "$HIST_RUN/main.mbt" \
  -target wasm-gc -w -unused_constructor -o "$HIST_RUN/main.wasm" \
  > "$HIST_RUN/stdout.txt" 2> "$HIST_RUN/stderr.txt"
```

案例编译退出码为 **199**，stdout 为空，stderr 的关键原始内容为：

```text
Oops, the compiler has encountered an unexpected situation.
This is a bug in the compiler.

A bug report containing the error description and relevant code would be
greatly appreciated. You can submit the bug report here:

  https://github.com/moonbitlang/moonbit-docs/issues/new?template=ice.md

Error: File "moonc.ml", line 271835, characters 24-30: Assertion failed
```

只把同一源码中的 `7 |> Pair(9)` 改为 `Pair(7, 9)`，保留其他输入、编译器及参数：

```shell
sed 's/7 |> Pair(9)/Pair(7, 9)/' "$HIST_RUN/main.mbt" > "$HIST_RUN/control.mbt"
node --stack-size=4096 "$HIST_TOOLCHAIN/moonc.js" compile "$HIST_RUN/control.mbt" \
  -target wasm-gc -w -unused_constructor -o "$HIST_RUN/control.wasm"
```

对照编译退出码为 **0**，stdout、stderr 均为空。原始 JSON、输入和对照源码仅保存在本地
运行目录，未纳入版本控制。保存输入与当前案例一致，对照只替换上述一处调用形式；归档
SHA-256 与官方 release asset 的 digest 一致。
该结果支持 #1266 所述触发模式在此正式编译器中的真实复现；验证版本的三配置通过
另外记录，不据此推断精确修复版本或其他平台行为。

## 结果边界

案例 #1006 涉及标准库修复；#1070 的上游报告未注明受影响编译器版本。本记录没有执行这两例的
原始受影响版本，也不推断完整版本范围。#1266 的旧版证据仅覆盖上述 Wasm 编译器与目标，
不能由验证版本三配置通过推断精确修复版本或其他平台结果。

历史输入没有导入生成器的 AST，也未作结构化归约。这些结果不能替代随机生成再发现、
真实缺陷归约或申报书要求的完整样本量与工具链矩阵。
