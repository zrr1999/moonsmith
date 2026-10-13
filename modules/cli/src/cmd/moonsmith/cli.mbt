///|
async fn cli(args : Array[String]) -> Int {
  if args.is_empty() || args == ["--help"] {
    println(
      "moonsmith run|demo [--seed INT] [--depth 0..4] [--out DIR] [--budget 0..64]",
    )
    println("moonsmith replay CASE_DIR")
    return 0
  }
  if args[0] == "replay" {
    guard args.length() == 2 else { fail("replay requires one case directory") }
    let attempt = @app.replay(args[1])
    println("Replay: \{@debug.to_string(attempt.verdict)}")
    return match attempt.verdict {
      Match => 0
      Finding(_) => 2
      Inconclusive(_) => 3
    }
  }
  guard args[0] == "run" || args[0] == "demo" else {
    fail("unknown command: \{args[0]}")
  }
  let mut seed = 7
  let mut depth = 3
  let mut base = "runs"
  let mut budget = 16
  let mut i = 1
  while i < args.length() {
    guard i + 1 < args.length() else { fail("missing option value") }
    match args[i] {
      "--seed" => seed = @string.parse_int(args[i + 1])
      "--depth" => depth = @string.parse_int(args[i + 1])
      "--out" => base = args[i + 1]
      "--budget" => budget = @string.parse_int(args[i + 1])
      flag => fail("unknown option: \{flag}")
    }
    i += 2
  }
  let injected = args[0] == "demo"
  let result = @app.run(seed~, depth~, base~, injected~, reduction_limit=budget)
  println("Case: \{result.directory}")
  let evidence = if injected {
    "fault injection"
  } else {
    "real compiler execution"
  }
  println("Evidence: \{evidence}")
  println("Result: \{@debug.to_string(result.final_attempt.verdict)}")
  println(
    "Nodes: \{result.original.nodes} -> \{result.final_attempt.nodes}; reduction attempts: \{result.attempts}",
  )
  match result.final_attempt.verdict {
    Match => 0
    Finding(_) => 2
    Inconclusive(_) => 3
  }
}
