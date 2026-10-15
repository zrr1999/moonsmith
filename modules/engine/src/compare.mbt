///|
/// Compare successful observations using a language-owned observation protocol.
/// Incomplete configurations cannot hide a difference between valid results.
pub fn compare(
  configurations : Array[String],
  observations : Array[@contracts.Observation],
  normalize~ : (String) -> String?,
) -> @contracts.Comparison {
  let values = comparable_results(configurations, observations, normalize~)
  guard !values.is_empty() else { return Incomplete }
  let (other, previous) = values[0]
  for (configuration, value) in values {
    if value != previous {
      return Difference(other, configuration)
    }
  }
  if values.length() == configurations.length() {
    Consistent
  } else {
    Incomplete
  }
}

///|
/// Returns every valid normalized result, including those after the first difference.
pub fn comparable_results(
  configurations : Array[String],
  observations : Array[@contracts.Observation],
  normalize~ : (String) -> String?,
) -> Array[(String, String)] {
  guard configurations.length() >= 2 else { return [] }
  for i, configuration in configurations {
    for j = 0; j < i; j = j + 1 {
      guard configurations[j] != configuration else { return [] }
    }
  }
  let values = []
  for configuration in configurations {
    let builds = observations.filter(o => {
      o.configuration == configuration && o.phase == Build
    })
    let runs = observations.filter(o => {
      o.configuration == configuration && o.phase == Execute
    })
    if builds.length() != 1 || runs.length() != 1 {
      continue
    }
    if builds[0].output.status != Exited(0) ||
      runs[0].output.status != Exited(0) {
      continue
    }
    let run = runs[0]
    guard normalize(run.injected_stdout.unwrap_or(run.output.stdout))
      is Some(value) else {
      continue
    }
    values.push((configuration, value))
  }
  values
}
