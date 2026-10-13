///|
fn structure_error(template : Template) -> StructureError? {
  try {
    ignore(template.finish())
    None
  } catch {
    error => Some(error)
  }
}

///|
test "typed holes are valid in templates but cannot become complete programs" {
  let template : Template = { functions: [], result: Hole(Int), }
  @debug.assert_eq(template.check(), Ty::Int)
  @debug.assert_eq(structure_error(template), Some(UnfilledHole(Int)))
  let incompatible : Template = {
    functions: [],
    result: Let({ id: 0, ty: Bool, }, Hole(Int), Ref(0)),
  }
  let error = try {
    ignore(incompatible.check())
    None
  } catch {
    error => Some(error)
  }
  @debug.assert_eq(error, Some(TypeMismatch(Bool, Int)))
}

///|
test "lexical references cannot escape their binding or refer forward" {
  for
    expression in [
      Expr::Ref(0),
      Let({ id: 0, ty: Int, }, Ref(0), IntLiteral(1)),
      Add(Let({ id: 0, ty: Int, }, IntLiteral(1), Ref(0)), Ref(0)),
      If(
        BoolLiteral(true),
        Let({ id: 0, ty: Int, }, IntLiteral(1), Ref(0)),
        Ref(0),
      ),
    ] {
    @debug.assert_eq(
      structure_error({ functions: [], result: expression, }),
      Some(UnknownBinding(0)),
    )
  }
  @debug.assert_eq(
    structure_error({ functions: [], result: Ref(-1), }),
    Some(UnknownBinding(-1)),
  )
}

///|
test "binding identities are unique within a live scope and can repeat in separate scopes" {
  @debug.assert_eq(
    structure_error({
      functions: [],
      result: Let(
        { id: 0, ty: Int, },
        IntLiteral(1),
        Let({ id: 0, ty: Int, }, IntLiteral(2), Ref(0)),
      ),
    }),
    Some(DuplicateBinding(0)),
  )
  @debug.assert_eq(
    structure_error({
      functions: [],
      result: Let({ id: -1, ty: Int, }, IntLiteral(1), IntLiteral(2)),
    }),
    Some(InvalidBinder(-1)),
  )
  let disjoint : Template = {
    functions: [],
    result: If(
      BoolLiteral(true),
      Let({ id: 0, ty: Int, }, IntLiteral(1), Ref(0)),
      Let({ id: 0, ty: Int, }, IntLiteral(2), Ref(0)),
    ),
  }
  @debug.assert_eq(disjoint.finish().result_type(), Ty::Int)
}

///|
test "operators conditions and both branch results must agree with their types" {
  for
    expression in [
      Expr::Add(BoolLiteral(true), IntLiteral(0)),
      Subtract(IntLiteral(0), BoolLiteral(false)),
      Less(BoolLiteral(true), IntLiteral(0)),
    ] {
    @debug.assert_eq(
      structure_error({ functions: [], result: expression, }),
      Some(TypeMismatch(Int, Bool)),
    )
  }
  for
    expression in [
      Expr::Not(IntLiteral(0)),
      If(IntLiteral(0), IntLiteral(1), IntLiteral(2)),
    ] {
    @debug.assert_eq(
      structure_error({ functions: [], result: expression, }),
      Some(TypeMismatch(Bool, Int)),
    )
  }
  @debug.assert_eq(
    structure_error({
      functions: [],
      result: If(BoolLiteral(true), IntLiteral(1), BoolLiteral(false)),
    }),
    Some(TypeMismatch(Int, Bool)),
  )
}

///|
test "function parameters arguments returns and entry scopes are checked separately" {
  let function : Function = {
    parameters: [{ id: 0, ty: Int, }, { id: 1, ty: Bool, }],
    returns: Int,
    body: If(Ref(1), Add(Ref(0), IntLiteral(1)), Ref(0)),
  }
  let template : Template = {
    functions: [function],
    result: Call(0, [IntLiteral(4), BoolLiteral(true)]),
  }
  @debug.assert_eq(template.finish().result_type(), Ty::Int)
  @debug.assert_eq(
    structure_error({ ..template, result: Call(0, [IntLiteral(4)]), }),
    Some(ArgumentCount(0, 2, 1)),
  )
  @debug.assert_eq(
    structure_error({
      ..template,
      result: Call(0, [IntLiteral(4), IntLiteral(5)]),
    }),
    Some(TypeMismatch(Bool, Int)),
  )
  @debug.assert_eq(
    structure_error({ ..template, result: Ref(0), }),
    Some(UnknownBinding(0)),
  )
  @debug.assert_eq(
    structure_error({ ..template, functions: [{ ..function, returns: Bool, }], }),
    Some(TypeMismatch(Bool, Int)),
  )
  @debug.assert_eq(
    structure_error({
      ..template,
      functions: [
        { ..function, parameters: [{ id: 0, ty: Int, }, { id: 0, ty: Bool, }], },
      ],
    }),
    Some(DuplicateBinding(0)),
  )
  @debug.assert_eq(
    structure_error({
      functions: [{ parameters: [], returns: Int, body: Ref(0), }],
      result: Let({ id: 0, ty: Int, }, IntLiteral(4), Call(0, [])),
    }),
    Some(UnknownBinding(0)),
  )
  for id in [-1, 1] {
    @debug.assert_eq(
      structure_error({ ..template, result: Call(id, []), }),
      Some(UnknownFunction(id)),
    )
  }
}

///|
test "all call dependencies must be acyclic including uncalled functions and dead branches" {
  for
    functions in [
      [Function::{ parameters: [], returns: Int, body: Call(0, []), }],
      [
        Function::{ parameters: [], returns: Int, body: Call(1, []), },
        { parameters: [], returns: Int, body: Call(0, []), },
      ],
      [
        Function::{
          parameters: [],
          returns: Int,
          body: If(BoolLiteral(false), Call(0, []), IntLiteral(1)),
        },
      ],
    ] {
    @debug.assert_eq(
      structure_error({ functions, result: IntLiteral(0), }),
      Some(CyclicCall(0)),
    )
  }
  let forward : Template = {
    functions: [
      { parameters: [], returns: Int, body: Call(1, []), },
      { parameters: [], returns: Int, body: IntLiteral(42), },
    ],
    result: Call(0, []),
  }
  @debug.assert_eq(forward.finish().result_type(), Ty::Int)
}

///|
test "structural checking never evaluates arithmetic or selects a branch" {
  let expression = Expr::Add(IntLiteral(2147483647), IntLiteral(1))
  let template : Template = { functions: [], result: expression, }
  @debug.assert_eq(template.finish().result_type(), Ty::Int)
  @debug.assert_eq(
    structure_error({
      functions: [],
      result: If(BoolLiteral(true), IntLiteral(0), Ref(9)),
    }),
    Some(UnknownBinding(9)),
  )
}

///|
test "completed programs own nested argument and parameter arrays" {
  let arguments = [Expr::IntLiteral(5)]
  let parameters = [Binder::{ id: 0, ty: Int, }]
  let functions = [Function::{ parameters, returns: Int, body: Ref(0), }]
  let template : Template = { functions, result: Call(0, arguments), }
  let program = template.finish()
  let source = program.emit()
  arguments[0] = Hole(Int)
  parameters[0] = { id: 1, ty: Bool, }
  functions[0] = { parameters: [], returns: Int, body: Hole(Int), }
  @debug.assert_eq(program.emit(), source)
  @debug.assert_eq(program.result_type(), Ty::Int)
  @debug.assert_eq(program.size(), 5)
}

///|
test "size includes definitions and parameters while depth measures expression nesting" {
  let template : Template = {
    functions: [
      { parameters: [{ id: 0, ty: Bool, }], returns: Bool, body: Not(Ref(0)), },
    ],
    result: Call(0, [BoolLiteral(true)]),
  }
  @debug.assert_eq(template.size(), 6)
  @debug.assert_eq(template.depth(), 1)
  @debug.assert_eq(template.finish().size(), 6)
  @debug.assert_eq(template.finish().depth(), 1)
  let binding_tree : Template = {
    functions: [],
    result: Let({ id: 0, ty: Int, }, IntLiteral(1), Add(Ref(0), IntLiteral(2))),
  }
  @debug.assert_eq(binding_tree.size(), 5)
  @debug.assert_eq(binding_tree.depth(), 2)
}
