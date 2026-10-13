///|
fn Ty::source(self : Ty) -> String {
  match self {
    Int => "Int"
    Bool => "Bool"
  }
}

///|
fn Expr::source(self : Expr) -> String {
  match self {
    Hole(_) => abort("a CompleteProgram cannot contain a hole")
    IntLiteral(value) => if value < 0 { "(\{value})" } else { "\{value}" }
    BoolLiteral(value) => "\{value}"
    Ref(id) => "v\{id}"
    Let(binder, value, body) =>
      "{ let v\{binder.id} : \{binder.ty.source()} = \{value.source()}; \{body.source()} }"
    Add(a, b) => "(\{a.source()} + \{b.source()})"
    Subtract(a, b) => "(\{a.source()} - \{b.source()})"
    Less(a, b) => "(\{a.source()} < \{b.source()})"
    Not(e) => "(!\{e.source()})"
    If(condition, yes, no) =>
      "(if \{condition.source()} { \{yes.source()} } else { \{no.source()} })"
    Call(id, arguments) =>
      "f\{id}(\{arguments.map(e => e.source()).join(", ")})"
  }
}

///|
pub fn CompleteProgram::emit(self : CompleteProgram) -> String {
  let lines : Array[String] = []
  for id, function in self.syntax.functions {
    let parameters = function.parameters
      .map(p => "v\{p.id} : \{p.ty.source()}")
      .join(", ")
    lines.push("fn f\{id}(\{parameters}) -> \{function.returns.source()} {")
    lines.push("  \{function.body.source()}")
    lines.push("}")
    lines.push("")
  }
  lines.push("fn main {")
  lines.push("  println(\{self.syntax.result.source()})")
  lines.push("}")
  lines.join("\n") + "\n"
}
