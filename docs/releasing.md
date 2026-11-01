# 发行与验收

MoonSmith 的四个模块共用一个版本号。发布从已合入 `main` 的固定提交构建，工具链及宿主依赖见
[安装要求](https://github.com/zrr1999/moonsmith/blob/main/README.md#安装)。预编译程序覆盖 macOS arm64 与 Linux x86_64，分别在 macOS 15
与 Ubuntu 24.04 的官方 runner 上构建。

## 工作流职责

文件名前缀只表示触发条件。`ci` 监听 `push`、`pull_request` 和 `merge_group`，其中 `push` 可以省略。
`ce` 使用定时或手动触发。`cd` 可以包含与 CI 相同的检查，其余触发用于发版，例如推送版本标签。
`policy` 和 `automation` 不受这三项限制，触发也可以与 CI 相同。

| 工作流 | 职责 |
| --- | --- |
| [CI - Static Checks](https://github.com/zrr1999/moonsmith/blob/main/.github/workflows/ci-static-checks.yml) | 仓库静态门禁与 CodeQL |
| [CI - Tests](https://github.com/zrr1999/moonsmith/blob/main/.github/workflows/ci-tests.yml) | 行为测试、覆盖率与双平台固定旧工具链的历史复现 |
| [CD - Publish](https://github.com/zrr1999/moonsmith/blob/main/.github/workflows/cd-publish.yml) | PR 与标签的构建、包验收和打包；标签推送时完成种子 0–99 验收与签名后发布，再核对已发布产物 |

各工作流的检查结果和验收材料由对应运行保存。`All Required Checks Passed (Tests)` 和 `All Required Checks Passed (Static Checks)` 分别汇总对应工作流的上游 job，任一结果为 `failure` 时失败。合并规则还要求 `All Required Checks Passed (Policy)`。
推送版本标签后，构建和完整验收都通过才执行发布。
CD 不调用测试或历史复现工作流。

## PR 发布构建

每个指向 `main` 的 PR 创建、更新或重新打开时，都会触发 CD 的双平台 `build` job。
它与正式发布共用 native release 构建、CLI 打包、解包启动检查、四模块打包检查和包验收。
种子 0–99 的完整验收、`publish` 和已发布产物核对只在推送版本标签时执行。

PR 产物文件名包含版本、PR 编号与实际检出提交的短 SHA，例如
`moonsmith-0.0.1-pr.49-COMMIT-macos-arm64.tar.gz`。默认检出 GitHub 的 PR 合并测试提交，
完整提交身份写入 `build.json`，便于区分 PR 更新及基线变化。
两个平台的 CLI 与模块 zip 包保存为 Actions artifacts，保留 21 天。
构建只需要只读权限，也适用于 fork PR；凭据只属于标签发布 job。

重跑使用相同构建步骤，不修改模块版本、Git 标签或 registry。
产物按 workflow run 隔离，同一运行重跑时替换该平台的同名 artifact；
PR 的新提交取消该 PR 的旧构建，正式发布之间继续串行执行。

## 产品验收

`CD - Publish` 在指向 `main` 的 PR 上执行包验收。推送 `vVERSION` 标签时，同一验收额外执行种子 0–99
的完整验收；任一平台失败则不发布。PR 上的验收结果不能代替该标签上的完整验收。

包验收参考 MoonBit 官方 [x 的工作流](https://github.com/moonbitlang/x/blob/main/.github/workflows/package.yml)，
直接使用 MoonBit 命令在两个平台验证：

- 通过 `moon work sync` 检查内部依赖版本，打包四模块后解包到仓库外。
  README、许可证和模块清单与原文件一致；类型检查和全部原生行为测试使用解包后的源码与 C 文件。
  测试所需固定案例和任务配置另行复制，不将仓库产品源码混入包验收。
- [公开库示例](https://github.com/zrr1999/moonsmith/blob/main/examples/library/main.mbt)可以生成等价组并调用 Engine；CLI 可以从解包模块安装。
- 安装后的程序执行种子 42 的五配置普通任务和等价任务；搬迁材料后重放仍成功，
  原始文件保持不变，新执行及组记录追加。
- 标签上的完整验收额外执行种子 0–99 的五配置等价检查，记录每份源码、配置、原始观察和任务汇总。
- 当前编译器分别执行种子 1272、3745、6968；存在独立确认材料时再次重放，保存实际结果。

静态检查、覆盖率和性能基准由各自 CI/CE 负责。`CI - Tests` 用 `0.10.18` 构建 MoonSmith，再分别调用
`0.10.14+7d59c7ec9` 和 `0.10.11+6ff76a5f9`。`0.10.14` 在仓库外验证三例构建异常的自动归约、独立确认和重放；
入口见[贡献指南](https://github.com/zrr1999/moonsmith/blob/main/CONTRIBUTING.md#变更与验证)。

包验收与已发布产物验收共用[本地安装验收 Action](https://github.com/zrr1999/moonsmith/blob/main/.github/actions/check-installed/action.yml)，
传入已安装程序的路径和尚不存在的输出目录，保留执行日志、原始材料和重放结果。
Action 读取[公开 CLI 配置](https://github.com/zrr1999/moonsmith/blob/main/examples/quickstart.toml)，依赖 Bash、jq 和 SHA-256 工具。
本地可直接使用工作流中的 MoonBit 命令检查解包模块，按[CLI 安装验收](cli-installation-validation.md)运行与重放。

## 正式发布

正式发布前由维护者确认具体提交和版本。通过 GitHub 仓库的安全入口配置
`MOONCAKES_CREDENTIALS`，其内容为拥有四模块发布权限的 Mooncakes 凭据 JSON。

推送该提交的 `vVERSION` 标签后，`CD - Publish` 同时进行构建和完整验收，二者都通过后才发布：

1. 核对标签指向检出提交、提交属于 `main`、四模块版本与标签一致。
2. 在两个平台执行与 PR 相同的 native release 构建、打包、解包启动和模块归档检查。
3. 在两个平台执行包检查、历史种子重放和种子 0–99 的五配置等价验收。任一平台失败则不创建 Release，
   也不执行 `moon publish`。
4. `publish` job 创建或复用该标签的 Draft Release，上传两份 CLI 附件及 `SHA256SUMS`。
   官方 packslip Action 为附件生成来源证明和签名清单，验证后直接上传 `packslip.sigstore.json`。
   签名使用当前工作流的 GitHub OIDC 身份，不保管长期签名私钥。
5. 签名成功后，按 contracts → engine → moonbit → CLI 顺序直接运行 `moon publish`。
   任一模块失败即停止后续发布；全部成功才公开 GitHub Release。
6. 两个平台分别通过 packslip 验签并安装精确版本，检查安装包内的版本、提交和平台，
   随后验收 CLI 与 Mooncakes 安装、库消费、材料搬迁和重放。
   这一步失败不会撤回已经公开的 Release 或已发布的模块。

签名与上传使用同一个发布 job，共享内容写入、OIDC 与来源证明权限。构建和包验收保持只读。
Action 固定到正式发行的完整提交，清单直接附于 Draft Release，不再经过中间 Actions artifact。
签名失败会留下 Draft，但不会发布 Mooncakes 模块或公开 Release。

创建 Draft Release 时，通过 GitHub 自动生成发行说明，包含已合并 PR、贡献者和完整变更对比链接。
重试复用 Draft 和最终公开时沿用已有正文，保留人工补充的迁移要求或破坏性变更说明。
后续发行无需维护逐版本 Markdown 文件；0.0.1 的能力与边界保留在
[公开发行记录](https://github.com/zrr1999/moonsmith/releases/tag/v0.0.1)，
历史运行及安装结果见 [0.0.1 发行验收记录](cli-installation-validation.md#001-发行安装验收)。

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
| Release 中的 `packslip.sigstore.json` | 两份 CLI 附件的签名摘要、平台、执行入口、源提交与来源证明链接；0.0.1 不提供 |
| `CD - Publish` 的 `acceptance-PLATFORM` artifact | 模块包、解包测试、历史种子与安装重放；标签运行还包含种子 0–99 |
| `CI - Tests` 的历史证据 artifact | 固定旧工具链的异常复现、归约、确认和重放记录 |
| `CD - Publish` 的 `distribution-PLATFORM` artifact | 已发布二进制与 registry 安装的验收材料 |

安装签名发行使用 [README](https://github.com/zrr1999/moonsmith/blob/main/README.md#安装) 的 `packslip install` 入口：它以指定的 GitHub
仓库为信任依据，只下载本机平台的附件，验证签名与摘要后导出命令，并记住后续安装的信任状态。
清单声明必需的 `moon` 命令；C 编译器及运行时要求仍见[安装要求](https://github.com/zrr1999/moonsmith/blob/main/README.md#安装)。
签名来自 `cd-publish.yml`；迁移签名工作流可能要求使用者确认信任变化。

手动下载仍可使用 `SHA256SUMS`：macOS 运行 `shasum -a 256 -c SHA256SUMS`，Linux 运行
`sha256sum -c SHA256SUMS`，通过后解包并将 `moonsmith` 加入 `PATH`。校验和列出两个平台附件，
完整校验时应一并下载；校验和本身不提供签名身份保证。
需要独立审计构建来源时，可对下载的附件运行 `gh attestation verify ARCHIVE --repo zrr1999/moonsmith`。
这项检查独立于 packslip 安装，来源证明的生成仍由官方 Action 负责。
首次正式签名发行后，可用 `packslip pin packslip.sigstore.json` 取得 signer fingerprint，
供需要预先固定仓库身份的使用者通过 `--pin` 安装；它不是日常安装的额外步骤。

验收材料使用标准 `tar` 归档并由 GitHub Actions artifact 保存，构建缓存不入包。
历史异常的生成 C 文件随历史证据保存。执行记录可能包含当时的绝对路径，重放时使用实际解包位置。
组内材料关联使用相对路径，可随所属案例一起搬迁：

```shell
moonsmith replay /absolute/path/to/case-directory
moonsmith replay /absolute/path/to/group-directory
```

原万例实验与人工调查材料已附于 [0.0.1 Release](https://github.com/zrr1999/moonsmith/releases/tag/v0.0.1)，
其摘要见[历史材料清单](https://github.com/zrr1999/moonsmith/blob/main/.github/release-evidence.json)，
可在历史压缩包所在目录使用 `jq` 和 `shasum` 校验：

```shell
jq -r '"\(.sha256)  \(.file)"' /absolute/path/to/moonsmith/.github/release-evidence.json |
  shasum -a 256 --check -
```

该 Release 还包含双平台历史编译器复现和发行安装材料；来源及范围见附件
[`EVIDENCE.md`](https://github.com/zrr1999/moonsmith/releases/download/v0.0.1/EVIDENCE.md)，
五个证据包使用 `SHA256SUMS-EVIDENCE` 校验。后续需要长期公开的材料由维护者附到对应 Release。
适用版本与原始结果见[规模验收](acceptance-validation.md)、[归约演示](reduction-demonstration.md)
和[构建异常分析](native-release-analysis.md)。

## 已发布产物验收

发布公开后，`CD - Publish` 在两个平台以只读权限执行同一个 `packslip install` 入口，
将签名身份限制为本次标签的 `cd-publish.yml`。packslip 负责选包、下载、验签、摘要核对和安装，
每个平台只取对应附件。安装后的 `build.json` 必须匹配版本、提交和平台，再运行五配置任务与重放验收。
Mooncakes 精确版本的库消费与 CLI 安装另行验收。结果与失败材料保留在该次运行中，不撤回已完成的发布。

发行安装不再重复下载其他平台附件、校验 `SHA256SUMS` 或独立验证来源证明。
packslip 保证安装内容与允许的签名身份一致；它不验证链接的构建来源证明，两者的区别见
[packslip 信任说明](https://packslip.dev/docs/trust/)。

packslip CLI 通过官方推荐的 [mise](https://packslip.dev/docs/install/#install-with-mise) 安装，
下载、签名校验和 `PATH` 设置由 mise 及其官方 Action 负责；mise 与 packslip 均固定正式版本，
两个上游 Action 均固定完整 release commit。PR 构建不执行 OIDC 签名与公开安装，这两项由标签发布执行。

0.0.1 的双平台发行安装、库消费与重放结果见[CLI 安装验收](cli-installation-validation.md#001-发行安装验收)，
实际安装入口见[README](https://github.com/zrr1999/moonsmith/blob/main/README.md#安装)。后续版本发布后按相同流程核对，再更新安装说明。
