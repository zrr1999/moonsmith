///|
fn literal_program(value : Int32) -> CompleteProgram raise StructureError {
  Template::{ enums: [], functions: [], result: IntLiteral(value), }.finish()
}

///|
test "integer cost and same-node simplification cover signed boundaries without overflow" {
  for
    (value, magnitude) in [
      (0, 0L),
      (1, 1L),
      (-1, 1L),
      (2147483647, 2147483647L),
      (-2147483648, 2147483648L),
    ] {
    let program = literal_program(value)
    let source = program.emit()
    @debug.assert_eq(program.cost().nodes, 1)
    @debug.assert_eq(program.cost().integer_magnitude, magnitude)
    let candidates = program.integer_candidates()
    if value == 0 {
      @debug.assert_eq(candidates.length(), 0)
      @debug.assert_eq(program.cost().source_bytes, 25)
    } else {
      @debug.assert_eq(candidates.length(), 1)
      @debug.assert_eq(candidates[0], literal_program(0))
      @debug.assert_eq(candidates[0].size(), program.size())
      assert_true(candidates[0].is_smaller_than(program))
      assert_false(program.is_smaller_than(candidates[0]))
    }
    @debug.assert_eq(program.emit(), source)
  }
}

///|
test "cost prioritizes structure then integer magnitude then source bytes" {
  let zero_sum = Template::{
    enums: [],
    functions: [],
    result: Add(IntLiteral(0), IntLiteral(0)),
  }.finish()
  assert_true(literal_program(2147483647).is_smaller_than(zero_sum))
  assert_true(literal_program(-1).is_smaller_than(literal_program(10)))
  assert_true(literal_program(1).is_smaller_than(literal_program(-1)))
  assert_false(literal_program(1).is_smaller_than(literal_program(1)))
}

///|
test "integer operations visit nested results and function bodies in stable order" {
  let program = Template::{
    enums: [],
    functions: [
      {
        parameters: [{ id: 0, ty: Int, }],
        returns: Int,
        body: Add(IntLiteral(-2147483648), Ref(0)),
      },
    ],
    result: Let({ id: 1, ty: Int, }, IntLiteral(1), Call(0, [Ref(1)])),
  }.finish()
  let source = program.emit()
  let candidates = program.integer_candidates()
  @debug.assert_eq(candidates.length(), 2)
  @debug.assert_eq(program.cost().integer_magnitude, 2147483649L)
  @debug.assert_eq(
    candidates[0].syntax.result,
    Let({ id: 1, ty: Int, }, IntLiteral(0), Call(0, [Ref(1)])),
  )
  @debug.assert_eq(candidates[0].cost().integer_magnitude, 2147483648L)
  @debug.assert_eq(
    candidates[1].syntax.functions[0].body,
    Add(IntLiteral(0), Ref(0)),
  )
  @debug.assert_eq(candidates[1].cost().integer_magnitude, 1L)
  @debug.assert_eq(
    candidates.map(p => p.emit()),
    program.integer_candidates().map(p => p.emit()),
  )
  for candidate in candidates {
    @debug.assert_eq(candidate.size(), program.size())
    @debug.assert_eq(candidate.syntax.finish().result_type(), Int)
    assert_true(candidate.is_smaller_than(program))
  }
  @debug.assert_eq(program.emit(), source)
}
