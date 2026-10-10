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
  !self.results.is_empty() &&
  !self.results.any(r => {
    r.outcome is Insufficient(_) ||
    self.results
    .filter(other => {
      other.oracle == r.oracle &&
      other.configuration == r.configuration &&
      other.phase == r.phase
    })
    .length() !=
    1
  })
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
