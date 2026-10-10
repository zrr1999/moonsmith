///|
pub(all) enum Phase {
  Build
  Execute
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) enum ProcessStatus {
  Exited(Int)
  TimedOut
  OutputLimit
  HostError(String)
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct Command {
  program : String
  args : Array[String]
  cwd : String
  timeout_ms : Int
  output_limit : Int
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct Output {
  status : ProcessStatus
  stdout : String
  stderr : String
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct Observation {
  configuration : String
  phase : Phase
  command : Command
  output : Output
  injected_stdout : String?
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) enum FailureKind {
  Exit(Int)
  Mismatch
  Timeout
  OutputExceeded
  Infrastructure
  MissingObservation
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct Fingerprint {
  configuration : String
  phase : Phase
  kind : FailureKind
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) enum Verdict {
  Match
  Finding(Fingerprint)
  Inconclusive(Fingerprint)
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct Case {
  format_version : Int
  generator : String
  seed : Int
  depth : Int
  source : String
  expected : String
  nodes : Int
  injected : Bool
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub(all) struct Attempt {
  purpose : String
  compiler : String
  source : String
  expected : String
  nodes : Int
  observations : Array[Observation]
  verdict : Verdict
} derive(Eq, @debug.Debug, ToJson, @json.FromJson)

///|
pub extend Phase with Eq::{equal, not_equal}

///|
pub extend Phase with ToJson::{to_json}

///|
pub extend Phase with @json.FromJson::{from_json}

///|
pub extend ProcessStatus with Eq::{equal, not_equal}

///|
pub extend ProcessStatus with ToJson::{to_json}

///|
pub extend ProcessStatus with @json.FromJson::{from_json}

///|
pub extend Command with Eq::{equal, not_equal}

///|
pub extend Command with ToJson::{to_json}

///|
pub extend Command with @json.FromJson::{from_json}

///|
pub extend Output with Eq::{equal, not_equal}

///|
pub extend Output with ToJson::{to_json}

///|
pub extend Output with @json.FromJson::{from_json}

///|
pub extend Observation with Eq::{equal, not_equal}

///|
pub extend Observation with ToJson::{to_json}

///|
pub extend Observation with @json.FromJson::{from_json}

///|
pub extend FailureKind with Eq::{equal, not_equal}

///|
pub extend FailureKind with ToJson::{to_json}

///|
pub extend FailureKind with @json.FromJson::{from_json}

///|
pub extend Fingerprint with Eq::{equal, not_equal}

///|
pub extend Fingerprint with ToJson::{to_json}

///|
pub extend Fingerprint with @json.FromJson::{from_json}

///|
pub extend Verdict with Eq::{equal, not_equal}

///|
pub extend Verdict with ToJson::{to_json}

///|
pub extend Verdict with @json.FromJson::{from_json}

///|
pub extend Case with Eq::{equal, not_equal}

///|
pub extend Case with ToJson::{to_json}

///|
pub extend Case with @json.FromJson::{from_json}

///|
pub extend Attempt with Eq::{equal, not_equal}

///|
pub extend Attempt with ToJson::{to_json}

///|
pub extend Attempt with @json.FromJson::{from_json}

///|
pub extend Phase with @debug.Debug::{to_repr}

///|
pub extend ProcessStatus with @debug.Debug::{to_repr}

///|
pub extend Command with @debug.Debug::{to_repr}

///|
pub extend Output with @debug.Debug::{to_repr}

///|
pub extend Observation with @debug.Debug::{to_repr}

///|
pub extend FailureKind with @debug.Debug::{to_repr}

///|
pub extend Fingerprint with @debug.Debug::{to_repr}

///|
pub extend Verdict with @debug.Debug::{to_repr}

///|
pub extend Case with @debug.Debug::{to_repr}

///|
pub extend Attempt with @debug.Debug::{to_repr}
