///|
async test "native constructor oracle recognizes the three generated failures with fresh controls" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/constructor-oracle-")
  defer @host.remove_tree(base)
  for seed in [1272, 3745, 6968] {
    let program = @moonbit.synthesize(seed).program
    let run = run_differential(seed~, base~, reduction_limit=0)
    assert_true(run.save_error is None)
    @debug.assert_eq(run.attempt.source, program.emit())
    @debug.assert_eq(run.attempt.comparison, @contracts.Incomplete)
    let controls = @engine.comparable_results(
      ["native-debug", "wasm-gc-debug"],
      run.attempt.observations,
      normalize=value => program.result_type().normalize_output(value),
    )
    @debug.assert_eq(controls.length(), 2)
    @debug.assert_eq(controls[0].1, controls[1].1)
    @debug.assert_eq(
      @engine.match_failure(
        @moon.native_constructor_predicate(),
        @moon.native_constructor_assessment(
          run.attempt.observations,
          Some(controls[0].1),
        ),
      ),
      @contracts.Preserved,
      msg=@debug.to_string(run.attempt.observations),
    )
  }
}
