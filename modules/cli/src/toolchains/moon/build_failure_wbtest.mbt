///|
fn constructor_observations(
  diagnostic? : String = "generated.c:10:2: error: use of undeclared identifier '_M0L6constrS84'\n",
  expected? : String = "0\n",
) -> Array[@contracts.Observation] {
  let observations : Array[@contracts.Observation] = []
  for configuration in configurations() {
    for phase in [@contracts.Build, @contracts.Execute] {
      if configuration == "native-release" && phase == Execute {
        continue
      }
      let target = configuration == "native-release"
      observations.push({
        configuration,
        phase,
        command: command("fixture", [], ".", 1000),
        output: {
          status: if target {
            Exited(255)
          } else {
            Exited(0)
          },
          stdout: if !target && phase == Execute {
            expected
          } else {
            ""
          },
          stderr: if target {
            diagnostic
          } else {
            ""
          },
        },
        injected_stdout: None,
      })
    }
  }
  observations
}

///|
fn constructor_result(
  observations : Array[@contracts.Observation],
  expected? : String? = Some("0\n"),
) -> @contracts.CheckOutcome {
  native_constructor_assessment(observations, expected).results()[0].outcome
}

///|
test "constructor oracle requires the diagnostic family and each candidate's controls" {
  @debug.assert_eq(
    constructor_result(constructor_observations()),
    @contracts.Violated(Exit(255)),
  )
  @debug.assert_eq(
    constructor_result(
      constructor_observations(expected="1\n"),
      expected=Some("1\n"),
    ),
    @contracts.Violated(Exit(255)),
  )
  @debug.assert_eq(
    constructor_result(constructor_observations(expected="1\n")),
    @contracts.NotApplicable,
  )
  for identifier in ["_M12L34constrS567", "_M0L0constrS0"] {
    @debug.assert_eq(
      constructor_result(
        constructor_observations(
          diagnostic="c:1: error: use of undeclared identifier '\{identifier}'\n",
        ),
      ),
      @contracts.Violated(Exit(255)),
    )
  }
  for
    diagnostic in [
      "c:1: error: '_M0L6constrS84' undeclared (first use in this function)\n", "c:1: error: ‘_M0L6constrS84’ undeclared (first use in this function)\n",
    ] {
    @debug.assert_eq(
      constructor_result(constructor_observations(diagnostic~)),
      @contracts.Violated(Exit(255)),
    )
  }
  for
    diagnostic in [
      "error: duplicate label 'join_84'\n", "error: use of undeclared identifier '_M0L6constrS84'\nerror: type mismatch\n",
      "error: use of undeclared identifier '_ML6constrS84'\n", "error: use of undeclared identifier '_M0LconstrS84'\n",
      "error: use of undeclared identifier '_M0L6constrS'\n", "error: use of undeclared identifier '_M0L6constrS84_extra'\n",
      "error: 'other' undeclared (first use in this function)\n", "error: '_M0L6constrS84_extra' undeclared (first use in this function)\n",
      "error: '_M0L6constrS84’ undeclared (first use in this function)\n", "error: '_M0L6constrS84' undeclared (first use in this function)\nerror: conflicting types\n",
    ] {
    @debug.assert_eq(
      constructor_result(constructor_observations(diagnostic~)),
      @contracts.Satisfied,
    )
  }
  @debug.assert_eq(
    constructor_result(constructor_observations(diagnostic="")),
    @contracts.Insufficient(MissingObservation),
  )
  @debug.assert_eq(
    constructor_result(constructor_observations(), expected=None),
    @contracts.Insufficient(MissingObservation),
  )
}

///|
test "constructor oracle rejects missing duplicate truncated and injected evidence" {
  let observations = constructor_observations()
  for index in 0..<observations.length() {
    let incomplete : Array[@contracts.Observation] = []
    for i, observation in observations {
      if i != index {
        incomplete.push(observation)
      }
    }
    @debug.assert_eq(
      constructor_result(incomplete),
      @contracts.Insufficient(MissingObservation),
    )
    let duplicate = observations + [observations[index]]
    @debug.assert_eq(
      constructor_result(duplicate),
      @contracts.Insufficient(MissingObservation),
    )
    for
      (status, expected) in [
        (@contracts.TimedOut, @contracts.Insufficient(Timeout)),
        (OutputLimit, Insufficient(OutputExceeded)),
        (HostError("fixture"), Insufficient(Infrastructure)),
      ] {
      let interrupted = observations.copy()
      interrupted[index] = {
        ..interrupted[index],
        output: { ..interrupted[index].output, status, },
      }
      @debug.assert_eq(constructor_result(interrupted), expected)
    }
  }
  for index in 0..<observations.length() {
    let injected = observations.copy()
    injected[index] = { ..injected[index], injected_stdout: Some("0\n"), }
    @debug.assert_eq(constructor_result(injected), @contracts.NotApplicable)
  }
  let recovered = observations.map(o => {
    if o.configuration == "native-release" {
      { ..o, output: { status: Exited(0), stdout: "", stderr: "", }, }
    } else {
      o
    }
  })
  @debug.assert_eq(constructor_result(recovered), @contracts.Satisfied)
}
