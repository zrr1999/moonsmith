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
fn sample_evidence(verdict : @contracts.Verdict) -> @contracts.Assessment {
  let (fingerprint, outcome) = match verdict {
    Finding(f) => (f, @contracts.Violated(f.kind))
    Inconclusive(f) => (f, @contracts.Insufficient(f.kind))
    Match =>
      (
        {
          configuration: "toy",
          phase: @contracts.Execute,
          kind: @contracts.Mismatch,
        },
        @contracts.Satisfied,
      )
  }
  @contracts.Assessment::new([
    {
      oracle: "reference",
      configuration: fingerprint.configuration,
      phase: fingerprint.phase,
      outcome,
    },
  ])
}

///|
test "reducer is independent of MoonBit and preserves the selected failure" {
  let fingerprint : @contracts.Fingerprint = {
    configuration: "toy",
    phase: Execute,
    kind: Mismatch,
  }
  guard Reducer::new(
      10,
      sample_evidence(Finding(fingerprint)),
      { oracle: "reference", fingerprint, },
      id="enumeration",
      limit=8,
      size=n => n,
      valid=n => n >= 0,
      candidates=n => if n == 10 { [12, -1, 8, 7, 6] } else { [] },
    )
    is Ok(reducer) else {
    fail("invalid initial evidence")
  }
  guard reducer.next() is Some(first) else { fail("missing candidate") }
  @debug.assert_eq(first.program, 8)
  @debug.assert_eq(reducer.next().map(r => r.id), Some(first.id))
  assert_false(
    reducer.observe(
      first.id,
      sample_evidence(Inconclusive({ ..fingerprint, kind: Timeout, })),
    ),
  )
  guard reducer.next() is Some(second) else { fail("missing candidate") }
  @debug.assert_eq(second.program, 7)
  assert_false(
    reducer.observe(
      second.id,
      sample_evidence(Finding({ ..fingerprint, configuration: "other", })),
    ),
  )
  guard reducer.next() is Some(third) else { fail("missing candidate") }
  @debug.assert_eq(third.program, 6)
  assert_true(reducer.observe(third.id, sample_evidence(Finding(fingerprint))))
  @debug.assert_eq(reducer.result(), 6)
  assert_true(reducer.next() is None)
  @debug.assert_eq(reducer.stop_reason(), Some(SearchComplete))
}

///|
test "invalid candidates consume the reduction budget" {
  let fingerprint : @contracts.Fingerprint = {
    configuration: "toy",
    phase: Execute,
    kind: Mismatch,
  }
  guard Reducer::new(
      10,
      sample_evidence(Finding(fingerprint)),
      { oracle: "reference", fingerprint, },
      id="invalid",
      limit=2,
      size=n => n,
      valid=n => n == 10,
      candidates=_ => [9, 8, 7],
    )
    is Ok(reducer) else {
    fail("invalid initial evidence")
  }
  assert_true(reducer.next() is None)
  @debug.assert_eq(reducer.attempts(), 2)
  @debug.assert_eq(reducer.result(), 10)
  @debug.assert_eq(reducer.stop_reason(), Some(BudgetExhausted))
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
