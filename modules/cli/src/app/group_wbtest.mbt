///|
async fn controlled_group(
  directory : String,
  case : @contracts.DifferentialCase,
  group : @moonbit.EquivalentGroup,
  values : Array[String],
  purpose : String,
  missing~ : Bool = false,
  broken~ : Bool = false,
  failed_member~ : Bool = false,
) -> DifferentialRun {
  let runs = []
  for index, (id, _, program) in group.members() {
    let fixture = equivalent_fixture(values[index])
    let attempt_directory = @artifacts.begin_attempt(directory)
    @moon.prepare_saved(
      attempt_directory,
      program.emit(),
      case.module_source,
      case.package_source,
    )
    let observations = fixture.attempt.observations.filter(observation => {
      !(missing &&
      index == 0 &&
      observation.configuration == "native-debug" &&
      observation.phase == Execute)
    })
    let observations = observations.map(observation => {
      if broken &&
        index == 0 &&
        observation.configuration == "native-debug" &&
        observation.phase == Build {
        { ..observation, output: { ..observation.output, status: Exited(1), }, }
      } else {
        observation
      }
    })
    let attempt = {
      ..fixture.attempt,
      purpose,
      source: program.emit(),
      observations,
      comparison: @engine.compare(case.configurations, observations, normalize=value => {
        @moonbit.Ty::Int.normalize_output(value)
      }),
    }
    if failed_member && index == 1 {
      @host.write_new("\{attempt_directory}/attempt.json", "occupied")
    }
    let run = finish_differential(
      directory,
      case,
      attempt_directory,
      attempt,
      None,
    )
    runs.push((id, run))
  }
  record_equivalent_group(runs[0].1, group.relations(), runs, purpose, [])
}

///|
async fn original_group_fixture(
  base : String,
  group : @moonbit.EquivalentGroup,
) -> DifferentialRun {
  let case = saved_fixture(group.members()[0].2.emit())
  let directory = @artifacts.create_differential(base, case)
  controlled_group(directory, case, group, ["0\n", "1\n", "0\n"], "original")
}

///|
async test "group reduction retains the selected member pair and fresh aggregate evidence within budget" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-reduction-")
  defer @host.remove_tree(base)
  let group = composed_structure(42).finish().equivalent_group()
  for limit in [0, 1, 16, 64] {
    let original = original_group_fixture(base, group)
    @debug.assert_eq(
      execution_error(original),
      None,
      msg=describe_differential(original),
    )
    @debug.assert_eq(original.attempt.comparison, @contracts.Consistent)
    @debug.assert_eq(
      original.comparison(),
      @contracts.Difference(
        "original/native-debug", "equivalent-1/native-debug",
      ),
    )
    let source = @host.read_text("\{original.directory}/original.mbt")
    let record = @host.read_text("\{group_material(original)}/group.json")
    let result = reduce_equivalent_group(original, group, limit, evaluate=(
      candidate,
      purpose,
    ) => {
      controlled_group(
        original.directory,
        original.case,
        candidate,
        ["0\n", "1\n", "0\n"],
        purpose,
      )
    })
    @debug.assert_eq(execution_error(result), None)
    guard result.group_reduction is Some(reduction) else {
      fail("missing group reduction")
    }
    let progress = reduction.progress
    @debug.assert_eq(progress.error, None)
    @debug.assert_eq(progress.confirmation, Some(@contracts.Preserved))
    @debug.assert_eq(reduction.first_configuration, "original/native-debug")
    @debug.assert_eq(
      reduction.second_configuration,
      "equivalent-1/native-debug",
    )
    @debug.assert_eq(reduction.relations, group.relations())
    assert_true(progress.candidates <= limit)
    @debug.assert_eq(progress.candidates, progress.trials.length())
    if limit == 0 {
      @debug.assert_eq(progress.best_cost, group.cost())
      @debug.assert_eq(progress.accepted, 0)
    } else {
      assert_true(progress.accepted > 0)
      assert_true(progress.best_cost.nodes < group.cost().nodes)
    }
    guard progress.confirmation_attempt is Some(confirmation) else {
      fail("missing fresh confirmation")
    }
    assert_true(confirmation != progress.best_attempt)
    let best = @artifacts.load_group(progress.best_attempt)
    let confirmed = @artifacts.load_group(confirmation)
    @debug.assert_eq(
      best.record.members.map(entry => entry.source),
      confirmed.record.members.map(entry => entry.source),
    )
    @debug.assert_eq(confirmed.record.purpose, "confirmation")
    @debug.assert_eq(
      @host.list_directory("\{original.directory}/attempts").length(),
      (progress.candidates + 2) * 3,
    )
    for trial in progress.trials {
      @debug.assert_eq(trial.status, @contracts.Preserved)
      assert_true(trial.accepted)
      let saved = @artifacts.load_group(trial.attempt)
      @debug.assert_eq(saved.attempts.length(), 3)
    }
    let persisted : @contracts.EquivalentGroupReduction = @json.from_json(
      @json.parse(@host.read_text("\{group_material(original)}/reduction.json")),
    )
    assert_true(persisted.progress.best_attempt.has_prefix("../group-"))
    assert_true(persisted.progress.original_attempt.has_prefix("../group-"))
    @debug.assert_eq(
      @host.read_text("\{group_material(original)}/group.json"),
      record,
    )
    @debug.assert_eq(
      @host.read_text("\{original.directory}/original.mbt"),
      source,
    )
  }
}

///|
async test "group reduction rejects replacement differences missing observations and changed relations" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-target-")
  defer @host.remove_tree(base)
  let group = composed_structure(42).finish().equivalent_group()
  for mode in 0..<5 {
    let original = original_group_fixture(base, group)
    @debug.assert_eq(
      execution_error(original),
      None,
      msg=describe_differential(original),
    )
    let result = reduce_equivalent_group(original, group, 1, evaluate=(
      candidate,
      purpose,
    ) => {
      if purpose == "confirmation" {
        return controlled_group(
          original.directory,
          original.case,
          candidate,
          ["0\n", "1\n", "0\n"],
          purpose,
        )
      }
      let values = match mode {
        0 => ["0\n", "0\n", "0\n"]
        1 => ["0\n", "0\n", "1\n"]
        _ => ["0\n", "1\n", "0\n"]
      }
      let run = controlled_group(
        original.directory,
        original.case,
        candidate,
        values,
        purpose,
        missing=mode == 2 || mode == 4,
        broken=mode == 4,
      )
      if mode == 3 && run.group is Some(saved) {
        let members = saved.record.members.map(entry => {
          ..entry,
          transformation: "unknown/v2",
        })
        {
          ..run,
          group: Some({ ..saved, record: { ..saved.record, members, }, }),
        }
      } else {
        run
      }
    })
    guard result.group_reduction is Some(reduction) else {
      fail("missing group reduction")
    }
    let progress = reduction.progress
    @debug.assert_eq(progress.candidates, 1)
    @debug.assert_eq(progress.accepted, 0)
    @debug.assert_eq(progress.best_cost, group.cost())
    @debug.assert_eq(progress.trials[0].accepted, false)
    @debug.assert_eq(
      progress.trials[0].status,
      if mode < 2 {
        @contracts.NotPreserved
      } else {
        @contracts.Undetermined
      },
    )
    @debug.assert_eq(progress.confirmation, Some(@contracts.Preserved))
  }
}

///|
async test "group confirmation and storage failures preserve the original finding without claiming success" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-failure-")
  defer @host.remove_tree(base)
  let group = composed_structure(42).finish().equivalent_group()
  for save_failure in [false, true] {
    let original = original_group_fixture(base, group)
    @debug.assert_eq(
      execution_error(original),
      None,
      msg=describe_differential(original),
    )
    let result = reduce_equivalent_group(original, group, 1, evaluate=(
      candidate,
      purpose,
    ) => {
      let values = if purpose == "confirmation" {
        ["0\n", "0\n", "0\n"]
      } else {
        ["0\n", "1\n", "0\n"]
      }
      let run = controlled_group(
        original.directory,
        original.case,
        candidate,
        values,
        purpose,
      )
      if save_failure && run.equivalents is Some(comparison) {
        // Exercise the actual append-only storage boundary.
        finish_equivalents(run, comparison)
      } else {
        run
      }
    })
    guard result.group_reduction is Some(reduction) else {
      fail("missing group reduction")
    }
    @debug.assert_eq(result.comparison(), original.comparison())
    if save_failure {
      assert_true(result.save_error is Some(_))
      assert_true(reduction.progress.error is Some(_))
      @debug.assert_eq(reduction.progress.accepted, 0)
      @debug.assert_eq(reduction.progress.confirmation, None)
    } else {
      @debug.assert_eq(
        reduction.progress.confirmation,
        Some(@contracts.NotPreserved),
      )
      assert_true(
        describe_differential(result).contains("Reduction: unconfirmed"),
      )
      assert_false(
        describe_differential(result).contains("Reduction: confirmed"),
      )
    }
    let path = "\{group_material(result)}/reduction.json"
    let before = @host.read_text(path)
    let duplicate = finish_group_reduction(result, reduction)
    assert_true(duplicate.save_error is Some(_))
    @debug.assert_eq(@host.read_text(path), before)
  }
}

///|
async test "group or member storage failure retains the observed difference and prevents reduction" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-storage-")
  defer @host.remove_tree(base)
  let group = composed_structure(42).finish().equivalent_group()
  for failed_member in [false, true] {
    let case = saved_fixture(group.members()[0].2.emit())
    let directory = @artifacts.create_differential(base, case)
    if !failed_member {
      @host.write_new("\{directory}/groups", "occupied")
    }
    let run = controlled_group(
      directory,
      case,
      group,
      ["0\n", "1\n", "0\n"],
      "original",
      failed_member~,
    )
    assert_true(execution_error(run) is Some(_))
    assert_true(run.group is None)
    assert_true(run.comparison() is Difference(_, _))
    let attempts = @host.list_directory("\{directory}/attempts")
    let result = reduce_equivalent_group(run, group, 16)
    @debug.assert_eq(result.group_reduction, None)
    @debug.assert_eq(result.comparison(), run.comparison())
    @debug.assert_eq(@host.list_directory("\{directory}/attempts"), attempts)
    @debug.assert_eq(@host.read_text("\{directory}/original.mbt"), case.source)
    if failed_member {
      assert_false(@host.exists("\{directory}/groups"))
    } else {
      @debug.assert_eq(@host.read_text("\{directory}/groups"), "occupied")
    }
  }
}

///|
async test "failed variant preparation retains missing members and reports the execution error" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-prepare-")
  defer @host.remove_tree(base)
  let original = run_differential(seed=42, base~)
  let attempts = "\{original.directory}/attempts"
  @fs.rename(attempts, "\{original.directory}/original-attempts", replace=false)
  @host.write_new(attempts, "occupied")
  let group = @moonbit.synthesize(42).program.equivalent_group()
  let result = check_equivalents(original, group)
  assert_true(execution_error(result) is Some(_))
  @debug.assert_eq(result.comparison(), @contracts.Incomplete)
  assert_true(result.group is None)
  guard result.equivalents is Some(comparison) else { fail("missing result") }
  @debug.assert_eq(comparison.configurations.length(), 9)
  @debug.assert_eq(comparison.attempts.length(), 1)
  @debug.assert_eq(@host.read_text(attempts), "occupied")
}

///|
async test "group confirmation execution errors retain the finding and append an unconfirmed record" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-confirmation-")
  defer @host.remove_tree(base)
  let group = composed_structure(42).finish().equivalent_group()
  let original = original_group_fixture(base, group)
  let directory = group_material(original)
  let before = @host.read_text("\{directory}/group.json")
  let attempts = @host.list_directory("\{original.directory}/attempts")
  let result = reduce_equivalent_group(original, group, 0, evaluate=(_, purpose) => {
    @debug.assert_eq(purpose, "confirmation")
    fail("confirmation process failed")
  })
  @debug.assert_eq(result.comparison(), original.comparison())
  guard result.group_reduction is Some(reduction) else {
    fail("missing unconfirmed reduction")
  }
  @debug.assert_eq(reduction.progress.candidates, 0)
  @debug.assert_eq(reduction.progress.confirmation_attempt, None)
  @debug.assert_eq(reduction.progress.confirmation, None)
  @debug.assert_eq(reduction.progress.stop_reason, "operation error")
  guard reduction.progress.error is Some(error) else {
    fail("missing execution error")
  }
  assert_true(error.contains("confirmation process failed"))
  assert_false(describe_differential(result).contains("Reduction: confirmed"))
  @debug.assert_eq(@host.read_text("\{directory}/group.json"), before)
  @debug.assert_eq(
    @host.list_directory("\{original.directory}/attempts"),
    attempts,
  )
  let saved : @contracts.EquivalentGroupReduction = @json.from_json(
    @json.parse(@host.read_text("\{directory}/reduction.json")),
  )
  @debug.assert_eq(saved.progress.error, reduction.progress.error)
  @debug.assert_eq(saved.progress.confirmation, None)
}

///|
async test "group assembly refuses missing or reordered members without saving a misleading group" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-members-")
  defer @host.remove_tree(base)
  let group = @moonbit.synthesize(42).program.equivalent_group()
  for reordered in [false, true] {
    let original = run_differential(seed=42, base~)
    let runs = [("original", original)]
    if reordered {
      runs.push(("equivalent-2", replay_differential(original.directory)))
      runs.push(("equivalent-1", replay_differential(original.directory)))
    }
    let attempts = @host.list_directory("\{original.directory}/attempts")
    let result = record_equivalent_group(
      original,
      group.relations(),
      runs,
      "original",
      [],
    )
    assert_true(result.group is None)
    guard execution_error(result) is Some(error) else {
      fail("missing group assembly error")
    }
    assert_true(
      error.contains(
        if reordered {
          "member order changed"
        } else {
          "missing members"
        },
      ),
    )
    assert_false(@host.exists("\{original.directory}/groups"))
    @debug.assert_eq(
      @host.list_directory("\{original.directory}/attempts"),
      attempts,
    )
    @debug.assert_eq(
      @host.read_text("\{original.directory}/original.mbt"),
      original.case.source,
    )
    assert_true(@host.exists("\{original.attempt_directory}/attempt.json"))
  }
}
