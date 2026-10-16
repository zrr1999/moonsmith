///|
test "assessment snapshots do not share mutable result arrays" {
  let row : OracleResult = {
    oracle: "reference",
    configuration: "toy",
    phase: Execute,
    outcome: Violated(Mismatch),
  }
  let source = [row]
  let report = Assessment::new(source)
  source[0] = { ..row, outcome: Satisfied, }
  @debug.assert_eq(report.results()[0].outcome, Violated(Mismatch))
  let exposed = report.results()
  exposed.clear()
  @debug.assert_eq(report.results().length(), 1)
  assert_true(report.is_complete())
  assert_false(Assessment::new([]).is_complete())
  assert_false(Assessment::new([row, row]).is_complete())
}

///|
test "assessment completeness distinguishes oracle configuration and phase" {
  let row : OracleResult = {
    oracle: "reference",
    configuration: "native",
    phase: Build,
    outcome: Satisfied,
  }
  let rows = [
    row,
    { ..row, oracle: "differential", },
    { ..row, configuration: "wasm", },
    { ..row, phase: Execute, outcome: NotApplicable, },
  ]
  assert_true(Assessment::new(rows).is_complete())
  rows.push({ ..row, outcome: Violated(Exit(9)), })
  assert_false(Assessment::new(rows).is_complete())
  assert_false(
    Assessment::new([{ ..row, outcome: Insufficient(Timeout), }]).is_complete(),
  )
}
