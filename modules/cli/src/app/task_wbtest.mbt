///|
fn task_fixture() -> String {
  (
    #|name = "task-fixture"
    #|seed_start = 2147483646
    #|sample_count = 2
    #|
    #|[generation]
    #|max_nodes = 1
    #|max_depth = 0
    #|max_attempts = 2
    #|
    #|[execution]
    #|configurations = ["native-release", "native-debug"]
    #|build_timeout_ms = 45000
    #|run_timeout_ms = 5000
    #|
    #|[reduction]
    #|candidate_limit = 0
    #|
    #|[output]
    #|directory = "output"
  )
}

///|
test "task configuration rejects unknown fields invalid plans budgets and overflowing seed ranges" {
  let source = task_fixture()
  let task = parse_task(source)
  @debug.assert_eq(task.seed_start, 2147483646)
  @debug.assert_eq(task.sample_count, 2)
  @debug.assert_eq(task.configurations, ["native-release", "native-debug"])
  @debug.assert_eq(task.output_directory, "output")
  @debug.assert_eq(
    parse_task(source.replace(old="2147483646", new="-2147483648")).seed_start,
    -2147483648,
  )
  @debug.assert_eq(
    parse_task(
      source
      .replace(old="2147483646", new="2147483647")
      .replace(old="sample_count = 2", new="sample_count = 1"),
    ).sample_count,
    1,
  )
  for
    invalid in [
      source + "\nextra = true",
      source.replace(old="sample_count", new="samples"),
      source.replace(old="sample_count = 2", new="sample_count = 0"),
      source.replace(old="sample_count = 2", new="sample_count = -1"),
      source.replace(old="sample_count = 2", new="sample_count = 3"),
      source.replace(old="2147483646", new="2147483648"),
      source.replace(old="max_nodes = 1", new="max_nodes = 0"),
      source.replace(old="max_depth = 0", new="max_depth = -1"),
      source.replace(old="max_attempts = 2", new="max_attempts = 0"),
      source.replace(old="candidate_limit = 0", new="candidate_limit = 65"),
      source.replace(old="candidate_limit = 0", new="candidate_limit = -1"),
      source.replace(old="45000", new="0"),
      source.replace(old="5000", new="600001"),
      source.replace(old="native-debug", new="native-release"),
      source.replace(old="native-debug", new="unsupported"),
      source.replace(
        old="\"native-release\", \"native-debug\"",
        new="\"native-debug\"",
      ),
      source.replace(old="\"native-release\", \"native-debug\"", new="false, 1"),
      source.replace(old="name = \"task-fixture\"", new="name = \" \""),
      source.replace(old="directory = \"output\"", new="directory = \"\""),
      source.replace(old="[reduction]", new="[unknown]"),
      "name = \"incomplete\"",
    ] {
    let rejected = try {
      ignore(parse_task(invalid))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=invalid)
  }
}

///|
async test "invalid tasks fail before output creation or progress" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/invalid-task-")
  defer @host.remove_tree(base)
  let filename = "\{base}/task.toml"
  let source = task_fixture().replace(old="native-debug", new="unsupported")
  @host.write_new(filename, source)
  let progress : Array[Int] = []
  let rejected = try {
    ignore(run_task(filename, on_progress=(done, _) => progress.push(done)))
    false
  } catch {
    error => error.to_string().contains("unsupported configuration")
  }
  assert_true(rejected)
  assert_true(progress.is_empty())
  @debug.assert_eq(@host.list_directory(base), ["task.toml"])
  @debug.assert_eq(@host.read_text(filename), source)
}

///|
async test "tasks execute their seed range and saved plan resolve output beside the file and replay independently" {
  let root = case_root()
  ignore(parse_task(@host.read_text("\{root}/acceptance.toml")))
  @host.mkdir("runs")
  let base = @host.new_directory("runs/task-integration-")
  defer @host.remove_tree(base)
  let filename = "\{base}/task.toml"
  let source = task_fixture()
  @host.write_new(filename, source)
  let progress : Array[(Int, Int)] = []
  let run = run_task(filename, on_progress=(done, total) => {
    progress.push((done, total))
  })
  @debug.assert_eq(progress, [(0, 2), (1, 2), (2, 2)])
  @debug.assert_eq(task_exit_code(run), 0)
  @debug.assert_eq(run.summary.attempted, 2)
  @debug.assert_eq(run.summary.consistent, 2)
  @debug.assert_eq(run.summary.differences, 0)
  @debug.assert_eq(run.summary.incomplete, 0)
  @debug.assert_eq(run.summary.operation_errors, 0)
  assert_true(run.directory.has_prefix("\{base}/output/task-"))
  @debug.assert_eq(@host.read_text("\{run.directory}/task.toml"), source)
  let saved : @contracts.TaskSummary = @json.from_json(
    @json.parse(@host.read_text("\{run.directory}/summary.json")),
  )
  @debug.assert_eq(saved, run.summary)
  for index, seed in [2147483646, 2147483647] {
    let sample_file = "\{run.directory}/samples/\{index}.json"
    let sample_source = @host.read_text(sample_file)
    let sample : @contracts.TaskSample = @json.from_json(
      @json.parse(sample_source),
    )
    @debug.assert_eq(sample.seed, seed)
    guard sample.outcome is Observed(observation) else {
      fail("missing observed sample")
    }
    @debug.assert_eq(observation.comparison, @contracts.Consistent)
    @debug.assert_eq(observation.error, None)
    let case = @artifacts.load_differential(observation.case_directory)
    @debug.assert_eq(case.generation.seed, seed)
    @debug.assert_eq(case.generation.max_nodes, 1)
    @debug.assert_eq(case.generation.max_depth, 0)
    @debug.assert_eq(case.generation.max_attempts, 2)
    @debug.assert_eq(case.configurations, ["native-release", "native-debug"])
    @debug.assert_eq(case.build_timeout_ms, 45000)
    @debug.assert_eq(case.run_timeout_ms, 5000)
    let original = @host.read_text(
      "\{observation.attempt_directory}/attempt.json",
    )
    let replay = replay_differential(observation.case_directory)
    @debug.assert_eq(replay.attempt.source, case.source)
    @debug.assert_eq(replay.attempt.configurations, case.configurations)
    @debug.assert_eq(replay.attempt.comparison, @contracts.Consistent)
    @debug.assert_eq(
      @host.read_text("\{observation.attempt_directory}/attempt.json"),
      original,
    )
    @debug.assert_eq(@host.read_text(sample_file), sample_source)
    @debug.assert_eq(
      @host.read_text("\{observation.case_directory}/original.mbt"),
      case.source,
    )
  }
  @debug.assert_eq(@host.read_text(filename), source)
  @debug.assert_eq(
    @host.read_text("\{run.directory}/summary.json"),
    saved.to_json().stringify(),
  )
}

///|
async test "sample generation failures retain every seed and continue through the task" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/task-generation-failure-")
  defer @host.remove_tree(base)
  let filename = "\{base}/task.toml"
  @host.write_new(
    filename,
    task_fixture().replace(old="max_attempts = 2", new="max_attempts = 1"),
  )
  let run = run_task(filename)
  @debug.assert_eq(task_exit_code(run), 1)
  @debug.assert_eq(run.summary.attempted, 2)
  @debug.assert_eq(run.summary.operation_errors, 2)
  @debug.assert_eq(run.summary.consistent, 0)
  @debug.assert_eq(@host.list_directory("\{run.directory}/cases"), [])
  for index, seed in [2147483646, 2147483647] {
    let sample : @contracts.TaskSample = @json.from_json(
      @json.parse(@host.read_text("\{run.directory}/samples/\{index}.json")),
    )
    @debug.assert_eq(sample.seed, seed)
    guard sample.outcome is Failed(message) else {
      fail("missing generation failure")
    }
    assert_true(message.contains("generation failed for seed \{seed}"))
  }
}

///|
test "task aggregation preserves differences alongside errors and uses command result precedence" {
  let original : @contracts.TaskSummary = {
    format_version: 1,
    name: "model-task",
    sample_count: 2,
    attempted: 0,
    consistent: 0,
    differences: 0,
    incomplete: 0,
    operation_errors: 0,
  }
  let first = record_task_result(original, {
    seed: 0,
    outcome: Observed({
      case_directory: "model-case",
      attempt_directory: "model-attempt",
      comparison: Difference("a", "b"),
      error: Some("storage failed"),
    }),
  })
  let summary = record_task_result(first, {
    seed: 1,
    outcome: Failed("generation failed"),
  })
  @debug.assert_eq(summary.attempted, 2)
  @debug.assert_eq(summary.differences, 1)
  @debug.assert_eq(summary.operation_errors, 2)
  for
    (value, expected) in [
      (summary, 1),
      ({ ..summary, operation_errors: 0, }, 2),
      ({ ..summary, operation_errors: 0, differences: 0, incomplete: 2, }, 3),
      ({ ..original, attempted: 2, consistent: 2, }, 0),
      (original, 1),
    ] {
    @debug.assert_eq(
      task_exit_code({ directory: "model-task", summary: value, }),
      expected,
    )
  }
  let text = describe_task({ directory: "model-task", summary, })
  assert_true(text.contains("Samples attempted: 2/2"))
  assert_true(text.contains("Differences: 1"))
  assert_true(text.contains("Samples with operation errors: 2"))
}

///|
async test "task sample records cannot be overwritten and failed finalization has no completion marker" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/task-storage-")
  defer @host.remove_tree(base)
  let directory = @artifacts.create_task(base, task_fixture())
  let sample : @contracts.TaskSample = {
    seed: 1,
    outcome: Failed("model generation failure"),
  }
  @artifacts.save_task_sample(directory, 0, sample)
  let before = @host.read_text("\{directory}/samples/0.json")
  let overwrite_rejected = try {
    @artifacts.save_task_sample(directory, 0, { ..sample, seed: 2, })
    false
  } catch {
    _ => true
  }
  assert_true(overwrite_rejected)
  @host.mkdir("\{directory}/report.md")
  let summary : @contracts.TaskSummary = {
    format_version: 1,
    name: "model-task",
    sample_count: 1,
    attempted: 1,
    consistent: 0,
    differences: 0,
    incomplete: 0,
    operation_errors: 1,
  }
  let finish_rejected = try {
    @artifacts.finish_task(directory, summary, "report")
    false
  } catch {
    _ => true
  }
  assert_true(finish_rejected)
  assert_false(@host.exists("\{directory}/summary.json"))
  @debug.assert_eq(@host.read_text("\{directory}/samples/0.json"), before)
}

///|
async test "selected run configurations remain frozen through execution reduction and confirmation" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/selected-plan-")
  defer @host.remove_tree(base)
  let planned = ["native-release", "native-debug"]
  let run = run_differential(
    seed=7,
    base~,
    planned~,
    injected=true,
    reduction_limit=0,
    on_plan=announced => announced.clear(),
  )
  @debug.assert_eq(planned, ["native-release", "native-debug"])
  @debug.assert_eq(run.case.configurations, planned)
  assert_planned_observations(run.attempt.observations, planned, [
    Build,
    Execute,
  ])
  @debug.assert_eq(
    run.attempt.comparison,
    @contracts.Difference("native-release", "native-debug"),
  )
  guard run.reduction is Some(reduction) &&
    reduction.confirmation_attempt is Some(directory) else {
    fail("missing independent confirmation")
  }
  let confirmation = @artifacts.load_differential_attempt(directory, run.case)
  @debug.assert_eq(confirmation.configurations, planned)
  @debug.assert_eq(reduction.confirmation, Some(@contracts.Preserved))
  let rejected = try {
    ignore(
      run_differential(seed=7, base~, planned=["native-debug", "unsupported"]),
    )
    false
  } catch {
    error => error.to_string().contains("unsupported configuration")
  }
  assert_true(rejected)
  @debug.assert_eq(@host.list_directory(base).length(), 1)
}
