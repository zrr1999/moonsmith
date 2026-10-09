---
fp: 1
title: "多模块基础架构与质量检查"
type: Feature
authors:
  - "zrr1999"
created: 2026-10-09
supersedes: []
---

# FP-0001: 多模块基础架构与质量检查

## 摘要

将单 module 的初始化骨架调整为四个独立 module，由根目录 `moon.work` 组织。
contracts、core、moonbit 与 cli 分别维护版本和依赖；模块内部按职责划分九个 package。
通过统一开发入口和自动检查约束依赖方向，为后续算法实现提供可构建的基础。

## 动机

[项目申报书](../docs/project-proposal.md)要求通用 Core 与 MoonBit 适配器解耦，并为 Rust、
Swift 保留扩展空间，但尚未确定发布单元、包的归属及自动检查方式。原骨架只有一个
`moon.mod`，内部拆包仍只能共同发布，不能独立版本化核心库与语言适配器。

这次决定同时确定共享契约、纯计算、宿主副作用和应用装配的归属，影响后续所有组件的
导入路径、依赖声明和发布顺序。若等公共 API 和调用方形成后再拆分，就需要协调各组件及
外部使用者迁移。当前尚无已发布 API，适合先建立边界，再逐步实现真实调用。

## 设计

### 模块与发布边界

module 是版本与发布单位，package 是 module 内部的编译与命名空间单位。采用
[Moon workspace](https://docs.moonbitlang.com/en/stable/toolchain/moon/workspace.html)
管理本地成员，根目录只保留 `moon.work`，不再定义外层 module。

| 目录 | Module 名称 | 仓库内模块依赖 |
| --- | --- | --- |
| `modules/contracts` | `zrr1999/moonsmith-contracts` | 无 |
| `modules/core` | `zrr1999/moonsmith-core` | contracts |
| `modules/moonbit` | `zrr1999/moonsmith-moonbit` | contracts |
| `modules/cli` | `zrr1999/moonsmith` | contracts、core、moonbit |

每个成员拥有自己的 `moon.mod`、README、LICENSE 和 `src` 目录。初始版本均为 `0.0.0`，
表示未发布的骨架；后续独立管理版本。模块依赖使用名称和版本声明，workspace 内解析到
本地成员源码。成员版本变化后用 `moon work sync` 更新依赖方声明。

有内部依赖时，按 contracts、Core／语言适配器、CLI 的顺序发布相关模块。此次只建立可
分别打包的结构，不建立自动发布流程。Host 等组件暂时没有独立发布需求，归入 CLI 模块。

### 包的职责与依赖

三个库模块各有一个根包，其余六个包位于 CLI 模块内。下表描述责任和允许的项目内依赖；
实际 `moon.pkg` import 只在出现真实调用时添加，不预建没有调用方的公共接口。

| 包 | 职责 | 允许的仓库内依赖 |
| --- | --- | --- |
| `contracts` | 语言无关的配置、观察值、预算和案例记录 | 无 |
| `core` | 纯测试编排、判定和归约搜索 | `contracts` |
| `moonbit` | MoonBit 程序表示、生成、解释、源码输出和归约候选 | `contracts` |
| `host` | 进程生命周期、文件系统及平台访问 | `contracts` |
| `toolchains/moon` | Moon 工具链探测、命令计划及诊断分类 | `contracts`、`host` |
| `artifacts` | 案例持久化和追加式执行记录 | `contracts`、`host` |
| `report` | 从传入的记录生成报告 | `contracts` |
| `app` | 装配适配器，协调执行、存储及报告 | 上述各包 |
| `cmd/moonsmith` | CLI 参数、终端交互和退出码 | `app`、`host` |

Core 不导入语言 AST、Host 或存储；语言适配器不拥有测试编排和执行环境。两者通过共享
契约及应用装配协作。纯计算使用显式输入、种子与预算，报告包只处理传入的记录。
CLI、app、Host、工具链与存储包先限定为 native，其余包保留其他后端的使用空间。
Rust、Swift 适配器后续作为与 MoonBit 并列的 module 接入，由 app 装配。

### 开发与质量检查

根目录统一提供格式、检查、构建、测试及运行入口，具体命令维护在贡献指南。
`prek` 连接本地与 CI，第三方检查工具固定版本。静态检查和构建测试覆盖 stack PR 的
非 main 基线，避免依赖层尚未合并时跳过验证。

alint 检查 workspace 布局、成员文件、模块依赖和包导入，拒绝反向依赖以及已列出的
纯计算组件 I/O 依赖。规则覆盖 `moon.mod` 与 `moon.pkg`，以 `moon fmt` 规范化的导入格式
为前提；新增组件或依赖时同步核对规则，不能把文本规则当作完整语义分析。

在 MoonBit、Just、ZenDev 和已有文件检查的基础上，加入 TOML、YAML、Markdown、JSON
Schema、GitHub Actions 安全和凭据检查，继续检查拼写及本地链接。门禁保持只读，格式化
通过单独入口执行；凭据检查隐藏匹配值，并排除构建缓存、依赖下载和本地实验产物。

## 兼容性

当前没有已发布版本、公共 API 或产品案例格式。根 module 迁移到 `modules/cli`，保留
`zrr1999/moonsmith` 名称；三个库使用各自的模块根包。开发者通过根目录任务入口运行
workspace，直接调用旧源码路径的本地命令需要更新。

包边界与门禁会约束后续实现和依赖引入；实际算法、语义契约及行为测试仍由对应实现
逐步提供。此次不实现生成、判定、归约或多后端执行，CLI 只说明当前开发状态。

## 验证

实现 PR 应提供以下证据，本提案仅定义验收条件：

- 根目录格式与检查命令覆盖四个成员，native 构建通过，CLI 可运行并准确说明开发状态。
- 依赖树将仓库内依赖标记为本地成员；隔离样例中修改提供方后，调用方能观察到变化。
- 独立调整一个成员版本后，`moon work sync` 更新依赖声明，不改变其他成员自身版本。
- alint 接受允许的依赖，拒绝反向导入、缺失的必需文件及纯计算组件的宿主 I/O 依赖。
- 每个成员可单独打包，产物包含自身 manifest、README、LICENSE 和源码。
- 本地与 CI 使用同一质量检查入口，stack PR 能触发相应检查。

零项测试、临时集成样例和打包清单只验证骨架，不代表产品功能或发布已经完成。
