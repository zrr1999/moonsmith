///|
pub(all) enum CheckOutcome {
  Satisfied
  Violated(FailureKind)
  NotApplicable
  Insufficient(FailureKind)
} derive(Eq, @debug.Debug)

///|
pub(all) struct OracleResult {
  oracle : String
  configuration : String
  phase : Phase
  outcome : CheckOutcome
} derive(Eq, @debug.Debug)

///|
/// A snapshot of independent results; callers cannot mutate the retained array.
pub struct Assessment {
  priv results : Array[OracleResult]
} derive(Eq, @debug.Debug)

///|
pub fn Assessment::new(results : Array[OracleResult]) -> Assessment {
  { results: results.copy(), }
}

///|
pub fn Assessment::results(self : Assessment) -> Array[OracleResult] {
  self.results.copy()
}

///|
pub fn Assessment::is_complete(self : Assessment) -> Bool {
  let seen : Map[(String, String, Phase), Unit] = Map([])
  for result in self.results {
    let key = (result.oracle, result.configuration, result.phase)
    if result.outcome is Insufficient(_) || seen.contains(key) {
      return false
    }
    seen[key] = ()
  }
  !self.results.is_empty()
}

///|
/// One observed failure condition, scoped to its oracle and execution phase.
pub(all) struct FailurePredicate {
  oracle : String
  fingerprint : Fingerprint
} derive(Eq, @debug.Debug)

///|
pub(all) enum PredicateStatus {
  Preserved
  NotPreserved
  Undetermined
  Inapplicable
} derive(Eq, @debug.Debug)

///|
pub extend CheckOutcome with Eq::{equal, not_equal}

///|
pub extend OracleResult with Eq::{equal, not_equal}

///|
pub extend Assessment with Eq::{equal, not_equal}

///|
pub extend FailurePredicate with Eq::{equal, not_equal}

///|
pub extend PredicateStatus with Eq::{equal, not_equal}

///|
pub extend CheckOutcome with @debug.Debug::{to_repr}

///|
pub extend OracleResult with @debug.Debug::{to_repr}

///|
pub extend Assessment with @debug.Debug::{to_repr}

///|
pub extend FailurePredicate with @debug.Debug::{to_repr}

///|
pub extend PredicateStatus with @debug.Debug::{to_repr}
