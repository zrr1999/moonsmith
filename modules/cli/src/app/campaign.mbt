///|
pub struct Run {
  directory : String
  original : @contracts.Attempt
  final_attempt : @contracts.Attempt
  attempts : Int
}

///|
async fn execute(
  directory : String,
  compiler : String,
  source : String,
  expected : String,
  nodes : Int,
  purpose : String,
  injected : Bool,
) -> @contracts.Attempt {
  let workspace = @artifacts.begin_attempt(directory)
  @moon.prepare(workspace, source)
  let observations = @moon.observe(workspace, inject=injected)
  let verdict = @engine.judge(expected, @moon.configurations(), observations)
  let attempt : @contracts.Attempt = {
    purpose,
    compiler,
    source,
    expected,
    nodes,
    observations,
    verdict,
  }
  @artifacts.finish_attempt(
    workspace,
    attempt,
    @report.render(attempt, injected~),
  )
  attempt
}

///|
pub async fn run(
  seed? : Int = 7,
  depth? : Int = 3,
  base? : String = "runs",
  injected? : Bool = false,
  reduction_limit? : Int = 16,
) -> Run {
  guard @moonbit.generate(seed, depth~) is Some(program) else {
    fail("depth must be between 0 and 4")
  }
  guard program.evaluate() is Some(value) else {
    fail("generator produced an invalid program")
  }
  guard reduction_limit >= 0 && reduction_limit <= 64 else {
    fail("reduction limit must be between 0 and 64")
  }
  let compiler = @moon.version()
  let case : @contracts.Case = {
    format_version: 1,
    generator: "int-bool-v1",
    seed,
    depth,
    source: program.emit(),
    expected: "\{value}\n",
    nodes: program.size(),
    injected,
  }
  let directory = @artifacts.create(base, case)
  let original = execute(
    directory,
    compiler,
    case.source,
    case.expected,
    case.nodes,
    "original",
    injected,
  )
  let mut final_attempt = original
  let mut attempts = 0
  if original.verdict is Finding(fingerprint) {
    let search = @engine.Reducer::new(
      program,
      fingerprint,
      limit=reduction_limit,
      size=p => p.size(),
      valid=p => p.valid(),
      candidates=p => p.candidates(),
    )
    while search.next() is Some(candidate) {
      guard candidate.evaluate() is Some(value) else {
        fail("invalid reduction candidate")
      }
      let attempt = execute(
        directory,
        compiler,
        candidate.emit(),
        "\{value}\n",
        candidate.size(),
        "reduction",
        injected,
      )
      if search.observe(attempt.verdict) {
        final_attempt = attempt
      }
    }
    attempts = search.attempts()
    // Recheck the selected case in a fresh compiler workspace before reporting reduction.
    let best = search.result()
    guard best.evaluate() is Some(expected) else {
      fail("invalid reduced program")
    }
    let confirmation = execute(
      directory,
      compiler,
      best.emit(),
      "\{expected}\n",
      best.size(),
      "confirmation",
      injected,
    )
    guard confirmation.verdict == original.verdict else {
      fail("finding did not reproduce during confirmation")
    }
    final_attempt = confirmation
  }
  { directory, original, final_attempt, attempts, }
}

///|
pub async fn replay(directory : String) -> @contracts.Attempt {
  let directory = @host.canonical(directory)
  let case = @artifacts.load(directory)
  guard case.generator == "int-bool-v1" else {
    fail("unsupported generator profile")
  }
  guard @moonbit.generate(case.seed, depth=case.depth) is Some(program) else {
    fail("invalid case configuration")
  }
  guard program.evaluate() is Some(value) else {
    fail("invalid original program")
  }
  guard program.emit() == case.source &&
    case.expected == "\{value}\n" &&
    program.size() == case.nodes else {
    fail("case does not match the recorded generator and reference result")
  }
  execute(
    directory,
    @moon.version(),
    case.source,
    case.expected,
    case.nodes,
    "replay",
    case.injected,
  )
}

///|
fn exit_code(verdict : @contracts.Verdict) -> Int {
  match verdict {
    Match => 0
    Finding(_) => 2
    Inconclusive(_) => 3
  }
}

///|
pub async fn cli(args : Array[String]) -> Int {
  if args.is_empty() || args == ["--help"] {
    println(
      "moonsmith run|demo [--seed INT] [--depth 0..4] [--out DIR] [--budget 0..64]",
    )
    println("moonsmith replay CASE_DIR")
    return 0
  }
  if args[0] == "replay" {
    guard args.length() == 2 else { fail("replay requires one case directory") }
    let attempt = replay(args[1])
    println("Replay: \{@debug.to_string(attempt.verdict)}")
    return exit_code(attempt.verdict)
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
  let result = run(seed~, depth~, base~, injected~, reduction_limit=budget)
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
  exit_code(result.final_attempt.verdict)
}
