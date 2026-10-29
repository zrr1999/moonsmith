///|
fn composite_program(tag : Int32) -> CompleteProgram raise {
  Template::{
    enums: [{ variants: [[Int, Tuple([Bool, Int])], []], }],
    functions: [
      {
        parameters: [{ id: 0, ty: Tuple([Int, Bool]), }],
        returns: Enum(0),
        body: If(
          Project(Ref(0), 1),
          Variant(0, 0, [
            Project(Ref(0), 0),
            Tuple([BoolLiteral(true), IntLiteral(2)]),
          ]),
          Variant(0, 1, []),
        ),
      },
      {
        parameters: [{ id: 0, ty: Enum(0), }],
        returns: Tuple([Int, Bool]),
        body: Match(0, Ref(0), [
          {
            parameters: [
              { id: 1, ty: Int, },
              { id: 2, ty: Tuple([Bool, Int]), },
            ],
            body: Tuple([Add(Ref(1), Project(Ref(2), 1)), Project(Ref(2), 0)]),
          },
          { parameters: [], body: Tuple([IntLiteral(0), BoolLiteral(false)]), },
        ]),
      },
    ],
    result: Project(
      Call(1, [Call(0, [Tuple([IntLiteral(40), BoolLiteral(tag == 0)])])]),
      0,
    ),
  }.finish()
}

///|
test "tuples and nominal enums flow through bindings calls returns and exhaustive matches" {
  @debug.assert_eq(composite_program(0).result_type(), Ty::Int)
  @debug.assert_eq(composite_program(1).result_type(), Ty::Int)
  @debug.assert_eq(Ty::Tuple([Int, Bool]).result_protocol(), None)
  @debug.assert_eq(Ty::Enum(0).result_protocol(), None)
  @debug.assert_eq(Ty::Tuple([Int, Bool]).normalize_output("(1, true)\n"), None)
  let tuple : Template = {
    enums: [],
    functions: [],
    result: Tuple([IntLiteral(1), BoolLiteral(true)]),
  }
  @debug.assert_eq(tuple.check(), Ty::Tuple([Int, Bool]))
  @debug.assert_eq(
    structure_error(tuple),
    Some(UnsupportedResultType(Tuple([Int, Bool]))),
  )
}

///|
test "enum declarations reject direct indirect and tuple-mediated recursion even when unused" {
  for
    definitions in [
      [EnumDefinition::{ variants: [[Enum(0)]], }],
      [{ variants: [[Enum(1)]], }, { variants: [[Enum(0)]], }],
      [{ variants: [[Tuple([Bool, Enum(0)])]], }],
    ] {
    @debug.assert_eq(
      structure_error({
        enums: definitions,
        functions: [],
        result: IntLiteral(0),
      }),
      Some(CyclicEnum(0)),
    )
  }
  @debug.assert_eq(
    structure_error({
      enums: [{ variants: [], }],
      functions: [],
      result: IntLiteral(0),
    }),
    Some(EmptyEnum(0)),
  )
  @debug.assert_eq(
    structure_error({
      enums: [{ variants: [[Enum(1)]], }],
      functions: [],
      result: IntLiteral(0),
    }),
    Some(UnknownEnum(1)),
  )
  let forward = Template::{
    enums: [{ variants: [[Enum(1)]], }, { variants: [[Int]], }],
    functions: [],
    result: Match(0, Variant(0, 0, [Variant(1, 0, [IntLiteral(42)])]), [
      {
        parameters: [{ id: 0, ty: Enum(1), }],
        body: Match(1, Ref(0), [
          { parameters: [{ id: 1, ty: Int, }], body: Ref(1), },
        ]),
      },
    ]),
  }.finish()
  @debug.assert_eq(forward.result_type(), Ty::Int)
}

///|
test "tuple arity projections constructors pattern arguments and all branches are checked" {
  for fields in [[], [Expr::IntLiteral(1)]] {
    @debug.assert_eq(
      structure_error({ enums: [], functions: [], result: Tuple(fields), }),
      Some(InvalidTupleArity(fields.length())),
    )
  }
  for index in [-1, 2] {
    @debug.assert_eq(
      structure_error({
        enums: [],
        functions: [],
        result: Project(Tuple([IntLiteral(1), BoolLiteral(true)]), index),
      }),
      Some(InvalidProjection(index, 2)),
    )
  }
  @debug.assert_eq(
    structure_error({
      enums: [],
      functions: [],
      result: Project(IntLiteral(1), 0),
    }),
    Some(ExpectedTuple(Int)),
  )
  let definitions : Array[EnumDefinition] = [{ variants: [[Int], []], }]
  for
    (expression, expected) in [
      (Expr::Variant(0, 2, []), StructureError::UnknownVariant(0, 2)),
      (Variant(0, 0, []), VariantArguments(0, 0, 1, 0)),
      (Variant(0, 0, [BoolLiteral(true)]), TypeMismatch(Int, Bool)),
      (Match(0, Variant(0, 1, []), []), MatchArms(0, 2, 0)),
      (
        Match(0, Variant(0, 1, []), [
          { parameters: [], body: IntLiteral(0), },
          { parameters: [], body: IntLiteral(0), },
        ]),
        PatternArguments(0, 0, 1, 0),
      ),
      (
        Match(0, Variant(0, 1, []), [
          { parameters: [{ id: 0, ty: Bool, }], body: IntLiteral(0), },
          { parameters: [], body: IntLiteral(0), },
        ]),
        TypeMismatch(Int, Bool),
      ),
      (
        Match(0, Variant(0, 1, []), [
          { parameters: [{ id: 0, ty: Int, }], body: Ref(0), },
          { parameters: [], body: Ref(0), },
        ]),
        UnknownBinding(0),
      ),
      (
        Match(0, Variant(0, 1, []), [
          { parameters: [{ id: 0, ty: Int, }], body: BoolLiteral(false), },
          { parameters: [], body: IntLiteral(0), },
        ]),
        TypeMismatch(Bool, Int),
      ),
    ] {
    @debug.assert_eq(
      structure_error({ enums: definitions, functions: [], result: expression, }),
      Some(expected),
    )
  }
  @debug.assert_eq(
    structure_error({
      enums: definitions + definitions,
      functions: [],
      result: Match(1, Variant(0, 1, []), [
        { parameters: [{ id: 0, ty: Int, }], body: Ref(0), },
        { parameters: [], body: IntLiteral(0), },
      ]),
    }),
    Some(TypeMismatch(Enum(1), Enum(0))),
  )
  @debug.assert_eq(
    structure_error({
      enums: definitions,
      functions: [],
      result: Let(
        { id: 0, ty: Int, },
        IntLiteral(1),
        Match(0, Variant(0, 1, []), [
          { parameters: [{ id: 0, ty: Int, }], body: Ref(0), },
          { parameters: [], body: IntLiteral(0), },
        ]),
      ),
    }),
    Some(DuplicateBinding(0)),
  )
  @debug.assert_eq(
    structure_error({
      enums: definitions,
      functions: [
        {
          parameters: [],
          returns: Int,
          body: Match(0, Variant(0, 1, []), [
            { parameters: [{ id: 0, ty: Int, }], body: Call(0, []), },
            { parameters: [], body: IntLiteral(0), },
          ]),
        },
      ],
      result: IntLiteral(0),
    }),
    Some(CyclicCall(0)),
  )
}

///|
test "completed snapshots own enum fields tuple types pattern parameters and expression arrays" {
  let types = [Ty::Int, Bool]
  let fields = [Ty::Tuple(types)]
  let variants = [fields, []]
  let parameters = [Binder::{ id: 0, ty: Tuple(types), }]
  let arms = [
    MatchArm::{ parameters, body: Project(Ref(0), 0), },
    { parameters: [], body: IntLiteral(0), },
  ]
  let values = [Expr::IntLiteral(42), BoolLiteral(true)]
  let program = Template::{
    enums: [{ variants, }],
    functions: [],
    result: Match(0, Variant(0, 0, [Tuple(values)]), arms),
  }.finish()
  let before = program.emit()
  let cost = program.cost()
  types[0] = Enum(99)
  fields.clear()
  variants.clear()
  parameters.clear()
  arms.clear()
  values.clear()
  @debug.assert_eq(program.emit(), before)
  @debug.assert_eq(program.cost(), cost)
}

///|
test "composite reductions preserve checked types costs determinism and original snapshots" {
  let program = composite_program(0)
  let source = program.emit()
  let candidates = program.candidates()
  assert_false(candidates.is_empty())
  @debug.assert_eq(program.candidates(), candidates)
  for candidate in candidates {
    @debug.assert_eq(candidate.result_type(), program.result_type())
    assert_true(candidate.is_smaller_than(program))
  }
  assert_true(
    program
    .integer_candidates()
    .any(candidate => candidate.size() == program.size()),
  )
  @debug.assert_eq(program.emit(), source)
}
