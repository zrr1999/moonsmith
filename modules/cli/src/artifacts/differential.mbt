///|
pub async fn create_differential(
  base : String,
  case : @contracts.DifferentialCase,
) -> String {
  @host.mkdir(base)
  let directory = @host.new_directory("\{base}/case-")
  try {
    @host.write_new("\{directory}/original.mbt", case.source)
    @host.write_new("\{directory}/moon.mod", case.module_source)
    @host.write_new("\{directory}/moon.pkg", case.package_source)
    @host.mkdir("\{directory}/attempts")
    @host.write_new("\{directory}/case.json", case.to_json().stringify())
  } catch {
    error => fail("case storage failed at \{directory}: \{error}")
  }
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

///|
pub async fn original_environment(
  directory : String,
) -> (@contracts.ProcessEvidence?, Array[@contracts.ProcessEvidence]?) {
  let mut original : @contracts.ProcessEvidence? = None
  let mut runtimes : Array[@contracts.ProcessEvidence]? = None
  for name in @host.list_directory("\{directory}/attempts") {
    let path = "\{directory}/attempts/\{name}/attempt.json"
    if !@host.exists(path) {
      continue
    }
    let attempt : @contracts.DifferentialAttempt = @json.from_json(
      @json.parse(@host.read_text(path)),
    )
    guard attempt.format_version == 2 else {
      fail("unsupported attempt format at \{path}")
    }
    if attempt.purpose == "original" {
      guard original is None else {
        fail("multiple original execution records")
      }
      original = Some(attempt.toolchain)
      runtimes = load_runtimes("\{directory}/attempts/\{name}")
    }
  }
  (original, runtimes)
}

///|
pub async fn load_differential_attempt(
  directory : String,
  case : @contracts.DifferentialCase,
) -> @contracts.DifferentialAttempt {
  let attempt : @contracts.DifferentialAttempt = @json.from_json(
    @json.parse(@host.read_text("\{directory}/attempt.json")),
  )
  guard attempt.format_version == 2 else {
    fail("unsupported differential attempt format")
  }
  guard attempt.configurations == case.configurations &&
    attempt.result_protocol == case.result_protocol &&
    attempt.injected == case.injected else {
    fail("saved attempt does not match its case")
  }
  for
    (name, expected) in [
      ("main.mbt", attempt.source),
      ("moon.mod", case.module_source),
      ("moon.pkg", case.package_source),
    ] {
    guard @host.read_text("\{directory}/\{name}") == expected else {
      fail("\{name} does not match saved execution material")
    }
  }
  attempt
}

///|
pub async fn save_reduction(
  directory : String,
  record : @contracts.DifferentialReduction,
) -> Unit {
  @host.write_new("\{directory}/reduction.json", record.to_json().stringify())
}

///|
pub async fn save_build_reduction(directory : String, report : String) -> Unit {
  @host.write_new("\{directory}/build-reduction.md", report)
}
