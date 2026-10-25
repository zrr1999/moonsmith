///|
fn Expr::contains(self : Expr, predicate : (Expr) -> Bool) -> Bool {
  if predicate(self) {
    return true
  }
  let mut found = false
  ignore(
    self.map_children(child => {
      found = found || child.contains(predicate)
      child
    }),
  )
  found
}

///|
test "versioned generators are explicit and round trip without aliases" {
  @debug.assert_eq(Generator::default(), CompositeV2)
  for identifier in generator_identifiers() {
    guard parse_generator(identifier) is Some(generator) else {
      fail("missing generator")
    }
    @debug.assert_eq(generator.identifier(), identifier)
  }
  for
    identifier in [
      "", "v1", "future", "template-rules-v3", " template-rules-v2",
    ] {
    @debug.assert_eq(parse_generator(identifier), None)
  }
  for generator in [Generator::ScalarV1, CompositeV2] {
    let first = synthesize(7, generator~)
    let second = synthesize(7, generator~)
    @debug.assert_eq(first.generator, generator)
    @debug.assert_eq(first.program, second.program)
    @debug.assert_eq(first.program.emit(), second.program.emit())
    @debug.assert_eq(first.construction_attempts, second.construction_attempts)
  }
  let old = synthesize(7, generator=ScalarV1).program
  assert_true(old.syntax.enums.is_empty())
  assert_false(
    old.syntax.result.contains(expression => {
      expression is Expr::Tuple(_) || expression is Match(_, _, _)
    }),
  )
}

///|
test "composite rules generate a checked deterministic thousand seed window within shared budgets" {
  let limits = GenerationLimits::default()
  let mut tuples = false
  let mut enums = false
  for seed in 0..<1000 {
    let generated = synthesize(seed, limits~, generator=CompositeV2)
    let program = generated.program
    assert_true(program.size() <= limits.max_nodes)
    assert_true(program.depth() <= limits.max_depth)
    assert_true(generated.construction_attempts <= limits.max_attempts)
    assert_true(program.result_type().result_protocol() is Some(_))
    enums = enums || !program.syntax.enums.is_empty()
    tuples = tuples ||
      program.syntax.result.contains(expression => expression is Expr::Tuple(_)) ||
      program.syntax.functions.any(function => {
        function.body.contains(expression => expression is Expr::Tuple(_))
      })
    if seed % 100 == 0 {
      @debug.assert_eq(
        program,
        synthesize(seed, limits~, generator=CompositeV2).program,
      )
    }
  }
  assert_true(tuples)
  assert_true(enums)
}
