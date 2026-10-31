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
test "defaults partial files and settings share field types and last assignments win" {
  let task = parse_task(
    "seed_start = -1\nsample_count = 2\n[generation]\nmax_depth = 3",
    settings=[
      "seed_start = 42", "sample_count=1_000", "sample_count={value=3}", "sample_count=3",
      "generation.max_nodes=64", "execution.configurations=['native-release','native-debug']",
      "execution.equivalent_variants=true", "execution.build_timeout_ms=45000", "execution.run_timeout_ms=5000",
      "reduction.candidate_limit=0", "name='settings task'", "output.directory='path=with spaces'",
    ],
    automatic=() => fail("explicit seed must not request entropy"),
  )
  @debug.assert_eq(task.seed_start, 42)
  @debug.assert_eq(task.sample_count, 3)
  @debug.assert_eq(task.limits, {
    max_nodes: 64,
    max_depth: 3,
    max_attempts: 256,
  })
  @debug.assert_eq(task.configurations, ["native-release", "native-debug"])
  assert_true(task.equivalent_variants)
  @debug.assert_eq(task.build_timeout_ms, 45000)
  @debug.assert_eq(task.run_timeout_ms, 5000)
  @debug.assert_eq(task.candidate_limit, 0)
  @debug.assert_eq(task.name, "settings task")
  @debug.assert_eq(task.output_directory, "path=with spaces")
  let defaults = parse_task("", automatic=() => -7)
  @debug.assert_eq(defaults.seed_start, -7)
  @debug.assert_eq(defaults.sample_count, 1)
  assert_false(defaults.equivalent_variants)
  @debug.assert_eq(defaults.limits, @moonbit.GenerationLimits::default())
  @debug.assert_eq(defaults.generator, @moonbit.CompositeV2)
  @debug.assert_eq(
    parse_task("[generation]\ngenerator='template-rules-v1'", automatic=() => 0).generator,
    @moonbit.ScalarV1,
  )
  @debug.assert_eq(defaults.configurations, [
    "native-debug", "native-release", "wasm-gc-debug",
  ])
  let extended = parse_task(
    "",
    settings=["execution.configurations=['js-debug','wasm-debug']"],
    automatic=() => 0,
  )
  @debug.assert_eq(extended.configurations, ["js-debug", "wasm-debug"])
}

///|
test "automatic starts fit complete Int32 ranges and invalid tasks never request entropy" {
  for count in [1, 2, 2147483647] {
    for entropy in [-2147483648, 0, 2147483647] {
      let mut calls = 0
      let task = parse_task("sample_count = \{count}", automatic=() => {
        calls += 1
        entropy
      })
      @debug.assert_eq(calls, 1)
      assert_true(task.seed_start.to_int64() >= -2147483648L)
      assert_true(
        task.seed_start.to_int64() + count.to_int64() - 1L <= 2147483647L,
      )
      if count == 1 {
        @debug.assert_eq(task.seed_start, entropy)
      }
    }
  }
  for
    settings in [
      ["missing"],
      ["unknown=1"],
      ["generation=1"],
      ["generation.max_nodes.extra=1"],
      ["sample_count='2'"],
      ["seed_start=2147483648"],
      ["sample_count=0"],
      ["seed_start=2147483647", "sample_count=2"],
      ["execution.configurations=['native-debug']"],
      ["execution.equivalent_variants=1"],
      ["execution.equivalent_variants='true'"],
      ["execution.configurations=['native-debug','native-debug']"],
      ["generation.max_nodes=1\nsample_count=2"],
      ["generation.max_nodes=1\n[value]\nextra=2"],
      ["generation.generator='unsupported'"],
      ["generation.generator=1"],
      ["output.directory=bare"],
    ] {
    let mut requested = false
    let rejected = try {
      ignore(
        parse_task("", settings~, automatic=() => {
          requested = true
          0
        }),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=settings.join(" "))
    assert_false(requested)
  }
  let failed_entropy = try {
    ignore(parse_task("", automatic=() => fail("entropy unavailable")))
    false
  } catch {
    error => error.to_string().contains("entropy unavailable")
  }
  assert_true(failed_entropy)
}

///|
test "relative output paths retain the origin of their effective value" {
  for
    (source, settings, expected) in [
      ("", [], "/working/runs"),
      ("name='partial'", [], "/working/runs"),
      ("[output]\ndirectory='results'", [], "/config/results"),
      (
        "[output]\ndirectory='results'",
        ["output.directory='local'"],
        "/working/local",
      ),
      ("[output]\ndirectory='/absolute'", [], "/absolute"),
      ("", ["output.directory='/absolute'"], "/absolute"),
    ] {
    let task = parse_task(
      source,
      settings~,
      directory="/working",
      config_directory="/config",
      automatic=() => 42,
    )
    @debug.assert_eq(task.output_directory, expected)
  }
  @debug.assert_eq(
    parse_task("[output]\ndirectory='results'", directory="/", automatic=() => 0).output_directory,
    "/results",
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
test "task configuration names five installed moon directories" {
  let roots = [
    "/opt/moon-0", "/opt/moon-1", "/opt/moon-2", "/opt/moon-3", "/opt/moon-4",
  ]
  let task = parse_task(
    "name = \"five\"\n",
    settings=[
      "execution.toolchains=[\"/opt/moon-0\",\"/opt/moon-1\",\"/opt/moon-2\",\"/opt/moon-3\",\"/opt/moon-4\"]",
      "seed_start=1",
    ],
    directory="/work",
    automatic=() => 0,
  )
  @debug.assert_eq(task.toolchains, roots)
  @debug.assert_eq(roots.map(root => @moon.MoonToolchain::at(root).moon), [
    "/opt/moon-0/bin/moon", "/opt/moon-1/bin/moon", "/opt/moon-2/bin/moon", "/opt/moon-3/bin/moon",
    "/opt/moon-4/bin/moon",
  ])
  let rejected = try {
    ignore(
      parse_task(
        "name = \"five\"\n",
        settings=["execution.toolchains=[\"\"]", "seed_start=1"],
        directory="/work",
        automatic=() => 0,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
async test "invalid tasks fail before output creation or progress" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/invalid-task-")
  defer @host.remove_tree(base)
  let filename = "\{base}/task.toml"
  let source = task_fixture().replace(old="native-debug", new="unsupported")
  @host.write_new(filename, source)
  let progress : Array[Int32] = []
  let rejected = try {
    ignore(run_task(filename~, on_progress=(done, _) => progress.push(done)))
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
  let progress : Array[(Int32, Int32)] = []
  let run = run_task(filename~, on_progress=(done, total) => {
    progress.push((done, total))
  })
  @debug.assert_eq(progress, [(0, 2), (1, 2), (2, 2)])
  @debug.assert_eq(task_exit_code(run), 0)
  @debug.assert_eq(run.summary.attempted, 2)
  @debug.assert_eq(run.summary.consistent, 2)
  @debug.assert_eq(run.summary.differences, 0)
  @debug.assert_eq(run.summary.incomplete, 0)
  @debug.assert_eq(run.summary.operation_errors, 0)
  @debug.assert_eq(run.summary.format_version, 2)
  @debug.assert_eq(run.summary.generated_valid, 2)
  @debug.assert_eq(run.summary.baseline_configuration, Some("native-debug"))
  @debug.assert_eq(run.summary.baseline_attempted, 2)
  @debug.assert_eq(run.summary.baseline_accepted, 2)
  @debug.assert_eq(run.summary.comparisons_complete, 2)
  assert_true(run.directory.has_prefix("\{base}/output/task-"))
  @debug.assert_eq(@host.read_text("\{run.directory}/task.toml"), source)
  let effective = parse_task(@host.read_text("\{run.directory}/effective.toml"))
  @debug.assert_eq(effective.seed_start, 2147483646)
  @debug.assert_eq(effective.sample_count, 2)
  @debug.assert_eq(effective.output_directory, "\{base}/output")
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
    @debug.assert_eq(sample.format_version, 2)
    @debug.assert_eq(sample.baseline_build, Some(true))
    @debug.assert_eq(sample.comparable_results, sample.planned_results)
    assert_true(sample.elapsed_ms > 0L)
    assert_true(run.summary.elapsed_ms >= sample.elapsed_ms)
    guard sample.outcome is Observed(observation) else {
      fail("missing observed sample")
    }
    @debug.assert_eq(observation.comparison, @contracts.Consistent)
    @debug.assert_eq(observation.error, None)
    let case = @artifacts.load_differential(observation.case_directory)
    @debug.assert_eq(
      case.generation.generator,
      effective.generator.identifier(),
    )
    @debug.assert_eq(sample.generation, Some(case.generation))
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
  let overridden = run_task(filename~, settings=[
    "seed_start=-5",
    "sample_count=1",
    "name='overridden'",
    "execution.configurations=['native-debug','native-release']",
    "execution.build_timeout_ms=36000",
    "execution.run_timeout_ms=3000",
    "output.directory='\{base}/overridden'",
  ])
  @debug.assert_eq(overridden.summary.name, "overridden")
  @debug.assert_eq(overridden.summary.attempted, 1)
  let sample : @contracts.TaskSample = @json.from_json(
    @json.parse(@host.read_text("\{overridden.directory}/samples/0.json")),
  )
  @debug.assert_eq(sample.seed, -5)
  guard sample.outcome is Observed(observation) else {
    fail("missing observed sample")
  }
  let case = @artifacts.load_differential(observation.case_directory)
  @debug.assert_eq(case.generation.seed, -5)
  @debug.assert_eq(case.generation.max_nodes, 1)
  @debug.assert_eq(case.configurations, ["native-debug", "native-release"])
  @debug.assert_eq(case.build_timeout_ms, 36000)
  @debug.assert_eq(case.run_timeout_ms, 3000)
  @debug.assert_eq(@host.read_text("\{overridden.directory}/task.toml"), source)
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
  let run = run_task(filename~)
  @debug.assert_eq(task_exit_code(run), 1)
  @debug.assert_eq(run.summary.attempted, 2)
  @debug.assert_eq(run.summary.operation_errors, 2)
  @debug.assert_eq(run.summary.consistent, 0)
  @debug.assert_eq(run.summary.generated_valid, 0)
  @debug.assert_eq(run.summary.baseline_attempted, 0)
  @debug.assert_eq(run.summary.baseline_accepted, 0)
  @debug.assert_eq(run.summary.comparisons_complete, 0)
  @debug.assert_eq(@host.list_directory("\{run.directory}/cases"), [])
  for index, seed in [2147483646, 2147483647] {
    let sample : @contracts.TaskSample = @json.from_json(
      @json.parse(@host.read_text("\{run.directory}/samples/\{index}.json")),
    )
    @debug.assert_eq(sample.seed, seed)
    @debug.assert_eq(sample.generation, None)
    @debug.assert_eq(sample.baseline_build, None)
    @debug.assert_eq(sample.comparable_results, 0)
    guard sample.outcome is Failed(message) else {
      fail("missing generation failure")
    }
    assert_true(message.contains("generation failed for seed \{seed}"))
  }
}

///|
test "task aggregation preserves differences alongside errors and uses command result precedence" {
  let original : @contracts.TaskSummary = {
    format_version: 2,
    name: "model-task",
    sample_count: 2,
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
  let first = record_task_result(original, {
    format_version: 2,
    seed: 0,
    generation: Some(saved_fixture("fn main { println(0) }\n").generation),
    baseline_build: Some(false),
    comparable_results: 2,
    planned_results: 3,
    elapsed_ms: 50L,
    outcome: Observed({
      case_directory: "model-case",
      attempt_directory: "model-attempt",
      comparison: Difference("a", "b"),
      error: Some("storage failed"),
    }),
  })
  let summary = record_task_result(first, {
    format_version: 2,
    seed: 1,
    generation: None,
    baseline_build: None,
    comparable_results: 0,
    planned_results: 3,
    elapsed_ms: 0L,
    outcome: Failed("generation failed"),
  })
  @debug.assert_eq(summary.attempted, 2)
  @debug.assert_eq(summary.differences, 1)
  @debug.assert_eq(summary.operation_errors, 2)
  @debug.assert_eq(summary.generated_valid, 1)
  @debug.assert_eq(summary.baseline_attempted, 1)
  @debug.assert_eq(summary.baseline_accepted, 0)
  @debug.assert_eq(summary.comparisons_complete, 0)
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
    format_version: 2,
    seed: 1,
    generation: None,
    baseline_build: None,
    comparable_results: 0,
    planned_results: 3,
    elapsed_ms: 0L,
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
    format_version: 2,
    name: "model-task",
    sample_count: 1,
    attempted: 1,
    consistent: 0,
    differences: 0,
    incomplete: 0,
    operation_errors: 1,
    generated_valid: 0,
    baseline_configuration: None,
    baseline_attempted: 0,
    baseline_accepted: 0,
    comparisons_complete: 0,
    elapsed_ms: 0L,
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
