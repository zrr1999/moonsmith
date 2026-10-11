# MoonSmith MoonBit Adapter

作为 MoonBit 的[语言适配器](../../fps/FP-0001-workspace-modules.md#term-language-adapter)，
提供类型化程序、确定性生成、参考求值、源码输出及归约候选。

`int-bool-v1` 使用分开的整数和布尔表达式树、顺序局部绑定及有界深度。
`generate` 接收显式种子；`Program` 提供 `evaluate`、`valid`、`emit`、`size` 和 `candidates`。
删除绑定时修正引用，候选再次校验作用域与 Int 运算范围。

FP-0002 的结构路径使用 `Template`、`Expr`、`Function` 和 `Binder` 表达带类型空洞、词法绑定、
分支与函数调用。函数以定义数组中的索引标识；同一作用域内绑定标识唯一，不同函数或分支的
独立作用域可以复用标识。函数可引用后面的定义，但整个调用关系必须无环，包括未调用函数
及未执行分支中的调用。

`Template.check` 检查部分程序的约束，允许类型正确的空洞；`Template.finish` 拒绝剩余空洞，
返回拥有独立快照的 `CompleteProgram`。检查只处理结构和类型，不求值，也不裁定整数溢出
是否进入默认生成范围。错误通过 `StructureError` 区分空洞、非法引用、类型、参数和调用依赖。

`CompleteProgram.emit` 输出包含函数定义和单值输出入口的 MoonBit 源码，`result_type` 给出
输出表达式类型。`size` 为表达式、函数和形参的节点总数；`depth` 为表达式最大嵌套层数，
叶子深度为零，不代表运行时调用栈深度。完整程序不会因原模板中的可变数组被修改而改变。

上述结构路径已通过手工构造案例的类型、作用域、调用关系及三配置执行测试；自动模板组合、
规则补全、预算和 CLI 接入仍待完成。当前生成命令继续使用 `int-bool-v1`。

本模块不调用编译器，不负责搜索或保存结果。profile 范围和实验入口见根目录贡献指南。
