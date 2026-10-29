///|
pub(all) struct GroupMember {
  id : String
  transformation : String
  source : String
  attempt : String
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
/// All associations are relative to the group's directory inside its owning case.
pub(all) struct EquivalentGroupRecord {
  format_version : Int32
  purpose : String
  case_source : String
  configurations : Array[String]
  result_protocol : String
  injected : Bool
  members : Array[GroupMember]
  comparison : Comparison
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct EquivalentGroupReduction {
  format_version : Int32
  first_configuration : String
  second_configuration : String
  relations : Array[(String, String)]
  progress : ReductionProgress
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub extend GroupMember with Eq::{equal, not_equal}

///|
pub extend GroupMember with @debug.Debug::{to_repr}

///|
pub extend GroupMember with ToJson::{to_json}

///|
pub extend GroupMember with @json.FromJson::{from_json}

///|
pub extend EquivalentGroupRecord with Eq::{equal, not_equal}

///|
pub extend EquivalentGroupRecord with @debug.Debug::{to_repr}

///|
pub extend EquivalentGroupRecord with ToJson::{to_json}

///|
pub extend EquivalentGroupRecord with @json.FromJson::{from_json}

///|
pub extend EquivalentGroupReduction with Eq::{equal, not_equal}

///|
pub extend EquivalentGroupReduction with @debug.Debug::{to_repr}

///|
pub extend EquivalentGroupReduction with ToJson::{to_json}

///|
pub extend EquivalentGroupReduction with @json.FromJson::{from_json}
