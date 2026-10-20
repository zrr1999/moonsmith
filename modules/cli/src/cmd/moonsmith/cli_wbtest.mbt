///|
test "commands accept a config and repeated settings and reject obsolete or ambiguous arguments" {
  for
    args in [
      [],
      ["--help"],
      ["run", "--help"],
      ["replay", "--help"],
      ["run", "-h"],
    ] {
    @debug.assert_eq(parse(args), Help)
  }
  @debug.assert_eq(parse(["run"]), Run(None, []))
  @debug.assert_eq(
    parse([
      "run", "--set", "seed_start=-2147483648", "--config", "task file.toml", "--set=sample_count=2",
    ]),
    Run(Some("task file.toml"), ["seed_start=-2147483648", "sample_count=2"]),
  )
  @debug.assert_eq(
    parse(["run", "--config=task.toml"]),
    Run(Some("task.toml"), []),
  )
  @debug.assert_eq(parse(["replay", "saved case"]), Replay("saved case"))
  for
    args in [
      ["unknown"],
      ["run", "--unknown", "value"],
      ["run", "--seed", "42"],
      ["run", "task.toml"],
      ["run", "--set"],
      ["run", "--set="],
      ["run", "--config"],
      ["run", "--config", "--set", "sample_count=1"],
      ["run", "--config", "one", "--config", "two"],
      ["replay"],
      ["replay", "one", "two"],
      ["replay", "saved", "--set", "seed_start=42"],
    ] {
    let rejected = try {
      ignore(parse(args))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=args.join(" "))
  }
}

///|
async test "help describes the shared configuration and errors occur before a run starts" {
  let help = []
  @debug.assert_eq(cli([], output=line => help.push(line)), 0)
  assert_true(
    help.join("\n").contains("run [--config FILE] [--set KEY=VALUE]..."),
  )
  assert_true(help.join("\n").contains("replay CASE_DIR"))
  assert_true(help.join("\n").contains("generation.max_nodes"))
  assert_true(help.join("\n").contains("bounded reduction"))
  for
    (args, diagnostic) in [
      (["unknown"], "unknown command: unknown"),
      (["run", "--seed", "42"], "use --set seed_start=VALUE"),
      (["run", "--set"], "--set requires a value"),
      (["run", "--set", "seed_start=2147483648"], "seed_start"),
      (["run", "--set", "sample_count=0"], "sample_count"),
      (["run", "--set", "unknown=1"], "unknown"),
    ] {
    let output = []
    @debug.assert_eq(cli(args, output=line => output.push(line)), 1)
    let text = output.join("\n")
    assert_true(text.contains(diagnostic), msg=text)
    assert_false(text.contains("Planned configurations:"))
    assert_false(text.contains("Evidence: saved"))
  }
}

///|
async test "CLI runs default and file tasks through settings and saves the effective range" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/cli-task-")
  defer @host.remove_tree(base)
  let working = @host.current_directory()
  let relative = base[working.length() + 1:].to_owned()
  @host.mkdir("\{base}/config")
  let filename = "\{base}/config/task.toml"
  let source = "name = 'file-task'\nseed_start = 40\nsample_count = 2\n[output]\ndirectory = 'file-output'\n"
  @host.write_new(filename, source)
  for
    (config, count, name) in [
      ([], 1, "default"),
      (["--config", filename], 2, "file"),
    ] {
    let output = []
    let path = "\{relative}/\{name}"
    let args = ["run"] +
      config +
      [
        "--set",
        "seed_start=41",
        "--set",
        "seed_start=42",
        "--set",
        "generation.max_nodes=1",
        "--set",
        "generation.max_depth=0",
        "--set",
        "generation.max_attempts=2",
        "--set",
        "execution.configurations=['native-debug','native-release']",
        "--set",
        "execution.run_timeout_ms=5000",
        "--set",
        "reduction.candidate_limit=0",
        "--set",
        "output.directory='\{path}'",
      ]
    @debug.assert_eq(cli(args, output=line => output.push(line)), 0)
    let text = output.join("\n")
    assert_true(text.contains("Samples attempted: \{count}/\{count}"), msg=text)
    assert_true(text.contains("Seed: 42"), msg=text)
    if count == 2 {
      assert_true(text.contains("Seed: 43"), msg=text)
    }
    let directories = @host.list_directory("\{base}/\{name}")
    @debug.assert_eq(directories.length(), 1)
    let directory = "\{base}/\{name}/\{directories[0]}"
    let effective = @host.read_text("\{directory}/effective.toml")
    assert_true(effective.contains("seed_start = 42"))
    assert_true(effective.contains("sample_count = \{count}"))
    assert_true(effective.contains("directory = \"\{working}/\{path}\""))
    @debug.assert_eq(
      @host.list_directory("\{directory}/samples").length(),
      count,
    )
    assert_true(@host.exists("\{directory}/summary.json"))
    if name == "file" {
      @debug.assert_eq(@host.read_text("\{directory}/task.toml"), source)
    } else {
      assert_false(@host.exists("\{directory}/task.toml"))
    }
  }
  @debug.assert_eq(@host.read_text(filename), source)
  assert_false(@host.exists("\{base}/config/file-output"))
}

///|
async test "CLI presents automatic reduction and replays its confirmed source" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/cli-reduction-")
  defer @host.remove_tree(base)
  let run = @app.run_differential(
    seed=7,
    base~,
    injected=true,
    reduction_limit=1,
  )
  let output = []
  @debug.assert_eq(present(run, line => output.push(line)), 2)
  let summary = output.join("\n")
  assert_true(summary.contains("Reduction: confirmed"))
  assert_true(summary.contains("fault injection"))
  guard run.reduction is Some(reduction) &&
    reduction.confirmation_attempt is Some(directory) else {
    fail("missing confirmed replay material")
  }
  let replay_output = []
  @debug.assert_eq(
    cli(["replay", directory], output=line => replay_output.push(line)),
    2,
  )
  assert_false(replay_output.join("\n").contains("Reduction:"))
}

///|
async test "replay exit codes and summaries follow saved differential evidence" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/cli-replay-")
  defer @host.remove_tree(base)
  let original = @app.run_differential(seed=42, base~)
  assert_true(original.save_error is None)
  for
    (case, exit_code, result) in [
      (original.case, 0, "consistent"),
      ({ ..original.case, injected: true, }, 2, "difference observed"),
      (
        {
          ..original.case,
          source: "fn main { let x : Int = true; println(x) }\n",
        },
        3,
        "comparison incomplete",
      ),
      (
        { ..original.case, format_version: 999, },
        1,
        "unsupported differential case format",
      ),
    ] {
    let directory = @host.new_directory("\{base}/saved-")
    @host.mkdir("\{directory}/attempts")
    let files = [
      ("case.json", case.to_json().stringify()),
      ("original.mbt", case.source),
      ("moon.mod", case.module_source),
      ("moon.pkg", case.package_source),
    ]
    for (name, content) in files {
      @host.write_new("\{directory}/\{name}", content)
    }
    let output = []
    @debug.assert_eq(
      cli(["replay", directory], output=line => output.push(line)),
      exit_code,
    )
    let text = output.join("\n")
    assert_true(text.contains(result), msg=text)
    let attempts = @host.list_directory("\{directory}/attempts")
    if exit_code == 1 {
      assert_true(attempts.is_empty())
      assert_false(text.contains("Evidence: saved"))
    } else {
      assert_true(output[0].has_prefix("Planned configurations:"))
      assert_true(text.contains("Seed: 42"))
      assert_true(text.contains("Case: \{directory}"))
      assert_true(text.contains("Evidence: saved"))
      @debug.assert_eq(attempts.length(), 1)
      assert_true(
        @host.exists("\{directory}/attempts/\{attempts[0]}/attempt.json"),
      )
      if exit_code == 0 {
        assert_false(text.contains("native-debug:"))
      } else {
        assert_true(text.contains("native-debug:"))
        assert_true(text.contains("wasm-gc-debug:"))
      }
      if exit_code == 2 {
        assert_true(text.contains("fault injection"))
      }
      if exit_code == 3 {
        assert_true(text.contains("build: exited with code"))
      }
    }
    for (name, content) in files {
      @debug.assert_eq(@host.read_text("\{directory}/\{name}"), content)
    }
  }
}
