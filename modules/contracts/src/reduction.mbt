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
  best_cost : ReductionCost
  best_attempt : String
  stop_reason : String
  confirmation_attempt : String?
  confirmation : PredicateStatus?
  error : String?
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

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
