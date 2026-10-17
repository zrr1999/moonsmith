///|
async test "automatic differential reduction preserves the original and replays the confirmed candidate" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/reduction-")
  defer @host.remove_tree(base)
  let run = run_differential(seed=7, base~, injected=true)
  assert_true(run.save_error is None)
  guard run.reduction is Some(reduction) else {
    fail("missing automatic reduction")
  }
  assert_true(reduction.error is None)
  assert_true(reduction.best_nodes < reduction.original_nodes)
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
      @debug.assert_eq(reduction.best_nodes, reduction.original_nodes)
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
