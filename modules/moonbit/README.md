# MoonSmith MoonBit Adapter

作为 MoonBit 的[语言适配器](../../fps/FP-0001-workspace-modules.md#term-language-adapter)，
提供类型化程序、确定性生成、参考求值、源码输出及归约候选。

`int-bool-v1` 使用分开的整数和布尔表达式树、顺序局部绑定及有界深度。
`generate` 接收显式种子；`Program` 提供 `evaluate`、`valid`、`emit`、`size` 和 `candidates`。
删除绑定时修正引用，候选再次校验作用域与 Int 运算范围。

本模块不调用编译器，不负责搜索或保存结果。profile 范围和实验入口见根目录贡献指南。
