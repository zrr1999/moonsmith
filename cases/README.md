# 固定回归案例

每个案例默认只有 `main.mbt` 与 `case.toml`，按语言和稳定案例 ID 保存。
源码是被测输入，不加入 `moon.work`，不随发布库打包。需要多文件或特殊构建设置时，
先验证具体需求，再扩充案例和执行支持。

## MoonBit 案例

| 案例 | 预期行为 | 公开来源 |
| --- | --- | --- |
| [moonbit-docs-1006](moonbit/moonbit-docs-1006/main.mbt) | 字符串尾部模式绑定最后一个字符，输出 `n` | [上游问题 #1006](https://github.com/moonbitlang/moonbit-docs/issues/1006)，上游讨论指向 core 修复 |
| [moonbit-docs-1070](moonbit/moonbit-docs-1070/main.mbt) | 选择正零分支后，Double 的 Int64 位表示为 `0` | [上游问题 #1070](https://github.com/moonbitlang/moonbit-docs/issues/1070) |
| [moonbit-docs-1266](moonbit/moonbit-docs-1266/main.mbt) | 管道向二元 tuple struct 构造器传参可编译，正常退出且无输出 | [上游问题 #1266](https://github.com/moonbitlang/moonbit-docs/issues/1266) |

三个源码均依据公开问题独立编写，使用本仓库的 GPL-3.0-only 许可证；保留来源，
不将上游问题状态或故障注入当作本次复现证据。引入第三方原始源码时另行保留其许可说明。

## 案例元数据

`case.toml` 是仓库回归测试的输入，包含：

- `source`：公开问题来源，必填。
- `reported_compiler`：上游报告中的编译器版本，可省略；不表示已在该版本实测。
- `configurations`：本例实际检查的配置，按数组顺序执行。
- `expected_stdout`：成功构建、正常退出时应得到的完整 stdout，保留换行；无输出写空字符串。

当前执行支持独立、无外部依赖的单文件程序，以及现有 native debug、native release、
wasm-gc debug 配置中的至少两个。配置重复、未知字段或缺少预期会在该例编译前报错。
预期来自案例语义；多个配置输出一致仍可能不符合预期。

## 执行与记录

从仓库根目录运行：

```shell
moon test modules/cli/src/app/regression_wbtest.mbt --target native
```

`just test` 同样执行这些案例。执行器使用当前 `PATH` 中的工具链，不自动安装或恢复
`reported_compiler`。TOML 读取使用已发布的 `moonbit-community/toml@0.5.0`，仅由测试包导入。

每次执行创建新的 `runs/historical-<id>/`，复制案例源码和元数据，准备通用构建文件。
各例保存 `attempt.json` 和 `report.md`，包含实际工具链、平台、命令、原始输出与判定。
完成该例的执行与存证后，即使结果不符合预期也继续其余案例，最后汇总失败。
测试不覆盖原案例或旧记录；`attempt.json` 最后写入，缺少它表示该次材料尚未完整保存。

历史回归记录供检查与归档，区别于现有生成案例的 `case.json`；CLI 的 `run`、`replay`
仍使用原有材料格式。旧版本复现按公开来源单独验证，必要记录长期保留在验收材料中，
不把日常运行目录全部纳入 Git。

首批案例在 `v0.10.14+7d59c7ec9` 上的三配置检查，以及 #1266 在正式发布的
`v0.10.0+e66899a54` Wasm 编译器上的崩溃复现与对照实验，见
[历史回归验收记录](../.agents/notes/research/historical-regressions.md)。
