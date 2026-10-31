# 文档站维护

文档站使用 [Zensical](https://zensical.org/) 0.0.74，只收录 `docs/`。MoonBit 代码块由 Pygments 着色，lexer 来自 [moonbit-docs `v0.10.16`](https://github.com/moonbitlang/moonbit-docs/blob/v0.10.16/next/_ext/lexer.py) 的网站代码，许可证为 Apache-2.0，本地包是 `tools/moonbit-lexer`。上游没有 PyPI 发行包，也没有 GitHub Release；版本标签是可固定的发布点。shell、C 和 text 继续使用 Pygments 自带 lexer。

## 构建与预览

安装 `uv` 和 `just` 后，在仓库根目录运行：

```shell
just docs
just docs serve
```

`just docs` 用锁定的依赖严格构建，检查站内链接和标题锚点。产物在 `.artifacts/docs/site/`。`just docs serve` 在 `http://127.0.0.1:8000` 预览，并在原始 Markdown 变化后同步到暂存目录。`just docs serve 8001` 可换端口；端口只接受 1–65535 的整数。

`scripts/docs.py` 用 PEP 723 固定 Zensical，并把 `tools/moonbit-lexer` 装进同一个环境，使 Pygments 能按 `moonbit` 和 `mbt` 找到 lexer。升级 Zensical 或 lexer 后重新锁定：

```shell
uv lock --script scripts/docs.py
just docs
```

构建前会把 `docs/` 复制到 `.artifacts/docs/source/`。复制时，指向 `docs/` 之外仓库文件的相对链接改成 GitHub 上 `main` 的对应文件，站内链接保持不动。不要手改暂存目录或站点输出。

## Cloudflare 托管

托管方式与 ZenDev 相同，使用 [Cloudflare Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/)。Worker 名是 `moonsmith-docs`，配置的站点地址是 `https://docs.moonsmith.zrr.dev/`。`zensical.toml` 的 `site_url` 决定 canonical URL 和 sitemap；`wrangler.toml` 决定产物目录、域名、目录索引和 404。没有 Worker 脚本。

仓库不保存 Node.js 包。Wrangler 通过 npx 使用固定版本，Zensical 由 `scripts/docs.py.lock` 锁定。验证配置：

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
| 构建命令 | `python -m pip install uv==0.13.5 && uv run --locked --script scripts/docs.py build` |
| 部署命令 | `npx --yes --ignore-scripts wrangler@4.156.0 deploy` |
| 非生产分支命令 | `npx --yes --ignore-scripts wrangler@4.156.0 versions upload` |
| 构建变量 | `NODE_VERSION=22`、`PYTHON_VERSION=3.13`、`SKIP_DEPENDENCY_INSTALL=true` |

生产部署更新正式域名。非生产分支只上传预览版本。GitHub Actions 只构建并做 dry-run，不部署。凭据放在 Cloudflare 或本机受保护的环境中，不写入仓库。

首次部署会按 `routes` 创建自定义域名。若该域名已有 DNS 记录，先核对用途。部署后核对首页、一篇含 MoonBit 代码块的页面、搜索，以及不存在路径的 404。
