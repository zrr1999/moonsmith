# CI 与发布职责

2026-10-31，针对发布脚本同时承担产品验收、历史复现、归档和 registry 校验的问题，
用户明确要求“测试，复现之类的都是专门的 ci”“cd 就只管发布”。
这是工作流职责调整，不改变 MoonSmith 的产品语义，不需要新 FP。
随后用户要求每个 PR 触发幂等的发布构建，并明确选择“发布前验证这部分 PR 也会触发，
只是最后 publish 会被 skip”，因此采用同一工作流的 build/publish 分离，不发布 PR dev 版本。
用户随后明确要求删除全部 Python 脚本，并排除无人维护的社区发布 Action，优先使用官方入口。

## 官方实现

本次读取的官方源码：

- [async 发布工作流](https://github.com/moonbitlang/async/blob/main/.github/workflows/publish.yml)
  在发布 job 中运行检查与测试，但发布步骤只写入临时凭据、执行 `moon publish` 并删除凭据。
- [x 发布工作流](https://github.com/moonbitlang/x/blob/main/.github/workflows/publish.yml)
  同样直接调用 `moon publish`，用 shell trap 清理凭据。它也保留部分检查，不能将“所有官方项目
  都严格拆开 CI/CD”作为事实。
- [x 包验收工作流](https://github.com/moonbitlang/x/blob/main/.github/workflows/package.yml)
  在 PR 和主分支推送时独立检查实际包内容，解包后运行类型检查和测试。
- [async 发布前检查](https://github.com/moonbitlang/async/blob/main/.github/workflows/pre-release-check.yml)
  单独运行多平台、多个后端和 sanitizer 检查。

官方源码支持直接使用标准发布命令。严格的 CI/CD 职责边界来自本次用户决定。
保留原有“CD 调用完整验收”的方案会继续重复测试和历史复现，因此不采用。

检索 MoonBit 官方组织中与 Action、发布及 Mooncakes 相关的仓库和官方文档，未找到官方专用
发布 Action。社区 `cogna-dev/moonbit-actions` 不采用；沿用官方项目直接调用 `moon publish`
的方式，GitHub Release 使用 GitHub 官方 `gh`。工具链安装继续使用仓库已固定的 setup-moonbit。

## PR 构建调研

- [GoReleaser 官方 PR 配置](https://goreleaser.com/customization/ci/rwx/)以 snapshot 构建配合
  跳过 publish 验证发布配置，支持用户选定的“复用打包、跳过发布”模式；无需为此引入 GoReleaser。
- [uv 开发构建](https://github.com/astral-sh/uv/blob/main/.github/workflows/build-dev-binaries.yml)
  将平台二进制和提交 SHA 一起命名并上传 Actions artifact。
- [uv 正式发布](https://github.com/astral-sh/uv/blob/main/.github/workflows/release.yml)
  将构建与发布分开，以发布开关控制外部写入。
- [MoonBit 包管理文档](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html)
  允许 SemVer 预发布扩展，但 PR dev 包会额外引入四模块版本与依赖版本协调及 registry 写入，
  不符合本次已明确选择。
- [GitHub PR 事件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request)
  默认检出合并测试提交；fork PR 仅有只读 token，不能依赖 Mooncakes 凭据。

构建重跑的幂等含义是无需变更版本、标签或 registry 即可完成；未承诺不同运行生成逐字节一致的压缩包。

## 实施边界

- CD 核对标签及模块版本，构建两平台 CLI，用标准 `tar` 和 `sha256sum` 打包；
  按依赖顺序执行 `moon publish`，最后上传附件并公开 GitHub Release。
- 指向 main 的全部 PR 触发同一 CD 的 build job，共用构建和包体检查。
  publish 仅允许版本标签 push；PR 文件名带 PR 编号与检出提交身份，artifact 可重跑覆盖，
  不创建 dev Release，也不变更 registry 包版本。
- `CI - Acceptance` 参考官方 x 的包验收：打包、解包后运行原生类型检查和行为测试，
  并验证独立库消费者与 CLI 安装。测试所需 cases 和任务配置单独复制，产品源码只来自 zip 包。
  普通及等价任务、搬迁后的重放与原文件校验由一个共享 shell 入口执行，不再维护 Python 框架。
- 静态门禁、覆盖率和基准分别保留在原有 CI/CE；历史复现由 `CI - Tests` 在两平台运行，
  保留固定旧版编译器、错误版本拒绝、归约、独立确认和仓库外重放。
- `CI - Distribution` 按已发布标签手动运行，以只读权限验证该提交的已发布产物。
  下载验证、registry 安装与普通及整组重放的失败由 CI 单独报告。
- 删除自定义发布、轮询、registry 内容对比和七附件汇总代码。原始证据保持可下载和可校验，
  当前 CI 材料作为 Actions artifacts；历史材料可由维护者单独附到 Release。
- registry 的不可变版本和错误结果由 `moon publish` 处理；部分发布失败后停止后续模块，
  不再承诺自动跳过已存在版本。
- 删除 Python 验收脚本及仅测试该框架的单元测试，移除 Ruff 和 CodeQL Python 条目。
  上游检查工具的 Python 运行时仍属于既有工具环境，不属于仓库维护的 Python 脚本。
  历史材料清单保留，摘要用标准工具校验；CI 使用 tar 与 upload-artifact 保存证据，
  不再维护自定义归档格式、逐文件 manifest 或重复的归档读写器。

未采用 `workflow_run` 级联：当前 Zizmor 门禁禁止该触发方式；独立手动触发也使 CD 无需调度或等待 CI。
静态检查、真实本地打包、安装重放与失败路径验证记录在任务交付记录及 CI，
不将未实际发布的流程称为已完成发布。
