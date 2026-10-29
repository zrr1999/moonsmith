///|
pub(all) struct GenerationRecord {
  generator : String
  seed : Int32
  max_nodes : Int32
  max_depth : Int32
  max_attempts : Int32
  construction_attempts : Int32
  nodes : Int32
  depth : Int32
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
/// Inputs are embedded in source; this format executes a closed program with empty stdin.
pub(all) struct DifferentialCase {
  format_version : Int32
  generation : GenerationRecord
  source : String
  module_source : String
  package_source : String
  result_protocol : String
  configurations : Array[String]
  build_timeout_ms : Int32
  run_timeout_ms : Int32
  injected : Bool
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct ProcessEvidence {
  command : Command
  output : Output
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct DifferentialAttempt {
  format_version : Int32
  purpose : String
  source : String
  configurations : Array[String]
  result_protocol : String
  toolchain : ProcessEvidence
  platform : ProcessEvidence
  injected : Bool
  observations : Array[Observation]
  comparison : Comparison
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub extend GenerationRecord with Eq::{equal, not_equal}

///|
pub extend GenerationRecord with @debug.Debug::{to_repr}

///|
pub extend GenerationRecord with ToJson::{to_json}

///|
pub extend GenerationRecord with @json.FromJson::{from_json}

///|
pub extend DifferentialCase with Eq::{equal, not_equal}

///|
pub extend DifferentialCase with @debug.Debug::{to_repr}

///|
pub extend DifferentialCase with ToJson::{to_json}

///|
pub extend DifferentialCase with @json.FromJson::{from_json}

///|
pub extend ProcessEvidence with Eq::{equal, not_equal}

///|
pub extend ProcessEvidence with @debug.Debug::{to_repr}

///|
pub extend ProcessEvidence with ToJson::{to_json}

///|
pub extend ProcessEvidence with @json.FromJson::{from_json}

///|
pub extend DifferentialAttempt with Eq::{equal, not_equal}

///|
pub extend DifferentialAttempt with @debug.Debug::{to_repr}

///|
pub extend DifferentialAttempt with ToJson::{to_json}

///|
pub extend DifferentialAttempt with @json.FromJson::{from_json}
