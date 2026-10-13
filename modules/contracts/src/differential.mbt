///|
pub(all) struct GenerationRecord {
  generator : String
  seed : Int
  max_nodes : Int
  max_depth : Int
  max_attempts : Int
  construction_attempts : Int
  nodes : Int
  depth : Int
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
/// Inputs are embedded in source; this format executes a closed program with empty stdin.
pub(all) struct DifferentialCase {
  format_version : Int
  generation : GenerationRecord
  source : String
  module_source : String
  package_source : String
  result_protocol : String
  configurations : Array[String]
  build_timeout_ms : Int
  run_timeout_ms : Int
  injected : Bool
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct ProcessEvidence {
  command : Command
  output : Output
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct DifferentialAttempt {
  format_version : Int
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
