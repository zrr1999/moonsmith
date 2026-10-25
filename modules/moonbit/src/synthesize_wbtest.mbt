///|
test "templates and completion share size depth and construction budgets" {
  for
    limits in [
      GenerationLimits::{ max_nodes: 1, max_depth: 0, max_attempts: 4, },
      { max_nodes: 7, max_depth: 2, max_attempts: 32, },
      GenerationLimits::default(),
      { max_nodes: 512, max_depth: 10, max_attempts: 1024, },
    ] {
    for seed in -10..<80 {
      let state = Construction::new(seed, limits)
      let template = state.compose_template()
      ignore(template.check())
      @debug.assert_eq(template.size(), state.nodes)
      assert_true(template.size() <= limits.max_nodes)
      assert_true(template.depth() <= limits.max_depth)
      let template_source = @debug.to_string(template)
      let program = state.complete(template)
      @debug.assert_eq(program.size(), state.nodes)
      assert_true(program.size() <= limits.max_nodes)
      assert_true(program.depth() <= limits.max_depth)
      assert_true(state.attempts <= limits.max_attempts)
      @debug.assert_eq(@debug.to_string(template), template_source)
      let again = synthesize(seed, limits~)
      @debug.assert_eq(again.program, program)
      @debug.assert_eq(again.program.emit(), program.emit())
      @debug.assert_eq(again.construction_attempts, state.attempts)
    }
  }
}

///|
test "automatic templates combine bindings branches and calls across seeds" {
  let templates : Map[String, Unit] = Map([])
  let mut combined = false
  let mut has_function_dependency = false
  let mut int_result = false
  let mut bool_result = false
  for seed in 0..<100 {
    let state = Construction::new(seed, GenerationLimits::default())
    let template = state.compose_template()
    templates[@debug.to_string(template)] = ()
    let program = state.complete(template)
    let source = program.emit()
    combined = combined ||
      (
        source.contains("let v") &&
        source.contains("if ") &&
        source.contains("f0(")
      )
    has_function_dependency = has_function_dependency ||
      template.functions.any(f => @debug.to_string(f.body).contains("Call("))
    int_result = int_result || program.result_type() == Ty::Int
    bool_result = bool_result || program.result_type() == Ty::Bool
  }
  assert_true(templates.length() > 50)
  assert_true(combined)
  assert_true(has_function_dependency)
  assert_true(int_result && bool_result)
}

///|
test "completion preserves a template's binding references and function arguments" {
  let template : Template = {
    enums: [],
    functions: [
      {
        parameters: [{ id: 4, ty: Int, }],
        returns: Int,
        body: Add(Ref(4), Hole(Int)),
      },
    ],
    result: Let(
      { id: 9, ty: Int, },
      Hole(Int),
      If(Hole(Bool), Call(0, [Ref(9)]), Ref(9)),
    ),
  }
  let limits = { max_nodes: template.size(), max_depth: 3, max_attempts: 20, }
  let state = Construction::new(42, limits)
  state.nodes = template.size()
  let program = state.complete(template)
  @debug.assert_eq(program.size(), template.size())
  assert_true(program.syntax.functions[0].body is Add(Ref(4), IntLiteral(_)))
  assert_true(
    program.syntax.result
    is Let({ id: 9, .. }, IntLiteral(_), If(_, Call(0, [Ref(9)]), Ref(9))),
  )
}

///|
test "construction exhaustion is bounded and reports the consumed attempts" {
  let error = try {
    ignore(
      synthesize(7, limits={ max_nodes: 1, max_depth: 0, max_attempts: 1, }),
    )
    None
  } catch {
    GenerationError::AttemptsExhausted(n) => Some(n)
    _ => fail("unexpected generation error")
  }
  @debug.assert_eq(error, Some(1))
  let generated = synthesize(7, limits={
    max_nodes: 1,
    max_depth: 0,
    max_attempts: 2,
  })
  @debug.assert_eq(generated.program.size(), 1)
  @debug.assert_eq(generated.construction_attempts, 2)
}

///|
test "invalid generation limits are rejected without constructing a program" {
  let defaults = GenerationLimits::default()
  for
    limits in [
      { ..defaults, max_nodes: 0, },
      { ..defaults, max_nodes: 2049, },
      { ..defaults, max_depth: -1, },
      { ..defaults, max_depth: 17, },
      { ..defaults, max_attempts: 0, },
      { ..defaults, max_attempts: 8193, },
    ] {
    let rejected = try {
      ignore(synthesize(7, limits~))
      false
    } catch {
      GenerationError::InvalidLimits(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}
