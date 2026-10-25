///|
fn Ty::source(self : Ty) -> String {
  match self {
    Int => "Int"
    Bool => "Bool"
    Tuple(fields) => "(\{fields.map(ty => ty.source()).join(", ")})"
    Enum(id) => "E\{id}"
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
    Tuple(fields) => "(\{fields.map(e => e.source()).join(", ")})"
    Project(value, index) => "(\{value.source()}).\{index}"
    Variant(id, tag, arguments) => {
      let name = "E\{id}::C\{tag}"
      if arguments.is_empty() {
        name
      } else {
        "\{name}(\{arguments.map(e => e.source()).join(", ")})"
      }
    }
    Match(id, value, arms) => {
      let branches = []
      for tag, arm in arms {
        let parameters = arm.parameters.map(p => "v\{p.id}").join(", ")
        let pattern = if arm.parameters.is_empty() {
          "E\{id}::C\{tag}"
        } else {
          "E\{id}::C\{tag}(\{parameters})"
        }
        branches.push("\{pattern} => (\{arm.body.source()})")
      }
      "(match \{value.source()} {\n\{branches.join("\n")}\n})"
    }
  }
}

///|
pub fn CompleteProgram::emit(self : CompleteProgram) -> String {
  let lines : Array[String] = []
  for id, definition in self.syntax.enums {
    lines.push("enum E\{id} {")
    for tag, fields in definition.variants {
      let name = if fields.is_empty() {
        "C\{tag}"
      } else {
        "C\{tag}(\{fields.map(ty => ty.source()).join(", ")})"
      }
      lines.push("  \{name}")
    }
    lines.push("}")
    lines.push("")
  }
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
