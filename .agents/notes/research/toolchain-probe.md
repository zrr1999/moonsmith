# 工具链与依赖探针

核查日期：2026 年 10 月 9 日。探针放在当时任务目录的 `work/dependency-probe/`、
`work/semantic-probe/` 与 `work/semantic-invalid/`，没有纳入本仓库，下列通过次数不能从当前工作区重跑。

2026 年 10 月 18 日对照仓库里的 `moon.mod`、CLI 参数解析、生成器随机源和 Host 进程实现，
区分当时的接口观察与后来实际采用的依赖。本文保留来源观察，不另写一套生成、判定或归约契约。
现行依赖与进程边界见 [CLI 模块说明](../../../modules/cli/README.md#差分执行与存证)。

## 1 探针环境

| 环境项 | 当时基线 |
| --- | --- |
| 宿主 | macOS arm64，目标 native |
| 编译器 | `moonc v0.10.14+7d59c7ec9` |
| 构建工具 | `moon 0.1.20260920` |
| 标准库 | `0.1.20260920+7d59c7ec9` |
| 外部模块 | `async 0.22.4`、`x 0.5.5`、`toml 0.5.0`、`jsonl 0.2.1`、`parser 0.4.3` |

依赖探针执行 `moon -C work/dependency-probe test --target native --deny-warn`，结果为 11 项通过、0 项失败。
QuickCheck 属性检查跑了 100 个样本。运行中出现目标声明诊断和 macOS 归档工具的空目标文件提示。
该次检查没有覆盖 Linux/Windows、整棵进程树、无限输出、并发竞争或完整格式合规性。

## 2 依赖接口观察

| 检查 | 观察结果 |
| --- | --- |
| CLI 子命令及错误选项 | 用 `moonbitlang/core/argparse` 取得 seed，拒绝未知选项 |
| 显式随机种子 | `quickcheck/splitmix` 同种子连续 32 个值相同；当次派生流首值不同 |
| JSON 性质测试 | 100 个 `Array[Int]` 经标准库 JSON 编解码往返一致 |
| 摘要与路径 | `x@0.5.5` 的 SHA-256 对 `abc` 的已知向量匹配，`x/path` 拼接符合预期 |
| TOML 配置 | `moonbit-community/toml@0.5.0` 解析 seed 和 target 列表，拒绝重复键 |
| JSONL 记录 | `moonbitlang/jsonl@0.2.1` 读出两条记录，拒绝截断尾行 |
| 子进程结果 | stdout/stderr 分离，退出码 7 保留，参数中的空格和分号不被 shell 解释 |
| 环境变量 | 关闭继承后只传入指定变量 |
| 文件操作 | 写入、重命名、读取和清理成功 |
| 直接子进程取消 | 被测 sleep 被终止，取得信号对应状态 -9 |
| 直接子进程超时 | 50 ms 超时返回，整个调用在 3 秒内结束 |

`async@0.22.4` 的 POSIX 取消对直接子进程执行 `kill(pid, signal)`，该实现没有建立进程组，
也不回收整棵后代进程树；默认取消还包含最长 5 秒的优雅退出等待。
`collect_output` 一类接口通过 `read_all()` 收集输出，没有总字节限额。
来源：[进程 API](https://mooncakes.io/docs/moonbitlang/async/process)、
[当时查阅的 Unix 实现](https://github.com/moonbitlang/async/blob/main/src/process/unix.c)。
`main` 分支可能继续变化，这条观察对应 2026 年 10 月 9 日看到的发布源码。

TOML 库依赖 `bobzhang/lexer@0.3.0`。上游报告通过 736/745 项 `toml-test`，本次没有重跑完整合规套件。
JSONL 不承担追加写入事务、尾部损坏恢复或记录长度限制。
`parser@0.4.3` 的独立项目把传递依赖解到 `x@0.5.1` 和 `async@0.22.4`；没有验证它与 `x@0.5.5` 的组合。

## 3 对照当前仓库

| 当时的候选 | 当前仓库 |
| --- | --- |
| `core/argparse` | CLI 自行解析 `run`、`--seed` 和 `replay`，见 `modules/cli/src/cmd/moonsmith/cli.mbt` |
| `quickcheck/splitmix` | 生成器使用标准库 `Rand::chacha8` |
| `core/quickcheck` | 未作为产品依赖；行为测试使用 MoonBit 测试入口 |
| 标准库 JSON | Contracts 与案例记录继续使用标准库 JSON |
| `async@0.22.4` | `modules/cli/moon.mod` 声明此版本。Host 对每个输出流设置字节上限，并回收直接子进程 |
| `x@0.5.5` 的 `crypto`、`path` | 四个模块的 `moon.mod` 都没有导入 |
| TOML、JSONL、parser | 四个模块的 `moon.mod` 都没有导入 |

Host 已补上输出字节上限和直接子进程超时回收。整棵进程树隔离仍未实现，与上面的 `async` 源码观察一致；
[CLI 模块说明](../../../modules/cli/README.md#差分执行与存证)把它排除在任意源码沙箱之外。

## 4 官方工具边界

同一工具链上的另外三项检查：

- `parser@0.4.3` 的 3 项边界测试通过：类型错误和未绑定名称不产生解析诊断；残缺语法产生解析诊断。
  解析成功不代表名称已解析或类型正确。[parser 文档](https://mooncakes.io/docs/moonbitlang/parser)
- `pub fn bad() -> Int { true }` 上，`moon check --json --target native` 返回退出码 1、`status=failure`、错误码 4014，并指出 `Bool` 与 `Int` 不一致。
- 样例中的 `selected`：`moon ide hover` 返回的 `contents` 仍是 Markdown 类型文本，本次内容为 `Int`；`peek-def` 定位到对应局部绑定。JSON 外壳不是稳定的类型树协议，位置查询必须绑定源码版本。
- `moon info` 输出 `pub fn describe(Int) -> (Int, Bool)`，没有局部变量和函数体。

官方编译器仓库在提交
[d4ada10](https://github.com/moonbitlang/moonbit-compiler/tree/d4ada10d212b5376f7f8bf49cd2fbaa275a395df/src)
包含 `typedtree.ml`、`typer.ml` 等 OCaml 实现。该树组织为编译器可执行程序，直接复用内部类型检查器会带上跨语言集成和版本耦合；其许可证也不同于 Apache-2.0 的 parser。
当时因此选择通过命令接口调用。这条边界仍是后续源码导入的前置观察，不表示当前生成路径已经接入 parser 或 `moon ide`。
