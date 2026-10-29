///|
async test "whole group replay survives relocation toolchain changes and appends every member" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-replay-")
  defer @host.remove_tree(base)
  let original = run_differential(
    seed=42,
    base~,
    equivalent_variants=true,
    reduction_limit=0,
  )
  @debug.assert_eq(execution_error(original), None)
  guard original.group is Some(saved) else { fail("missing group") }
  let before = [
    ("case.json", @host.read_text("\{original.directory}/case.json")),
    ("original.mbt", @host.read_text("\{original.directory}/original.mbt")),
  ]
  let old_records = []
  for entry in saved.record.members {
    let path = "\{saved.directory}/\{entry.attempt}/attempt.json"
    let attempt = @artifacts.load_differential_attempt(
      "\{saved.directory}/\{entry.attempt}",
      original.case,
    )
    let previous = {
        ..attempt,
        toolchain: {
          ..attempt.toolchain,
          output: {
            ..attempt.toolchain.output,
            stdout: "old-group-toolchain\n",
          },
        },
      }
      .to_json()
      .stringify()
    @fs.write_file(path, previous)
    old_records.push((entry.attempt, previous))
  }
  let original_record = @host.read_text("\{saved.directory}/group.json")
  guard saved.directory.rev_find("/") is Some(index) else {
    fail("invalid group path")
  }
  let relocated_case = "\{base}/relocated-case"
  let relocated_group = "\{relocated_case}/groups/\{saved.directory[index + 1:]}"
  @fs.rename(original.directory, relocated_case, replace=false)
  let announced = []
  let replay = replay_differential(relocated_group, on_plan=plan => {
    announced.push(plan)
  })
  @debug.assert_eq(announced, [original.case.configurations])
  @debug.assert_eq(replay.comparison(), @contracts.Consistent)
  @debug.assert_eq(execution_error(replay), None)
  @debug.assert_eq(replay.group_reduction, None)
  @debug.assert_eq(replay.reduction, None)
  @debug.assert_eq(replay.build_reduction, None)
  assert_true(describe_differential(replay).contains("Toolchain changed"))
  assert_true(describe_differential(replay).contains("old-group-toolchain"))
  guard replay.group is Some(replayed) else { fail("missing appended group") }
  assert_true(replayed.directory != relocated_group)
  @debug.assert_eq(replayed.record.purpose, "replay")
  @debug.assert_eq(
    replayed.record.members.map(entry => entry.source),
    saved.record.members.map(entry => entry.source),
  )
  @debug.assert_eq(
    @host.list_directory("\{relocated_case}/attempts").length(),
    6,
  )
  @debug.assert_eq(@host.list_directory("\{relocated_case}/groups").length(), 2)
  for (path, contents) in old_records {
    @debug.assert_eq(
      @host.read_text("\{relocated_group}/\{path}/attempt.json"),
      contents,
    )
  }
  for (path, contents) in before {
    @debug.assert_eq(@host.read_text("\{relocated_case}/\{path}"), contents)
  }
  @debug.assert_eq(
    @host.read_text("\{relocated_group}/group.json"),
    original_record,
  )
  let again = replay_differential(replayed.directory)
  @debug.assert_eq(again.comparison(), @contracts.Consistent)
  @debug.assert_eq(execution_error(again), None)
  @debug.assert_eq(
    @host.list_directory("\{relocated_case}/attempts").length(),
    9,
  )
}

///|
async fn assert_group_refused(path : String, case_directory : String) -> Unit {
  let before = @host.list_directory("\{case_directory}/attempts")
  let mut announced = false
  let refused = try {
    ignore(replay_differential(path, on_plan=_ => announced = true))
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  assert_false(announced)
  @debug.assert_eq(@host.list_directory("\{case_directory}/attempts"), before)
}

///|
async test "group replay rejects unknown formats relations and mismatched material before execution" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/group-preflight-")
  defer @host.remove_tree(base)
  let program = composed_structure(42).finish().equivalent_group()
  let original = original_group_fixture(base, program)
  @debug.assert_eq(execution_error(original), None)
  guard original.group is Some(saved) else { fail("missing group") }
  let path = "\{saved.directory}/group.json"
  let record = saved.record
  let damaged : Array[@contracts.EquivalentGroupRecord] = [
    { ..record, format_version: 99, },
    { ..record, case_source: "another case", },
    { ..record, configurations: ["native-debug", "wasm-gc-debug"], },
    { ..record, result_protocol: "unknown", },
    { ..record, injected: !record.injected, },
    { ..record, members: [], },
    { ..record, members: [record.members[1], record.members[2]], },
    { ..record, members: [record.members[0], record.members[1]], },
    {
      ..record,
      members: [record.members[0], record.members[1], record.members[1]],
    },
    {
      ..record,
      members: record.members.mapi((i, entry) => {
        if i == 2 {
          { ..entry, source: "another source", }
        } else {
          entry
        }
      }),
    },
    {
      ..record,
      members: record.members.mapi((i, entry) => {
        if i == 2 {
          { ..entry, transformation: "unknown/v2", }
        } else {
          entry
        }
      }),
    },
    {
      ..record,
      members: record.members.mapi((i, entry) => {
        if i == 2 {
          { ..entry, attempt: "../../attempts/run-missing", }
        } else {
          entry
        }
      }),
    },
    {
      ..record,
      members: record.members.mapi((i, entry) => {
        if i == 2 {
          { ..entry, attempt: "/other-case/attempts/run-0", }
        } else {
          entry
        }
      }),
    },
    {
      ..record,
      members: record.members.mapi((i, entry) => {
        if i == 2 {
          { ..entry, attempt: "../../attempts/../run-0", }
        } else {
          entry
        }
      }),
    },
  ]
  for changed in damaged {
    @fs.write_file(path, changed.to_json().stringify())
    assert_group_refused(saved.directory, original.directory)
  }
  @fs.write_file(path, record.to_json().stringify())
  let last = "\{saved.directory}/\{record.members[2].attempt}"
  let source = @host.read_text("\{last}/main.mbt")
  @fs.write_file("\{last}/main.mbt", "corrupt source")
  assert_group_refused(saved.directory, original.directory)
  @fs.write_file("\{last}/main.mbt", source)
  let attempt = @host.read_text("\{last}/attempt.json")
  @fs.remove("\{last}/attempt.json")
  assert_group_refused(saved.directory, original.directory)
  @host.write_new("\{last}/attempt.json", attempt)
  @host.write_new(
    "\{last}/runtimes.json",
    "{\"format_version\":99,\"probes\":[]}",
  )
  assert_group_refused(saved.directory, original.directory)
  @fs.remove("\{last}/runtimes.json")
  let other = original_group_fixture(base, program)
  guard other.group is Some(other_group) else { fail("missing other group") }
  let linked = "\{original.directory}/attempts/run-foreign"
  @fs.symlink(
    target="\{other_group.directory}/\{other_group.record.members[2].attempt}",
    linked,
  )
  let changed = {
    ..record,
    members: record.members.mapi((i, entry) => {
      if i == 2 {
        { ..entry, attempt: "../../attempts/run-foreign", }
      } else {
        entry
      }
    }),
  }
  @fs.write_file(path, changed.to_json().stringify())
  assert_group_refused(saved.directory, original.directory)
  @fs.write_file(path, record.to_json().stringify())
  @debug.assert_eq(@artifacts.load_group(saved.directory).record, record)
  @host.mkdir("\{original.directory}/misplaced")
  let misplaced = @host.new_directory("\{original.directory}/misplaced/group-")
  @host.write_new("\{misplaced}/group.json", record.to_json().stringify())
  assert_group_refused(misplaced, original.directory)
}
