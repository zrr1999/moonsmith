///|
fn Ty::zero(self : Ty) -> Expr {
  match self {
    Int => IntLiteral(0)
    Bool => BoolLiteral(false)
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
  }
}

///|
fn Expr::erase_binding(self : Expr, binder : Binder) -> Expr {
  match self {
    Ref(id) if id == binder.id => binder.ty.zero()
    _ => self.map_children(child => child.erase_binding(binder))
  }
}

///|
fn Expr::erase_function(self : Expr, removed : Int, returns : Ty) -> Expr {
  let rewritten = self.map_children(child => {
    child.erase_function(removed, returns)
  })
  match rewritten {
    Call(id, _) if id == removed => returns.zero()
    Call(id, arguments) if id > removed => Call(id - 1, arguments)
    _ => rewritten
  }
}

///|
fn Expr::reductions(self : Expr) -> Array[Expr] {
  let result : Array[Expr] = match self {
    Hole(_) | IntLiteral(_) | BoolLiteral(_) | Ref(_) => []
    Let(binder, value, body) =>
      [IntLiteral(0), BoolLiteral(false), value, body.erase_binding(binder)]
    Add(a, b) | Subtract(a, b) | Less(a, b) =>
      [IntLiteral(0), BoolLiteral(false), a, b]
    Not(e) => [BoolLiteral(false), e]
    If(_, yes, no) => [IntLiteral(0), BoolLiteral(false), yes, no]
    Call(_, _) => [IntLiteral(0), BoolLiteral(false)]
  }
  let children : Array[Expr] = []
  ignore(
    self.map_children(child => {
      children.push(child)
      child
    }),
  )
  for index, child in children {
    for smaller in child.reductions() {
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
/// Stable, strictly smaller candidates; every rewrite passes the complete checker.
pub fn CompleteProgram::candidates(
  self : CompleteProgram,
) -> Array[CompleteProgram] {
  let syntax = self.syntax
  let candidates : Array[Template] = []
  for removed, function in syntax.functions {
    let functions : Array[Function] = []
    for id, other in syntax.functions {
      if id != removed {
        functions.push({
          ..other,
          body: other.body.erase_function(removed, function.returns),
        })
      }
    }
    candidates.push({
      functions,
      result: syntax.result.erase_function(removed, function.returns),
    })
  }
  for result in syntax.result.reductions() {
    candidates.push({ ..syntax, result, })
  }
  for id, function in syntax.functions {
    for body in function.body.reductions() {
      let functions = syntax.functions.copy()
      functions[id] = { ..function, body, }
      candidates.push({ ..syntax, functions, })
    }
  }
  let seen : Map[String, Unit] = Map([])
  let result : Array[CompleteProgram] = []
  for candidate in candidates {
    if candidate.size() >= self.size() {
      continue
    }
    let complete = Some(candidate.finish()) catch { _ => None }
    if complete is Some(program) && program.result_type() == self.result_type() {
      let source = program.emit()
      if !seen.contains(source) {
        seen[source] = ()
        result.push(program)
      }
    }
  }
  result
}
