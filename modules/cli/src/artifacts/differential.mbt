///|
pub async fn create_differential(
  base : String,
  case : @contracts.DifferentialCase,
) -> String {
  @host.mkdir(base)
  let directory = @host.new_directory("\{base}/case-")
  @host.write_new("\{directory}/original.mbt", case.source)
  @host.write_new("\{directory}/moon.mod", case.module_source)
  @host.write_new("\{directory}/moon.pkg", case.package_source)
  @host.mkdir("\{directory}/attempts")
  @host.write_new("\{directory}/case.json", case.to_json().stringify())
  directory
}

///|
pub async fn case_version(directory : String) -> Int {
  let json = @json.parse(@host.read_text("\{directory}/case.json"))
  guard json is Object(fields) && fields.get("format_version") is Some(version) else {
    fail("missing case format version")
  }
  @json.from_json(version)
}

///|
pub async fn load_differential(
  directory : String,
) -> @contracts.DifferentialCase {
  let case : @contracts.DifferentialCase = @json.from_json(
    @json.parse(@host.read_text("\{directory}/case.json")),
  )
  guard case.format_version == 2 else {
    fail("unsupported differential case format")
  }
  for
    (name, expected) in [
      ("original.mbt", case.source),
      ("moon.mod", case.module_source),
      ("moon.pkg", case.package_source),
    ] {
    guard @host.read_text("\{directory}/\{name}") == expected else {
      fail("\{name} does not match case.json")
    }
  }
  case
}

///|
pub async fn finish_differential(
  directory : String,
  attempt : @contracts.DifferentialAttempt,
  report : String,
) -> Unit {
  @host.write_new("\{directory}/report.md", report)
  @host.write_new("\{directory}/attempt.json", attempt.to_json().stringify())
}
