# 发行与验收

MoonSmith 的四个模块共用一个版本号。发布从已合入 `main` 的固定提交构建，工具链及宿主依赖见
[安装要求](../README.md#安装)。预编译程序覆盖 macOS arm64 与 Linux x86_64，分别在 macOS 15 与 Ubuntu 24.04 的官方 runner 上构建和验证。

## 发布准备

在最终提交上运行 `Release - Prepare`，启用 `full_acceptance`。该工作流也在发行相关 PR 中运行
较小的准备检查，PR 的结果不能代替合入后最终提交的完整验收。

两个平台分别执行仓库静态检查、构建、行为测试、覆盖率与基准，并验证：

- 四个模块及内部依赖版本一致；包内包含源码、原生 C 文件、README 和许可证。
- 解包到仓库外后，库消费程序可以生成等价组并调用 Engine；CLI 可以从解包模块安装。
- release 二进制在仓库外执行种子 42 的五配置普通任务和等价任务；搬迁材料后重放仍成功，
  原始文件保持不变，新执行及组记录追加。
- 完整验收执行种子 0–99 的五配置等价检查，记录每份源码、配置、原始观察和任务汇总。
- 当前编译器分别执行种子 1272、3745、6968；存在独立确认材料时再次重放，保存实际结果。
- 用当前工具链构建历史检查程序，再以固定旧版 `0.10.14+7d59c7ec9` 验证三例构建异常的
  自动归约、独立确认和重放。历史入口首先验证错误版本会被拒绝。

可在匹配平台的本地工作区运行同一准备脚本，Python 要求 3.13 或更新版本：

```shell
python scripts/release.py prepare --full
# 按贡献指南构建历史检查程序并切换被测编译器后：
python scripts/release.py historical
python scripts/release.py archive
```

`prepare` 要求新的输出目录；可用 `--output` 选择位置。它不发布包或创建标签。
历史工具链切换与检查入口见[贡献指南](../CONTRIBUTING.md#变更与验证)。

## 产物与材料

| 文件 | 内容 |
| --- | --- |
| `moonsmith-VERSION-macos-arm64.tar.gz` | macOS arm64 CLI、许可证、安装说明及构建身份 |
| `moonsmith-VERSION-linux-x86_64.tar.gz` | Linux x86_64 CLI、许可证、安装说明及构建身份 |
| `moonsmith-VERSION-evidence-PLATFORM.tar.gz` | 模块包、库消费、当前产品任务、历史检查与平台验收材料 |
| `moonsmith-VERSION-historical-evidence.tar.gz` | 原万例实验、三例调查与人工缩减材料，保留原提交和工具链身份 |
| `moonsmith-VERSION-registry-PLATFORM.tar.gz` | 正式发布后从 Mooncakes 安装精确版本的验证材料 |
| `SHA256SUMS` | 上述七份附件的 SHA-256 |

每个压缩包内另含文件清单 `manifest.json` 和逐文件 `SHA256SUMS`。构建缓存不入包；
构建异常的关键生成 C 文件单独保留。原始执行记录可能包含当时的绝对路径，这些路径是执行证据，
重放时应使用实际解包位置。组内材料关联使用相对路径，可随所属案例一起搬迁。

下载附件后先校验，再解包；macOS 使用 `shasum -a 256 -c SHA256SUMS`，Linux 使用
`sha256sum -c SHA256SUMS`。进入解包目录再次校验内部文件。使用安装后的命令重放案例、尝试或组目录：

```shell
moonsmith replay /absolute/path/to/case-directory
moonsmith replay /absolute/path/to/group-directory
```

原万例实验与当前版本验收分别归档。适用版本和原始结果见[规模验收](acceptance-validation.md)，
真实异常的产品归约与人工调查分别见[归约演示](reduction-demonstration.md)和
[构建异常分析](native-release-analysis.md)。

## 正式发布

正式发布前由维护者确认具体提交、版本、产物和验收结果。通过 GitHub 仓库的安全入口配置
`MOONCAKES_CREDENTIALS`，其内容为拥有四模块发布权限的 Mooncakes 凭据 JSON；不要写入源码或日志。

确认后，先为该提交创建对应版本的 Draft Release，上传历史证据附件。附件名称和 SHA-256 必须与
[已审阅的历史材料清单](../.github/release-evidence.json)一致，再推送同一提交的 `vVERSION` 标签。
`CD - Publish` 自动完成以下步骤：

1. 核对标签、检出提交、`main` 归属、四模块版本和内部依赖，校验 Draft Release 中的历史附件。
2. 在两个平台重新执行完整发布准备。
3. 按 contracts → engine → moonbit → CLI 顺序发布。每个版本可从 registry 精确解析且内容与包一致后
   才继续；失败时停止后续发布。重试先核对已存在的版本，内容不一致时拒绝覆盖或继续。
4. 在两个平台从 Mooncakes 安装精确版本，验证库消费、CLI、普通案例和整组重放。
5. 汇总二进制、历史与当前证据及 registry 验证附件，上传到 Draft Release。重新下载并校验所有附件，
   解包执行一次整组重放，然后将 Release 正式公开。

凭据只在发布步骤临时写入 `MOON_HOME/credentials.json`，文件权限为 `0600`，结束时清除。
失败的发布保留已成功发布的版本，排查后从原标签重试；不能用同版本不同内容覆盖 registry 包。
正式发布和安装验证完成后，更新根 README 的实际安装入口。
