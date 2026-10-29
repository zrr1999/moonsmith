///|
pub struct GroupExecution {
  directory : String
  record : @contracts.EquivalentGroupRecord
}

///|
async fn record_equivalent_group(
  original : DifferentialRun,
  relations : Array[(String, String)],
  runs : Array[(String, DifferentialRun)],
  purpose : String,
  errors : Array[String],
) -> DifferentialRun {
  let comparison = compare_equivalents(original, relations.map(r => r.0), runs)
  if comparison.error is Some(error) {
    errors.push(error)
  }
  let mut result = original
  if errors.is_empty() {
    try {
      guard runs.length() == relations.length() else {
        fail("group execution is missing members")
      }
      let members : Array[@contracts.GroupMember] = relations.mapi((
        index,
        relation,
      ) => {
        let (id, transformation) = relation
        let (label, run) = runs[index]
        guard label == id else { fail("group execution member order changed") }
        {
          id,
          transformation,
          source: run.attempt.source,
          attempt: @artifacts.group_attempt_reference(run.attempt_directory),
        }
      })
      let record : @contracts.EquivalentGroupRecord = {
        format_version: 1,
        purpose,
        case_source: original.case.source,
        configurations: original.case.configurations.copy(),
        result_protocol: original.case.result_protocol,
        injected: original.case.injected,
        members,
        comparison: comparison.comparison,
      }
      validate_group_relation(record)
      let directory = @artifacts.create_group(original.directory, record)
      result = { ..result, group: Some({ directory, record, }), }
    } catch {
      error => errors.push("group storage failed: \{error}")
    }
  }
  finish_equivalents(result, {
    ..comparison,
    error: if errors.is_empty() {
      None
    } else {
      Some(errors.join("\n"))
    },
  })
}

///|
async fn check_equivalents(
  original : DifferentialRun,
  group : @moonbit.EquivalentGroup,
  purpose~ : String = "original",
) -> DifferentialRun {
  let runs = [("original", original)]
  let errors = []
  let members = group.members()
  for index in 1..<members.length() {
    let (id, _, program) = members[index]
    try {
      let run = execute_differential(
        original.directory,
        original.case,
        if purpose == "original" {
          id
        } else {
          "\{purpose}/\{id}"
        },
        source=program.emit(),
      )
      runs.push((id, run))
    } catch {
      error => errors.push("\{id}: \{error}")
    }
  }
  record_equivalent_group(original, group.relations(), runs, purpose, errors)
}

///|
async fn execute_equivalent_group(
  original : DifferentialRun,
  group : @moonbit.EquivalentGroup,
  purpose : String,
) -> DifferentialRun {
  let (_, _, program) = group.members()[0]
  let run = execute_differential(
    original.directory,
    original.case,
    "\{purpose}/original",
    source=program.emit(),
  )
  check_equivalents(run, group, purpose~)
}

///|
fn validate_group_relation(
  record : @contracts.EquivalentGroupRecord,
) -> Unit raise {
  guard @moonbit.parse_result_protocol(record.result_protocol) is Some(ty) &&
    record.members.map(entry => (entry.id, entry.transformation)) ==
    @moonbit.equivalent_relations(ty) else {
    fail("unknown or inconsistent equivalent group relation")
  }
}

///|
async fn replay_equivalent_group(
  input : String,
  on_plan~ : (Array[String]) -> Unit,
) -> DifferentialRun {
  let saved = @artifacts.load_group(input)
  validate_group_relation(saved.record)
  @moon.validate_plan(saved.case.configurations)
  @moon.validate_timeouts(
    saved.case.build_timeout_ms,
    saved.case.run_timeout_ms,
  )
  // Load every member and its environment before starting any compiler process.
  let runtimes = []
  for entry in saved.record.members {
    runtimes.push(
      @artifacts.load_runtimes("\{saved.directory}/\{entry.attempt}"),
    )
  }
  on_plan(saved.case.configurations.copy())
  let runs = []
  for index, entry in saved.record.members {
    let previous = saved.attempts[index]
    let original_runtimes = runtimes[index]
    let run = execute_differential(
      saved.case_directory,
      saved.case,
      "replay",
      source=previous.source,
      original_toolchain=previous.toolchain,
      original_runtimes?,
    )
    runs.push((entry.id, run))
  }
  record_equivalent_group(
    runs[0].1,
    saved.record.members.map(entry => (entry.id, entry.transformation)),
    runs,
    "replay",
    [],
  )
}

///|
fn group_material(run : DifferentialRun) -> String raise {
  guard run.group is Some(group) else { fail("missing saved equivalent group") }
  group.directory
}

///|
fn execution_error(run : DifferentialRun) -> String? {
  if run.save_error is Some(_) {
    run.save_error
  } else {
    match run.equivalents {
      Some(comparison) => comparison.error
      None => None
    }
  }
}
