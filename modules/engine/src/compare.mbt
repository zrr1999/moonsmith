///|
/// Compare successful observations using a language-owned observation protocol.
/// Incomplete configurations cannot hide a difference between valid results.
pub fn compare(
  configurations : Array[String],
  observations : Array[@contracts.Observation],
  normalize~ : (String) -> String?,
) -> @contracts.Comparison {
  guard configurations.length() >= 2 else { return Incomplete }
  for i, configuration in configurations {
    for j = 0; j < i; j = j + 1 {
      guard configurations[j] != configuration else { return Incomplete }
    }
  }
  let mut first : (String, String)? = None
  let mut complete = true
  for configuration in configurations {
    let builds = observations.filter(o => {
      o.configuration == configuration && o.phase == Build
    })
    let runs = observations.filter(o => {
      o.configuration == configuration && o.phase == Execute
    })
    if builds.length() != 1 || runs.length() != 1 {
      complete = false
      continue
    }
    if builds[0].output.status != Exited(0) ||
      runs[0].output.status != Exited(0) {
      complete = false
      continue
    }
    let run = runs[0]
    guard normalize(run.injected_stdout.unwrap_or(run.output.stdout))
      is Some(value) else {
      complete = false
      continue
    }
    match first {
      None => first = Some((configuration, value))
      Some((other, previous)) =>
        if value != previous {
          return Difference(other, configuration)
        }
    }
  }
  if complete {
    Consistent
  } else {
    Incomplete
  }
}
