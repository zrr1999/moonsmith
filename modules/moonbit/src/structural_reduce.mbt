///|
fn Ty::zero(self : Ty, enums : Array[EnumDefinition]) -> Expr {
  match self {
    Int => IntLiteral(0)
    Bool => BoolLiteral(false)
    Tuple(fields) => Expr::Tuple(fields.map(ty => ty.zero(enums)))
    Enum(id) => Variant(id, 0, enums[id].variants[0].map(ty => ty.zero(enums)))
  }
}

///|
fn Expr::map_children(self : Expr, f : (Expr) -> Expr) -> Expr {
  match self {
    Hole(_) | IntLiteral(_) | BoolLiteral(_) | Ref(_) => self
    Let(binder, value, body) => Let(binder, f(value), f(body))
    Add(a, b) => Add(f(a), f(b))
    Subtract(a, b) => Subtract(f(a), f(b))
    Less(a, b) => Less(f(a), f(b))
    Not(e) => Not(f(e))
    If(condition, yes, no) => If(f(condition), f(yes), f(no))
    Call(id, arguments) => Call(id, arguments.map(f))
    Tuple(fields) => Tuple(fields.map(f))
    Project(value, index) => Project(f(value), index)
    Variant(id, tag, arguments) => Variant(id, tag, arguments.map(f))
    Match(id, value, arms) =>
      Match(id, f(value), arms.map(arm => { ..arm, body: f(arm.body), }))
  }
}

///|
fn Expr::erase_binding(
  self : Expr,
  binder : Binder,
  enums : Array[EnumDefinition],
) -> Expr {
  match self {
    Ref(id) if id == binder.id => binder.ty.zero(enums)
    _ => self.map_children(child => child.erase_binding(binder, enums))
  }
}

///|
fn Expr::erase_function(
  self : Expr,
  removed : Int,
  returns : Ty,
  enums : Array[EnumDefinition],
) -> Expr {
  let rewritten = self.map_children(child => {
    child.erase_function(removed, returns, enums)
  })
  match rewritten {
    Call(id, _) if id == removed => returns.zero(enums)
    Call(id, arguments) if id > removed => Call(id - 1, arguments)
    _ => rewritten
  }
}

///|
fn Expr::rewrites(self : Expr, rewrite : (Expr) -> Array[Expr]) -> Array[Expr] {
  let result = rewrite(self)
  let children : Array[Expr] = []
  ignore(
    self.map_children(child => {
      children.push(child)
      child
    }),
  )
  for index, child in children {
    for smaller in child.rewrites(rewrite) {
      let mut position = 0
      result.push(
        self.map_children(original => {
          let replaced = if position == index { smaller } else { original }
          position += 1
          replaced
        }),
      )
    }
  }
  result
}

///|
fn Expr::reductions(self : Expr, enums : Array[EnumDefinition]) -> Array[Expr] {
  self.rewrites(expr => {
    match expr {
      Hole(_) | IntLiteral(_) | BoolLiteral(_) | Ref(_) => []
      Let(binder, value, body) =>
        [
          IntLiteral(0),
          BoolLiteral(false),
          value,
          body.erase_binding(binder, enums),
        ]
      Add(a, b) | Subtract(a, b) | Less(a, b) =>
        [IntLiteral(0), BoolLiteral(false), a, b]
      Not(e) => [BoolLiteral(false), e]
      If(_, yes, no) => [IntLiteral(0), BoolLiteral(false), yes, no]
      Call(_, _) => [IntLiteral(0), BoolLiteral(false)]
      Tuple(fields) => [IntLiteral(0), BoolLiteral(false)] + fields
      Project(value, index) => {
        let result = [IntLiteral(0), BoolLiteral(false), value]
        if value is Tuple(fields) {
          result.push(fields[index])
        }
        result
      }
      Variant(id, _, arguments) => [Ty::Enum(id).zero(enums)] + arguments
      Match(_, _, arms) => {
        let result = [IntLiteral(0), BoolLiteral(false)]
        for arm in arms {
          let mut body = arm.body
          for parameter in arm.parameters {
            body = body.erase_binding(parameter, enums)
          }
          result.push(body)
        }
        result
      }
    }
  })
}

///|
fn Expr::integer_reductions(self : Expr) -> Array[Expr] {
  self.rewrites(expr => {
    match expr {
      IntLiteral(n) if n != 0 => [IntLiteral(0)]
      _ => []
    }
  })
}

///|
fn Template::rewrite_expressions(
  self : Template,
  rewrite : (Expr) -> Array[Expr],
) -> Array[Template] {
  let candidates : Array[Template] = []
  for result in rewrite(self.result) {
    candidates.push({ ..self, result, })
  }
  for id, function in self.functions {
    for body in rewrite(function.body) {
      let functions = self.functions.copy()
      functions[id] = { ..function, body, }
      candidates.push({ ..self, functions, })
    }
  }
  candidates
}

///|
fn CompleteProgram::structural_templates(
  self : CompleteProgram,
) -> Array[Template] {
  let syntax = self.syntax
  let candidates : Array[Template] = []
  for removed, function in syntax.functions {
    let functions : Array[Function] = []
    for id, other in syntax.functions {
      if id != removed {
        functions.push({
          ..other,
          body: other.body.erase_function(
            removed,
            function.returns,
            syntax.enums,
          ),
        })
      }
    }
    candidates.push({
      enums: syntax.enums,
      functions,
      result: syntax.result.erase_function(
        removed,
        function.returns,
        syntax.enums,
      ),
    })
  }
  for length = syntax.enums.length() - 1; length >= 0; length = length - 1 {
    candidates.push({ ..syntax, enums: syntax.enums[:length].to_owned(), })
  }
  for
    candidate in syntax.rewrite_expressions(expr => {
      expr.reductions(syntax.enums)
    }) {
    candidates.push(candidate)
  }
  candidates
}

///|
fn CompleteProgram::checked_candidates(
  self : CompleteProgram,
  candidates : Array[Template],
) -> Array[CompleteProgram] {
  let seen : Map[String, Unit] = Map([])
  let result : Array[CompleteProgram] = []
  for candidate in candidates {
    let complete = Some(candidate.finish()) catch { _ => None }
    if complete is Some(program) &&
      program.result_type() == self.result_type() &&
      program.is_smaller_than(self) {
      let source = program.emit()
      if !seen.contains(source) {
        seen[source] = ()
        result.push(program)
      }
    }
  }
  result
}

///|
pub fn CompleteProgram::structural_candidates(
  self : CompleteProgram,
) -> Array[CompleteProgram] {
  self.checked_candidates(self.structural_templates())
}

///|
pub fn CompleteProgram::integer_candidates(
  self : CompleteProgram,
) -> Array[CompleteProgram] {
  self.checked_candidates(
    self.syntax.rewrite_expressions(expr => expr.integer_reductions()),
  )
}

///|
/// Stable, cost-decreasing candidates; every rewrite passes the complete checker.
pub fn CompleteProgram::candidates(
  self : CompleteProgram,
) -> Array[CompleteProgram] {
  let candidates = self.structural_templates()
  for
    candidate in self.syntax.rewrite_expressions(expr => {
      expr.integer_reductions()
    }) {
    candidates.push(candidate)
  }
  self.checked_candidates(candidates)
}
