///|
priv struct CorpusCase {
  path : String
  runner : String
}

///|
fn corpus_string(
  fields : Map[String, @toml.TomlValue],
  key : String,
) -> String raise {
  guard fields.get(key) is Some(TomlString(value)) && !value.is_empty() else {
    fail("missing nonempty corpus string: \{key}")
  }
  value
}

///|
fn corpus_int(fields : Map[String, @toml.TomlValue], key : String) -> Int raise {
  guard fields.get(key) is Some(TomlInteger(value)) &&
    value >= -2147483648L &&
    value <= 2147483647L else {
    fail("corpus field must be an Int: \{key}")
  }
  value.to_int()
}

///|
fn validate_case_path(path : String) -> Unit raise {
  guard path.has_prefix("cases/") &&
    !path.contains("..") &&
    !path.contains("\\") &&
    !path.has_suffix("/") else {
    fail("case path must stay under cases/: \{path}")
  }
}

///|
fn corpus_spec(text : String) -> (String, Array[CorpusCase]) raise {
  guard @toml.parse(text) is TomlTable(fields) else {
    fail("corpus must be a table")
  }
  for key, _ in fields {
    guard ["id", "claim", "cases"].contains(key) else {
      fail("unknown corpus field: \{key}")
    }
  }
  let id = corpus_string(fields, "id")
  ignore(corpus_string(fields, "claim"))
  guard fields.get("cases") is Some(TomlArray(values)) && !values.is_empty() else {
    fail("corpus must name at least one case")
  }
  let entries : Array[CorpusCase] = []
  for value in values {
    guard value is TomlTable(entry) else { fail("corpus case must be a table") }
    for key, _ in entry {
      guard ["path", "runner", "evidence"].contains(key) else {
        fail("unknown corpus case field: \{key}")
      }
    }
    let path = corpus_string(entry, "path")
    validate_case_path(path)
    guard !entries.any(previous => previous.path == path) else {
      fail("duplicate case in corpus: \{path}")
    }
    let runner = corpus_string(entry, "runner")
    guard [
      "pending", "reference-output", "generation-properties", "differential-observations",
    ].contains(runner) else {
      fail("unknown corpus runner: \{runner}")
    }
    let evidence = corpus_string(entry, "evidence")
    guard ["real-toolchain", "controlled", "model"].contains(evidence) else {
      fail("unknown evidence kind: \{evidence}")
    }
    if runner != "pending" {
      guard evidence ==
        (if runner == "reference-output" { "real-toolchain" } else { "model" }) else {
        fail("runner and evidence kind disagree")
      }
    }
    entries.push({ path, runner, })
  }
  (id, entries)
}

///|
async fn load_corpus(root : String, name : String) -> Array[CorpusCase] {
  let (id, entries) = corpus_spec(
    @host.read_text("\{root}/corpora/\{name}/corpus.toml"),
  )
  guard id == name else { fail("corpus id does not match its directory") }
  entries
}

///|
async test "eight corpus definitions resolve case inputs without claiming pending execution" {
  let root = regression_root()
  let names = @host.list_directory("\{root}/corpora").filter(name => {
    name != "README.md"
  })
  @debug.assert_eq(names.length(), 8)
  for name in names {
    for entry in load_corpus(root, name) {
      guard @toml.parse(@host.read_text("\{root}/\{entry.path}/case.toml"))
        is TomlTable(fields) else {
        fail("case metadata must be a table: \{entry.path}")
      }
      for key in ["input", "observations"] {
        if fields.get(key) is Some(_) {
          let file = corpus_string(fields, key)
          guard !file.contains("/") && !file.contains("\\") && file != ".." else {
            fail("case input must be a file in its case directory")
          }
          ignore(@host.read_text("\{root}/\{entry.path}/\{file}"))
        }
      }
      if entry.runner == "reference-output" {
        ignore(@host.read_text("\{root}/\{entry.path}/main.mbt"))
        ignore(
          regression_spec(@host.read_text("\{root}/\{entry.path}/case.toml")),
        )
      }
      for key in ["target_case", "source_case"] {
        if fields.get(key) is Some(_) {
          let target = corpus_string(fields, key)
          validate_case_path(target)
          ignore(@host.read_text("\{root}/\{target}/case.toml"))
        }
      }
    }
  }
}

///|
test "corpus definitions reject escaping paths duplicates and false evidence labels" {
  let valid =
    #|id = "oracles"
    #|claim = "classification of controlled observations"
    #|[[cases]]
    #|path = "cases/engine/missing-observation"
    #|runner = "differential-observations"
    #|evidence = "model"
  let (_, entries) = corpus_spec(valid)
  @debug.assert_eq(entries.length(), 1)
  for
    invalid in [
      valid.replace(
        old="cases/engine/missing-observation",
        new="cases/../../outside",
      ),
      valid.replace(old="differential-observations", new="unknown"),
      valid.replace(
        old="evidence = \"model\"",
        new="evidence = \"real-toolchain\"",
      ),
      valid.replace(old="claim =", new="claims ="),
      valid +
      "\n[[cases]]\npath = \"cases/engine/missing-observation\"\nrunner = \"pending\"\nevidence = \"model\"",
    ] {
    let rejected = try {
      ignore(corpus_spec(invalid))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=invalid)
  }
}

///|
async test "generation corpus checks deterministic output and declared construction budgets" {
  let root = regression_root()
  for entry in load_corpus(root, "generation") {
    guard entry.runner == "generation-properties" else {
      fail("generation case is not connected to this runner")
    }
    guard @toml.parse(@host.read_text("\{root}/\{entry.path}/case.toml"))
      is TomlTable(fields) else {
      fail("generation case must be a table")
    }
    @debug.assert_eq(corpus_string(fields, "generator"), "template-rules-v1")
    @debug.assert_eq(corpus_string(fields, "kind"), "generation")
    @debug.assert_eq(
      corpus_string(fields, "expected"),
      "valid-deterministic-and-within-budgets",
    )
    let first = corpus_int(fields, "seed_start")
    let count = corpus_int(fields, "seed_count")
    guard count > 0 && first.to_int64() + count.to_int64() <= 2147483648L else {
      fail("generation seed range must be nonempty and fit Int")
    }
    let limits : @moonbit.GenerationLimits = {
      max_nodes: corpus_int(fields, "max_nodes"),
      max_depth: corpus_int(fields, "max_depth"),
      max_attempts: corpus_int(fields, "max_attempts"),
    }
    limits.validate()
    for offset in 0..<count {
      let seed = first + offset
      let generated = @moonbit.synthesize(seed, limits~)
      let again = @moonbit.synthesize(seed, limits~)
      @debug.assert_eq(generated.program.emit(), again.program.emit())
      assert_true(generated.program.size() <= limits.max_nodes)
      assert_true(generated.program.depth() <= limits.max_depth)
      assert_true(generated.construction_attempts <= limits.max_attempts)
    }
  }
}

///|
async test "oracle corpus classifies model observations using the declared output protocol" {
  let root = regression_root()
  for entry in load_corpus(root, "oracles") {
    if entry.runner != "differential-observations" {
      continue
    }
    guard @toml.parse(@host.read_text("\{root}/\{entry.path}/case.toml"))
      is TomlTable(fields) else {
      fail("oracle case must be a table")
    }
    guard fields.get("configurations") is Some(TomlArray(values)) else {
      fail("oracle configurations must be an array")
    }
    let configurations = values.map(value => {
      guard value is TomlString(name) else {
        fail("configuration must be a string")
      }
      name
    })
    guard @moonbit.parse_result_protocol(
        corpus_string(fields, "result_protocol"),
      )
      is Some(ty) else {
      fail("unknown oracle output protocol")
    }
    let observations : Array[@contracts.Observation] = @json.from_json(
      @json.parse(
        @host.read_text(
          "\{root}/\{entry.path}/\{corpus_string(fields, "observations")}",
        ),
      ),
    )
    let result = @engine.compare(configurations, observations, normalize=value => {
      ty.normalize_output(value)
    })
    let label = match result {
      Consistent => "consistent"
      Difference(_, _) => "difference"
      Incomplete => "incomplete"
    }
    @debug.assert_eq(
      label,
      corpus_string(fields, "expected_comparison"),
      msg=entry.path,
    )
  }
}
