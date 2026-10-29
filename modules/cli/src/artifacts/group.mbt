///|
pub struct SavedGroup {
  directory : String
  case_directory : String
  case : @contracts.DifferentialCase
  record : @contracts.EquivalentGroupRecord
  attempts : Array[@contracts.DifferentialAttempt]
}

///|
pub fn group_attempt_reference(attempt : String) -> String raise {
  guard attempt.rev_find("/") is Some(index) else {
    fail("attempt requires an absolute material path")
  }
  "../../attempts/" + attempt[index + 1:].to_owned()
}

///|
async fn group_attempts(
  directory : String,
  case_directory : String,
  case : @contracts.DifferentialCase,
  record : @contracts.EquivalentGroupRecord,
) -> Array[@contracts.DifferentialAttempt] {
  guard record.format_version == 1 else { fail("unsupported group format") }
  guard record.case_source == case.source &&
    record.configurations == case.configurations &&
    record.result_protocol == case.result_protocol &&
    record.injected == case.injected else {
    fail("saved group does not match its case")
  }
  guard record.members.length() >= 2 &&
    record.members[0].id == "original" &&
    record.members[0].transformation == "identity/v1" else {
    fail("group requires an original and its transformed members")
  }
  let ids : Array[String] = []
  let paths : Array[String] = []
  let attempts = []
  for entry in record.members {
    guard !entry.id.is_empty() &&
      !entry.id.contains("/") &&
      !entry.transformation.is_empty() &&
      !ids.contains(entry.id) else {
      fail("invalid or duplicate group member")
    }
    ids.push(entry.id)
    let prefix = "../../attempts/"
    guard entry.attempt.has_prefix(prefix) else {
      fail("group member must refer to an attempt within its case")
    }
    let name = entry.attempt[prefix.length():].to_owned()
    guard name.has_prefix("run-") && !name.contains("/") && !name.contains("\\") else {
      fail("invalid group attempt reference")
    }
    let path = @host.canonical("\{directory}/\{entry.attempt}")
    guard @host.canonical("\{path}/..") ==
      @host.canonical("\{case_directory}/attempts") &&
      !paths.contains(path) else {
      fail("group attempt belongs to another case or repeats a member")
    }
    paths.push(path)
    let attempt = load_differential_attempt(path, case)
    guard attempt.source == entry.source else {
      fail("group member source does not match its execution material")
    }
    attempts.push(attempt)
  }
  attempts
}

///|
pub async fn create_group(
  case_directory : String,
  record : @contracts.EquivalentGroupRecord,
) -> String {
  let case = load_differential(case_directory)
  @host.mkdir("\{case_directory}/groups")
  let directory = @host.new_directory("\{case_directory}/groups/group-")
  ignore(group_attempts(directory, case_directory, case, record))
  @host.write_new("\{directory}/group.json", record.to_json().stringify())
  directory
}

///|
pub async fn load_group(input : String) -> SavedGroup {
  let directory = @host.canonical(input)
  let case_directory = @host.canonical("\{directory}/../..")
  guard @host.canonical("\{directory}/..") ==
    @host.canonical("\{case_directory}/groups") else {
    fail("group must be stored inside its owning case")
  }
  let case = load_differential(case_directory)
  let record : @contracts.EquivalentGroupRecord = @json.from_json(
    @json.parse(@host.read_text("\{directory}/group.json")),
  )
  let attempts = group_attempts(directory, case_directory, case, record)
  { directory, case_directory, case, record, attempts, }
}

///|
fn sibling_group(path : String) -> String raise {
  guard path.rev_find("/") is Some(index) else {
    fail("group reduction requires an absolute material path")
  }
  "../" + path[index + 1:].to_owned()
}

///|
pub async fn save_group_reduction(
  directory : String,
  record : @contracts.EquivalentGroupReduction,
) -> Unit {
  let progress = record.progress
  let progress = {
    ..progress,
    original_attempt: sibling_group(progress.original_attempt),
    best_attempt: sibling_group(progress.best_attempt),
    confirmation_attempt: match progress.confirmation_attempt {
      Some(path) => Some(sibling_group(path))
      None => None
    },
    trials: progress.trials.map(trial => {
      ..trial,
      attempt: sibling_group(trial.attempt),
    }),
  }
  @host.write_new(
    "\{directory}/reduction.json",
    { ..record, progress, }.to_json().stringify(),
  )
}
