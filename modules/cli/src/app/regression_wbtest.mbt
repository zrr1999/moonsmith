///|
fn regression_spec(text : String) -> (Array[String], String) raise {
  guard @toml.parse(text) is TomlTable(fields) else {
    fail("regression metadata must be a table")
  }
  for key, _ in fields {
    guard [
      "kind", "source", "reported_compiler", "configurations", "expected_stdout",
    ].contains(key) else {
      fail("unknown regression field: \{key}")
    }
  }
  guard case_string(fields, "kind") == "reference-output" else {
    fail("reference checks require a reference-output case")
  }
  guard fields.get("source") is Some(TomlString(source)) && !source.is_empty() else {
    fail("regression source must identify the upstream issue")
  }
  match fields.get("reported_compiler") {
    None => ()
    Some(TomlString(version)) if !version.is_empty() => ()
    _ => fail("reported_compiler must be a nonempty string when present")
  }
  guard fields.get("expected_stdout") is Some(TomlString(expected)) else {
    fail("expected_stdout must be a string, including for empty output")
  }
  guard fields.get("configurations") is Some(TomlArray(values)) else {
    fail("configurations must be an array")
  }
  let configurations = values.map(value => {
    guard value is TomlString(configuration) else {
      fail("configuration must be a string")
    }
    configuration
  })
  @moon.validate_plan(configurations)
  (configurations, expected)
}

///|
priv struct RegressionAttempt {
  case_id : String
  metadata : String
  toolchain : @contracts.ProcessEvidence
  platform : @contracts.ProcessEvidence
  observations : Array[@contracts.Observation]
  verdict : @contracts.Verdict
} derive(ToJson)

///|
async test "historical MoonBit regressions match explicit expectations on the real toolchain" {
  let root = case_root()
  let cases = fixed_cases_for(root, "reference-output")
  @host.mkdir("\{root}/runs")
  let run = @host.new_directory("\{root}/runs/historical-")
  let toolchain = @moon.identify()
  let platform = @host.platform()
  let failures : Array[String] = []
  for entry in cases {
    let id = entry.path
    let input = "\{root}/\{entry.path}"
    let metadata = entry.metadata
    let source = entry.source
    let (planned, expected) = regression_spec(metadata)
    let directory = "\{run}/\{id}"
    @host.mkdir(directory)
    @host.write_new("\{directory}/case.toml", metadata)
    @moon.prepare(directory, source)
    let observations = @moon.observe(directory, planned~)
    let verdict = @engine.judge(expected, planned, observations)
    let attempt : RegressionAttempt = {
      case_id: id,
      metadata,
      toolchain,
      platform,
      observations,
      verdict,
    }
    @artifacts.finish_attempt(
      directory,
      attempt,
      "# Historical regression: \{id}\n\nVerdict: \{@debug.to_string(verdict)}\n",
    )
    if verdict != @contracts.Match {
      failures.push(
        "\{id}: evidence saved at \{directory}\n\{ToJson::to_json(attempt).stringify()}",
      )
    }
    @debug.assert_eq(@host.read_text("\{input}/main.mbt"), source)
    @debug.assert_eq(@host.read_text("\{input}/case.toml"), metadata)
  }
  @debug.assert_eq(failures.length(), 0, msg=@debug.to_string(failures))
}

///|
test "regression metadata rejects missing or ambiguous expectations before execution" {
  let valid =
    #|kind = "reference-output"
    #|source = "https://github.com/moonbitlang/moonbit-docs/issues/1266"
    #|configurations = ["native-debug", "native-release"]
    #|expected_stdout = ""
  let (configurations, expected) = regression_spec(valid)
  @debug.assert_eq(configurations, ["native-debug", "native-release"])
  @debug.assert_eq(expected, "")
  for
    invalid in [
      valid.replace(old="reference-output", new="differential"),
      valid.replace(old="expected_stdout", new="expected_stderr"),
      valid.replace(old="expected_stdout = \"\"", new="expected_stdout = 0"),
      valid.replace(old="native-release", new="unsupported"),
      valid.replace(old="native-release", new="native-debug"),
      valid + "\nreported_compiler = false",
      "source = \"only provenance\"",
    ] {
    let rejected = try {
      ignore(regression_spec(invalid))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=invalid)
  }
}
