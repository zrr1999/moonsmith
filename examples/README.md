# MoonSmith 示例

先按[安装说明](../README.md#安装)安装 MoonSmith 0.0.1、MoonBit/core
`0.10.18+6c83a7f62` 和 C 编译器。五配置示例还需要 Node.js。

## 生成、五配置比较与重放

从仓库根目录执行单样本任务：

```shell
moonsmith run --config examples/quickstart.toml
```

[配置文件](quickstart.toml)固定种子 42，比较 native debug、native release、wasm-gc debug、
wasm debug 和 js debug。成功时退出码为 `0`，摘要显示一个样本、五个有效配置和保存材料路径。
任务目录的 `summary.json` 中，`attempted`、`generated_valid`、`baseline_accepted`、
`comparisons_complete`、`consistent` 均为 `1`，`operation_errors` 为 `0`。

把输出中的案例目录传给重放命令：

```shell
moonsmith replay runs/quickstart/task-<id>/cases/case-<id>
```

`<id>` 使用本次输出的实际值。案例目录中的 `case.json` 保存原始源码、生成参数与配置，
`attempts/` 保存每次执行的观察。重放追加一次尝试，保留原始材料。

增加等价程序检查时，使用同一个配置文件：

```shell
moonsmith run --config examples/quickstart.toml --set execution.equivalent_variants=true
moonsmith replay runs/quickstart/task-<id>/cases/case-<id>/groups/group-<id>
```

第二条命令使用本次摘要中的组目录。每个样本执行原程序与两个等价变体，各自覆盖五配置；
任务仍计为一个样本。组重放重新执行三个成员并追加组记录。

退出码 `2` 表示有效输出分歧，`3` 表示比较未完成，`1` 表示参数、生成或保存等操作错误。
遇到异常时保留报告和材料，不能将退出码直接解释为编译器缺陷。

## 作为库生成程序

[`library/main.mbt`](library/main.mbt)使用三个公开库：MoonBit 适配器生成固定种子的程序和
等价组，Contracts 表达成本与比较结果，Engine 在没有执行观察时返回 `Incomplete`。
示例打印成员身份、成本和可编译的 MoonBit 源码；它本身不调用被测编译器。

将独立示例复制到仓库外，从 Mooncakes 解析 `0.0.1` 依赖后运行：

```shell
EXAMPLE_ROOT=$(mktemp -d)
cp -R examples/library "$EXAMPLE_ROOT/library"
moon -C "$EXAMPLE_ROOT/library" update
moon -C "$EXAMPLE_ROOT/library" run . --target native --deny-warn
```

预期输出以 `Seed: 42` 开始，包含 `original`、`equivalent-1`、`equivalent-2` 三个成员，
随后是组成本、`Before execution: Incomplete` 和生成的完整源码。
`Incomplete` 表示尚无执行证据；真正的多后端执行使用上面的 CLI 示例。

## 归约与真实异常

- [受控归约演示](../docs/reduction-demonstration.md#目标输入与方法)运行真实编译器，
  注入指定输出差异，展示归约、独立确认和重放。
- [真实构建异常](../docs/reduction-demonstration.md#真实构建异常的产品演示)使用种子 1272，
  给出工具链、自动归约结果和重放入口。复现结果取决于被测编译器与平台。
- [历史回归案例](../cases/README.md)保存公开问题对应的输入与执行方式。

包验收与发布后验收复用本目录的库示例和 CLI 配置，验证仓库外运行、材料搬迁、追加式重放
及原始文件完整性，入口见[发行与验收](../docs/releasing.md)。
