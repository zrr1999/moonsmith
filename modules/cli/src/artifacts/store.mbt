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
/// attempt.json is the completion marker; unfinished attempts retain their workspace.
pub async fn finish_attempt(
  directory : String,
  attempt : @contracts.Attempt,
  report : String,
) -> Unit {
  @host.write_new("\{directory}/report.md", report)
  @host.write_new("\{directory}/attempt.json", attempt.to_json().stringify())
}
