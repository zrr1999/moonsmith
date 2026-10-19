///|
pub(all) struct TaskObservation {
  case_directory : String
  attempt_directory : String
  comparison : Comparison
  error : String?
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) enum TaskOutcome {
  Observed(TaskObservation)
  Failed(String)
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct TaskSample {
  seed : Int
  outcome : TaskOutcome
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct TaskSummary {
  format_version : Int
  name : String
  sample_count : Int
  attempted : Int
  consistent : Int
  differences : Int
  incomplete : Int
  operation_errors : Int
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub extend TaskObservation with Eq::{equal, not_equal}

///|
pub extend TaskObservation with @debug.Debug::{to_repr}

///|
pub extend TaskObservation with ToJson::{to_json}

///|
pub extend TaskObservation with @json.FromJson::{from_json}

///|
pub extend TaskOutcome with Eq::{equal, not_equal}

///|
pub extend TaskOutcome with @debug.Debug::{to_repr}

///|
pub extend TaskOutcome with ToJson::{to_json}

///|
pub extend TaskOutcome with @json.FromJson::{from_json}

///|
pub extend TaskSample with Eq::{equal, not_equal}

///|
pub extend TaskSample with @debug.Debug::{to_repr}

///|
pub extend TaskSample with ToJson::{to_json}

///|
pub extend TaskSample with @json.FromJson::{from_json}

///|
pub extend TaskSummary with Eq::{equal, not_equal}

///|
pub extend TaskSummary with @debug.Debug::{to_repr}

///|
pub extend TaskSummary with ToJson::{to_json}

///|
pub extend TaskSummary with @json.FromJson::{from_json}
