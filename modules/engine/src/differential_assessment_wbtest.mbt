///|
test "differential reduction keeps the selected pair and accepts changed scalar values" {
  let predicate = difference_predicate("a", "b")
  let assess = observations => {
    differential_assessment(["a", "b", "c"], observations, normalize=value => {
      Some(value)
    })
  }
  @debug.assert_eq(
    match_failure(
      predicate,
      assess(evidence("a", "1\n") + evidence("b", "2\n")),
    ),
    @contracts.Preserved,
  )
  @debug.assert_eq(
    match_failure(
      predicate,
      assess(evidence("a", "7\n") + evidence("b", "8\n")),
    ),
    @contracts.Preserved,
  )
  @debug.assert_eq(
    match_failure(
      predicate,
      assess(evidence("a", "1\n") + evidence("b", "1\n") + evidence("c", "2\n")),
    ),
    @contracts.NotPreserved,
  )
  for
    status in [
      @contracts.Exited(1),
      TimedOut,
      OutputLimit,
      HostError("fixture"),
    ] {
    let failed = evidence("b", "2\n")
    failed[1] = { ..failed[1], output: { ..failed[1].output, status, }, }
    @debug.assert_eq(
      match_failure(predicate, assess(evidence("a", "1\n") + failed)),
      @contracts.Undetermined,
    )
  }
  @debug.assert_eq(
    match_failure(
      predicate,
      differential_assessment(
        ["a", "b"],
        evidence("a", "1\n") + evidence("b", "bad"),
        normalize=value => if value == "bad" { None } else { Some(value) },
      ),
    ),
    @contracts.Undetermined,
  )
}
