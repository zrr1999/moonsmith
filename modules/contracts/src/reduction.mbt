///|
/// Components of the current MoonBit reduction cost; the adapter owns their ordering.
pub(all) struct ReductionCost {
  nodes : Int32
  integer_magnitude : Int64
  source_bytes : Int32
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
/// A reduction links immutable execution records; it does not replace the original case.
pub(all) struct DifferentialReduction {
  format_version : Int32
  first_configuration : String
  second_configuration : String
  original_attempt : String
  cost_model : String
  original_cost : ReductionCost
  candidate_limit : Int32
  candidates : Int32
  accepted : Int32
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
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
/// Search results linking the original material, candidates, and independent confirmation.
pub(all) struct ReductionProgress {
  original_attempt : String
  cost_model : String
  original_cost : ReductionCost
  candidate_limit : Int32
  candidates : Int32
  accepted : Int32
  elapsed_ms : Int64
  best_cost : ReductionCost
  best_attempt : String
  stop_reason : String
  confirmation_attempt : String?
  confirmation : PredicateStatus?
  error : String?
  trials : Array[ReductionTrial]
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

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
pub extend ReductionProgress with ToJson::{to_json}

///|
pub extend ReductionProgress with @json.FromJson::{from_json}

///|
pub extend ReductionTrial with ToJson::{to_json}

///|
pub extend ReductionTrial with @json.FromJson::{from_json}

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
