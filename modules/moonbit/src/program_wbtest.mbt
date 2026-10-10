///|
test "reference evaluation respects bindings, arithmetic, and conditional branches" {
  let program : Program = {
    bindings: [Literal(3), Add(Variable(0), Literal(4))],
    result: Choose(
      Not(Less(Variable(1), Literal(5))),
      Subtract(Variable(1), Variable(0)),
      Literal(99),
    ),
  }
  @debug.assert_eq(program.evaluate(), Some(4))
  @debug.assert_eq(
    program.emit(),
    "fn main {\n  let v0 : Int = 3\n  let v1 : Int = (v0 + 4)\n  println((if (!(v1 < 5)) { (v1 - v0) } else { 99 }))\n}\n",
  )
}

///|
test "validator rejects dangling, forward, negative references and overflowing dead code" {
  for
    program in [
      Program::{ bindings: [], result: Variable(0), },
      Program::{ bindings: [Variable(0)], result: Literal(0), },
      Program::{ bindings: [Literal(1)], result: Variable(-1), },
      Program::{
        bindings: [],
        result: Choose(
          Boolean(true),
          Literal(0),
          Add(Literal(2147483647), Literal(1)),
        ),
      },
    ] {
    assert_false(program.valid())
  }
}

///|
test "fixed seeds and depths produce reproducible, valid programs and smaller valid candidates" {
  for seed = 0; seed < 128; seed = seed + 1 {
    let p = generate(seed, depth=seed % 5).unwrap()
    @debug.assert_eq(p, generate(seed, depth=seed % 5).unwrap())
    assert_true(p.valid())
    assert_true(p.size() < 1024)
    for candidate in p.candidates() {
      assert_true(candidate.valid())
      assert_true(candidate.size() < p.size())
    }
  }
  assert_false(generate(1) == generate(2))
  @debug.assert_eq(generate(7, depth=-1), None)
  @debug.assert_eq(generate(7, depth=5), None)
}

///|
test "removing a binding repairs all subsequent references" {
  let program : Program = {
    bindings: [Literal(5), Add(Variable(0), Literal(2)), Variable(1)],
    result: Variable(2),
  }
  let removed = program.candidates()[0]
  @debug.assert_eq(removed.evaluate(), Some(2))
  @debug.assert_eq(removed.bindings.length(), 2)
}
