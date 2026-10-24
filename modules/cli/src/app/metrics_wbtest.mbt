///|
async test "tasks without the baseline retain complete comparison counts without claiming baseline acceptance" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/metrics-no-baseline-")
  defer @host.remove_tree(base)
  let run = run_task(settings=[
    "seed_start=42",
    "generation.max_nodes=1",
    "generation.max_depth=0",
    "generation.max_attempts=2",
    "execution.configurations=['js-debug','wasm-debug']",
    "output.directory='\{base}'",
  ])
  @debug.assert_eq(run.summary.generated_valid, 1)
  @debug.assert_eq(run.summary.comparisons_complete, 1)
  @debug.assert_eq(run.summary.baseline_configuration, None)
  @debug.assert_eq(run.summary.baseline_attempted, 0)
  @debug.assert_eq(run.summary.baseline_accepted, 0)
  assert_true(describe_task(run).contains("Baseline builds: unavailable"))
  let sample : @contracts.TaskSample = @json.from_json(
    @json.parse(@host.read_text("\{run.directory}/samples/0.json")),
  )
  @debug.assert_eq(sample.baseline_build, None)
  @debug.assert_eq(sample.comparable_results, 2)
  @debug.assert_eq(sample.planned_results, 2)
  assert_true(sample.elapsed_ms > 0L)
  assert_true(run.summary.elapsed_ms >= sample.elapsed_ms)
}

///|
async test "checked generation is observable before storage failure and failed construction is never counted as valid" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/metrics-generation-")
  defer @host.remove_tree(base)
  let blocked = "\{base}/blocked"
  @host.write_new(blocked, "fixture")
  let mut generation = None
  let failed = try {
    ignore(
      run_differential(seed=42, base=blocked, on_generated=record => {
        generation = Some(record)
      }),
    )
    false
  } catch {
    error => error.to_string().contains("case storage failed")
  }
  assert_true(failed)
  guard generation is Some(record) else { fail("missing checked generation") }
  @debug.assert_eq(record.seed, 42)
  assert_true(record.nodes > 0)
  generation = None
  let rejected = try {
    ignore(
      run_differential(
        seed=42,
        base~,
        limits={ max_nodes: 1, max_depth: 0, max_attempts: 1, },
        on_generated=record => generation = Some(record),
      ),
    )
    false
  } catch {
    error => error.to_string().contains("generation failed")
  }
  assert_true(rejected)
  @debug.assert_eq(generation, None)
}

///|
test "a complete comparison may disagree and does not imply baseline acceptance" {
  let run : @contracts.TaskSummary = {
    format_version: 2,
    name: "counts",
    sample_count: 1,
    attempted: 0,
    consistent: 0,
    differences: 0,
    incomplete: 0,
    operation_errors: 0,
    generated_valid: 0,
    baseline_configuration: Some("native-debug"),
    baseline_attempted: 0,
    baseline_accepted: 0,
    comparisons_complete: 0,
    elapsed_ms: 0L,
  }
  let partial : @contracts.TaskSample = {
    format_version: 2,
    seed: 42,
    generation: None,
    baseline_build: Some(false),
    comparable_results: 2,
    planned_results: 3,
    elapsed_ms: 0L,
    outcome: Observed({
      case_directory: "fixture",
      attempt_directory: "fixture/attempts/original",
      comparison: Difference("js-debug", "wasm-debug"),
      error: None,
    }),
  }
  let result = record_task_result(run, partial)
  @debug.assert_eq(result.differences, 1)
  @debug.assert_eq(result.comparisons_complete, 0)
  @debug.assert_eq(result.baseline_attempted, 1)
  @debug.assert_eq(result.baseline_accepted, 0)
  let complete = record_task_result(run, {
    ..partial,
    comparable_results: 3,
    baseline_build: Some(true),
  })
  @debug.assert_eq(complete.comparisons_complete, 1)
  @debug.assert_eq(complete.differences, 1)
  @debug.assert_eq(complete.consistent, 0)
}
