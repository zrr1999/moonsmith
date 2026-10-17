///|
enum Operation {
  Help
  Run(Int?)
  Replay(String)
} derive(Eq, @debug.Debug)

///|
fn parse(args : Array[String]) -> Operation raise {
  if args.is_empty() ||
    args == ["--help"] ||
    args == ["run", "--help"] ||
    args == ["replay", "--help"] {
    return Help
  }
  match args[0] {
    "run" => {
      if args.length() == 1 {
        return Run(None)
      }
      guard args.length() == 3 && args[1] == "--seed" else {
        fail("usage: moonsmith run [--seed SEED]")
      }
      let seed = @string.parse_int(args[2]) catch {
        _ => fail("--seed must be a signed 32-bit integer")
      }
      Run(Some(seed))
    }
    "replay" => {
      guard args.length() == 2 else { fail("usage: moonsmith replay CASE_DIR") }
      Replay(args[1])
    }
    command => fail("unknown command: \{command}; use --help")
  }
}

///|
fn present(run : @app.DifferentialRun, output : (String) -> Unit) -> Int {
  output(@app.describe_differential(run))
  if run.save_error is Some(_) {
    return 1
  }
  if run.reduction is Some(reduction) && reduction.error is Some(_) {
    return 1
  }
  match run.attempt.comparison {
    Consistent => 0
    Difference(_, _) => 2
    Incomplete => 3
  }
}

///|
async fn cli(
  args : Array[String],
  output? : (String) -> Unit = line => println(line),
) -> Int {
  try {
    match parse(args) {
      Help => {
        output(
          [
            "MoonSmith — single-case differential compiler testing",
            "",
            "moonsmith run [--seed SEED]",
            "moonsmith replay CASE_DIR_OR_ATTEMPT_DIR",
            "",
            "SEED is a signed 32-bit integer; omitted seeds are selected automatically and recorded.",
            "Configurations: \{@app.differential_configurations().join(", ")}",
            "Runs continue through all configurations and save their evidence.",
            "A difference triggers bounded reduction and one fresh confirmation.",
            "Replay uses saved material with the current toolchain and appends a new record.",
            "Pass a saved attempt directory to replay a reduced program without restarting reduction.",
            "Exit codes: 0 consistent, 2 difference, 3 incomplete comparison, 1 operation error.",
          ].join("\n"),
        )
        0
      }
      Run(seed) =>
        present(
          @app.run_differential(seed?, on_plan=plan => {
            output("Planned configurations: \{plan.join(", ")}")
          }),
          output,
        )
      Replay(directory) =>
        present(
          @app.replay_differential(directory, on_plan=plan => {
            output("Planned configurations: \{plan.join(", ")}")
          }),
          output,
        )
    }
  } catch {
    error => {
      output("MoonSmith: \{error}")
      1
    }
  }
}
