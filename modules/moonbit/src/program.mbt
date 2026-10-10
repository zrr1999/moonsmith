///|
pub(all) enum IntExpr {
  Literal(Int)
  Variable(Int)
  Add(IntExpr, IntExpr)
  Subtract(IntExpr, IntExpr)
  Choose(BoolExpr, IntExpr, IntExpr)
} derive(Eq, @debug.Debug)

///|
pub(all) enum BoolExpr {
  Boolean(Bool)
  Less(IntExpr, IntExpr)
  Not(BoolExpr)
} derive(Eq, @debug.Debug)

///|
pub(all) struct Program {
  bindings : Array[IntExpr]
  result : IntExpr
} derive(Eq, @debug.Debug)

///|
fn IntExpr::evaluate(self : IntExpr, scope : Array[Int]) -> Int? {
  let value : Int64 = match self {
    Literal(n) => n.to_int64()
    Variable(index) => {
      guard index >= 0 && index < scope.length() else { return None }
      scope[index].to_int64()
    }
    Add(a, b) => {
      guard a.evaluate(scope) is Some(x) else { return None }
      guard b.evaluate(scope) is Some(y) else { return None }
      x.to_int64() + y.to_int64()
    }
    Subtract(a, b) => {
      guard a.evaluate(scope) is Some(x) else { return None }
      guard b.evaluate(scope) is Some(y) else { return None }
      x.to_int64() - y.to_int64()
    }
    Choose(c, a, b) => {
      guard c.evaluate(scope) is Some(condition) else { return None }
      // Validate both branches, including dead code, before accepting a program.
      guard a.evaluate(scope) is Some(x) else { return None }
      guard b.evaluate(scope) is Some(y) else { return None }
      (if condition { x } else { y }).to_int64()
    }
  }
  if value < -2147483648L || value > 2147483647L {
    None
  } else {
    Some(value.to_int())
  }
}

///|
fn BoolExpr::evaluate(self : BoolExpr, scope : Array[Int]) -> Bool? {
  match self {
    Boolean(b) => Some(b)
    Less(a, b) => {
      guard a.evaluate(scope) is Some(x) else { return None }
      guard b.evaluate(scope) is Some(y) else { return None }
      Some(x < y)
    }
    Not(e) => e.evaluate(scope).map(b => !b)
  }
}

///|
pub fn Program::evaluate(self : Program) -> Int? {
  let scope : Array[Int] = []
  for binding in self.bindings {
    guard binding.evaluate(scope) is Some(value) else { return None }
    scope.push(value)
  }
  self.result.evaluate(scope)
}

///|
pub fn Program::valid(self : Program) -> Bool {
  self.evaluate() is Some(_)
}

///|
fn IntExpr::size(self : IntExpr) -> Int {
  match self {
    Literal(_) | Variable(_) => 1
    Add(a, b) | Subtract(a, b) => 1 + a.size() + b.size()
    Choose(c, a, b) => 1 + c.size() + a.size() + b.size()
  }
}

///|
fn BoolExpr::size(self : BoolExpr) -> Int {
  match self {
    Boolean(_) => 1
    Less(a, b) => 1 + a.size() + b.size()
    Not(e) => 1 + e.size()
  }
}

///|
pub fn Program::size(self : Program) -> Int {
  self.bindings.fold(init=self.result.size(), (n, e) => n + 1 + e.size())
}

///|
fn IntExpr::emit(self : IntExpr) -> String {
  match self {
    Literal(n) => if n < 0 { "(\{n})" } else { "\{n}" }
    Variable(index) => "v\{index}"
    Add(a, b) => "(\{a.emit()} + \{b.emit()})"
    Subtract(a, b) => "(\{a.emit()} - \{b.emit()})"
    Choose(c, a, b) => "(if \{c.emit()} { \{a.emit()} } else { \{b.emit()} })"
  }
}

///|
fn BoolExpr::emit(self : BoolExpr) -> String {
  match self {
    Boolean(b) => "\{b}"
    Less(a, b) => "(\{a.emit()} < \{b.emit()})"
    Not(e) => "(!\{e.emit()})"
  }
}

///|
pub fn Program::emit(self : Program) -> String {
  let lines = ["fn main {"]
  for i, e in self.bindings {
    lines.push("  let v\{i} : Int = \{e.emit()}")
  }
  lines.push("  println(\{self.result.emit()})")
  lines.push("}")
  lines.join("\n") + "\n"
}

///|
pub extend IntExpr with Eq::{equal, not_equal}

///|
pub extend BoolExpr with Eq::{equal, not_equal}

///|
pub extend Program with Eq::{equal, not_equal}

///|
pub extend IntExpr with @debug.Debug::{to_repr}

///|
pub extend BoolExpr with @debug.Debug::{to_repr}

///|
pub extend Program with @debug.Debug::{to_repr}
