///|
priv struct FixedCase {
  path : String
  kind : String
  metadata : String
  source : String
}

///|
async fn case_root() -> String {
  let mut directory = @host.canonical(@host.current_directory())
  while !@host.exists("\{directory}/moon.work") {
    let parent = @host.canonical("\{directory}/..")
    guard parent != directory else {
      fail("fixed case tests require the MoonSmith checkout")
    }
    directory = parent
  }
  directory
}

///|
fn case_string(
  fields : Map[String, @toml.TomlValue],
  key : String,
) -> String raise {
  guard fields.get(key) is Some(TomlString(value)) && !value.is_empty() else {
    fail("missing nonempty case string: \{key}")
  }
  value
}

///|
fn case_int(fields : Map[String, @toml.TomlValue], key : String) -> Int32 raise {
  guard fields.get(key) is Some(TomlInteger(value)) &&
    value >= -2147483648L &&
    value <= 2147483647L else {
    fail("case field must be an Int: \{key}")
  }
  value.to_int()
}

///|
async fn fixed_cases(root : String) -> Array[FixedCase] {
  let cases : Array[FixedCase] = []
  for name in @host.list_directory("\{root}/cases/moonbit") {
    if name.has_prefix(".") {
      continue
    }
    let path = "cases/moonbit/\{name}"
    let metadata = @host.read_text("\{root}/\{path}/case.toml")
    guard @toml.parse(metadata) is TomlTable(fields) else {
      fail("case metadata must be a table: \{path}")
    }
    let kind = case_string(fields, "kind")
    guard ["reference-output", "differential", "reduction"].contains(kind) else {
      fail("unknown fixed case kind: \{kind} at \{path}")
    }
    let source = @host.read_text("\{root}/\{path}/main.mbt")
    guard !source.is_empty() else {
      fail("case source must not be empty: \{path}")
    }
    cases.push({ path, kind, metadata, source, })
  }
  guard !cases.is_empty() else { fail("no fixed MoonBit cases") }
  cases
}

///|
async fn fixed_cases_for(root : String, kind : String) -> Array[FixedCase] {
  let cases = fixed_cases(root).filter(entry => entry.kind == kind)
  guard !cases.is_empty() else { fail("no fixed cases for: \{kind}") }
  cases
}

///|
async test "fixed cases are discovered directly and remain selected after renaming" {
  @host.mkdir("runs")
  let root = @host.new_directory("runs/case-discovery-")
  defer @host.remove_tree(root)
  @host.mkdir("\{root}/cases/moonbit")
  @host.write_new("\{root}/cases/moonbit/.DS_Store", "local metadata")
  let empty_rejected = try {
    ignore(fixed_cases(root))
    false
  } catch {
    _ => true
  }
  assert_true(empty_rejected)
  let metadata =
    #|kind = "reference-output"
    #|source = "https://example.com/issue"
    #|configurations = ["native-release", "native-debug"]
    #|expected_stdout = "0\n"
  let source = "fn main { println(0) }\n"
  for name in ["zeta", "alpha"] {
    let directory = "\{root}/cases/moonbit/\{name}"
    @host.mkdir(directory)
    @host.write_new("\{directory}/case.toml", metadata)
    @host.write_new("\{directory}/main.mbt", source)
    let selected = fixed_cases_for(root, "reference-output")
    assert_true(selected.any(entry => entry.path == "cases/moonbit/\{name}"))
  }
  @debug.assert_eq(
    fixed_cases_for(root, "reference-output").map(entry => entry.path),
    ["cases/moonbit/zeta", "cases/moonbit/alpha"],
  )
  @host.mkdir("\{root}/cases/moonbit/beta")
  @host.write_new("\{root}/cases/moonbit/beta/case.toml", metadata)
  @host.write_new("\{root}/cases/moonbit/beta/main.mbt", source)
  @host.remove_tree("\{root}/cases/moonbit/zeta")
  let selected = fixed_cases_for(root, "reference-output")
  @debug.assert_eq(selected.map(entry => entry.path), [
    "cases/moonbit/beta", "cases/moonbit/alpha",
  ])
  for entry in selected {
    @debug.assert_eq(entry.metadata, metadata)
    @debug.assert_eq(entry.source, source)
    @debug.assert_eq(regression_spec(entry.metadata).0, [
      "native-release", "native-debug",
    ])
  }
  @host.mkdir("\{root}/cases/moonbit/candidate")
  @host.write_new(
    "\{root}/cases/moonbit/candidate/case.toml",
    "kind = \"differential\"",
  )
  @host.write_new(
    "\{root}/cases/moonbit/candidate/main.mbt",
    "candidate source",
  )
  @debug.assert_eq(
    fixed_cases_for(root, "reference-output").map(entry => entry.path),
    selected.map(entry => entry.path),
  )
  @debug.assert_eq(
    fixed_cases_for(root, "differential").map(entry => entry.path),
    ["cases/moonbit/candidate"],
  )
  let missing_kind_rejected = try {
    ignore(fixed_cases_for(root, "reduction"))
    false
  } catch {
    _ => true
  }
  assert_true(missing_kind_rejected)
}

///|
async test "invalid metadata and missing inputs cannot silently disappear from case selection" {
  @host.mkdir("runs")
  let root = @host.new_directory("runs/invalid-case-input-")
  defer @host.remove_tree(root)
  let directory = "\{root}/cases/moonbit/example"
  @host.mkdir(directory)
  @host.write_new("\{directory}/main.mbt", "fn main { println(0) }\n")
  for metadata in ["", "kind = [", "kind = false", "kind = \"unknown\""] {
    @fs.write_file("\{directory}/case.toml", metadata)
    let rejected = try {
      ignore(fixed_cases(root))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=metadata)
  }
  @host.remove_tree(directory)
  @host.mkdir(directory)
  @fs.write_file("\{directory}/case.toml", "kind = \"reference-output\"")
  let missing_source_rejected = try {
    ignore(fixed_cases(root))
    false
  } catch {
    _ => true
  }
  assert_true(missing_source_rejected)
  @host.write_new("\{directory}/main.mbt", "")
  let empty_source_rejected = try {
    ignore(fixed_cases(root))
    false
  } catch {
    _ => true
  }
  assert_true(empty_source_rejected)
}
