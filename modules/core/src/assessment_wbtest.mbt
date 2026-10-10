///|
test "reference assessment preserves all findings and incomplete configurations" {
  let build = observation(Build, Exited(0), "")
  let wrong = observation(Execute, Exited(0), "41\n")
  let other = { ..observation(Build, Exited(9), ""), configuration: "other", }
  let report = reference_assessment("42\n", ["test", "other", "missing"], [
    build, wrong, other,
  ])
  @debug.assert_eq(report.results().length(), 6)
  @debug.assert_eq(findings(report).length(), 2)
  assert_false(report.is_complete())
  @debug.assert_eq(
    match_failure(findings(report)[1], report),
    @contracts.Preserved,
  )
  let reordered = reference_assessment("42\n", ["missing", "other", "test"], [
    other, wrong, build,
  ])
  @debug.assert_eq(findings(reordered).length(), 2)
  @debug.assert_eq(
    match_failure(findings(report)[0], reordered),
    @contracts.Preserved,
  )
  assert_false(reordered.is_complete())
}

///|
test "reference phase results distinguish a lost failure from unavailable evidence" {
  let build_predicate : @contracts.FailurePredicate = {
    oracle: "reference",
    fingerprint: { configuration: "test", phase: Build, kind: Exit(9), },
  }
  let run_predicate : @contracts.FailurePredicate = {
    oracle: "reference",
    fingerprint: { configuration: "test", phase: Execute, kind: Mismatch, },
  }
  let build = observation(Build, Exited(0), "")
  let run = observation(Execute, Exited(0), "42\n")
  let success = reference_assessment("42\n", ["test"], [build, run])
  @debug.assert_eq(
    match_failure(build_predicate, success),
    @contracts.NotPreserved,
  )
  @debug.assert_eq(
    match_failure(run_predicate, success),
    @contracts.NotPreserved,
  )
  let wrong = reference_assessment("42\n", ["test"], [
    build,
    observation(Execute, Exited(0), "41\n"),
  ])
  @debug.assert_eq(
    match_failure(build_predicate, wrong),
    @contracts.NotPreserved,
  )
  @debug.assert_eq(match_failure(run_predicate, wrong), @contracts.Preserved)
  let failed_build = reference_assessment("42\n", ["test"], [
    observation(Build, Exited(9), ""),
  ])
  @debug.assert_eq(
    match_failure(build_predicate, failed_build),
    @contracts.Preserved,
  )
  @debug.assert_eq(
    match_failure(run_predicate, failed_build),
    @contracts.Inapplicable,
  )
  let missing_run = reference_assessment("42\n", ["test"], [build])
  @debug.assert_eq(
    match_failure(build_predicate, missing_run),
    @contracts.NotPreserved,
  )
  @debug.assert_eq(
    match_failure(run_predicate, missing_run),
    @contracts.Undetermined,
  )
  let timeout = reference_assessment("42\n", ["test"], [
    observation(Build, TimedOut, ""),
  ])
  @debug.assert_eq(
    match_failure(build_predicate, timeout),
    @contracts.Undetermined,
  )
}

///|
test "failure predicates cannot cross oracle identity or use ambiguous results" {
  let row : @contracts.OracleResult = {
    oracle: "reference",
    configuration: "toy",
    phase: Execute,
    outcome: Violated(Mismatch),
  }
  let predicate = toy_predicate()
  @debug.assert_eq(
    match_failure(predicate, @contracts.Assessment::new([row])),
    @contracts.Preserved,
  )
  @debug.assert_eq(
    match_failure(
      predicate,
      @contracts.Assessment::new([{ ..row, oracle: "other", }]),
    ),
    @contracts.Undetermined,
  )
  let duplicate = @contracts.Assessment::new([
    row,
    { ..row, outcome: Satisfied, },
  ])
  @debug.assert_eq(match_failure(predicate, duplicate), @contracts.Undetermined)
  assert_false(duplicate.is_complete())
  let repeated_success = @contracts.Assessment::new([
    { ..row, outcome: Satisfied, },
    { ..row, outcome: Satisfied, },
  ])
  assert_true(summarize(repeated_success) is Inconclusive(_))
  @debug.assert_eq(
    match_failure(
      predicate,
      @contracts.Assessment::new([{ ..row, phase: Build, }]),
    ),
    @contracts.Undetermined,
  )
}

///|
test "duplicate requested configurations and absent evidence are incomplete" {
  let build = observation(Build, Exited(0), "")
  let run = observation(Execute, Exited(0), "42\n")
  let duplicate = reference_assessment("42\n", ["test", "test"], [build, run])
  assert_false(duplicate.is_complete())
  assert_true(summarize(duplicate) is Inconclusive(_))
  assert_false(reference_assessment("42\n", [], []).is_complete())
  let not_applicable = @contracts.Assessment::new([
    {
      oracle: "relation",
      configuration: "toy",
      phase: Execute,
      outcome: NotApplicable,
    },
  ])
  assert_true(not_applicable.is_complete())
  assert_true(summarize(not_applicable) is Inconclusive(_))
}
