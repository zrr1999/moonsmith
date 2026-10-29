///|
fn equivalent_fixture(value : String) -> DifferentialRun {
  let case = saved_fixture("fn main { println(42) }\n")
  let command : @contracts.Command = {
    program: "controlled-equivalence-fixture",
    args: [],
    cwd: "/fixture",
    timeout_ms: 1,
    output_limit: 1024,
  }
  let output : @contracts.Output = {
    status: Exited(0),
    stdout: "",
    stderr: "",
  }
  let observations : Array[@contracts.Observation] = []
  for configuration in case.configurations {
    for phase in [@contracts.Build, @contracts.Execute] {
      observations.push({
        configuration,
        phase,
        command,
        output: { ..output, stdout: if phase == Execute { value } else { "" }, },
        injected_stdout: None,
      })
    }
  }
  let probe : @contracts.ProcessEvidence = { command, output, }
  let attempt : @contracts.DifferentialAttempt = {
    format_version: 2,
    purpose: "controlled-fixture",
    source: case.source,
    configurations: case.configurations,
    result_protocol: case.result_protocol,
    toolchain: probe,
    platform: probe,
    injected: false,
    observations,
    comparison: @engine.compare(case.configurations, observations, normalize=value => {
      @moonbit.Ty::Int.normalize_output(value)
    }),
  }
  {
    directory: "/fixture/case",
    case,
    attempt,
    attempt_directory: "/fixture/attempt",
    original_toolchain: None,
    runtimes: [],
    original_runtimes: None,
    save_error: None,
    reduction: None,
    build_reduction: None,
    equivalents: None,
    group: None,
    group_reduction: None,
  }
}

///|
test "equivalent programs detect shared output differences even when each program is internally consistent" {
  let original = equivalent_fixture("42\n")
  let variant = equivalent_fixture("43\n")
  @debug.assert_eq(original.attempt.comparison, @contracts.Consistent)
  @debug.assert_eq(variant.attempt.comparison, @contracts.Consistent)
  let comparison = compare_equivalents(
    original,
    ["original", "equivalent-1", "equivalent-2"],
    [("original", original), ("equivalent-1", variant)],
  )
  @debug.assert_eq(
    comparison.comparison,
    @contracts.Difference("original/native-debug", "equivalent-1/native-debug"),
  )
  let run = { ..original, equivalents: Some(comparison), }
  @debug.assert_eq(run.comparison(), comparison.comparison)
  let text = describe_differential(run)
  assert_true(text.has_prefix("Equivalent program result: difference observed"))
  assert_true(text.contains("Valid equivalent results: 6/9"))
  assert_true(text.contains("equivalent-2/native-debug: not executed"))
  assert_true(
    text.contains("Group reduction regenerates the same transformations"),
  )
  @debug.assert_eq(
    original.attempt.observations[0].configuration,
    "native-debug",
  )
}

///|
test "missing timed out invalid and unsaved variant evidence cannot produce a complete success" {
  let original = equivalent_fixture("42\n")
  let invalid = equivalent_fixture("not an Int\n")
  let timeout = {
    ..original,
    attempt: {
      ..original.attempt,
      observations: original.attempt.observations.map(observation => {
        ..observation,
        output: { ..observation.output, status: TimedOut, },
      }),
    },
  }
  for
    runs in [
      [("original", original)],
      [("original", original), ("equivalent-1", invalid)],
      [("original", original), ("equivalent-1", timeout)],
    ] {
    let comparison = compare_equivalents(
      original,
      ["original", "equivalent-1"],
      runs,
    )
    @debug.assert_eq(comparison.comparison, @contracts.Incomplete)
    @debug.assert_eq(equivalent_values(original, comparison).length(), 3)
  }
  let unsaved = { ..equivalent_fixture("43\n"), save_error: Some("disk full"), }
  let comparison = compare_equivalents(
    original,
    ["original", "equivalent-1", "equivalent-2"],
    [
      ("original", original),
      ("equivalent-1", unsaved),
      ("equivalent-2", timeout),
    ],
  )
  assert_true(comparison.comparison is Difference(_, _))
  @debug.assert_eq(comparison.error, Some("equivalent-1: disk full"))
}

///|
async test "enabled tasks compare fifteen results preserve original material and replay both variants" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/equivalent-task-")
  defer @host.remove_tree(base)
  let samples = []
  let runs = []
  let task = run_task(
    settings=[
      "seed_start=42",
      "execution.equivalent_variants=true",
      "execution.configurations=['native-debug','native-release','wasm-gc-debug','wasm-debug','js-debug']",
      "reduction.candidate_limit=0",
      "output.directory='\{base}'",
    ],
    on_sample=(sample, run) => {
      samples.push(sample)
      if run is Some(run) {
        runs.push(run)
      }
    },
  )
  @debug.assert_eq(task_exit_code(task), 0)
  @debug.assert_eq(task.summary.attempted, 1)
  @debug.assert_eq(task.summary.comparisons_complete, 1)
  @debug.assert_eq(samples[0].planned_results, 15)
  @debug.assert_eq(samples[0].comparable_results, 15)
  assert_true(
    @host.read_text("\{task.directory}/effective.toml").contains(
      "equivalent_variants = true",
    ),
  )
  let run = runs[0]
  guard run.equivalents is Some(comparison) else {
    fail("missing equivalent check")
  }
  @debug.assert_eq(comparison.attempts.length(), 3)
  @debug.assert_eq(comparison.error, None)
  @debug.assert_eq(comparison.comparison, @contracts.Consistent)
  let original_source = @host.read_text("\{run.directory}/original.mbt")
  let original_attempt = @host.read_text(
    "\{run.attempt_directory}/attempt.json",
  )
  let report_path = "\{run.attempt_directory}/equivalents.md"
  let report = @host.read_text(report_path)
  assert_true(report.contains("Valid equivalent results: 15/15"))
  for index in 1..<comparison.attempts.length() {
    let (label, directory) = comparison.attempts[index]
    let saved = @artifacts.load_differential_attempt(directory, run.case)
    @debug.assert_eq(saved.purpose, label)
    assert_true(saved.source != original_source)
    let before = @host.read_text("\{directory}/attempt.json")
    let replay = replay_differential(directory)
    @debug.assert_eq(replay.attempt.source, saved.source)
    @debug.assert_eq(replay.comparison(), @contracts.Consistent)
    assert_true(replay.equivalents is None)
    @debug.assert_eq(@host.read_text("\{directory}/attempt.json"), before)
  }
  let duplicate = finish_equivalents(run, comparison)
  guard duplicate.equivalents is Some(failed) else {
    fail("missing failed save")
  }
  assert_true(failed.error is Some(_))
  @debug.assert_eq(failed.comparison, @contracts.Consistent)
  @debug.assert_eq(@host.read_text(report_path), report)
  @debug.assert_eq(
    @host.read_text("\{run.directory}/original.mbt"),
    original_source,
  )
  @debug.assert_eq(
    @host.read_text("\{run.attempt_directory}/attempt.json"),
    original_attempt,
  )
  @debug.assert_eq(
    @host.list_directory("\{run.directory}/attempts").length(),
    5,
  )
}
