///|
fn evidence(
  configuration : String,
  value : String,
) -> Array[@contracts.Observation] {
  [
    { ..observation(Build, Exited(0), ""), configuration, },
    { ..observation(Execute, Exited(0), value), configuration, },
  ]
}

///|
test "differential comparison requires two distinct complete configurations" {
  let a = evidence("a", "42\n")
  let b = evidence("b", "42\n")
  @debug.assert_eq(
    compare(["a", "b"], a + b, normalize=value => Some(value)),
    @contracts.Consistent,
  )
  for configurations in [[], ["a"], ["a", "a"], ["a", "b", "missing"]] {
    @debug.assert_eq(
      compare(configurations, a + b, normalize=value => Some(value)),
      @contracts.Incomplete,
    )
  }
  @debug.assert_eq(
    compare(["a", "b"], a + b + [b[1]], normalize=value => Some(value)),
    @contracts.Incomplete,
  )
}

///|
test "missing and failed configurations cannot hide valid differences in any position" {
  let values = evidence("a", "41\n") + evidence("b", "42\n")
  for
    configurations in [
      ["missing", "a", "b"],
      ["a", "missing", "b"],
      ["a", "b", "missing"],
    ] {
    @debug.assert_eq(
      compare(configurations, values, normalize=value => Some(value)),
      @contracts.Difference("a", "b"),
    )
    for
      status in [
        @contracts.Exited(9),
        @contracts.TimedOut,
        @contracts.OutputLimit,
        @contracts.HostError("compiler unavailable"),
      ] {
      let failure = {
        ..observation(Build, status, "42\n"),
        configuration: "missing",
      }
      @debug.assert_eq(
        compare(configurations, [failure] + values, normalize=value => {
          Some(value)
        }),
        @contracts.Difference("a", "b"),
      )
    }
  }
}

///|
test "failed executions and failed builds never contribute result values" {
  for
    status in [
      @contracts.Exited(9),
      @contracts.TimedOut,
      @contracts.OutputLimit,
      @contracts.HostError("missing runtime"),
    ] {
    for phase in [@contracts.Build, @contracts.Execute] {
      let b = evidence("b", "different\n")
      let index = if phase == Build { 0 } else { 1 }
      b[index] = {
        ..b[index],
        output: { status, stdout: "different\n", stderr: "diagnostic", },
      }
      @debug.assert_eq(
        compare(["a", "b"], evidence("a", "42\n") + b, normalize=value => {
          Some(value)
        }),
        @contracts.Incomplete,
      )
    }
  }
}

///|
test "the observation protocol can reject or normalize results without changing raw evidence" {
  let values = evidence("a", "value=42\n") + evidence("b", "42\n")
  let normalize = text => {
    if text == "value=42\n" || text == "42\n" {
      Some("42")
    } else {
      None
    }
  }
  @debug.assert_eq(
    compare(["a", "b"], values, normalize~),
    @contracts.Consistent,
  )
  @debug.assert_eq(values[1].output.stdout, "value=42\n")
  @debug.assert_eq(
    compare(
      ["a", "b"],
      evidence("a", "invalid") + evidence("b", "42\n"),
      normalize~,
    ),
    @contracts.Incomplete,
  )
  @debug.assert_eq(
    compare(
      ["a", "b"],
      evidence("a", "invalid") + evidence("b", "invalid"),
      normalize~,
    ),
    @contracts.Incomplete,
  )
}

///|
test "test injection remains separate from original stdout" {
  let values = evidence("a", "42\n") + evidence("b", "42\n")
  values[3] = { ..values[3], injected_stdout: Some("43\n"), }
  @debug.assert_eq(
    compare(["a", "b"], values, normalize=value => Some(value)),
    @contracts.Difference("a", "b"),
  )
  @debug.assert_eq(values[3].output.stdout, "42\n")
}

///|
test "comparable results retain later configurations and exclude invalid evidence" {
  let observations = evidence("a", "41\n") +
    evidence("b", "42\n") +
    evidence("c", "43\n") +
    evidence("invalid", "diagnostic")
  let values = comparable_results(
    ["a", "b", "c", "invalid", "missing"],
    observations,
    normalize=text => if text == "diagnostic" { None } else { Some(text) },
  )
  @debug.assert_eq(values, [("a", "41\n"), ("b", "42\n"), ("c", "43\n")])
  @debug.assert_eq(
    comparable_results(["a", "a"], observations, normalize=text => Some(text)),
    [],
  )
}
