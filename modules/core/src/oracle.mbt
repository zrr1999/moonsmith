///|
/// A primary verdict for the prototype's report; use reference_assessment for all results.
pub fn judge(
  expected : String,
  configurations : Array[String],
  observations : Array[@contracts.Observation],
) -> @contracts.Verdict {
  summarize(reference_assessment(expected, configurations, observations))
}

///|
pub fn reference_assessment(
  expected : String,
  configurations : Array[String],
  observations : Array[@contracts.Observation],
) -> @contracts.Assessment {
  let results : Array[@contracts.OracleResult] = []
  if configurations.is_empty() {
    results.push({
      oracle: "reference",
      configuration: "matrix",
      phase: Execute,
      outcome: Insufficient(MissingObservation),
    })
  }
  for configuration in configurations {
    if configurations.filter(c => c == configuration).length() != 1 {
      results.push({
        oracle: "reference",
        configuration,
        phase: Execute,
        outcome: Insufficient(MissingObservation),
      })
      continue
    }
    let verdict = judge_configuration(expected, configuration, observations)
    let (phase, outcome) = match verdict {
      Match => (@contracts.Execute, @contracts.Satisfied)
      Finding(f) => (f.phase, @contracts.Violated(f.kind))
      Inconclusive(f) => (f.phase, @contracts.Insufficient(f.kind))
    }
    results.push({ oracle: "reference", configuration, phase, outcome, })
  }
  @contracts.Assessment::new(results)
}

///|
pub fn summarize(assessment : @contracts.Assessment) -> @contracts.Verdict {
  let mut uncertain : @contracts.Verdict = Inconclusive({
    configuration: "matrix",
    phase: Execute,
    kind: MissingObservation,
  })
  let mut have_result = false
  let mut missing = false
  for result in assessment.results() {
    let fingerprint : @contracts.Fingerprint = {
      configuration: result.configuration,
      phase: result.phase,
      kind: MissingObservation,
    }
    match result.outcome {
      Violated(kind) => return Finding({ ..fingerprint, kind, })
      Insufficient(kind) => {
        if !missing {
          uncertain = Inconclusive({ ..fingerprint, kind, })
        }
        missing = true
      }
      Satisfied => have_result = true
      NotApplicable => ()
    }
  }
  if have_result && assessment.is_complete() {
    Match
  } else {
    uncertain
  }
}

///|
pub fn findings(
  assessment : @contracts.Assessment,
) -> Array[@contracts.FailurePredicate] {
  let failures : Array[@contracts.FailurePredicate] = []
  for result in assessment.results() {
    if result.outcome is Violated(kind) {
      failures.push({
        oracle: result.oracle,
        fingerprint: {
          configuration: result.configuration,
          phase: result.phase,
          kind,
        },
      })
    }
  }
  failures
}

///|
pub fn match_failure(
  predicate : @contracts.FailurePredicate,
  assessment : @contracts.Assessment,
) -> @contracts.PredicateStatus {
  let matching = assessment
    .results()
    .filter(result => {
      result.oracle == predicate.oracle &&
      result.configuration == predicate.fingerprint.configuration &&
      result.phase == predicate.fingerprint.phase
    })
  if matching.length() != 1 {
    return Undetermined
  }
  match matching[0].outcome {
    Satisfied => NotPreserved
    Violated(kind) =>
      if kind == predicate.fingerprint.kind {
        Preserved
      } else {
        NotPreserved
      }
    NotApplicable => Inapplicable
    Insufficient(_) => Undetermined
  }
}

///|
fn judge_configuration(
  expected : String,
  configuration : String,
  observations : Array[@contracts.Observation],
) -> @contracts.Verdict {
  for phase in [@contracts.Build, @contracts.Execute] {
    let matching = observations.filter(o => {
      o.configuration == configuration && o.phase == phase
    })
    if matching.length() != 1 {
      return Inconclusive({ configuration, phase, kind: MissingObservation, })
    }
    let o = matching[0]
    let kind = match o.output.status {
      Exited(0) => None
      Exited(code) => Some(@contracts.Exit(code))
      TimedOut => return Inconclusive({ configuration, phase, kind: Timeout, })
      OutputLimit =>
        return Inconclusive({ configuration, phase, kind: OutputExceeded, })
      HostError(_) =>
        return Inconclusive({ configuration, phase, kind: Infrastructure, })
    }
    if kind is Some(kind) {
      return Finding({ configuration, phase, kind, })
    }
    if phase == Execute {
      let actual = o.injected_stdout.unwrap_or(o.output.stdout)
      if actual != expected {
        return Finding({ configuration, phase, kind: Mismatch, })
      }
    }
  }
  Match
}
