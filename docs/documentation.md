# 文档站维护

文档站使用 [Zensical](https://zensical.org/) 0.0.74，直接构建 `docs/`。提案与术语索引暂不收录到站点，仓库中的提案和定义导航继续保留。MoonBit 代码块由 Pygments 着色，lexer 来自 [moonbit-docs `v0.10.16`](https://github.com/moonbitlang/moonbit-docs/blob/v0.10.16/next/_ext/lexer.py) 的网站代码，许可证为 Apache-2.0，本地包是 `tools/moonbit-lexer`。上游没有 PyPI 发行包，也没有 GitHub Release；版本标签是可固定的发布点。shell、C 和 text 继续使用 Pygments 自带 lexer。

## 构建与预览

安装 `uv` 和 `just` 后，在仓库根目录运行：

```shell
just docs
just docs serve
```

`just docs` 用锁定的依赖严格构建，检查站内链接和标题锚点。产物在 `.artifacts/docs/site/`。`just docs serve` 在 `http://localhost:8000` 预览，Markdown 变化后由 Zensical 自动重建。需要换端口时使用 `just docs serve --dev-addr 127.0.0.1:8001`。

`tools/moonbit-lexer/pyproject.toml` 的 `docs` 依赖组固定 Zensical，与 lexer 一起由同目录的 `uv.lock` 锁定，使 Pygments 能按 `moonbit` 和 `mbt` 找到 lexer。构建与预览使用 `--no-build`，第三方依赖只安装 wheel；本地 lexer 作为项目本体，仍由其固定的构建后端构建。升级 Zensical 或 lexer 后重新锁定：

```shell
uv lock --project tools/moonbit-lexer
just docs
```

站内页面使用相对链接，由 Zensical 解析和校验。源码、配置和模块 README 使用指向 GitHub 的链接。构建与预览直接读取原始文档，不生成中间副本。

## Cloudflare 托管

托管方式与 ZenDev 相同，使用 [Cloudflare Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/)。Worker 名是 `moonsmith-docs`，配置的站点地址是 `https://docs.moonsmith.zrr.dev/`。`zensical.toml` 的 `site_url` 决定 canonical URL 和 sitemap；`wrangler.toml` 决定产物目录、域名、目录索引和 404。没有 Worker 脚本。

仓库不保存 Node.js 包。Wrangler 通过 npx 使用固定版本，Zensical 由 lexer 项目的锁文件管理。验证配置：

```shell
just docs
npx --yes --ignore-scripts wrangler@4.156.0 deploy --dry-run
```

dry-run 不登录，也不上传。它不能证明域名、TLS 或 Git 集成已经生效。

在 Cloudflare Workers Builds 中连接 `zrr1999/moonsmith`：

| 设置 | 值 |
| --- | --- |
| Worker 名称 | `moonsmith-docs`，与 `wrangler.toml` 一致 |
| 根目录 | `/` |
| 生产分支 | `main` |
| 构建命令 | `python -m pip install --only-binary=:all: uv==0.13.5 && uv run --project tools/moonbit-lexer --group docs --no-build --locked zensical build --strict` |
| 部署命令 | `npx --yes --ignore-scripts wrangler@4.156.0 deploy` |
| 非生产分支命令 | `npx --yes --ignore-scripts wrangler@4.156.0 versions upload` |
| 构建变量 | `NODE_VERSION=22`、`PYTHON_VERSION=3.13`、`SKIP_DEPENDENCY_INSTALL=true` |

生产部署更新正式域名。非生产分支只上传预览版本。GitHub Actions 只构建并做 dry-run，不部署。凭据放在 Cloudflare 或本机受保护的环境中，不写入仓库。

首次部署会按 `routes` 创建自定义域名。若该域名已有 DNS 记录，先核对用途。部署后核对首页、一篇含 MoonBit 代码块的页面、搜索，以及不存在路径的 404。
