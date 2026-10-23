# CLI 源码安装验证报告

本报告记录 2026-10-21 对完整源码快照 `dae0ff260204aae1dc1e5004e1dd2faa16916d6b` 的安装与仓库外运行验证。目标是确认：从不含构建产物的源码快照安装 native CLI 后，可在工作区外显示帮助、完成单样本五配置任务，并重放保存的案例。

## 环境与方法

| 条件 | 实测值 |
| --- | --- |
| 宿主 | Darwin 27.0.0 arm64 |
| Moon / moonrun | `0.1.20260920`，提交 `914d7da` |
| 编译器与 core | `0.10.14+7d59c7ec9` |
| 外部依赖 | async `0.22.4`、toml `0.5.0`；使用宿主下载缓存 |
| Node.js | 初始运行 `v26.8.1`；另一命令环境的重放为 `v26.3.1` |

从仓库根目录导出被测 revision 的已跟踪文件；导出内容不含 `.mooncakes` 与 `_build`。以下命令创建独立的临时安装根目录和工作目录：源码快照与可执行文件位于安装根目录下，任务从其外部工作目录启动。

```shell
MOONSMITH_VALIDATION_ROOT=$(mktemp -d)
MOONSMITH_VALIDATION_WORK=$(mktemp -d)
SOURCE_DIR="$MOONSMITH_VALIDATION_ROOT/source"
INSTALL_DIR="$MOONSMITH_VALIDATION_ROOT/bin"
mkdir -p "$SOURCE_DIR" "$INSTALL_DIR"
git archive dae0ff260204aae1dc1e5004e1dd2faa16916d6b | tar -x -C "$SOURCE_DIR"
(cd "$SOURCE_DIR" && moon install ./modules/cli/src/cmd/moonsmith --bin "$INSTALL_DIR")

(cd "$MOONSMITH_VALIDATION_WORK" && "$INSTALL_DIR/moonsmith" --help)
(cd "$MOONSMITH_VALIDATION_WORK" && "$INSTALL_DIR/moonsmith" run \
  --set seed_start=42 \
  --set sample_count=1 \
  --set 'execution.configurations=["native-debug","native-release","wasm-gc-debug","wasm-debug","js-debug"]' \
  --set 'output.directory="evidence"')
# 将此值替换为任务输出报告的已保存案例目录。
CASE_DIR=/absolute/path/to/saved-case
(cd "$MOONSMITH_VALIDATION_WORK" && "$INSTALL_DIR/moonsmith" replay "$CASE_DIR")
```

最后一条命令使用前一步保存材料中报告的案例目录。安装由快照内 `moon.work` 解析内部模块，外部模块使用声明的正式版本。运行和重放均从独立工作目录发起，不切换回源码快照。

## 预期与实测结果

| 检查 | 预期 | 实测 |
| --- | --- | --- |
| 安装 | 生成独立 native `moonsmith` 可执行文件 | 成功 |
| `--help` | 退出码 0，列出统一任务配置与五个配置名称 | 符合 |
| 单样本任务 | 种子 42、默认生成预算、五配置完成比较 | 计划、内部检查、基线编译接受、完整比较及一致均为 1；操作错误为 0，退出码 0 |
| 样本处理时间 | 记录单调时钟耗时 | 1448 毫秒 |
| 保存案例重放 | 新增独立尝试且五配置结果一致 | 退出码 0，五配置继续一致 |
| 已有材料完整性 | 比较案例、原始源码、原始尝试与任务汇总的 SHA-256 | 四项均保持不变 |

在另一宿主命令环境重放同一案例时，Node.js 实际版本为 `v26.3.1`，初始运行版本为 `v26.8.1`。工具正确提示版本变化，五配置结果仍一致；每次版本均来自实际探测。重放追加独立尝试，不覆盖原记录。

## 结论与边界

该验证确认完整源码安装、工作区外启动、五配置单样本执行及保存源码重放路径可用。它使用宿主已安装的 MoonBit、Node.js 和用户级依赖下载缓存；没有验证全新操作系统上的工具链安装。单样本耗时不代表性能基准，也不计作项目规模验收。

安装入口和用户可见安装要求见[根目录安装说明](../README.md#安装)；CLI 的案例、尝试与重放存储行为见[差分执行与存证](../modules/cli/README.md#差分执行与存证)。项目规模目标见[项目申报书](project-proposal.md#预期验收产物)。
