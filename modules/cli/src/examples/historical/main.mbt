///|
async fn main {
  let toolchain = @moon.identify()
  guard toolchain.output.status == Exited(0) &&
    toolchain.output.stdout.contains("moonc v0.10.14+7d59c7ec9") else {
    fail("historical validation requires MoonBit 0.10.14+7d59c7ec9 on PATH")
  }
  @host.mkdir("runs")
  let base = @host.new_directory("runs/historical-build-failures-")
  for seed in [1272, 3745, 6968] {
    let program = @moonbit.synthesize(seed).program
    let run = @app.run_differential(seed~, base~, reduction_limit=16)
    println(@app.describe_differential(run))
    assert_true(run.save_error is None)
    @debug.assert_eq(run.attempt.source, program.emit())
    @debug.assert_eq(run.attempt.comparison, @contracts.Incomplete)
    @debug.assert_eq(run.reduction, None)
    guard run.build_reduction is Some(reduction) else {
      fail("missing automatic build failure reduction")
    }
    let progress = reduction.progress
    assert_true(progress.error is None, msg=@debug.to_string(progress))
    @debug.assert_eq(progress.confirmation, Some(@contracts.Preserved))
    assert_true(progress.best_cost.nodes < program.size())
    assert_true(progress.accepted > 0)
    assert_true(progress.candidates <= 16)
    @debug.assert_eq(progress.trials.length(), progress.candidates)
    for trial in progress.trials {
      if trial.accepted {
        @debug.assert_eq(trial.status, @contracts.Preserved)
      }
    }
    guard progress.confirmation_attempt is Some(confirmed) else {
      fail("missing independent confirmation")
    }
    assert_true(confirmed != progress.best_attempt)
    let best = @artifacts.load_differential_attempt(
      progress.best_attempt,
      run.case,
    )
    let confirmation = @artifacts.load_differential_attempt(confirmed, run.case)
    @debug.assert_eq(best.source, confirmation.source)
    @debug.assert_eq(confirmation.purpose, "build-confirmation")
    let path = "\{run.attempt_directory}/build-reduction.md"
    let report = @host.read_text(path)
    assert_true(report.contains(reduction.predicate.oracle))
    assert_true(report.contains(confirmed))
    assert_true(report.contains("No reference evaluator is used"))
    assert_false(@host.exists("\{run.attempt_directory}/reduction.json"))
    let replay = @app.replay_differential(confirmed)
    println(@app.describe_differential(replay))
    @debug.assert_eq(replay.attempt.comparison, @contracts.Incomplete)
    @debug.assert_eq(replay.attempt.source, best.source)
    @debug.assert_eq(replay.build_reduction, None)
    @debug.assert_eq(
      @host.read_text("\{run.directory}/original.mbt"),
      program.emit(),
    )
    @debug.assert_eq(
      @artifacts.load_differential_attempt(run.attempt_directory, run.case),
      run.attempt,
    )
    @debug.assert_eq(@host.read_text(path), report)
  }
}
