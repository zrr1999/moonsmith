///|
pub(all) enum Ty {
  Int
  Bool
} derive(Eq, @debug.Debug)

///|
pub(all) struct Binder {
  id : Int
  ty : Ty
} derive(Eq, @debug.Debug)

///|
/// Templates and complete programs share these structural nodes.
pub(all) enum Expr {
  Hole(Ty)
  IntLiteral(Int)
  BoolLiteral(Bool)
  Ref(Int)
  Let(Binder, Expr, Expr)
  Add(Expr, Expr)
  Subtract(Expr, Expr)
  Less(Expr, Expr)
  Not(Expr)
  If(Expr, Expr, Expr)
  Call(Int, Array[Expr])
} derive(Eq, @debug.Debug)

///|
/// A function's identifier is its index in Template.functions.
pub(all) struct Function {
  parameters : Array[Binder]
  returns : Ty
  body : Expr
} derive(Eq, @debug.Debug)

///|
pub(all) struct Template {
  functions : Array[Function]
  result : Expr
} derive(Eq, @debug.Debug)

///|
/// A private snapshot prevents mutable template arrays from invalidating the check.
/// Structural validity does not certify compiler acceptance or execution results.
pub struct CompleteProgram {
  priv syntax : Template
  priv result_ty : Ty
} derive(Eq, @debug.Debug)

///|
pub(all) suberror StructureError {
  UnfilledHole(Ty)
  InvalidBinder(Int)
  DuplicateBinding(Int)
  UnknownBinding(Int)
  TypeMismatch(Ty, Ty)
  UnknownFunction(Int)
  ArgumentCount(Int, Int, Int)
  CyclicCall(Int)
} derive(Eq, @debug.Debug)

///|
fn Expr::snapshot(self : Expr) -> Expr {
  match self {
    Hole(_) | IntLiteral(_) | BoolLiteral(_) | Ref(_) => self
    Let(binder, value, body) => Let(binder, value.snapshot(), body.snapshot())
    Add(a, b) => Add(a.snapshot(), b.snapshot())
    Subtract(a, b) => Subtract(a.snapshot(), b.snapshot())
    Less(a, b) => Less(a.snapshot(), b.snapshot())
    Not(e) => Not(e.snapshot())
    If(condition, yes, no) =>
      If(condition.snapshot(), yes.snapshot(), no.snapshot())
    Call(function, arguments) =>
      Call(function, arguments.map(e => e.snapshot()))
  }
}

///|
fn Template::snapshot(self : Template) -> Template {
  {
    functions: self.functions.map(f => {
      parameters: f.parameters.copy(),
      returns: f.returns,
      body: f.body.snapshot(),
    }),
    result: self.result.snapshot(),
  }
}

///|
fn Expr::size(self : Expr) -> Int {
  match self {
    Hole(_) | IntLiteral(_) | BoolLiteral(_) | Ref(_) => 1
    Let(_, value, body)
    | Add(value, body)
    | Subtract(value, body)
    | Less(value, body) => 1 + value.size() + body.size()
    Not(e) => 1 + e.size()
    If(condition, yes, no) => 1 + condition.size() + yes.size() + no.size()
    Call(_, arguments) => arguments.fold(init=1, (n, e) => n + e.size())
  }
}

///|
/// Count each expression, function and parameter once; a hole occupies one node.
pub fn Template::size(self : Template) -> Int {
  self.functions.fold(init=self.result.size(), (n, f) => {
    n + 1 + f.parameters.length() + f.body.size()
  })
}

///|
fn Expr::depth(self : Expr) -> Int {
  match self {
    Hole(_) | IntLiteral(_) | BoolLiteral(_) | Ref(_) => 0
    Let(_, value, body)
    | Add(value, body)
    | Subtract(value, body)
    | Less(value, body) => 1 + value.depth().max(body.depth())
    Not(e) => 1 + e.depth()
    If(condition, yes, no) =>
      1 + condition.depth().max(yes.depth()).max(no.depth())
    Call(_, arguments) => 1 + arguments.fold(init=0, (n, e) => n.max(e.depth()))
  }
}

///|
/// Maximum expression nesting, independent of the runtime call-stack depth.
pub fn Template::depth(self : Template) -> Int {
  self.functions.fold(init=self.result.depth(), (n, f) => n.max(f.body.depth()))
}

///|
pub fn CompleteProgram::size(self : CompleteProgram) -> Int {
  self.syntax.size()
}

///|
pub fn CompleteProgram::depth(self : CompleteProgram) -> Int {
  self.syntax.depth()
}

///|
pub fn CompleteProgram::result_type(self : CompleteProgram) -> Ty {
  self.result_ty
}

///|
pub extend Ty with Eq::{equal, not_equal}

///|
pub extend Ty with @debug.Debug::{to_repr}

///|
pub extend Binder with Eq::{equal, not_equal}

///|
pub extend Binder with @debug.Debug::{to_repr}

///|
pub extend Expr with Eq::{equal, not_equal}

///|
pub extend Expr with @debug.Debug::{to_repr}

///|
pub extend Function with Eq::{equal, not_equal}

///|
pub extend Function with @debug.Debug::{to_repr}

///|
pub extend Template with Eq::{equal, not_equal}

///|
pub extend Template with @debug.Debug::{to_repr}

///|
pub extend CompleteProgram with Eq::{equal, not_equal}

///|
pub extend CompleteProgram with @debug.Debug::{to_repr}

///|
pub extend StructureError with Eq::{equal, not_equal}

///|
pub extend StructureError with @debug.Debug::{to_repr}
