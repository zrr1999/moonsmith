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
  format_version : Int32
  seed : Int32
  generation : GenerationRecord?
  baseline_build : Bool?
  comparable_results : Int32
  planned_results : Int32
  elapsed_ms : Int64
  outcome : TaskOutcome
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct TaskSummary {
  format_version : Int32
  name : String
  sample_count : Int32
  attempted : Int32
  consistent : Int32
  differences : Int32
  incomplete : Int32
  operation_errors : Int32
  generated_valid : Int32
  baseline_configuration : String?
  baseline_attempted : Int32
  baseline_accepted : Int32
  comparisons_complete : Int32
  elapsed_ms : Int64
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
