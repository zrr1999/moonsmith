///|
pub struct Run {
  directory : String
  original : @contracts.Attempt
  final_attempt : @contracts.Attempt
  attempts : Int32
}

///|
async fn execute(
  directory : String,
  compiler : String,
  source : String,
  expected : String,
  nodes : Int32,
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
  seed~ : Int32 = 7,
  depth~ : Int32 = 3,
  base~ : String = "runs",
  injected~ : Bool = false,
  reduction_limit~ : Int32 = 16,
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
    let predicate : @contracts.FailurePredicate = {
      oracle: "reference",
      fingerprint,
    }
    guard @engine.Reducer::new(
        program,
        @engine.reference_assessment(
          original.expected,
          @moon.configurations(),
          original.observations,
        ),
        predicate,
        id=directory,
        limit=reduction_limit,
        better=(candidate, incumbent) => candidate.size() < incumbent.size(),
        valid=p => p.valid(),
        operations=[p => p.candidates()],
      )
      is Ok(search) else {
      fail("initial reduction evidence is invalid")
    }
    while search.next() is Some(request) {
      let candidate = request.program
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
      ignore(
        search.observe(
          request.id,
          @engine.reference_assessment(
            attempt.expected,
            @moon.configurations(),
            attempt.observations,
          ),
        ),
      )
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
    guard @engine.match_failure(
        predicate,
        @engine.reference_assessment(
          confirmation.expected,
          @moon.configurations(),
          confirmation.observations,
        ),
      ) ==
      Preserved else {
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
