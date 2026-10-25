///|
/// Components of the current MoonBit reduction cost; the adapter owns their ordering.
pub(all) struct ReductionCost {
  nodes : Int
  integer_magnitude : Int64
  source_bytes : Int
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
/// A reduction links immutable execution records; it does not replace the original case.
pub(all) struct DifferentialReduction {
  format_version : Int
  first_configuration : String
  second_configuration : String
  original_attempt : String
  cost_model : String
  original_cost : ReductionCost
  candidate_limit : Int
  candidates : Int
  accepted : Int
  elapsed_ms : Int64
  best_cost : ReductionCost
  best_attempt : String
  stop_reason : String
  confirmation_attempt : String?
  confirmation : PredicateStatus?
  error : String?
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct ReductionTrial {
  attempt : String
  cost : ReductionCost
  status : PredicateStatus
  accepted : Bool
} derive(Eq, @debug.Debug)

///|
/// Runtime search results; local reports do not establish an archive format.
pub(all) struct ReductionProgress {
  original_attempt : String
  cost_model : String
  original_cost : ReductionCost
  candidate_limit : Int
  candidates : Int
  accepted : Int
  elapsed_ms : Int64
  best_cost : ReductionCost
  best_attempt : String
  stop_reason : String
  confirmation_attempt : String?
  confirmation : PredicateStatus?
  error : String?
  trials : Array[ReductionTrial]
} derive(Eq, @debug.Debug)

///|
pub(all) struct BuildFailureReduction {
  predicate : FailurePredicate
  progress : ReductionProgress
} derive(Eq, @debug.Debug)

///|
pub extend ReductionTrial with Eq::{equal, not_equal}

///|
pub extend ReductionTrial with @debug.Debug::{to_repr}

///|
pub extend ReductionProgress with Eq::{equal, not_equal}

///|
pub extend ReductionProgress with @debug.Debug::{to_repr}

///|
pub extend BuildFailureReduction with Eq::{equal, not_equal}

///|
pub extend BuildFailureReduction with @debug.Debug::{to_repr}

///|
pub extend ReductionCost with Eq::{equal, not_equal}

///|
pub extend ReductionCost with @debug.Debug::{to_repr}

///|
pub extend ReductionCost with ToJson::{to_json}

///|
pub extend ReductionCost with @json.FromJson::{from_json}

///|
pub extend DifferentialReduction with Eq::{equal, not_equal}

///|
pub extend DifferentialReduction with @debug.Debug::{to_repr}

///|
pub extend DifferentialReduction with ToJson::{to_json}

///|
pub extend DifferentialReduction with @json.FromJson::{from_json}
