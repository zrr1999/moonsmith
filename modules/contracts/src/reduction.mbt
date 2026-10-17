///|
/// A reduction links immutable execution records; it does not replace the original case.
pub(all) struct DifferentialReduction {
  format_version : Int
  first_configuration : String
  second_configuration : String
  original_attempt : String
  original_nodes : Int
  candidate_limit : Int
  candidates : Int
  accepted : Int
  best_nodes : Int
  best_attempt : String
  stop_reason : String
  confirmation_attempt : String?
  confirmation : PredicateStatus?
  error : String?
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub extend DifferentialReduction with Eq::{equal, not_equal}

///|
pub extend DifferentialReduction with @debug.Debug::{to_repr}

///|
pub extend DifferentialReduction with ToJson::{to_json}

///|
pub extend DifferentialReduction with @json.FromJson::{from_json}
