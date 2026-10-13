///|
/// A difference identifies two disagreeing configurations, not a faulty compiler.
pub(all) enum Comparison {
  Consistent
  Difference(String, String)
  Incomplete
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub extend Comparison with Eq::{equal, not_equal}

///|
pub extend Comparison with @debug.Debug::{to_repr}

///|
pub extend Comparison with ToJson::{to_json}

///|
pub extend Comparison with @json.FromJson::{from_json}
