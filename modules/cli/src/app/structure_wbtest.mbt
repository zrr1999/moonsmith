///|
fn assert_planned_observations(
  observations : Array[@contracts.Observation],
  configurations : Array[String],
  phases : Array[@contracts.Phase],
) -> Unit raise {
  @debug.assert_eq(
    observations.length(),
    configurations.length() * phases.length(),
    msg=@debug.to_string(observations),
  )
  for configuration in configurations {
    for phase in phases {
      @debug.assert_eq(
        observations
        .filter(observation => {
          observation.configuration == configuration &&
          observation.phase == phase
        })
        .length(),
        1,
        msg="expected one observation for \{configuration} \{@debug.to_string(phase)}",
      )
    }
  }
}

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
    let observations = @moon.observe(
      directory,
      build_timeout_ms=45000,
      run_timeout_ms=5000,
    )
    assert_planned_observations(observations, @moon.configurations(), [
      Build,
      Execute,
    ])
    for observation in observations {
      @debug.assert_eq(
        observation.output.status,
        @contracts.Exited(0),
        msg=@debug.to_string(observation),
      )
      @debug.assert_eq(
        observation.command.timeout_ms,
        if observation.phase == Build {
          45000
        } else {
          5000
        },
      )
      if observation.phase == Execute {
        @debug.assert_eq(observation.output.stdout, expected)
      }
    }
    // The hand-derived expectations above check rendering; the oracle gets no reference value.
    @debug.assert_eq(
      @engine.compare(@moon.configurations(), observations, normalize=value => {
        program.result_type().normalize_output(value)
      }),
      @contracts.Consistent,
    )
    let injected = observations.map(observation => {
      if observation.configuration == "native-release" &&
        observation.phase == Execute {
        {
          ..observation,
          injected_stdout: Some(
            if program.result_type() == @moonbit.Ty::Int {
              "0\n"
            } else {
              "true\n"
            },
          ),
        }
      } else {
        observation
      }
    })
    @debug.assert_eq(
      @engine.compare(@moon.configurations(), injected, normalize=value => {
        program.result_type().normalize_output(value)
      }),
      @contracts.Difference("native-debug", "native-release"),
    )
    for observation in injected {
      if observation.phase == Execute {
        @debug.assert_eq(observation.output.stdout, expected)
      }
    }
    // Equal malformed outputs cannot become a successful comparison.
    let malformed = observations.map(observation => {
      if observation.phase == Execute {
        { ..observation, injected_stdout: Some("diagnostic\n"), }
      } else {
        observation
      }
    })
    @debug.assert_eq(
      @engine.compare(@moon.configurations(), malformed, normalize=value => {
        program.result_type().normalize_output(value)
      }),
      @contracts.Incomplete,
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
  assert_planned_observations(observations, @moon.configurations(), [Build])
  for observation in observations {
    @debug.assert_eq(observation.phase, @contracts.Build)
    @debug.assert_eq(observation.command.timeout_ms, 30000)
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

///|
async test "execution timeout is recorded and cannot become a differential result" {
  @host.mkdir("runs")
  let directory = @host.new_directory("runs/execution-timeout-")
  defer @host.remove_tree(directory)
  // A deliberately nonterminating fixture tests the runner, outside the generated subset.
  @moon.prepare(directory, "fn main { while true { () } }\n")
  let observations = @moon.observe(directory, run_timeout_ms=200)
  assert_planned_observations(observations, @moon.configurations(), [
    Build,
    Execute,
  ])
  for observation in observations {
    if observation.phase == Build {
      @debug.assert_eq(observation.output.status, @contracts.Exited(0))
      @debug.assert_eq(observation.command.timeout_ms, 30000)
    } else {
      @debug.assert_eq(observation.output.status, @contracts.TimedOut)
      @debug.assert_eq(observation.command.timeout_ms, 200)
      assert_true(observation.injected_stdout is None)
    }
  }
  @debug.assert_eq(
    @engine.compare(@moon.configurations(), observations, normalize=value => {
      Some(value)
    }),
    @contracts.Incomplete,
  )
}

///|
async test "invalid execution budgets are rejected before any compiler command" {
  for invalid in [-1, 0, 600001] {
    for build in [true, false] {
      let error = try {
        ignore(
          @moon.observe(
            "moonsmith-directory-that-does-not-exist",
            build_timeout_ms=if build { invalid } else { 30000 },
            run_timeout_ms=if build { 2000 } else { invalid },
          ),
        )
        None
      } catch {
        error => Some(error.to_string())
      }
      let phase = if build { "build" } else { "run" }
      assert_true(
        error is Some(message) &&
        message.contains(
          "\{phase} timeout must be between 1 and 600000 milliseconds",
        ),
      )
    }
  }
}
