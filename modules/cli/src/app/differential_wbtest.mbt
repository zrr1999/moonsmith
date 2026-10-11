///|
fn saved_fixture(
  source : String,
  protocol? : String = "moonbit-int32-line-v1",
  injected? : Bool = false,
) -> @contracts.DifferentialCase {
  {
    format_version: 2,
    // Replay must not require this retired generator or regenerate from these parameters.
    generation: {
      generator: "retired-test-generator",
      seed: 42,
      max_nodes: 16,
      max_depth: 3,
      max_attempts: 32,
      construction_attempts: 2,
      nodes: 1,
      depth: 0,
    },
    source,
    module_source: @moon.module_source() + "\n// saved module settings\n",
    package_source: @moon.package_source() + "\n// saved package settings\n",
    result_protocol: protocol,
    configurations: @moon.configurations(),
    build_timeout_ms: 30000,
    run_timeout_ms: 2000,
    injected,
  }
}

///|
async test "generated differential cases execute without a reference and replay appends evidence" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/differential-")
  defer @host.remove_tree(base)
  for seed in [7, -2147483648] {
    let limits : @moonbit.GenerationLimits = if seed == 7 {
      @moonbit.GenerationLimits::default()
    } else {
      { max_nodes: 40, max_depth: 4, max_attempts: 100, }
    }
    let run = run_differential(
      seed,
      base~,
      limits~,
      build_timeout_ms=45000,
      run_timeout_ms=5000,
    )
    @debug.assert_eq(
      run.attempt.comparison,
      @contracts.Consistent,
      msg=@debug.to_string(run.attempt),
    )
    @debug.assert_eq(run.attempt.observations.length(), 6)
    @debug.assert_eq(run.attempt.toolchain.output.status, @contracts.Exited(0))
    @debug.assert_eq(run.attempt.platform.output.status, @contracts.Exited(0))
    @debug.assert_eq(run.case.generation.seed, seed)
    @debug.assert_eq(run.case.generation.max_nodes, limits.max_nodes)
    @debug.assert_eq(run.case.generation.max_depth, limits.max_depth)
    @debug.assert_eq(run.case.generation.max_attempts, limits.max_attempts)
    assert_true(run.case.generation.nodes <= limits.max_nodes)
    assert_true(run.case.generation.depth <= limits.max_depth)
    assert_true(
      run.case.generation.construction_attempts <= limits.max_attempts,
    )
    @debug.assert_eq(@artifacts.load_differential(run.directory), run.case)
    @debug.assert_eq(@artifacts.case_version(run.directory), 2)
    for o in run.attempt.observations {
      @debug.assert_eq(o.output.status, @contracts.Exited(0))
      @debug.assert_eq(
        o.command.timeout_ms,
        if o.phase == Build {
          45000
        } else {
          5000
        },
      )
      assert_true(o.injected_stdout is None)
    }
    let before = Map([])
    for filename in ["case.json", "original.mbt", "moon.mod", "moon.pkg"] {
      before[filename] = @host.read_text("\{run.directory}/\{filename}")
    }
    let attempts = "\{run.directory}/attempts"
    for name in @fs.readdir(attempts) {
      for filename in ["attempt.json", "report.md"] {
        before["attempts/\{name}/\{filename}"] = @host.read_text(
          "\{attempts}/\{name}/\{filename}",
        )
      }
    }
    let replayed = replay_differential(run.directory)
    @debug.assert_eq(replayed.purpose, "replay")
    @debug.assert_eq(replayed.comparison, @contracts.Consistent)
    @debug.assert_eq(replayed.source, run.case.source)
    @debug.assert_eq(@fs.readdir(attempts).length(), 2)
    for name, content in before {
      @debug.assert_eq(@host.read_text("\{run.directory}/\{name}"), content)
    }
  }
}

///|
async test "replay uses saved source and project files even without a matching generator" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/saved-materials-")
  defer @host.remove_tree(base)
  let source = "fn main { println(2147483647 + 1) }\n"
  let case = saved_fixture(source)
  let directory = @artifacts.create_differential(base, case)
  let replayed = replay_differential(directory)
  @debug.assert_eq(
    replayed.comparison,
    @contracts.Consistent,
    msg=@debug.to_string(replayed),
  )
  for o in replayed.observations {
    @debug.assert_eq(o.output.status, @contracts.Exited(0))
    if o.phase == Execute {
      @debug.assert_eq(o.output.stdout, "-2147483648\n")
    }
  }
  for name in @fs.readdir("\{directory}/attempts") {
    let workspace = "\{directory}/attempts/\{name}"
    @debug.assert_eq(@host.read_text("\{workspace}/main.mbt"), source)
    @debug.assert_eq(
      @host.read_text("\{workspace}/moon.mod"),
      case.module_source,
    )
    @debug.assert_eq(
      @host.read_text("\{workspace}/moon.pkg"),
      case.package_source,
    )
  }
}

///|
async test "differential injection changes valid scalar results and preserves raw output" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/differential-injection-")
  defer @host.remove_tree(base)
  for
    (literal, protocol) in [
      ("0", "moonbit-int32-line-v1"),
      ("true", "moonbit-bool-line-v1"),
    ] {
    let case = saved_fixture(
      "fn main { println(\{literal}) }\n",
      protocol~,
      injected=true,
    )
    let directory = @artifacts.create_differential(base, case)
    let attempt = replay_differential(directory)
    @debug.assert_eq(
      attempt.comparison,
      @contracts.Difference("native-debug", "native-release"),
      msg=@debug.to_string(attempt),
    )
    assert_true(attempt.injected)
    for o in attempt.observations {
      if o.phase == Execute {
        @debug.assert_eq(o.output.stdout, "\{literal}\n")
        @debug.assert_eq(
          o.injected_stdout is Some(_),
          o.configuration == "native-release",
        )
      }
    }
    let report = @report.render_differential(attempt)
    assert_true(report.contains("fault injection"))
  }
}

///|
async test "a rejected saved program retains raw compiler errors as incomplete evidence" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/differential-rejection-")
  defer @host.remove_tree(base)
  let case = saved_fixture("fn main { let x : Int = true; println(x) }\n")
  let directory = @artifacts.create_differential(base, case)
  let attempt = replay_differential(directory)
  @debug.assert_eq(attempt.comparison, @contracts.Incomplete)
  @debug.assert_eq(attempt.observations.length(), 3)
  for o in attempt.observations {
    @debug.assert_eq(o.phase, @contracts.Build)
    assert_true(o.output.status is Exited(code) && code != 0)
    assert_true(o.output.stderr.contains("main.mbt"))
  }
  for name in @fs.readdir("\{directory}/attempts") {
    let record = @host.read_text("\{directory}/attempts/\{name}/attempt.json")
    assert_true(record.contains("Incomplete"))
    assert_false(record.contains("expected"))
  }
}

///|
async test "invalid saved protocol is rejected before starting a new attempt" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/invalid-protocol-")
  defer @host.remove_tree(base)
  let case = saved_fixture("fn main { println(0) }\n", protocol="unknown-v9")
  let directory = @artifacts.create_differential(base, case)
  let rejected = try {
    ignore(replay_differential(directory))
    false
  } catch {
    error => error.to_string().contains("unsupported result protocol")
  }
  assert_true(rejected)
  @debug.assert_eq(@fs.readdir("\{directory}/attempts").length(), 0)
}

///|
async test "replay rejects damaged saved source and never drops invalid plan members" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/invalid-evidence-")
  defer @host.remove_tree(base)
  let original = saved_fixture("fn main { println(0) }\n")
  for
    planned in [
      ["native-debug"],
      ["native-debug", "native-debug"],
      ["native-debug", "unknown-backend"],
    ] {
    let case = { ..original, configurations: planned, }
    let directory = @artifacts.create_differential(base, case)
    let rejected = try {
      ignore(replay_differential(directory))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
    @debug.assert_eq(@fs.readdir("\{directory}/attempts").length(), 0)
  }
  let directory = @artifacts.create_differential(base, original)
  @fs.write_file("\{directory}/original.mbt", "fn main { println(1) }\n")
  let rejected = try {
    ignore(replay_differential(directory))
    false
  } catch {
    error => error.to_string().contains("does not match case.json")
  }
  assert_true(rejected)
  @debug.assert_eq(@fs.readdir("\{directory}/attempts").length(), 0)
}

///|
async test "generation exhaustion reports the seed without creating a partial case" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/generation-failure-")
  defer @host.remove_tree(base)
  let message = try {
    ignore(
      run_differential(123, base~, limits={
        max_nodes: 1,
        max_depth: 0,
        max_attempts: 1,
      }),
    )
    ""
  } catch {
    error => error.to_string()
  }
  assert_true(message.contains("seed 123"))
  assert_true(message.contains("AttemptsExhausted"))
  @debug.assert_eq(@fs.readdir(base).length(), 0)
}
