---
fp: 1
title: "多模块基础架构与质量检查"
type: Feature
authors:
  - "zrr1999"
created: 2026-10-09
defines:
  - module
  - package
  - core
  - language-adapter
  - application-layer
  - host
  - shared-contracts
supersedes: []
---

# FP-0001: 多模块基础架构与质量检查

## 摘要

采用 Moon workspace 组织 contracts、core、moonbit 与 cli 四个独立 module，分别管理
版本和依赖。模块内部按职责划分九个 package，以共享契约连接纯计算与宿主执行，并通过
统一开发入口和质量检查约束依赖方向。

## 动机

[项目申报书](../docs/project-proposal.md)要求通用 Core 与 MoonBit 适配器解耦，并为 Rust、
Swift 保留扩展空间。单 module 内部拆包只能提供源码边界，核心库、适配器和 CLI 仍需
共同发布，无法分别演进版本与依赖。

需要同时确定发布单元和职责边界：Core 可被不同语言复用，语言适配器独立维护语义，
进程与文件系统集中在 Host，CLI 负责装配。该划分统一组件的导入路径、依赖方向和发布
顺序，避免语言实现或宿主环境反向侵入通用算法。

## 设计

### 模块与发布边界

<a id="term-module"></a>

模块（module）是版本与发布单位，以 `moon.mod` 声明名称、版本和模块依赖。

<a id="term-package"></a>

包（package）是 module 内部的编译与命名空间单位，以 `moon.pkg` 声明包配置及导入。

采用 [Moon workspace](https://docs.moonbitlang.com/en/stable/toolchain/moon/workspace.html)
管理本地成员，根目录只保留 `moon.work`，不再定义外层 module。

| 目录 | Module 名称 | 仓库内模块依赖 |
| --- | --- | --- |
| `modules/contracts` | `zrr1999/moonsmith-contracts` | 无 |
| `modules/core` | `zrr1999/moonsmith-core` | contracts |
| `modules/moonbit` | `zrr1999/moonsmith-moonbit` | contracts |
| `modules/cli` | `zrr1999/moonsmith` | contracts、core、moonbit |

每个成员拥有自己的 `moon.mod`、README、LICENSE 和 `src` 目录。workspace 通过目录路径
定位成员，通过 `moon.mod` 的 `name` 解析模块依赖，因此目录名采用简短的职责名称。
package 的完整导入路径由模块名与相对 `src` 的路径组成。

各模块按自身契约独立管理语义化版本。依赖使用模块名称和版本声明；workspace 内按名称
解析本地源码，发布时使用声明的版本。成员版本变化后运行 `moon work sync` 同步依赖方
声明。按 contracts、Core／语言适配器、CLI 的依赖顺序发布受影响模块。

Host、工具链、存储和报告服务于 CLI 的执行流程，作为其内部 package 管理；独立复用的
共享契约、通用算法和语言语义分别作为 module 发布。

### 包的职责与依赖

三个库模块各有一个根包，其余六个包位于 CLI 模块内。下表规定职责和允许的项目内依赖。

| 包 | 所属模块 | 职责 | 允许的仓库内依赖 |
| --- | --- | --- | --- |
| `contracts` | `zrr1999/moonsmith-contracts` | 语言无关的配置、观察值、预算和案例记录 | 无 |
| `core` | `zrr1999/moonsmith-core` | 纯测试编排、判定和归约搜索 | `contracts` |
| `moonbit` | `zrr1999/moonsmith-moonbit` | MoonBit 程序表示、生成、解释、源码输出和归约候选 | `contracts` |
| `host` | `zrr1999/moonsmith` | 进程生命周期、文件系统及平台访问 | `contracts` |
| `toolchains/moon` | `zrr1999/moonsmith` | Moon 工具链探测、命令计划及诊断分类 | `contracts`、`host` |
| `artifacts` | `zrr1999/moonsmith` | 案例持久化和追加式执行记录 | `contracts`、`host` |
| `report` | `zrr1999/moonsmith` | 从传入的记录生成报告 | `contracts` |
| `app` | `zrr1999/moonsmith` | 装配适配器，协调执行、存储及报告 | 上述各包 |
| `cmd/moonsmith` | `zrr1999/moonsmith` | CLI 参数、终端交互和退出码 | `app`、`host` |

### 协作角色

以下定义说明责任归属，不要求每个角色单独发布一个 module。

<a id="term-core"></a>

Core 是语言无关的纯计算层，负责测试编排、证据判定和归约搜索，拥有接受与停止的决定。
它通过共享契约使用语言能力与执行事实，不解释具体语言 AST，也不直接访问宿主 I/O。

<a id="term-language-adapter"></a>

语言适配器（language adapter）拥有某种语言的程序表示与语义，包括生成、合法性检查、
参考求值、观察协议、源码输出与归约候选。语言 AST 和改写上下文留在适配器中。

<a id="term-application-layer"></a>

应用装配层（application layer，当前为 `app`）连接 Core、语言及工具链能力，
执行 Core 请求的工作并关联、回传结果，协调证据保存和报告；它不另行定义判定与接受规则。

<a id="term-host"></a>

Host 是宿主环境访问层，负责进程生命周期、文件系统及外部资源，拥有资源句柄和实际执行事实。
工具链与存储通过 Host 访问环境，Core 和语言适配器不持有宿主资源。

<a id="term-shared-contracts"></a>

共享契约（shared contracts，当前为 `contracts`）只表达实际跨组件使用的数据，
包括配置、观察值、预算、判据和记录；不承载语言 AST、宿主资源或具体算法状态。

纯计算使用显式输入、种子与预算，报告包只处理传入的记录。
CLI、app、Host、工具链与存储包先限定为 native，其余包保留其他后端的使用空间。
Rust、Swift 适配器后续作为与 MoonBit 并列的 module 接入，由 app 装配。

### 开发与质量检查

根目录统一提供格式、检查、构建、测试及运行入口，覆盖 workspace 成员。具体命令维护
在贡献指南，本地与 CI 通过 `prek` 执行同一组检查，第三方检查工具固定版本。

alint 检查 workspace 布局、成员文件、模块依赖和包导入，拒绝反向依赖以及已列出的
纯计算组件 I/O 依赖。规则覆盖 `moon.mod` 与 `moon.pkg`，以 `moon fmt` 规范化的导入格式
为前提，新增组件或依赖时同步更新规则。

在 MoonBit、Just、ZenDev 和已有文件检查的基础上，加入 TOML、YAML、Markdown、JSON
Schema、GitHub Actions 安全和凭据检查，继续检查拼写及本地链接。门禁保持只读，格式化
通过单独入口执行；凭据检查隐藏匹配值，并排除构建缓存、依赖下载和本地实验产物。

## 兼容性

根 module 迁移到 `modules/cli`，保留 `zrr1999/moonsmith` 名称；三个库使用各自的模块
根包。调用方按所属 module 声明依赖，并使用新的完整包路径导入。根目录开发命令以
workspace 为作用域，直接使用源码路径的命令需指向对应成员。

共享契约的变更需协调 Core、语言适配器和 CLI 的版本及依赖声明；语言内部表示的变化
限定在对应适配器中。新增语言以并列 module 接入，由 app 装配。

## 验证

- 根目录格式与检查命令覆盖四个成员，native 构建、测试及 CLI 入口可运行。
- 依赖树将仓库内依赖标记为本地成员；隔离样例中修改提供方后，调用方能观察到变化。
- 独立调整一个成员版本后，`moon work sync` 更新依赖声明，不改变其他成员自身版本。
- alint 接受允许的依赖，拒绝反向导入、缺失的必需文件及纯计算组件的宿主 I/O 依赖。
- 每个成员可单独打包，产物包含自身 manifest、README、LICENSE 和源码。
- 本地与 CI 使用同一质量检查入口。
