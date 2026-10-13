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
