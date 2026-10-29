///|
pub(all) enum Ty {
  Int
  Bool
  Tuple(Array[Ty])
  Enum(Int32)
} derive(Eq, @debug.Debug)

///|
pub(all) struct EnumDefinition {
  variants : Array[Array[Ty]]
} derive(Eq, @debug.Debug)

///|
pub(all) struct Binder {
  id : Int32
  ty : Ty
} derive(Eq, @debug.Debug)

///|
/// Templates and complete programs share these structural nodes.
pub(all) enum Expr {
  Hole(Ty)
  IntLiteral(Int32)
  BoolLiteral(Bool)
  Ref(Int32)
  Let(Binder, Expr, Expr)
  Add(Expr, Expr)
  Subtract(Expr, Expr)
  Less(Expr, Expr)
  Not(Expr)
  If(Expr, Expr, Expr)
  Call(Int32, Array[Expr])
  Tuple(Array[Expr])
  Project(Expr, Int32)
  Variant(Int32, Int32, Array[Expr])
  Match(Int32, Expr, Array[MatchArm])
} derive(Eq, @debug.Debug)

///|
pub(all) struct MatchArm {
  parameters : Array[Binder]
  body : Expr
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
  enums : Array[EnumDefinition]
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
  InvalidBinder(Int32)
  DuplicateBinding(Int32)
  UnknownBinding(Int32)
  TypeMismatch(Ty, Ty)
  UnknownFunction(Int32)
  ArgumentCount(Int32, Int32, Int32)
  CyclicCall(Int32)
  InvalidTupleArity(Int32)
  ExpectedTuple(Ty)
  InvalidProjection(Int32, Int32)
  UnknownEnum(Int32)
  EmptyEnum(Int32)
  CyclicEnum(Int32)
  UnknownVariant(Int32, Int32)
  VariantArguments(Int32, Int32, Int32, Int32)
  MatchArms(Int32, Int32, Int32)
  PatternArguments(Int32, Int32, Int32, Int32)
  UnsupportedResultType(Ty)
} derive(Eq, @debug.Debug)

///|
fn Ty::snapshot(self : Ty) -> Ty {
  match self {
    Tuple(fields) => Tuple(fields.map(ty => ty.snapshot()))
    _ => self
  }
}

///|
fn Binder::snapshot(self : Binder) -> Binder {
  { id: self.id, ty: self.ty.snapshot(), }
}

///|
fn Expr::snapshot(self : Expr) -> Expr {
  match self {
    Hole(ty) => Hole(ty.snapshot())
    IntLiteral(_) | BoolLiteral(_) | Ref(_) => self
    Let(binder, value, body) =>
      Let(binder.snapshot(), value.snapshot(), body.snapshot())
    Add(a, b) => Add(a.snapshot(), b.snapshot())
    Subtract(a, b) => Subtract(a.snapshot(), b.snapshot())
    Less(a, b) => Less(a.snapshot(), b.snapshot())
    Not(e) => Not(e.snapshot())
    If(condition, yes, no) =>
      If(condition.snapshot(), yes.snapshot(), no.snapshot())
    Call(function, arguments) =>
      Call(function, arguments.map(e => e.snapshot()))
    Tuple(fields) => Tuple(fields.map(e => e.snapshot()))
    Project(value, index) => Project(value.snapshot(), index)
    Variant(id, tag, arguments) =>
      Variant(id, tag, arguments.map(e => e.snapshot()))
    Match(id, value, arms) =>
      Match(
        id,
        value.snapshot(),
        arms.map(arm => {
          parameters: arm.parameters.map(binder => binder.snapshot()),
          body: arm.body.snapshot(),
        }),
      )
  }
}

///|
fn Template::snapshot(self : Template) -> Template {
  {
    enums: self.enums.map(definition => {
      variants: definition.variants.map(fields => {
        fields.map(ty => ty.snapshot())
      }),
    }),
    functions: self.functions.map(f => {
      parameters: f.parameters.map(binder => binder.snapshot()),
      returns: f.returns.snapshot(),
      body: f.body.snapshot(),
    }),
    result: self.result.snapshot(),
  }
}

///|
fn Expr::size(self : Expr) -> Int32 {
  match self {
    Hole(_) | IntLiteral(_) | BoolLiteral(_) | Ref(_) => 1
    Let(_, value, body)
    | Add(value, body)
    | Subtract(value, body)
    | Less(value, body) => 1 + value.size() + body.size()
    Not(e) => 1 + e.size()
    If(condition, yes, no) => 1 + condition.size() + yes.size() + no.size()
    Call(_, arguments) => arguments.fold(init=1, (n, e) => n + e.size())
    Tuple(fields) | Variant(_, _, fields) =>
      fields.fold(init=1, (n, e) => n + e.size())
    Project(value, _) => 1 + value.size()
    Match(_, value, arms) =>
      arms.fold(init=1 + value.size(), (n, arm) => {
        n + arm.parameters.length() + arm.body.size()
      })
  }
}

///|
fn EnumDefinition::size(self : EnumDefinition) -> Int32 {
  self.variants.fold(init=1, (n, fields) => n + 1 + fields.length())
}

///|
/// Count expressions, definitions, constructors and parameters; a hole occupies one node.
pub fn Template::size(self : Template) -> Int32 {
  let declarations = self.enums.fold(init=0, (n, definition) => {
    n + definition.size()
  })
  self.functions.fold(init=declarations + self.result.size(), (n, f) => {
    n + 1 + f.parameters.length() + f.body.size()
  })
}

///|
fn Expr::depth(self : Expr) -> Int32 {
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
    Tuple(fields) | Variant(_, _, fields) =>
      if fields.is_empty() {
        0
      } else {
        1 + fields.fold(init=0, (n, e) => n.max(e.depth()))
      }
    Project(value, _) => 1 + value.depth()
    Match(_, value, arms) =>
      1 + arms.fold(init=value.depth(), (n, arm) => n.max(arm.body.depth()))
  }
}

///|
/// Maximum expression nesting, independent of the runtime call-stack depth.
pub fn Template::depth(self : Template) -> Int32 {
  self.functions.fold(init=self.result.depth(), (n, f) => n.max(f.body.depth()))
}

///|
pub fn CompleteProgram::size(self : CompleteProgram) -> Int32 {
  self.syntax.size()
}

///|
pub fn CompleteProgram::depth(self : CompleteProgram) -> Int32 {
  self.syntax.depth()
}

///|
pub fn CompleteProgram::result_type(self : CompleteProgram) -> Ty {
  self.result_ty.snapshot()
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

///|
pub extend EnumDefinition with Eq::{equal, not_equal}

///|
pub extend EnumDefinition with @debug.Debug::{to_repr}

///|
pub extend MatchArm with Eq::{equal, not_equal}

///|
pub extend MatchArm with @debug.Debug::{to_repr}
