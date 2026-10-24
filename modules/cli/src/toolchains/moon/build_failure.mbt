///|
pub fn native_constructor_predicate() -> @contracts.FailurePredicate {
  {
    oracle: "moonbit-native-undeclared-constructor/1",
    fingerprint: {
      configuration: "native-release",
      phase: Build,
      kind: Exit(255),
    },
  }
}

///|
fn decimal_digits(text : StringView) -> Bool {
  !text.is_empty() && text.iter().all(c => c >= '0' && c <= '9')
}

///|
fn constructor_identifier(identifier : StringView) -> Bool {
  guard identifier.find("L") is Some(local_index) &&
    identifier.find("constrS") is Some(tag_index) &&
    local_index < tag_index else {
    return false
  }
  decimal_digits(identifier[:local_index]) &&
  decimal_digits(identifier[local_index + 1:tag_index]) &&
  decimal_digits(identifier[tag_index + 7:])
}

///|
fn constructor_diagnostic(message : StringView) -> Bool {
  let message = message.trim()
  for
    (prefix, suffix) in [
      ("use of undeclared identifier '_M", "'"),
      ("'_M", "' undeclared (first use in this function)"),
      ("‘_M", "’ undeclared (first use in this function)"),
    ] {
    if message.strip_prefix(prefix) is Some(identifier) &&
      identifier.strip_suffix(suffix) is Some(identifier) {
      return constructor_identifier(identifier)
    }
  }
  false
}

///|
fn incomplete_status(
  status : @contracts.ProcessStatus,
) -> @contracts.CheckOutcome {
  match status {
    TimedOut => Insufficient(Timeout)
    OutputLimit => Insufficient(OutputExceeded)
    HostError(_) => Insufficient(Infrastructure)
    Exited(_) => NotApplicable
  }
}

///|
fn constructor_outcome(
  observations : Array[@contracts.Observation],
  expected : String?,
) -> @contracts.CheckOutcome {
  let builds = observations.filter(o => {
    o.configuration == "native-release" && o.phase == Build
  })
  guard builds.length() == 1 else { return Insufficient(MissingObservation) }
  if builds[0].injected_stdout is Some(_) {
    return NotApplicable
  }
  let output = builds[0].output
  match output.status {
    Exited(255) => ()
    Exited(_) => return Satisfied
    status => return incomplete_status(status)
  }
  let mut errors = 0
  for text in [output.stdout, output.stderr] {
    for line in text.split("\n") {
      if line.find("error:") is Some(index) {
        if !constructor_diagnostic(line[index + 6:]) {
          return Satisfied
        }
        errors += 1
      }
    }
  }
  guard errors > 0 && expected is Some(expected) else {
    return Insufficient(MissingObservation)
  }
  if observations.any(o => {
      o.configuration == "native-release" && o.phase == Execute
    }) {
    return Insufficient(MissingObservation)
  }
  for configuration in ["native-debug", "wasm-gc-debug"] {
    for phase in [@contracts.Build, @contracts.Execute] {
      let matching = observations.filter(o => {
        o.configuration == configuration && o.phase == phase
      })
      guard matching.length() == 1 else {
        return Insufficient(MissingObservation)
      }
      let observation = matching[0]
      if observation.output.status != Exited(0) {
        return incomplete_status(observation.output.status)
      }
      if observation.injected_stdout is Some(_) {
        return NotApplicable
      }
      if phase == Execute && observation.output.stdout != expected {
        return NotApplicable
      }
    }
  }
  Violated(Exit(255))
}

///|
/// The versioned oracle owns diagnostic matching and the candidate's control results.
pub fn native_constructor_assessment(
  observations : Array[@contracts.Observation],
  expected : String?,
) -> @contracts.Assessment {
  let predicate = native_constructor_predicate()
  @contracts.Assessment::new([
    {
      oracle: predicate.oracle,
      configuration: predicate.fingerprint.configuration,
      phase: predicate.fingerprint.phase,
      outcome: constructor_outcome(observations, expected),
    },
  ])
}
