///|
async test "stored generated inputs reduce with fresh confirmation and replay without changing the original" {
  let root = case_root()
  for fixture in fixed_cases_for(root, "reduction") {
    guard @toml.parse(fixture.metadata) is TomlTable(fields) else {
      fail("reduction case metadata must be a table")
    }
    guard @moonbit.parse_generator(case_string(fields, "generator"))
      is Some(generator) else {
      fail("unsupported reduction fixture generator")
    }
    let seed = case_int(fields, "seed")
    let limits : @moonbit.GenerationLimits = {
      max_nodes: case_int(fields, "max_nodes"),
      max_depth: case_int(fields, "max_depth"),
      max_attempts: case_int(fields, "max_attempts"),
    }
    let generated = @moonbit.synthesize(seed, limits~, generator~)
    @debug.assert_eq(
      generated.program.emit().trim_end().to_owned() + "\n",
      fixture.source,
    )
    @host.mkdir("runs")
    let base = @host.new_directory("runs/reduction-")
    defer @host.remove_tree(base)
    let run = run_differential(seed~, limits~, generator~, base~, injected=true)
    @debug.assert_eq(run.case.source, generated.program.emit())
    assert_true(run.save_error is None)
    guard run.reduction is Some(reduction) else {
      fail("missing automatic reduction")
    }
    assert_true(reduction.error is None)
    assert_true(reduction.best_cost.nodes < reduction.original_cost.nodes)
    @debug.assert_eq(reduction.format_version, 3)
    assert_true(reduction.elapsed_ms > 0L)
    @debug.assert_eq(reduction.cost_model, @moonbit.reduction_cost_model())
    assert_true(reduction.accepted > 0)
    assert_true(reduction.candidates <= reduction.candidate_limit)
    @debug.assert_eq(reduction.confirmation, Some(@contracts.Preserved))
    @debug.assert_eq(run.attempt.purpose, "original")
    @debug.assert_eq(run.attempt.source, run.case.source)
    @debug.assert_eq(@artifacts.load_differential(run.directory), run.case)
    let saved : @contracts.DifferentialReduction = @json.from_json(
      @json.parse(@host.read_text("\{run.attempt_directory}/reduction.json")),
    )
    @debug.assert_eq(saved, reduction)
    guard reduction.confirmation_attempt is Some(confirmed) else {
      fail("missing confirmation")
    }
    assert_true(confirmed != reduction.best_attempt)
    let best = @artifacts.load_differential_attempt(
      reduction.best_attempt,
      run.case,
    )
    let confirmation = @artifacts.load_differential_attempt(confirmed, run.case)
    @debug.assert_eq(confirmation.source, best.source)
    assert_true(confirmation.source != run.case.source)
    @debug.assert_eq(confirmation.purpose, "confirmation")
    let before : Map[String, String] = Map([])
    for name in @host.list_directory("\{run.directory}/attempts") {
      let directory = "\{run.directory}/attempts/\{name}"
      for file in ["main.mbt", "attempt.json", "report.md"] {
        before["\{directory}/\{file}"] = @host.read_text("\{directory}/\{file}")
      }
    }
    let count = @host.list_directory("\{run.directory}/attempts").length()
    @debug.assert_eq(count, reduction.candidates + 2)
    let replay = replay_differential(confirmed)
    @debug.assert_eq(replay.attempt.source, confirmation.source)
    @debug.assert_eq(
      replay.attempt.comparison,
      @contracts.Difference("native-debug", "native-release"),
    )
    @debug.assert_eq(replay.reduction, None)
    @debug.assert_eq(
      @host.list_directory("\{run.directory}/attempts").length(),
      count + 1,
    )
    for path, content in before {
      @debug.assert_eq(@host.read_text(path), content)
    }
    @debug.assert_eq(
      @host.read_text("\{run.directory}/original.mbt"),
      run.case.source,
    )
    // A saved attempt must be intact before replay can append anything.
    @fs.write_file("\{confirmed}/main.mbt", "fn main { println(999) }\n")
    let rejected = try {
      ignore(replay_differential(confirmed))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
    @debug.assert_eq(
      @host.list_directory("\{run.directory}/attempts").length(),
      count + 1,
    )
    @debug.assert_eq(
      @host.read_text("\{root}/\{fixture.path}/main.mbt"),
      fixture.source,
    )
    @debug.assert_eq(
      @host.read_text("\{root}/\{fixture.path}/case.toml"),
      fixture.metadata,
    )
  }
}

///|
async test "reduction budgets bound candidates and confirmation is an additional independent run" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/reduction-budget-")
  defer @host.remove_tree(base)
  for limit in [0, 1] {
    let run = run_differential(
      seed=7,
      base~,
      injected=true,
      reduction_limit=limit,
    )
    guard run.reduction is Some(reduction) else { fail("missing reduction") }
    @debug.assert_eq(reduction.candidates, limit)
    @debug.assert_eq(reduction.stop_reason, "candidate budget exhausted")
    @debug.assert_eq(reduction.confirmation, Some(@contracts.Preserved))
    @debug.assert_eq(
      @host.list_directory("\{run.directory}/attempts").length(),
      limit + 2,
    )
    if limit == 0 {
      @debug.assert_eq(reduction.best_cost, reduction.original_cost)
      assert_true(describe_differential(run).contains("no cost improvement"))
    }
  }
  let before = @host.list_directory(base)
  for limit in [-1, 65] {
    let rejected = try {
      ignore(run_differential(seed=7, base~, reduction_limit=limit))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  @debug.assert_eq(@host.list_directory(base), before)
}

///|
async test "same-node integer reduction saves costs confirms fresh evidence and replays" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/integer-reduction-")
  defer @host.remove_tree(base)
  let program = @moonbit.Template::{
    enums: [],
    functions: [],
    result: IntLiteral(-2147483648),
  }.finish()
  let case = saved_fixture(program.emit(), injected=true)
  let directory = @artifacts.create_differential(base, case)
  let original = execute_differential(directory, case, "original")
  let run = reduce_differential(original, program, 16)
  assert_true(run.save_error is None)
  guard run.reduction is Some(reduction) else { fail("missing reduction") }
  assert_true(reduction.error is None)
  @debug.assert_eq(reduction.format_version, 3)
  assert_true(reduction.elapsed_ms > 0L)
  @debug.assert_eq(reduction.original_cost.nodes, 1)
  @debug.assert_eq(reduction.best_cost.nodes, 1)
  @debug.assert_eq(reduction.original_cost.integer_magnitude, 2147483648L)
  @debug.assert_eq(reduction.best_cost.integer_magnitude, 0L)
  @debug.assert_eq(reduction.best_cost.source_bytes, 25)
  @debug.assert_eq(reduction.candidates, 1)
  @debug.assert_eq(reduction.accepted, 1)
  @debug.assert_eq(reduction.stop_reason, "candidate search finished")
  @debug.assert_eq(reduction.confirmation, Some(@contracts.Preserved))
  let summary = describe_differential(run)
  assert_true(summary.contains("Reduction nodes: 1 -> 1"))
  assert_true(summary.contains("2147483648 -> 0 integer magnitude"))
  assert_false(summary.contains("no cost improvement"))
  let saved : @contracts.DifferentialReduction = @json.from_json(
    @json.parse(@host.read_text("\{original.attempt_directory}/reduction.json")),
  )
  @debug.assert_eq(saved, reduction)
  guard reduction.confirmation_attempt is Some(confirmed) else {
    fail("missing independent confirmation")
  }
  assert_true(confirmed != reduction.best_attempt)
  let confirmation = @artifacts.load_differential_attempt(confirmed, case)
  @debug.assert_eq(confirmation.source, "fn main {\n  println(0)\n}\n")
  @debug.assert_eq(confirmation.purpose, "confirmation")
  for observation in confirmation.observations {
    @debug.assert_eq(observation.output.status, @contracts.Exited(0))
    if observation.phase == Execute {
      @debug.assert_eq(observation.output.stdout, "0\n")
    }
  }
  @debug.assert_eq(@host.list_directory("\{directory}/attempts").length(), 3)
  let replay = replay_differential(confirmed)
  @debug.assert_eq(replay.attempt.source, confirmation.source)
  @debug.assert_eq(replay.attempt.comparison, run.attempt.comparison)
  @debug.assert_eq(@host.list_directory("\{directory}/attempts").length(), 4)
  @debug.assert_eq(@artifacts.load_differential(directory), case)
  @debug.assert_eq(@host.read_text("\{directory}/original.mbt"), program.emit())
  @debug.assert_eq(
    @artifacts.load_differential_attempt(original.attempt_directory, case),
    original.attempt,
  )
}

///|
async test "reduction save failures retain original evidence and unconfirmed results stay explicit" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/reduction-storage-")
  defer @host.remove_tree(base)
  let run = run_differential(seed=7, base~, injected=true, reduction_limit=0)
  guard run.reduction is Some(reduction) else { fail("missing reduction") }
  let record = @host.read_text("\{run.attempt_directory}/reduction.json")
  // Exclusive creation must reject an overwrite of already completed reduction evidence.
  let failed = finish_reduction(run, reduction)
  assert_true(failed.save_error is Some(_))
  @debug.assert_eq(failed.attempt.comparison, run.attempt.comparison)
  @debug.assert_eq(
    @host.read_text("\{run.attempt_directory}/reduction.json"),
    record,
  )
  assert_true(describe_differential(failed).contains("saving failed"))
  for status in [@contracts.NotPreserved, Undetermined] {
    let unconfirmed = {
      ..run,
      reduction: Some({ ..reduction, confirmation: Some(status), }),
    }
    let summary = describe_differential(unconfirmed)
    assert_true(summary.contains("difference observed"))
    assert_true(summary.contains("Reduction: unconfirmed"))
    assert_false(summary.contains("Reduced source:"))
  }
}
