# 发行与验收

MoonSmith 的四个模块共用一个版本号。发布从已合入 `main` 的固定提交构建，工具链及宿主依赖见
[安装要求](../README.md#安装)。预编译程序覆盖 macOS arm64 与 Linux x86_64，分别在 macOS 15
与 Ubuntu 24.04 的官方 runner 上构建。

## 工作流职责

| 工作流 | 职责 |
| --- | --- |
| [CI - Static Checks](../.github/workflows/ci-static-checks.yml) | 仓库静态门禁与 CodeQL |
| [CI - Tests](../.github/workflows/ci-tests.yml) | 行为测试、覆盖率与双平台固定旧工具链的历史复现 |
| [CI - Acceptance](../.github/workflows/ci-acceptance.yml) | 双平台解包测试、库消费、仓库外安装与五配置验收 |
| [CD - Publish](../.github/workflows/cd-publish.yml) | PR 与标签的构建、打包和包体验证；仅标签执行正式发布 |
| [CI - Distribution](../.github/workflows/ci-distribution.yml) | 已发布二进制下载、registry 安装与重放验收 |

CI 的检查结果和验收材料由对应运行保存。维护者在发布前确认最终提交的结果；CD 不调用测试、
验收或历史复现工作流，也不重新执行它们。

## PR 发布构建

每个指向 `main` 的 PR 创建、更新或重新打开时，都会触发 CD 的双平台 `build` job。
它与正式发布共用 native release 构建、CLI 打包、解包启动检查和四模块打包检查。
最终 `publish` job 在 PR 上跳过，只有推送版本标签才能执行。

PR 产物文件名包含版本、PR 编号与实际检出提交的短 SHA，例如
`moonsmith-0.0.1-pr.49-COMMIT-macos-arm64.tar.gz`。默认检出 GitHub 的 PR 合并测试提交，
完整提交身份写入 `build.json`，便于区分 PR 更新及基线变化。
两个平台的 CLI 与模块 zip 包保存为 Actions artifacts，保留 21 天。
构建只需要只读权限，也适用于 fork PR；凭据只属于标签发布 job。

重跑使用相同构建步骤，不修改模块版本、Git 标签或 registry。
产物按 workflow run 隔离，同一运行重跑时替换该平台的同名 artifact；
PR 的新提交取消该 PR 的旧构建，正式发布之间继续串行执行。

## 产品验收

在最终提交上手动运行 `CI - Acceptance`，启用 `full_acceptance`。该工作流也在发行相关 PR 中运行
较小的验收，并在主分支推送后运行；PR 结果不能代替合入后最终提交的完整验收。

包验收参考 MoonBit 官方 [x 的工作流](https://github.com/moonbitlang/x/blob/main/.github/workflows/package.yml)，
直接使用 MoonBit 命令在两个平台验证：

- 通过 `moon work sync` 检查内部依赖版本，打包四模块后解包到仓库外。
  README、许可证和模块清单与原文件一致；类型检查和全部原生行为测试使用解包后的源码与 C 文件。
  测试所需固定案例和任务配置另行复制，不将仓库产品源码混入包验收。
- 独立的库消费程序可以生成等价组并调用 Engine；CLI 可以从解包模块安装。
- 安装后的程序执行种子 42 的五配置普通任务和等价任务；搬迁材料后重放仍成功，
  原始文件保持不变，新执行及组记录追加。
- 完整验收执行种子 0–99 的五配置等价检查，记录每份源码、配置、原始观察和任务汇总。
- 当前编译器分别执行种子 1272、3745、6968；存在独立确认材料时再次重放，保存实际结果。

静态检查、覆盖率和性能基准由各自 CI/CE 负责。`CI - Tests` 用 `0.10.18` 构建 MoonSmith，再分别调用
`0.10.14+7d59c7ec9` 和 `0.10.10+f8a486b6f`。`0.10.14` 在仓库外验证三例构建异常的自动归约、独立确认和重放；
入口见[贡献指南](../CONTRIBUTING.md#变更与验证)。

本地可直接使用工作流中的 MoonBit 命令检查解包模块，或对已安装程序运行共享的入口：

```shell
bash scripts/check-installed.sh /absolute/path/to/moonsmith /tmp/moonsmith-installed-check
```

输出目录必须尚不存在，用于保留执行日志、原始材料和重放结果。该入口由包验收与已发布产物验收共用，
依赖 Bash、jq 和 SHA-256 工具。验收不维护自定义 Python 框架。

## 正式发布

正式发布前由维护者确认具体提交、版本和验收结果。通过 GitHub 仓库的安全入口配置
`MOONCAKES_CREDENTIALS`，其内容为拥有四模块发布权限的 Mooncakes 凭据 JSON。

推送该提交的 `vVERSION` 标签后，`CD - Publish` 完成：

1. 核对标签指向检出提交、提交属于 `main`、四模块版本与标签一致，并存在对应发行说明。
2. 在两个平台执行与 PR 相同的 native release 构建、打包、解包启动和模块归档检查。
3. 创建或复用该标签的 Draft Release，按 contracts → engine → moonbit → CLI 顺序直接运行
   `moon publish`。任一模块失败即停止后续发布。
4. 为两份 CLI 附件生成 `SHA256SUMS`，上传附件并公开 GitHub Release。

发布沿用官方 [async](https://github.com/moonbitlang/async/blob/main/.github/workflows/publish.yml)
和 [x](https://github.com/moonbitlang/x/blob/main/.github/workflows/publish.yml) 的 `moon publish` 入口。
凭据只在发布步骤临时写入 `MOON_HOME/credentials.json`，权限为 `0600`，
步骤结束时清除。已经公开的 Release 不作为 Draft 覆盖。部分模块发布成功后发生失败时，成功版本
仍保留在 Mooncakes；先核实 registry 状态再处理剩余发布，流程不会自动跳过或覆盖已存在版本。

## 产物与材料

| 文件或位置 | 内容 |
| --- | --- |
| `moonsmith-VERSION-macos-arm64.tar.gz` | macOS arm64 CLI、许可证、README 及构建身份 |
| `moonsmith-VERSION-linux-x86_64.tar.gz` | Linux x86_64 CLI、许可证、README 及构建身份 |
| Release 中的 `SHA256SUMS` | 上述两份 CLI 附件的 SHA-256 |
| `CI - Acceptance` 的 `acceptance-PLATFORM` artifact | 模块包、解包测试、当前产品任务与安装重放材料 |
| `CI - Tests` 的历史证据 artifact | 固定旧工具链的异常复现、归约、确认和重放记录 |
| `CI - Distribution` 的 `distribution-PLATFORM` artifact | 已发布二进制与 registry 安装的验收材料 |

下载 CLI 附件后，macOS 使用 `shasum -a 256 -c SHA256SUMS`，Linux 使用
`sha256sum -c SHA256SUMS` 校验。校验和列出两个平台附件，完整校验时应一并下载。

验收材料使用标准 `tar` 归档并由 GitHub Actions artifact 保存，构建缓存不入包。
历史异常的生成 C 文件随历史证据保存。执行记录可能包含当时的绝对路径，重放时使用实际解包位置。
组内材料关联使用相对路径，可随所属案例一起搬迁：

```shell
moonsmith replay /absolute/path/to/case-directory
moonsmith replay /absolute/path/to/group-directory
```

原万例实验与人工调查材料独立归档，其摘要见[历史材料清单](../.github/release-evidence.json)，
可在历史压缩包所在目录使用 `jq` 和 `shasum` 校验：

```shell
jq -r '"\(.sha256)  \(.file)"' /absolute/path/to/moonsmith/.github/release-evidence.json |
  shasum -a 256 --check -
```

需要长期公开的 CI 或历史材料由维护者单独附到 Release，不影响 CD 的发布职责。
适用版本与原始结果见[规模验收](acceptance-validation.md)、[归约演示](reduction-demonstration.md)
和[构建异常分析](native-release-analysis.md)。

## 已发布产物验收

`CI - Distribution` 按已发布标签手动触发，以只读权限检出该标签的提交。它下载两份 CLI
附件并校验摘要，在各自平台解包运行五配置普通任务与等价任务，再从 Mooncakes 安装精确版本，
验证库消费、CLI、材料搬迁和重放。结果与失败材料保留在 CI，不阻塞或撤回已经完成的发布。

正式安装方式和实测结果核对完成后，再更新根 README 的实际安装入口。
