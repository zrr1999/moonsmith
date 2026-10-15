///|
test "commands expose only the differential workflow and explicit seeds" {
  for args in [[], ["--help"], ["run", "--help"], ["replay", "--help"]] {
    @debug.assert_eq(parse(args), Help)
  }
  @debug.assert_eq(parse(["run"]), Run(None))
  for
    (text, seed) in [
      ("-2147483648", -2147483648),
      ("0", 0),
      ("2147483647", 2147483647),
    ] {
    @debug.assert_eq(parse(["run", "--seed", text]), Run(Some(seed)))
  }
  @debug.assert_eq(parse(["replay", "saved case"]), Replay("saved case"))
  for
    args in [
      ["demo"],
      ["unknown"],
      ["run", "--depth", "2"],
      ["run", "--budget", "16"],
      ["run", "--seed"],
      ["run", "--seed", "invalid"],
      ["run", "--seed", "2147483648"],
      ["run", "--seed", "-2147483649"],
      ["run", "--seed", "1", "--seed", "2"],
      ["replay"],
      ["replay", "one", "two"],
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
async test "help succeeds and input errors identify the invalid input" {
  let help = []
  @debug.assert_eq(cli([], output=line => help.push(line)), 0)
  assert_true(help.join("\n").contains("run [--seed SEED]"))
  assert_true(help.join("\n").contains("replay CASE_DIR"))
  for
    (args, diagnostic) in [
      (["demo"], "unknown command: demo"),
      (["run", "--seed", "bad"], "--seed"),
      (["run", "--seed"], "usage:"),
    ] {
    let output = []
    @debug.assert_eq(cli(args, output=line => output.push(line)), 1)
    let text = output.join("\n")
    assert_true(text.contains(diagnostic))
    assert_false(text.contains("Planned configurations:"))
    assert_false(text.contains("Evidence: saved"))
  }
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
        { ..original.case, format_version: 1, },
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
