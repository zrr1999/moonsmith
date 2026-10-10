///|
fn observation(
  phase : @contracts.Phase,
  status : @contracts.ProcessStatus,
  stdout : String,
) -> @contracts.Observation {
  {
    configuration: "test",
    phase,
    command: {
      program: "test",
      args: [],
      cwd: ".",
      timeout_ms: 100,
      output_limit: 100,
    },
    output: { status, stdout, stderr: "", },
    injected_stdout: None,
  }
}

///|
test "oracle requires complete observations and compares against the reference" {
  let build = observation(Build, Exited(0), "")
  let run = observation(Execute, Exited(0), "42\n")
  @debug.assert_eq(judge("42\n", ["test"], [build, run]), @contracts.Match)
  @debug.assert_eq(
    judge("41\n", ["test"], [build, run]),
    @contracts.Finding({
      configuration: "test",
      phase: Execute,
      kind: Mismatch,
    }),
  )
  @debug.assert_eq(
    judge("42\n", ["test"], [build]),
    @contracts.Inconclusive({
      configuration: "test",
      phase: Execute,
      kind: MissingObservation,
    }),
  )
  @debug.assert_eq(
    judge("42\n", ["test"], [build, run, run]),
    @contracts.Inconclusive({
      configuration: "test",
      phase: Execute,
      kind: MissingObservation,
    }),
  )
  assert_true(judge("", [], []) is Inconclusive(_))
}

///|
test "oracle separates a compiler exit, timeout, output cap, and host failure" {
  let failed = observation(Build, Exited(9), "")
  @debug.assert_eq(
    judge("", ["test"], [failed]),
    @contracts.Finding({ configuration: "test", phase: Build, kind: Exit(9), }),
  )
  for
    status in [
      @contracts.TimedOut,
      @contracts.OutputLimit,
      @contracts.HostError("missing compiler"),
    ] {
    assert_true(
      judge("", ["test"], [observation(Build, status, "")]) is Inconclusive(_),
    )
  }
}

///|
test "reducer is independent of MoonBit and preserves the original fingerprint" {
  let fingerprint : @contracts.Fingerprint = {
    configuration: "toy",
    phase: Execute,
    kind: Mismatch,
  }
  let reducer = Reducer::new(
    10,
    fingerprint,
    limit=8,
    size=n => n,
    valid=n => n >= 0,
    candidates=n => if n == 10 { [12, -1, 8, 7, 6] } else { [] },
  )
  @debug.assert_eq(reducer.next(), Some(8))
  @debug.assert_eq(reducer.next(), Some(8))
  assert_false(reducer.observe(Inconclusive({ ..fingerprint, kind: Timeout, })))
  @debug.assert_eq(reducer.next(), Some(7))
  assert_false(
    reducer.observe(Finding({ ..fingerprint, configuration: "other", })),
  )
  @debug.assert_eq(reducer.next(), Some(6))
  assert_true(reducer.observe(Finding(fingerprint)))
  @debug.assert_eq(reducer.result(), 6)
  @debug.assert_eq(reducer.next(), None)
}

///|
test "invalid candidates consume the reduction budget" {
  let fingerprint : @contracts.Fingerprint = {
    configuration: "toy",
    phase: Execute,
    kind: Mismatch,
  }
  let reducer = Reducer::new(
    10,
    fingerprint,
    limit=2,
    size=n => n,
    valid=_ => false,
    candidates=_ => [9, 8, 7],
  )
  @debug.assert_eq(reducer.next(), None)
  @debug.assert_eq(reducer.attempts(), 2)
  @debug.assert_eq(reducer.result(), 10)
}

///|
test "inconclusive configurations cannot hide a later finding" {
  let build = { ..observation(Build, Exited(0), ""), configuration: "wrong", }
  let run = {
    ..observation(Execute, Exited(0), "41\n"),
    configuration: "wrong",
  }
  let expected : @contracts.Verdict = Finding({
    configuration: "wrong",
    phase: Execute,
    kind: Mismatch,
  })
  for
    status in [
      @contracts.TimedOut,
      @contracts.OutputLimit,
      @contracts.HostError("missing runtime"),
    ] {
    let uncertain = observation(Build, status, "")
    for configurations in [["test", "wrong"], ["wrong", "test"]] {
      @debug.assert_eq(
        judge("42\n", configurations, [uncertain, build, run]),
        expected,
      )
    }
  }
  @debug.assert_eq(judge("42\n", ["missing", "wrong"], [build, run]), expected)
}
