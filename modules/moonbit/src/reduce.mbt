///|
fn IntExpr::without_binding(self : IntExpr, removed : Int) -> IntExpr {
  match self {
    Literal(_) => self
    Variable(i) =>
      if i == removed {
        Literal(0)
      } else if i > removed {
        Variable(i - 1)
      } else {
        self
      }
    Add(a, b) => Add(a.without_binding(removed), b.without_binding(removed))
    Subtract(a, b) =>
      Subtract(a.without_binding(removed), b.without_binding(removed))
    Choose(c, a, b) =>
      Choose(
        c.without_binding(removed),
        a.without_binding(removed),
        b.without_binding(removed),
      )
  }
}

///|
fn BoolExpr::without_binding(self : BoolExpr, removed : Int) -> BoolExpr {
  match self {
    Boolean(_) => self
    Less(a, b) => Less(a.without_binding(removed), b.without_binding(removed))
    Not(e) => Not(e.without_binding(removed))
  }
}

///|
fn IntExpr::simpler(self : IntExpr) -> Array[IntExpr] {
  match self {
    Literal(0) => []
    Literal(_) | Variable(_) => [Literal(0)]
    Add(a, b) | Subtract(a, b) => [Literal(0), a, b]
    Choose(_, a, b) => [Literal(0), a, b]
  }
}

///|
/// Candidates preserve types and repair references when a binding is removed.
pub fn Program::candidates(self : Program) -> Array[Program] {
  let result : Array[Program] = []
  for removed = 0; removed < self.bindings.length(); removed = removed + 1 {
    let bindings : Array[IntExpr] = []
    for i, e in self.bindings {
      if i != removed {
        bindings.push(e.without_binding(removed))
      }
    }
    result.push({ bindings, result: self.result.without_binding(removed), })
  }
  for e in self.result.simpler() {
    result.push({ bindings: self.bindings, result: e, })
  }
  for i, e in self.bindings {
    for smaller in e.simpler() {
      let bindings = self.bindings.copy()
      bindings[i] = smaller
      result.push({ bindings, result: self.result, })
    }
  }
  result.filter(p => p.size() < self.size() && p.valid())
}
