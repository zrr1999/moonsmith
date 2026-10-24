///|
test "structural reduction preserves result type scope and deterministic order" {
  for seed = 0; seed < 40; seed = seed + 1 {
    let program = synthesize(seed).program
    let source = program.emit()
    let candidates = program.candidates()
    @debug.assert_eq(
      candidates.map(p => p.emit()),
      program.candidates().map(p => p.emit()),
    )
    let seen : Map[String, Unit] = Map([])
    for candidate in candidates {
      @debug.assert_eq(
        candidate.syntax.finish().result_type(),
        program.result_type(),
      )
      assert_true(candidate.is_smaller_than(program))
      assert_false(seen.contains(candidate.emit()))
      seen[candidate.emit()] = ()
    }
    @debug.assert_eq(program.emit(), source)
  }
}

///|
test "removing bindings repairs references while retaining surrounding bindings" {
  let program = Template::{
    enums: [],
    functions: [],
    result: Let(
      { id: 0, ty: Int, },
      IntLiteral(8),
      Let(
        { id: 1, ty: Bool, },
        BoolLiteral(true),
        If(Ref(1), Ref(0), IntLiteral(2)),
      ),
    ),
  }.finish()
  let expected = Template::{
      enums: [],
      functions: [],
      result: Let(
        { id: 0, ty: Int, },
        IntLiteral(8),
        If(BoolLiteral(false), Ref(0), IntLiteral(2)),
      ),
    }
    .finish()
    .emit()
  assert_true(program.candidates().any(p => p.emit() == expected))
}

///|
test "removing a function rewrites forward and backward calls and compacts identities" {
  let program = Template::{
    enums: [],
    functions: [
      { parameters: [], returns: Int, body: Call(2, []), },
      { parameters: [], returns: Int, body: Call(0, []), },
      { parameters: [], returns: Int, body: IntLiteral(42), },
    ],
    result: Add(Call(1, []), Call(2, [])),
  }.finish()
  let expected = Template::{
      enums: [],
      functions: [
        { parameters: [], returns: Int, body: IntLiteral(0), },
        { parameters: [], returns: Int, body: IntLiteral(42), },
      ],
      result: Add(Call(0, []), Call(1, [])),
    }
    .finish()
    .emit()
  assert_true(program.candidates().any(p => p.emit() == expected))
  @debug.assert_eq(
    Template::{ enums: [], functions: [], result: BoolLiteral(true), }
    .finish()
    .candidates()
    .length(),
    0,
  )
}
