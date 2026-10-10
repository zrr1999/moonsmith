///|
async test "real compiler matrix agrees with the reference and replay preserves the original" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/integration-")
  defer @host.remove_tree(base)
  for seed in [7, 42] {
    let result = run(seed~, base~)
    @debug.assert_eq(result.original.verdict, @contracts.Match)
    @debug.assert_eq(result.original.observations.length(), 6)
    for o in result.original.observations {
      @debug.assert_eq(o.output.status, @contracts.Exited(0))
      assert_true(o.injected_stdout is None)
    }
    let original = @host.read_text("\{result.directory}/original.mbt")
    let attempts = "\{result.directory}/attempts"
    let before = @fs.readdir(attempts)
    let saved = Map([])
    for name in before {
      saved[name] = @host.read_text("\{attempts}/\{name}/attempt.json")
    }
    let replayed = replay(result.directory)
    @debug.assert_eq(@fs.readdir(attempts).length(), before.length() + 1)
    for name, json in saved {
      @debug.assert_eq(
        @host.read_text("\{attempts}/\{name}/attempt.json"),
        json,
      )
    }
    @debug.assert_eq(replayed.verdict, @contracts.Match)
    @debug.assert_eq(replayed.source, original)
    @debug.assert_eq(
      @host.read_text("\{result.directory}/original.mbt"),
      original,
    )
    @debug.assert_eq(replayed.purpose, "replay")
  }
}

///|
async test "injected mismatch reduces to one node and survives fresh confirmation and replay" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/reduction-")
  defer @host.remove_tree(base)
  let result = run(seed=7, base~, injected=true)
  @debug.assert_eq(
    result.original.verdict,
    @contracts.Finding({
      configuration: "native-release",
      phase: Execute,
      kind: Mismatch,
    }),
  )
  @debug.assert_eq(result.final_attempt.verdict, result.original.verdict)
  @debug.assert_eq(result.final_attempt.nodes, 1)
  assert_true(result.original.nodes > result.final_attempt.nodes)
  assert_true(result.attempts <= 16)
  @debug.assert_eq(result.final_attempt.purpose, "confirmation")
  for o in result.original.observations {
    if o.phase == Execute {
      @debug.assert_eq(o.output.stdout, result.original.expected)
    }
  }
  let replayed = replay(result.directory)
  @debug.assert_eq(replayed.verdict, result.original.verdict)
  @debug.assert_eq(
    @host.read_text("\{result.directory}/original.mbt"),
    result.original.source,
  )
}

///|
async test "replay rejects a case with an inconsistent seed before execution" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/invalid-case-")
  defer @host.remove_tree(base)
  let case : @contracts.Case = {
    format_version: 1,
    generator: "int-bool-v1",
    seed: 7,
    depth: 3,
    source: "fn main { println(123) }\n",
    expected: "123\n",
    nodes: 1,
    injected: false,
  }
  let directory = @artifacts.create(base, case)
  let rejected = try {
    ignore(replay(directory))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
