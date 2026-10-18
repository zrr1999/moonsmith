# 首批历史回归验收

2026-10-18。用户确认优先推进历史回归，并选择每例默认只保留 `main.mbt` 和
`case.toml`。本轮落实已有申报书的案例验收，不新增 FP、公共 CLI 入口或跨仓库协议。
案例格式与执行说明统一维护在[案例入口](../../../cases/README.md)。

## 来源与检查范围

| 案例 | 来源事实 | 本轮检查 |
| --- | --- | --- |
| [#1006](https://github.com/moonbitlang/moonbit-docs/issues/1006) | 上游报告 `v0.6.28+d96d14d39` 在 Windows 上将字符串尾部字符错误绑定为首字符；讨论指向 [core 修复 #2822](https://github.com/moonbitlang/core/pull/2822) | 独立改写为 `"moon"` 的尾部匹配，期望 `n`；当前三配置通过；未执行原始版本 |
| [#1070](https://github.com/moonbitlang/moonbit-docs/issues/1070) | 上游报告正零分支产生负零位模式，未注明编译器版本 | 独立编写正零分支案例，期望 Int64 位表示 `0`；当前三配置通过；不猜测受影响版本范围 |
| [#1266](https://github.com/moonbitlang/moonbit-docs/issues/1266) | 上游报告 `v0.10.0+e66899a54` 编译管道向 tuple struct 构造器传参时内部断言失败 | 独立改写为 `7 |> Pair(9)`；当前三配置通过；同版本正式 Wasm 编译器真实复现，直接构造对照编译成功 |

这是三个公开问题候选、一个旧版真实复现，以及三个当前工具链回归检查。
其中 #1006 涉及标准库修复，不把它单独归因为编译器缺陷；本轮未发现新的编译器缺陷。
案例未导入生成器的 AST，也没有进行结构化归约。

## 当前工具链结果

环境为 macOS 27.0.1 arm64，`uname -srm` 为 `Darwin 27.0.0 arm64`。

```text
moon 0.1.20260920 (914d7da 2026-09-20)
moonc v0.10.14+7d59c7ec9 (2026-09-18)
moonrun 0.1.20260920 (914d7da 2026-09-20)
```

执行 `moon test modules/cli/src/app/regression_wbtest.mbt --target native`，实际执行两项测试：
历史案例执行与元数据负例，两项通过。每例都完成 native debug、native release、wasm-gc debug
的构建和执行，共 9 次构建、9 次执行。三个判定均为 `Match`，分别匹配完整输出
`"n\n"`、`"0\n"` 与空字符串，保留原始案例。

代表性原始记录在本任务工作区 `runs/historical-39361da5f1abcf6cbbed2ba623c1f404/`，
后续重跑创建独立目录，不覆盖该记录。工具链版本、平台、全部命令和 stdout/stderr
在各例的 `attempt.json` 中；这些日常运行产物不纳入 Git。

另做一次明确的负向检查：临时将 #1006 的预期改为错误字符串，执行后恢复原始元数据。
测试非零退出，#1006 被判为 `Mismatch`，其余两例仍执行并保存 `Match` 记录；
证据位于 `runs/historical-8b2d0fdd3806d67e90c6ef92f79612a1/`。
这只验证预期判定与失败后继续执行，不计作真实编译器问题复现。

## #1266 旧版复现与对照

受影响编译器来自官方正式发布
[v0.10.0+e66899a54](https://github.com/moonbitlang/moonbit-compiler/releases/tag/v0.10.0%2Be66899a54)，
使用该 release 的 `moonbit-wasm.tar.gz`。实测 SHA-256 与 GitHub asset 的 digest 相同：

```text
35499cef777568f6d18ad65b777c67f688f4d857b8fa9efbed40d978cab32bdf
```

执行环境为上述 macOS arm64、Node `v26.3.1`。归档内编译器自报
`v0.10.0+e66899a54 (2026-06-09)`；直接调用该编译器，目标显式设为 `wasm-gc`。
这个无标准库调用的案例无需安装配套 Moon 和 core。当前系统工具链未被替换。

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

对照编译退出码为 **0**，stdout、stderr 均为空。原始 JSON、复制的输入和对照源码保留在
本任务工作区 `runs/historical-1266-old-762fcd57de344e1786be986d8c8d1b36/`。
该结果支持 #1266 所述触发模式在此正式编译器中的真实复现；当前版本的三配置通过
另外记录，不据此推断精确修复版本或其他平台行为。

## 获取限制与维护边界

本轮请求官方分发站上 `0.10.0+e66899a54` 的 Darwin arm64 二进制归档及配套 core 归档，
两者均返回 HTTP 403。没有采用开发分支、私有补丁或替换当前依赖；使用了可取得的
同版本正式 Wasm 编译器。其他旧版本尚未取得实测证据。

回归装配在 CLI app 的测试包内，TOML 使用正式发布的
`moonbit-community/toml@0.5.0`；执行复用 `toolchains/moon` 与 Host，明确预期由
Engine 判定。原始输入保持只读，运行材料追加保存。新增代码与案例整理使用了 AI 辅助，
上述输出、版本、摘要及对照结果均经真实命令执行与核对。
