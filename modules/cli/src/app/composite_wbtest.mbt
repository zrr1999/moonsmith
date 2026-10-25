///|
fn composite_fixture(active : Bool) -> @moonbit.Template {
  let tuple : @moonbit.Ty = Tuple([Int, Bool, Int])
  {
    enums: [{ variants: [[tuple], []], }],
    functions: [
      {
        parameters: [{ id: 0, ty: tuple, }],
        returns: Enum(0),
        body: If(Project(Ref(0), 1), Variant(0, 0, [Ref(0)]), Variant(0, 1, [])),
      },
      {
        parameters: [{ id: 0, ty: Enum(0), }],
        returns: tuple,
        body: Match(0, Ref(0), [
          { parameters: [{ id: 1, ty: tuple, }], body: Ref(1), },
          {
            parameters: [],
            body: Tuple([IntLiteral(-1), BoolLiteral(false), IntLiteral(1)]),
          },
        ]),
      },
    ],
    result: Let(
      { id: 0, ty: Enum(0), },
      Call(0, [Tuple([IntLiteral(40), BoolLiteral(active), IntLiteral(2)])]),
      Let(
        { id: 1, ty: tuple, },
        Call(1, [Ref(0)]),
        Add(Project(Ref(1), 0), Project(Ref(1), 2)),
      ),
    ),
  }
}

///|
async test "composite values and equivalent variants execute across five real configurations" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/composite-values-")
  defer @host.remove_tree(base)
  let forward : @moonbit.Template = {
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
  }
  let conditional : @moonbit.Template = {
    enums: [],
    functions: [
      {
        parameters: [{ id: 0, ty: Tuple([Int, Bool]), }],
        returns: Tuple([Int, Bool]),
        body: If(BoolLiteral(true), Ref(0), Ref(0)),
      },
    ],
    result: Project(Call(0, [Tuple([IntLiteral(42), BoolLiteral(true)])]), 0),
  }
  for
    (template, expected) in [
      (composite_fixture(true), "42\n"),
      (composite_fixture(false), "0\n"),
      (forward, "42\n"),
      (conditional, "42\n"),
    ] {
    let program = template.finish()
    for variant in [program] + program.equivalent_variants() {
      let case = {
        ..saved_fixture(variant.emit()),
        configurations: @moon.available_configurations(),
      }
      let directory = @artifacts.create_differential(base, case)
      let run = replay_differential(directory)
      assert_true(run.save_error is None)
      @debug.assert_eq(
        @engine.judge(expected, case.configurations, run.attempt.observations),
        @contracts.Match,
        msg=@debug.to_string(run.attempt),
      )
      @debug.assert_eq(run.attempt.comparison, @contracts.Consistent)
    }
  }
}

///|
async test "composite reductions keep fresh failure evidence confirm independently and replay" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/composite-reduction-")
  defer @host.remove_tree(base)
  let program = composite_fixture(true).finish()
  let case = {
    ..saved_fixture(program.emit(), injected=true),
    configurations: @moon.available_configurations(),
  }
  let directory = @artifacts.create_differential(base, case)
  let original = execute_differential(directory, case, "original")
  let before = @host.read_text("\{original.attempt_directory}/attempt.json")
  let run = reduce_differential(original, program, 8)
  assert_true(run.save_error is None)
  guard run.reduction is Some(reduction) &&
    reduction.confirmation_attempt is Some(material) else {
    fail("missing composite confirmation")
  }
  assert_true(reduction.error is None)
  assert_true(reduction.best_cost.nodes < reduction.original_cost.nodes)
  @debug.assert_eq(reduction.best_cost.nodes, 1)
  @debug.assert_eq(reduction.confirmation, Some(@contracts.Preserved))
  let replay = replay_differential(material)
  @debug.assert_eq(
    replay.attempt.comparison,
    @contracts.Difference("native-debug", "native-release"),
  )
  @debug.assert_eq(
    @host.read_text("\{original.attempt_directory}/attempt.json"),
    before,
  )
  @debug.assert_eq(@host.read_text("\{directory}/original.mbt"), program.emit())
}
