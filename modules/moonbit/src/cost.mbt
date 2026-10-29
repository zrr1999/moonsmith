///|
pub fn reduction_cost_model() -> String {
  "moonbit-nodes-int-magnitude-utf8-v1"
}

///|
fn Expr::integer_magnitude(self : Expr) -> Int64 {
  match self {
    IntLiteral(n) => {
      let widened = n.to_int64()
      if widened < 0L {
        -widened
      } else {
        widened
      }
    }
    Hole(_) | BoolLiteral(_) | Ref(_) => 0L
    Let(_, value, body)
    | Add(value, body)
    | Subtract(value, body)
    | Less(value, body) => value.integer_magnitude() + body.integer_magnitude()
    Not(e) => e.integer_magnitude()
    If(condition, yes, no) =>
      condition.integer_magnitude() +
      yes.integer_magnitude() +
      no.integer_magnitude()
    Call(_, arguments) | Tuple(arguments) | Variant(_, _, arguments) =>
      arguments.fold(init=0L, (n, e) => n + e.integer_magnitude())
    Project(value, _) => value.integer_magnitude()
    Match(_, value, arms) =>
      arms.fold(init=value.integer_magnitude(), (n, arm) => {
        n + arm.body.integer_magnitude()
      })
  }
}

///|
pub fn CompleteProgram::cost(
  self : CompleteProgram,
) -> @contracts.ReductionCost {
  {
    nodes: self.size(),
    integer_magnitude: self.syntax.functions.fold(
      init=self.syntax.result.integer_magnitude(),
      (n, f) => n + f.body.integer_magnitude(),
    ),
    source_bytes: @utf8.encode(self.emit()).length(),
  }
}

///|
pub fn CompleteProgram::is_smaller_than(
  self : CompleteProgram,
  other : CompleteProgram,
) -> Bool {
  let candidate = self.cost()
  let incumbent = other.cost()
  cost_is_smaller(candidate, incumbent)
}

///|
fn cost_is_smaller(
  candidate : @contracts.ReductionCost,
  incumbent : @contracts.ReductionCost,
) -> Bool {
  if candidate.nodes != incumbent.nodes {
    candidate.nodes < incumbent.nodes
  } else if candidate.integer_magnitude != incumbent.integer_magnitude {
    candidate.integer_magnitude < incumbent.integer_magnitude
  } else {
    candidate.source_bytes < incumbent.source_bytes
  }
}
