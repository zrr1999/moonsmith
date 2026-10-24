///|
priv struct RecordedRuntimes {
  format_version : Int
  probes : Array[@contracts.ProcessEvidence]
} derive(ToJson, @json.FromJson)

///|
async test "five configurations use their own targets and runners and replay preserves the selected order" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/five-configurations-")
  defer @host.remove_tree(base)
  let planned = [
    "js-debug", "wasm-debug", "native-release", "wasm-gc-debug", "native-debug",
  ]
  for
    (source, expected, protocol) in [
      (
        "fn main { println(2147483647 + 1) }\n", "-2147483648\n", "moonbit-int32-line-v1",
      ),
      ("fn main { println(!false) }\n", "true\n", "moonbit-bool-line-v1"),
    ] {
    let case = { ..saved_fixture(source, protocol~), configurations: planned, }
    let directory = @artifacts.create_differential(base, case)
    let original = @host.read_text("\{directory}/case.json")
    for _ in 0..<2 {
      let run = replay_differential(directory)
      @debug.assert_eq(
        run.attempt.comparison,
        @contracts.Consistent,
        msg=@debug.to_string(run.attempt),
      )
      assert_true(run.save_error is None)
      assert_planned_observations(run.attempt.observations, planned, [
        Build,
        Execute,
      ])
      @debug.assert_eq(
        run.attempt.observations
        .filter(observation => observation.phase == Execute)
        .map(observation => observation.configuration),
        planned,
      )
      for observation in run.attempt.observations {
        @debug.assert_eq(observation.output.status, @contracts.Exited(0))
        let (target, mode) = match observation.configuration {
          "native-debug" => ("native", "debug")
          "native-release" => ("native", "release")
          "wasm-gc-debug" => ("wasm-gc", "debug")
          "wasm-debug" => ("wasm", "debug")
          "js-debug" => ("js", "debug")
          other => fail("unexpected configuration: \{other}")
        }
        if observation.phase == Build {
          @debug.assert_eq(observation.command.program, "moon")
          @debug.assert_eq(observation.command.args, [
            "build",
            "--target",
            target,
            "--\{mode}",
          ])
        } else {
          @debug.assert_eq(observation.output.stdout, expected)
          match target {
            "js" => {
              @debug.assert_eq(observation.command.program, "node")
              assert_true(
                observation.command.args[0].has_suffix("/generated.js"),
              )
            }
            "wasm" | "wasm-gc" => {
              @debug.assert_eq(observation.command.program, "moonrun")
              assert_true(
                observation.command.args[0].contains("/_build/\{target}/debug/"),
              )
            }
            _ =>
              assert_true(
                observation.command.program.has_suffix("/generated.exe"),
              )
          }
        }
      }
      let runtimes : RecordedRuntimes = @json.from_json(
        @json.parse(@host.read_text("\{run.attempt_directory}/runtimes.json")),
      )
      @debug.assert_eq(runtimes.format_version, 1)
      @debug.assert_eq(runtimes.probes.map(probe => probe.command.program), [
        "node", "moonrun",
      ])
      for probe in runtimes.probes {
        @debug.assert_eq(probe.command.args, ["--version"])
        @debug.assert_eq(probe.output.status, @contracts.Exited(0))
        assert_false(probe.output.stdout.trim().is_empty())
      }
      let report = @host.read_text("\{run.attempt_directory}/report.md")
      assert_true(report.contains("Runtime versions"))
      assert_true(report.contains("`node`"))
      @debug.assert_eq(@host.read_text("\{directory}/case.json"), original)
    }
    @debug.assert_eq(@host.list_directory("\{directory}/attempts").length(), 2)
  }
}

///|
async test "new backend failures retain all planned builds and no comparable result is invented" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/new-backend-failures-")
  defer @host.remove_tree(base)
  let case = {
    ..saved_fixture("fn main { let value : Int = true; println(value) }\n"),
    configurations: ["wasm-debug", "js-debug"],
  }
  let directory = @artifacts.create_differential(base, case)
  let run = replay_differential(directory)
  @debug.assert_eq(run.attempt.comparison, @contracts.Incomplete)
  assert_true(run.save_error is None)
  assert_planned_observations(run.attempt.observations, case.configurations, [
    Build,
  ])
  for observation in run.attempt.observations {
    assert_true(observation.output.status is Exited(code) && code != 0)
    assert_true(observation.output.stderr.contains("main.mbt"))
  }
}

///|
async test "runtime evidence save errors prevent a completion marker and failed probes remain unknown" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/runtime-evidence-")
  defer @host.remove_tree(base)
  let run = run_differential(seed=42, base~)
  let failed_probe : @contracts.ProcessEvidence = {
    command: {
      program: "node",
      args: ["--version"],
      cwd: base,
      timeout_ms: 10000,
      output_limit: 65536,
    },
    output: {
      status: HostError("fixture unavailable"),
      stdout: "",
      stderr: "",
    },
  }
  let report = @report.render_differential(run.attempt, runtimes=[failed_probe])
  assert_true(report.contains("`node`: unknown"))
  assert_true(report.contains("fixture unavailable"))
  let directory = @artifacts.begin_attempt(run.directory)
  @host.mkdir("\{directory}/runtimes.json")
  let failed = finish_differential(
    run.directory,
    run.case,
    directory,
    run.attempt,
    None,
    runtimes=[failed_probe],
  )
  assert_true(failed.save_error is Some(_))
  @debug.assert_eq(failed.attempt.comparison, run.attempt.comparison)
  assert_false(@host.exists("\{directory}/attempt.json"))
}

///|
async test "runtime replay compares saved identities and older attempts without probes remain executable" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/runtime-replay-")
  defer @host.remove_tree(base)
  let observed = run_differential(seed=42, base~, planned=[
    "js-debug", "native-debug",
  ])
  let historical = observed.runtimes.map(probe => {
    ..probe,
    output: { status: Exited(0), stdout: "v0.fixture\n", stderr: "", },
  })
  for probes in [historical, []] {
    let directory = @artifacts.create_differential(base, observed.case)
    let saved = @artifacts.begin_attempt(directory)
    @moon.prepare_saved(
      saved,
      observed.case.source,
      observed.case.module_source,
      observed.case.package_source,
    )
    @artifacts.finish_attempt(
      saved,
      observed.attempt,
      "fixture",
      runtimes=probes,
    )
    let original = @host.read_text("\{saved}/attempt.json")
    let replayed = replay_differential(directory)
    @debug.assert_eq(replayed.attempt.comparison, @contracts.Consistent)
    assert_true(replayed.save_error is None)
    let summary = describe_differential(replayed)
    if probes.is_empty() {
      assert_true(
        summary.contains("Runtime version comparison unavailable: node"),
      )
      assert_false(summary.contains("Runtime changed"))
    } else {
      assert_true(summary.contains("Runtime changed: node: v0.fixture ->"))
      let report = @host.read_text("\{replayed.attempt_directory}/report.md")
      assert_true(report.contains("Runtime changed: node: v0.fixture ->"))
      let previous : RecordedRuntimes = @json.from_json(
        @json.parse(@host.read_text("\{saved}/runtimes.json")),
      )
      @debug.assert_eq(previous.probes, probes)
      let candidate_replay = replay_differential(saved)
      assert_true(
        describe_differential(candidate_replay).contains(
          "Runtime changed: node:",
        ),
      )
    }
    @debug.assert_eq(@host.read_text("\{saved}/attempt.json"), original)
  }
}

///|
async test "unsupported or ambiguous runtime records reject replay before creating an attempt" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/runtime-invalid-")
  defer @host.remove_tree(base)
  let observed = run_differential(seed=42, base~)
  for
    record in [
      RecordedRuntimes::{ format_version: 2, probes: observed.runtimes, },
      RecordedRuntimes::{
        format_version: 1,
        probes: observed.runtimes + observed.runtimes,
      },
    ] {
    let directory = @artifacts.create_differential(base, observed.case)
    let saved = @artifacts.begin_attempt(directory)
    @artifacts.finish_attempt(saved, observed.attempt, "fixture")
    @host.write_new(
      "\{saved}/runtimes.json",
      ToJson::to_json(record).stringify(),
    )
    let error = try {
      ignore(replay_differential(directory))
      None
    } catch {
      error => Some(error.to_string())
    }
    assert_true(error is Some(message) && message.contains("runtime"))
    @debug.assert_eq(@host.list_directory("\{directory}/attempts").length(), 1)
  }
}
