///|
/// The oracle identifies the baseline; the configuration identifies its peer.
pub fn difference_predicate(
  first : String,
  second : String,
) -> @contracts.FailurePredicate {
  {
    oracle: "differential:\{first}",
    fingerprint: { configuration: second, phase: Execute, kind: Mismatch, },
  }
}

///|
/// Retain every planned pair so a different disagreement cannot replace the selected one.
pub fn differential_assessment(
  configurations : Array[String],
  observations : Array[@contracts.Observation],
  normalize~ : (String) -> String?,
) -> @contracts.Assessment {
  let values = Map(comparable_results(configurations, observations, normalize~))
  let results : Array[@contracts.OracleResult] = []
  for i, first in configurations {
    for j = i + 1; j < configurations.length(); j = j + 1 {
      let second = configurations[j]
      let predicate = difference_predicate(first, second)
      results.push({
        oracle: predicate.oracle,
        configuration: second,
        phase: Execute,
        outcome: match (values.get(first), values.get(second)) {
          (Some(a), Some(b)) =>
            if a == b {
              Satisfied
            } else {
              Violated(Mismatch)
            }
          _ => Insufficient(MissingObservation)
        },
      })
    }
  }
  @contracts.Assessment::new(results)
}
