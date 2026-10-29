///|
async test "build failure reduction rejects invalid controls unrelated errors and unsaved evidence before searching" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/build-reduction-guard-")
  defer @host.remove_tree(base)
  let program = @moonbit.synthesize(1272).program
  let fixture = equivalent_fixture("0\n")
  let case = { ..fixture.case, source: program.emit(), }
  let directory = @artifacts.create_differential(base, case)
  let attempt_directory = @artifacts.begin_attempt(directory)
  @moon.prepare_saved(
    attempt_directory,
    case.source,
    case.module_source,
    case.package_source,
  )
  let observations = fixture.attempt.observations
    .filter(o => !(o.configuration == "native-release" && o.phase == Execute))
    .map(o => {
      if o.configuration == "native-release" {
        {
          ..o,
          output: {
            status: Exited(255),
            stdout: "",
            stderr: "generated.c:1: error: use of undeclared identifier '_M0L6constrS84'\n",
          },
        }
      } else {
        o
      }
    })
  let original = finish_differential(
    directory,
    case,
    attempt_directory,
    {
      ..fixture.attempt,
      source: case.source,
      observations,
      comparison: Incomplete,
    },
    None,
  )
  @debug.assert_eq(
    @engine.match_failure(
      @moon.native_constructor_predicate(),
      build_failure_assessment(original),
    ),
    @contracts.Preserved,
  )
  let count = @host.list_directory("\{original.directory}/attempts").length()
  @debug.assert_eq(count, 1)
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
    @host.list_directory("\{original.directory}/attempts").length(),
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
  let reduction : @contracts.BuildFailureReduction = {
    predicate: @moon.native_constructor_predicate(),
    progress: {
      original_attempt: original.attempt_directory,
      cost_model: @moonbit.reduction_cost_model(),
      original_cost: program.cost(),
      candidate_limit: 0,
      candidates: 0,
      accepted: 0,
      elapsed_ms: 0L,
      best_cost: program.cost(),
      best_attempt: original.attempt_directory,
      stop_reason: "candidate budget exhausted",
      confirmation_attempt: None,
      confirmation: None,
      error: None,
      trials: [],
    },
  }
  let saved = finish_build_reduction(original, reduction)
  assert_true(saved.save_error is None)
  let path = "\{original.attempt_directory}/build-reduction.md"
  let report = @host.read_text(path)
  let duplicate = finish_build_reduction(original, reduction)
  assert_true(duplicate.save_error is Some(_))
  @debug.assert_eq(@host.read_text(path), report)
}
