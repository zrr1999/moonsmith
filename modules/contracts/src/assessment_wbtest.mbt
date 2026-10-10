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
