///|
test "unused parameters disappear from declarations and every call without deleting the function" {
  let program = Template::{
    enums: [],
    functions: [
      {
        parameters: [{ id: 0, ty: Bool, }, { id: 1, ty: Int, }],
        returns: Int,
        body: Ref(1),
      },
      {
        parameters: [],
        returns: Int,
        body: Call(0, [BoolLiteral(false), IntLiteral(40)]),
      },
    ],
    result: Add(Call(1, []), Call(0, [BoolLiteral(true), IntLiteral(2)])),
  }.finish()
  let expected = Template::{
    enums: [],
    functions: [
      { parameters: [{ id: 1, ty: Int, }], returns: Int, body: Ref(1), },
      { parameters: [], returns: Int, body: Call(0, [IntLiteral(40)]), },
    ],
    result: Add(Call(1, []), Call(0, [IntLiteral(2)])),
  }.finish()
  let candidates = program.structural_candidates()
  assert_true(candidates.any(p => p.emit() == expected.emit()))
  assert_false(
    candidates.any(p => {
      p.syntax.functions.length() == 2 &&
      p.syntax.functions[0].parameters.is_empty()
    }),
  )
}

///|
test "enum tag and payload removal updates constructors and exhaustive patterns" {
  let program = Template::{
    enums: [{ variants: [[], [Int, Bool], []], }],
    functions: [],
    result: Match(0, Variant(0, 1, [IntLiteral(42), BoolLiteral(true)]), [
      { parameters: [], body: IntLiteral(0), },
      { parameters: [{ id: 0, ty: Int, }, { id: 1, ty: Bool, }], body: Ref(0), },
      { parameters: [], body: IntLiteral(1), },
    ]),
  }.finish()
  let without_tag = Template::{
    enums: [{ variants: [[Int, Bool], []], }],
    functions: [],
    result: Match(0, Variant(0, 0, [IntLiteral(42), BoolLiteral(true)]), [
      { parameters: [{ id: 0, ty: Int, }, { id: 1, ty: Bool, }], body: Ref(0), },
      { parameters: [], body: IntLiteral(1), },
    ]),
  }.finish()
  let without_field = Template::{
    enums: [{ variants: [[], [Int], []], }],
    functions: [],
    result: Match(0, Variant(0, 1, [IntLiteral(42)]), [
      { parameters: [], body: IntLiteral(0), },
      { parameters: [{ id: 0, ty: Int, }], body: Ref(0), },
      { parameters: [], body: IntLiteral(1), },
    ]),
  }.finish()
  let candidates = program.structural_candidates()
  for expected in [without_tag, without_field] {
    assert_true(candidates.any(p => p.emit() == expected.emit()))
  }
  assert_false(
    candidates.any(p => {
      p.syntax.enums.length() == 1 &&
      p.syntax.enums[0].variants == [[], [Bool], []]
    }),
  )
}

///|
test "known constructors and boolean branches simplify while retaining bound payload values" {
  let program = Template::{
    enums: [{ variants: [[Int]], }],
    functions: [],
    result: Let(
      { id: 0, ty: Int, },
      IntLiteral(42),
      Match(0, Variant(0, 0, [Add(Ref(0), IntLiteral(1))]), [
        { parameters: [{ id: 1, ty: Int, }], body: Ref(1), },
      ]),
    ),
  }.finish()
  let expected = Template::{
    enums: [{ variants: [[Int]], }],
    functions: [],
    result: Let(
      { id: 0, ty: Int, },
      IntLiteral(42),
      Let({ id: 1, ty: Int, }, Add(Ref(0), IntLiteral(1)), Ref(1)),
    ),
  }.finish()
  assert_true(
    program.structural_candidates().any(p => p.emit() == expected.emit()),
  )
  for
    (expression, expected) in [
      (Expr::Not(BoolLiteral(false)), Expr::BoolLiteral(true)),
      (
        If(BoolLiteral(false), BoolLiteral(false), BoolLiteral(true)),
        Not(BoolLiteral(false)),
      ),
    ] {
    let original = Template::{ enums: [], functions: [], result: expression, }.finish()
    assert_true(
      original.structural_candidates().any(p => p.syntax.result == expected),
    )
  }
}
