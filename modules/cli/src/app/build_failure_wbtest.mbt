///|
async test "native constructor failures reduce automatically with agreeing controls and local replay records" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/constructor-oracle-")
  defer @host.remove_tree(base)
  for seed in [1272, 3745, 6968] {
    let program = @moonbit.synthesize(seed).program
    let run = run_differential(seed~, base~, reduction_limit=16)
    assert_true(run.save_error is None)
    @debug.assert_eq(run.attempt.source, program.emit())
    @debug.assert_eq(run.attempt.comparison, @contracts.Incomplete)
    @debug.assert_eq(
      @engine.match_failure(
        @moon.native_constructor_predicate(),
        build_failure_assessment(run),
      ),
      @contracts.Preserved,
      msg=@debug.to_string(run.attempt.observations),
    )
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
    let replay = replay_differential(confirmed)
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
    let duplicate = finish_build_reduction(run, reduction)
    assert_true(duplicate.save_error is Some(_))
    @debug.assert_eq(@host.read_text(path), report)
  }
}

///|
async test "build failure reduction rejects invalid controls unrelated errors and unsaved evidence before searching" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/build-reduction-guard-")
  defer @host.remove_tree(base)
  let program = @moonbit.synthesize(1272).program
  let run = run_differential(seed=1272, base~, reduction_limit=0)
  let original = { ..run, build_reduction: None, }
  let count = @host.list_directory("\{run.directory}/attempts").length()
  @debug.assert_eq(count, 2)
  let observations = run.attempt.observations
  for change in 0..<5 {
    let modified = observations.map(o => {
      if change == 0 && o.configuration == "native-release" {
        {
          ..o,
          output: { ..o.output, stderr: "error: duplicate label 'join_84'\n", },
        }
      } else if change == 1 && o.phase == Execute {
        { ..o, output: { ..o.output, stdout: "not a scalar\n", }, }
      } else if change == 2 &&
        o.configuration == "native-debug" &&
        o.phase == Execute {
        { ..o, output: { ..o.output, stdout: "123\n", }, }
      } else if change == 3 &&
        o.configuration == "wasm-gc-debug" &&
        o.phase == Execute {
        { ..o, output: { ..o.output, status: TimedOut, }, }
      } else if change == 4 && o.phase == Execute {
        { ..o, injected_stdout: Some(o.output.stdout), }
      } else {
        o
      }
    })
    let candidate = {
      ..original,
      attempt: { ..original.attempt, observations: modified, },
    }
    let skipped = reduce_build_failure(candidate, program, 1)
    @debug.assert_eq(skipped.build_reduction, None)
  }
  let unsaved = reduce_build_failure(
    { ..original, save_error: Some("fixture"), },
    program,
    1,
  )
  @debug.assert_eq(unsaved.build_reduction, None)
  @debug.assert_eq(
    @host.list_directory("\{run.directory}/attempts").length(),
    count,
  )
  let changed_controls = observations.map(o => {
    if o.phase == Execute {
      { ..o, output: { ..o.output, stdout: "123\n", }, }
    } else {
      o
    }
  })
  let changed = {
    ..original,
    attempt: { ..original.attempt, observations: changed_controls, },
  }
  @debug.assert_eq(
    @engine.match_failure(
      @moon.native_constructor_predicate(),
      build_failure_assessment(changed),
    ),
    @contracts.Preserved,
  )
}
