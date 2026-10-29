///|
fn require_type(actual : Ty, expected : Ty) -> Unit raise StructureError {
  guard actual == expected else { raise TypeMismatch(expected, actual) }
}

///|
fn Ty::dependencies(
  self : Ty,
  enums : Int32,
) -> Array[Int32] raise StructureError {
  match self {
    Int | Bool => []
    Enum(id) => {
      guard id >= 0 && id < enums else { raise UnknownEnum(id) }
      [id]
    }
    Tuple(fields) => {
      guard fields.length() >= 2 else {
        raise InvalidTupleArity(fields.length())
      }
      let dependencies = []
      for field in fields {
        dependencies.append(field.dependencies(enums))
      }
      dependencies
    }
  }
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
priv struct Checking {
  enums : Array[EnumDefinition]
  functions : Array[Function]
  calls : Array[Int32]
  allow_holes : Bool
}

///|
fn Checking::definition(
  self : Checking,
  id : Int32,
) -> EnumDefinition raise StructureError {
  guard id >= 0 && id < self.enums.length() else { raise UnknownEnum(id) }
  self.enums[id]
}

///|
fn Checking::infer(
  self : Checking,
  expression : Expr,
  scope : Array[Binder],
) -> Ty raise StructureError {
  match expression {
    Hole(ty) => {
      ignore(ty.dependencies(self.enums.length()))
      if self.allow_holes {
        ty
      } else {
        raise UnfilledHole(ty)
      }
    }
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
      ignore(binder.ty.dependencies(self.enums.length()))
      require_type(self.infer(value, scope), binder.ty)
      self.infer(body, bind(scope, binder))
    }
    Add(a, b) | Subtract(a, b) => {
      require_type(self.infer(a, scope), Int)
      require_type(self.infer(b, scope), Int)
      Int
    }
    Less(a, b) => {
      require_type(self.infer(a, scope), Int)
      require_type(self.infer(b, scope), Int)
      Bool
    }
    Not(e) => {
      require_type(self.infer(e, scope), Bool)
      Bool
    }
    If(condition, yes, no) => {
      require_type(self.infer(condition, scope), Bool)
      let ty = self.infer(yes, scope)
      require_type(self.infer(no, scope), ty)
      ty
    }
    Call(id, arguments) => {
      guard id >= 0 && id < self.functions.length() else {
        raise UnknownFunction(id)
      }
      let function = self.functions[id]
      guard arguments.length() == function.parameters.length() else {
        raise ArgumentCount(
          id,
          function.parameters.length(),
          arguments.length(),
        )
      }
      for index, argument in arguments {
        require_type(self.infer(argument, scope), function.parameters[index].ty)
      }
      self.calls.push(id)
      function.returns
    }
    Tuple(fields) => {
      guard fields.length() >= 2 else {
        raise InvalidTupleArity(fields.length())
      }
      Ty::Tuple(fields.map(field => self.infer(field, scope)))
    }
    Project(value, index) => {
      let ty = self.infer(value, scope)
      guard ty is Ty::Tuple(fields) else { raise ExpectedTuple(ty) }
      guard index >= 0 && index < fields.length() else {
        raise InvalidProjection(index, fields.length())
      }
      fields[index]
    }
    Variant(id, tag, arguments) => {
      let definition = self.definition(id)
      guard tag >= 0 && tag < definition.variants.length() else {
        raise UnknownVariant(id, tag)
      }
      let fields = definition.variants[tag]
      guard fields.length() == arguments.length() else {
        raise VariantArguments(id, tag, fields.length(), arguments.length())
      }
      for index, argument in arguments {
        require_type(self.infer(argument, scope), fields[index])
      }
      Enum(id)
    }
    Match(id, value, arms) => {
      let definition = self.definition(id)
      require_type(self.infer(value, scope), Enum(id))
      guard arms.length() == definition.variants.length() else {
        raise MatchArms(id, definition.variants.length(), arms.length())
      }
      let mut result : Ty? = None
      for tag, arm in arms {
        let fields = definition.variants[tag]
        guard arm.parameters.length() == fields.length() else {
          raise PatternArguments(
            id,
            tag,
            fields.length(),
            arm.parameters.length(),
          )
        }
        let mut nested = scope
        for index, parameter in arm.parameters {
          require_type(parameter.ty, fields[index])
          nested = bind(nested, parameter)
        }
        let ty = self.infer(arm.body, nested)
        match result {
          None => result = Some(ty)
          Some(expected) => require_type(ty, expected)
        }
      }
      result.unwrap()
    }
  }
}

///|
fn visit_dependencies(
  id : Int32,
  graph : Array[Array[Int32]],
  state : Array[Int32],
  cycle : (Int32) -> StructureError,
) -> Unit raise StructureError {
  if state[id] == 1 {
    raise cycle(id)
  }
  if state[id] == 2 {
    return
  }
  state[id] = 1
  for target in graph[id] {
    visit_dependencies(target, graph, state, cycle)
  }
  state[id] = 2
}

///|
fn Template::check_structure(
  self : Template,
  allow_holes : Bool,
) -> Ty raise StructureError {
  let types : Array[Array[Int32]] = []
  for id, definition in self.enums {
    guard !definition.variants.is_empty() else { raise EmptyEnum(id) }
    let dependencies = []
    for fields in definition.variants {
      for ty in fields {
        dependencies.append(ty.dependencies(self.enums.length()))
      }
    }
    types.push(dependencies)
  }
  let type_state = Array::make(types.length(), 0)
  for id in 0..<types.length() {
    visit_dependencies(id, types, type_state, id => CyclicEnum(id))
  }
  let graph : Array[Array[Int32]] = []
  for function in self.functions {
    ignore(function.returns.dependencies(self.enums.length()))
    let mut scope = []
    for parameter in function.parameters {
      ignore(parameter.ty.dependencies(self.enums.length()))
      scope = bind(scope, parameter)
    }
    let checking = {
      enums: self.enums,
      functions: self.functions,
      calls: [],
      allow_holes,
    }
    require_type(checking.infer(function.body, scope), function.returns)
    graph.push(checking.calls)
  }
  let state = Array::make(self.functions.length(), 0)
  for id in 0..<self.functions.length() {
    visit_dependencies(id, graph, state, id => CyclicCall(id))
  }
  Checking::{
    enums: self.enums,
    functions: self.functions,
    calls: [],
    allow_holes,
  }.infer(self.result, [])
}

///|
/// Check every definition and branch, allowing well-typed holes.
pub fn Template::check(self : Template) -> Ty raise StructureError {
  self.check_structure(true)
}

///|
/// Own a complete checked snapshot whose result has a supported observation protocol.
pub fn Template::finish(
  self : Template,
) -> CompleteProgram raise StructureError {
  let syntax = self.snapshot()
  let result_ty = syntax.check_structure(false)
  guard result_ty.result_protocol() is Some(_) else {
    raise UnsupportedResultType(result_ty)
  }
  { syntax, result_ty, }
}
