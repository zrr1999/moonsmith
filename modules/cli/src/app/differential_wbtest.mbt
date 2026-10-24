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
      seed~,
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
    assert_planned_observations(
      run.attempt.observations,
      run.case.configurations,
      [Build, Execute],
    )
    @debug.assert_eq(run.reduction, None)
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
    let replayed = replay_differential(run.directory).attempt
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
  let replayed = replay_differential(directory).attempt
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
    let attempt = replay_differential(directory).attempt
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
  let attempt = replay_differential(directory).attempt
  @debug.assert_eq(attempt.comparison, @contracts.Incomplete)
  assert_planned_observations(attempt.observations, case.configurations, [Build])
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
      run_differential(seed=123, base~, limits={
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

///|
test "explicit seeds take precedence without consulting automatic entropy" {
  for seed in [-2147483648, 0, 2147483647] {
    @debug.assert_eq(
      choose_seed(Some(seed), () => fail("entropy must not be consulted")),
      seed,
    )
  }
  let mut selections = 0
  let seed = choose_seed(None, () => {
    selections += 1
    -12345
  })
  @debug.assert_eq(seed, -12345)
  @debug.assert_eq(selections, 1)
  let rejected = try {
    ignore(choose_seed(None, () => fail("entropy unavailable")))
    false
  } catch {
    error => error.to_string().contains("entropy unavailable")
  }
  assert_true(rejected)
}

///|
async test "an automatic seed is saved and explicitly reproduces the generated source" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/automatic-seed-")
  defer @host.remove_tree(base)
  let automatic = run_differential(base~)
  let saved = @artifacts.load_differential(automatic.directory)
  @debug.assert_eq(saved.generation.seed, automatic.case.generation.seed)
  @debug.assert_eq(
    automatic.attempt.comparison,
    @contracts.Consistent,
    msg=@debug.to_string(automatic.attempt),
  )
  let explicit = run_differential(seed=saved.generation.seed, base~)
  @debug.assert_eq(explicit.case.source, saved.source)
  @debug.assert_eq(explicit.case.generation, saved.generation)
  @debug.assert_eq(explicit.attempt.comparison, @contracts.Consistent)
  assert_true(explicit.directory != automatic.directory)
  @debug.assert_eq(@fs.readdir(base).length(), 2)
}

///|
async test "storage failures retain the difference and identify incomplete evidence" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/save-failure-")
  defer @host.remove_tree(base)
  let run = run_differential(seed=42, base~, injected=true)
  assert_true(run.save_error is None)
  for blocked in ["report.md", "attempt.json"] {
    let directory = @artifacts.begin_attempt(run.directory)
    @host.mkdir("\{directory}/\{blocked}")
    let failed = finish_differential(
      run.directory,
      run.case,
      directory,
      run.attempt,
      None,
    )
    assert_true(failed.save_error is Some(_))
    @debug.assert_eq(failed.attempt.comparison, run.attempt.comparison)
    @debug.assert_eq(failed.attempt.observations, run.attempt.observations)
    let summary = describe_differential(failed)
    assert_true(summary.contains("difference observed"))
    assert_true(summary.contains("saving failed"))
    assert_true(summary.contains("Seed: 42"))
    assert_true(summary.contains(directory))
    assert_false(summary.contains("Evidence: saved"))
    if blocked == "report.md" {
      assert_false(@host.exists("\{directory}/attempt.json"))
    } else {
      assert_true(@host.exists("\{directory}/report.md"))
      @debug.assert_eq(@fs.kind("\{directory}/attempt.json"), @fs.Directory)
    }
  }
}

///|
async test "replay reports a changed toolchain and preserves the prior record" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/toolchain-change-")
  defer @host.remove_tree(base)
  let run = run_differential(seed=42, base~)
  // Model a case produced by a different toolchain, then preserve that fixture verbatim.
  let original = {
    ..run.attempt,
    toolchain: {
      ..run.attempt.toolchain,
      output: {
        ..run.attempt.toolchain.output,
        stdout: "fixture-old-toolchain\n",
      },
    },
  }
  let original_record = original.to_json().stringify()
  @fs.write_file("\{run.attempt_directory}/attempt.json", original_record)
  let replay = replay_differential(run.directory)
  assert_true(replay.save_error is None)
  @debug.assert_eq(replay.attempt.comparison, @contracts.Consistent)
  let summary = describe_differential(replay)
  assert_true(summary.contains("Toolchain changed"))
  assert_true(summary.contains("fixture-old-toolchain"))
  @debug.assert_eq(
    @host.read_text("\{run.attempt_directory}/attempt.json"),
    original_record,
  )
  @debug.assert_eq(
    @host.list_directory("\{run.directory}/attempts").length(),
    2,
  )
}

///|
async test "replay uses and announces the saved configuration subset and order" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/plan-notice-")
  defer @host.remove_tree(base)
  let case = {
    ..saved_fixture("fn main { println(0) }\n"),
    configurations: ["native-release", "native-debug"],
  }
  let directory = @artifacts.create_differential(base, case)
  let mut announced : Array[String] = []
  let result = replay_differential(directory, on_plan=plan => announced = plan)
  @debug.assert_eq(announced, case.configurations)
  assert_planned_observations(
    result.attempt.observations,
    case.configurations,
    [Build, Execute],
  )
  @debug.assert_eq(
    result.attempt.observations
    .filter(observation => observation.phase == Execute)
    .map(observation => observation.configuration),
    case.configurations,
  )
  @debug.assert_eq(result.attempt.comparison, @contracts.Consistent)
  assert_true(result.save_error is None)
}

///|
test "summaries preserve differences alongside failures and unknown toolchain probes" {
  let case = saved_fixture("fn main { println(0) }\n")
  let command : @contracts.Command = {
    program: "fixture",
    args: [],
    cwd: "/fixture",
    timeout_ms: 1,
    output_limit: 1024,
  }
  let observations : Array[@contracts.Observation] = []
  for
    (configuration, value) in [
      ("native-debug", "0\n"),
      ("native-release", "1\n"),
    ] {
    for phase in [@contracts.Build, @contracts.Execute] {
      observations.push({
        configuration,
        phase,
        command,
        output: {
          status: Exited(0),
          stdout: if phase == Execute {
            value
          } else {
            ""
          },
          stderr: "",
        },
        injected_stdout: None,
      })
    }
  }
  observations.push({
    configuration: "wasm-gc-debug",
    phase: Build,
    command,
    output: { status: TimedOut, stdout: "", stderr: "fixture timeout\n", },
    injected_stdout: None,
  })
  let probe : @contracts.ProcessEvidence = {
    command,
    output: { status: Exited(1), stdout: "unknown", stderr: "probe failed\n", },
  }
  let attempt : @contracts.DifferentialAttempt = {
    format_version: 2,
    purpose: "replay",
    source: case.source,
    configurations: case.configurations,
    result_protocol: case.result_protocol,
    toolchain: probe,
    platform: probe,
    injected: false,
    observations,
    comparison: @engine.compare(case.configurations, observations, normalize=value => {
      @moonbit.Ty::Int.normalize_output(value)
    }),
  }
  let run : DifferentialRun = {
    directory: "/fixture/case",
    case,
    attempt,
    attempt_directory: "/fixture/attempt",
    original_toolchain: Some(probe),
    runtimes: [],
    original_runtimes: None,
    save_error: None,
    reduction: None,
    build_reduction: None,
  }
  let text = describe_differential(run)
  assert_true(text.contains("difference observed"))
  assert_true(text.contains("Valid results: 2/3"))
  assert_true(text.contains("native-debug: 0"))
  assert_true(text.contains("native-release: 1"))
  assert_true(text.contains("wasm-gc-debug: build: timed out"))
  assert_true(text.contains("Toolchain: unknown"))
  assert_true(text.contains("probe failed"))
  assert_true(text.contains("version comparison is unavailable"))
  assert_false(text.contains("Toolchain changed"))
}
