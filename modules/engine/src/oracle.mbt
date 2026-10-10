///|
/// Every requested configuration must finish both phases before a match is reported.
pub fn judge(
  expected : String,
  configurations : Array[String],
  observations : Array[@contracts.Observation],
) -> @contracts.Verdict {
  if configurations.is_empty() {
    return Inconclusive({
      configuration: "matrix",
      phase: Execute,
      kind: MissingObservation,
    })
  }
  let mut uncertain : @contracts.Verdict = Match
  for configuration in configurations {
    let verdict = judge_configuration(expected, configuration, observations)
    match verdict {
      Finding(_) => return verdict
      Inconclusive(_) => if uncertain == Match { uncertain = verdict }
      Match => ()
    }
  }
  uncertain
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
