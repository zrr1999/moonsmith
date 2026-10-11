///|
fn composed_structure(input : Int) -> @moonbit.Template {
  {
    functions: [
      {
        parameters: [{ id: 0, ty: Int, }, { id: 1, ty: Bool, }],
        returns: Int,
        body: If(
          Ref(1),
          Add(Ref(0), IntLiteral(4)),
          Subtract(Ref(0), IntLiteral(3)),
        ),
      },
      {
        parameters: [{ id: 0, ty: Int, }],
        returns: Int,
        body: Let(
          { id: 1, ty: Int, },
          Call(0, [Ref(0), BoolLiteral(true)]),
          Let(
            { id: 2, ty: Bool, },
            Less(Ref(1), IntLiteral(8)),
            If(Ref(2), Call(0, [Ref(1), Ref(2)]), Ref(1)),
          ),
        ),
      },
    ],
    result: Let({ id: 0, ty: Int, }, IntLiteral(input), Call(1, [Ref(0)])),
  }
}

///|
async test "checked structures execute with known results and direct differential comparison" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/structures-")
  defer @host.remove_tree(base)
  let cases : Array[(@moonbit.Template, String)] = [
    (composed_structure(3), "11\n"),
    (composed_structure(10), "14\n"),
    (
      {
        functions: [
          { parameters: [], returns: Int, body: Call(1, []), },
          { parameters: [], returns: Int, body: IntLiteral(42), },
        ],
        result: Call(0, []),
      },
      "42\n",
    ),
    (
      {
        functions: [
          {
            parameters: [{ id: 0, ty: Bool, }],
            returns: Bool,
            body: Not(Ref(0)),
          },
        ],
        result: Call(0, [BoolLiteral(true)]),
      },
      "false\n",
    ),
  ]
  for (template, expected) in cases {
    let program = template.finish()
    let directory = @host.new_directory("\{base}/case-")
    @moon.prepare(directory, program.emit())
    let observations = @moon.observe(directory)
    @debug.assert_eq(
      observations.length(),
      6,
      msg=@debug.to_string(observations),
    )
    for observation in observations {
      @debug.assert_eq(
        observation.output.status,
        @contracts.Exited(0),
        msg=@debug.to_string(observation),
      )
      if observation.phase == Execute {
        @debug.assert_eq(observation.output.stdout, expected)
      }
    }
    // The hand-derived expectations above check rendering; the oracle gets no reference value.
    @debug.assert_eq(
      @engine.compare(@moon.configurations(), observations, normalize=value => {
        Some(value)
      }),
      @contracts.Consistent,
    )
  }
}

///|
async test "compiler rejection retains diagnostics and is an incomplete differential comparison" {
  @host.mkdir("runs")
  let directory = @host.new_directory("runs/compiler-rejection-")
  defer @host.remove_tree(directory)
  @moon.prepare(
    directory, "fn main { let value : Int = true; println(value) }\n",
  )
  let observations = @moon.observe(directory)
  @debug.assert_eq(observations.length(), @moon.configurations().length())
  for observation in observations {
    @debug.assert_eq(observation.phase, @contracts.Build)
    assert_true(observation.output.status is Exited(code) && code != 0)
    assert_false(observation.output.stderr.is_empty())
    assert_true(observation.injected_stdout is None)
  }
  @debug.assert_eq(
    @engine.compare(@moon.configurations(), observations, normalize=value => {
      Some(value)
    }),
    @contracts.Incomplete,
  )
}
