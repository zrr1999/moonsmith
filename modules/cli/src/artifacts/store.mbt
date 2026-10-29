///|
pub async fn create(base : String, case : @contracts.Case) -> String {
  @host.mkdir(base)
  let directory = @host.new_directory("\{base}/case-")
  @host.write_new("\{directory}/original.mbt", case.source)
  @host.mkdir("\{directory}/attempts")
  @host.write_new("\{directory}/case.json", case.to_json().stringify())
  @host.canonical(directory)
}

///|
pub async fn load(directory : String) -> @contracts.Case {
  let case : @contracts.Case = @json.from_json(
    @json.parse(@host.read_text("\{directory}/case.json")),
  )
  guard case.format_version == 1 else { fail("unsupported case format") }
  guard @host.read_text("\{directory}/original.mbt") == case.source else {
    fail("original source does not match case.json")
  }
  case
}

///|
pub async fn begin_attempt(directory : String) -> String {
  @host.new_directory("\{directory}/attempts/run-")
}

///|
priv struct RuntimeRecord {
  format_version : Int32
  probes : Array[@contracts.ProcessEvidence]
} derive(ToJson, @json.FromJson)

///|
pub async fn load_runtimes(
  directory : String,
) -> Array[@contracts.ProcessEvidence]? {
  let path = "\{directory}/runtimes.json"
  if !@host.exists(path) {
    return None
  }
  let record : RuntimeRecord = @json.from_json(
    @json.parse(@host.read_text(path)),
  )
  guard record.format_version == 1 else {
    fail("unsupported runtime record format at \{path}")
  }
  let programs : Array[String] = []
  for probe in record.probes {
    guard !programs.contains(probe.command.program) else {
      fail("duplicate runtime identity at \{path}")
    }
    programs.push(probe.command.program)
  }
  Some(record.probes)
}

///|
/// attempt.json is the completion marker; unfinished attempts retain their workspace.
pub async fn[T : ToJson] finish_attempt(
  directory : String,
  attempt : T,
  report : String,
  runtimes~ : Array[@contracts.ProcessEvidence] = [],
) -> Unit {
  if !runtimes.is_empty() {
    let record : RuntimeRecord = { format_version: 1, probes: runtimes, }
    @host.write_new(
      "\{directory}/runtimes.json",
      ToJson::to_json(record).stringify(),
    )
  }
  @host.write_new("\{directory}/report.md", report)
  @host.write_new("\{directory}/attempt.json", attempt.to_json().stringify())
}
