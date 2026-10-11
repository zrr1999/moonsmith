///|
fn require_type(actual : Ty, expected : Ty) -> Unit raise StructureError {
  guard actual == expected else { raise TypeMismatch(expected, actual) }
}

///|
fn bind(
  scope : Array[Binder],
  binder : Binder,
) -> Array[Binder] raise StructureError {
  guard binder.id >= 0 else { raise InvalidBinder(binder.id) }
  guard !scope.any(existing => existing.id == binder.id) else {
    raise DuplicateBinding(binder.id)
  }
  let next = scope.copy()
  next.push(binder)
  next
}

///|
fn Expr::infer(
  self : Expr,
  scope : Array[Binder],
  functions : Array[Function],
  calls : Array[Int],
  allow_holes : Bool,
) -> Ty raise StructureError {
  match self {
    Hole(ty) => if allow_holes { ty } else { raise UnfilledHole(ty) }
    IntLiteral(_) => Int
    BoolLiteral(_) => Bool
    Ref(id) => {
      for binder in scope {
        if binder.id == id {
          return binder.ty
        }
      }
      raise UnknownBinding(id)
    }
    Let(binder, value, body) => {
      require_type(value.infer(scope, functions, calls, allow_holes), binder.ty)
      body.infer(bind(scope, binder), functions, calls, allow_holes)
    }
    Add(a, b) | Subtract(a, b) => {
      require_type(a.infer(scope, functions, calls, allow_holes), Int)
      require_type(b.infer(scope, functions, calls, allow_holes), Int)
      Int
    }
    Less(a, b) => {
      require_type(a.infer(scope, functions, calls, allow_holes), Int)
      require_type(b.infer(scope, functions, calls, allow_holes), Int)
      Bool
    }
    Not(e) => {
      require_type(e.infer(scope, functions, calls, allow_holes), Bool)
      Bool
    }
    If(condition, yes, no) => {
      require_type(condition.infer(scope, functions, calls, allow_holes), Bool)
      let ty = yes.infer(scope, functions, calls, allow_holes)
      require_type(no.infer(scope, functions, calls, allow_holes), ty)
      ty
    }
    Call(id, arguments) => {
      guard id >= 0 && id < functions.length() else {
        raise UnknownFunction(id)
      }
      let function = functions[id]
      guard arguments.length() == function.parameters.length() else {
        raise ArgumentCount(
          id,
          function.parameters.length(),
          arguments.length(),
        )
      }
      for i, argument in arguments {
        require_type(
          argument.infer(scope, functions, calls, allow_holes),
          function.parameters[i].ty,
        )
      }
      calls.push(id)
      function.returns
    }
  }
}

///|
fn visit_calls(
  id : Int,
  graph : Array[Array[Int]],
  state : Array[Int],
) -> Unit raise StructureError {
  if state[id] == 1 {
    raise CyclicCall(id)
  }
  if state[id] == 2 {
    return
  }
  state[id] = 1
  for target in graph[id] {
    visit_calls(target, graph, state)
  }
  state[id] = 2
}

///|
fn Template::check_structure(
  self : Template,
  allow_holes : Bool,
) -> Ty raise StructureError {
  let graph : Array[Array[Int]] = []
  for function in self.functions {
    let mut scope : Array[Binder] = []
    for parameter in function.parameters {
      scope = bind(scope, parameter)
    }
    let calls : Array[Int] = []
    require_type(
      function.body.infer(scope, self.functions, calls, allow_holes),
      function.returns,
    )
    graph.push(calls)
  }
  let state = Array::make(self.functions.length(), 0)
  for id = 0; id < self.functions.length(); id = id + 1 {
    visit_calls(id, graph, state)
  }
  self.result.infer([], self.functions, [], allow_holes)
}

///|
/// Check the constraints of a partial program. Typed holes remain permissible.
pub fn Template::check(self : Template) -> Ty raise StructureError {
  self.check_structure(true)
}

///|
/// Require a complete, well-formed, acyclic program and take an owned snapshot.
pub fn Template::finish(
  self : Template,
) -> CompleteProgram raise StructureError {
  let syntax = self.snapshot()
  let result_ty = syntax.check_structure(false)
  { syntax, result_ty, }
}
